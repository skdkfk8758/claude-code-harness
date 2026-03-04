#!/usr/bin/env bash
# CCH Mode Detector - UserPromptSubmit Hook
# stdin으로 JSON 수신 → 의도 감지 → 모드 추천 + 팀 추천 + 문서화 안내 출력
#
# Fix log:
#   - sed → jq: 유니코드/특수문자/멀티라인 프롬프트 파싱 안정화
#   - 키워드 매칭: 단일 키워드 → 복합 스코어링으로 false positive 감소
#   - additionalContext: ACTION REQUIRED 마커 추가로 Agent 인지율 향상

set -uo pipefail

# stdin 읽기 (macOS 호환: timeout 대신 read 사용)
INPUT=""
while IFS= read -r -t 2 line; do
  INPUT="${INPUT}${line}"
done
[ -z "$INPUT" ] && INPUT='{}'

# prompt 추출 (jq 사용 — 유니코드/이스케이프/멀티라인 안전)
if command -v jq >/dev/null 2>&1; then
  PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null)
else
  # jq 미설치 시 fallback (sed)
  PROMPT=$(echo "$INPUT" | sed -n 's/.*"prompt"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
fi

# 프롬프트가 비어있거나 짧으면 조용히 종료
if [ -z "$PROMPT" ] || [ ${#PROMPT} -lt 5 ]; then
  echo '{"continue":true,"suppressOutput":true}'
  exit 0
fi

# 현재 모드 읽기
CURRENT_MODE=$(cat .claude/cch/mode 2>/dev/null || echo "code")

# --- 모드 감지 (복합 스코어링) ---
# 단일 키워드 매칭 대신 카테고리별 스코어를 합산하여 판단
# threshold=2: 최소 2개 시그널이 겹쳐야 모드 추천 발동
detect_intent() {
  local prompt="$1"

  # plan 모드: 구조적 설계 의도가 명확한 경우만
  local plan_score=0
  # 강한 시그널 (단독으로 +2)
  echo "$prompt" | grep -qiE '아키텍처|architect|blueprint|시스템\s*설계|system\s*design' && plan_score=$((plan_score+2))
  # 중간 시그널 (+1씩, 조합 필요)
  echo "$prompt" | grep -qiE '설계|design|기획' && plan_score=$((plan_score+1)) || true
  echo "$prompt" | grep -qiE '구조|structure|계층|layer' && plan_score=$((plan_score+1)) || true
  echo "$prompt" | grep -qiE '계획|plan|로드맵|roadmap|전략|strategy' && plan_score=$((plan_score+1)) || true
  echo "$prompt" | grep -qiE 'PRD|요구사항|requirement|spec' && plan_score=$((plan_score+1)) || true
  if [ $plan_score -ge 2 ]; then
    echo "plan"; return
  fi

  echo ""
}

# --- 팀 파이프라인 후보 감지 ---
detect_team_candidate() {
  local prompt="$1"
  if echo "$prompt" | grep -qiE '(구현|개발|만들어|추가).*(테스트|검증)|(implement|build).*(test|verify)'; then
    echo "true"; return
  fi
  local c=0
  echo "$prompt" | grep -qiE '구현|개발|implement|build|create' && c=$((c+1)) || true
  echo "$prompt" | grep -qiE '테스트|test|검증|verify' && c=$((c+1)) || true
  echo "$prompt" | grep -qiE 'API|데이터베이스|인증|로그인|결제|auth|login|payment' && c=$((c+1)) || true
  [ $c -ge 2 ] && echo "true" || echo "false"
}

DETECTED=$(detect_intent "$PROMPT")
IS_TEAM=$(detect_team_candidate "$PROMPT")
CONTEXT=""

# 모드 추천
if [ -n "$DETECTED" ] && [ "$DETECTED" != "$CURRENT_MODE" ]; then
  CONTEXT="[CCH ACTION REQUIRED] 이 요청은 '$DETECTED' 모드에 적합합니다 (현재: $CURRENT_MODE). 사용자에게 모드 전환을 안내하세요: bash bin/cch mode $DETECTED"
fi

# 팀 추천
if [ "$IS_TEAM" = "true" ] && [ "$CURRENT_MODE" = "code" ]; then
  CONTEXT="$CONTEXT [CCH SUGGESTION] 이 작업은 /cch-team 파이프라인(개발->테스트->검증)을 사용하면 효과적입니다. 사용자에게 안내하세요."
fi

# 문서화 안내 (plan 모드 전환 시)
if [ -n "$DETECTED" ] && [ "$DETECTED" = "plan" ]; then
  CONTEXT="$CONTEXT [CCH-DOC] 설계 결과물은 docs/plans/ 에 영구 문서로 저장하세요. 파일명 규칙: YYYY-MM-DD-<work-id>.md"
fi

# 추천할 내용이 없으면 조용히 종료
if [ -z "$CONTEXT" ]; then
  echo '{"continue":true,"suppressOutput":true}'
  exit 0
fi

cat <<HOOK_EOF
{"continue":true,"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"$CONTEXT"}}
HOOK_EOF
