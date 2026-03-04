#!/usr/bin/env bash
# CCH Mode Detector v2 - UserPromptSubmit Hook
# stdin JSON → plan/code 모드 추천 출력
# v2: plan/code 2모드만 지원

set -uo pipefail

INPUT=""
while IFS= read -r -t 2 line; do
  INPUT="${INPUT}${line}"
done
[ -z "$INPUT" ] && INPUT='{}'

# prompt 추출
if command -v jq >/dev/null 2>&1; then
  PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null)
else
  PROMPT=$(echo "$INPUT" | sed -n 's/.*"prompt"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
fi

if [ -z "$PROMPT" ] || [ ${#PROMPT} -lt 5 ]; then
  echo '{"continue":true,"suppressOutput":true}'
  exit 0
fi

CURRENT_MODE=$(cat .claude/cch/mode 2>/dev/null || echo "code")

# plan 모드 감지: 설계 의도가 명확한 경우만
detect_intent() {
  local prompt="$1"
  local plan_score=0

  # 강한 시그널 (+2)
  echo "$prompt" | grep -qiE '아키텍처|architect|blueprint|시스템\s*설계|system\s*design' && plan_score=$((plan_score+2))
  # 중간 시그널 (+1, 조합 필요)
  echo "$prompt" | grep -qiE '설계|design|기획' && plan_score=$((plan_score+1)) || true
  echo "$prompt" | grep -qiE '구조|structure|계층|layer' && plan_score=$((plan_score+1)) || true
  echo "$prompt" | grep -qiE '계획|plan|로드맵|roadmap|전략|strategy' && plan_score=$((plan_score+1)) || true
  echo "$prompt" | grep -qiE 'PRD|요구사항|requirement|spec' && plan_score=$((plan_score+1)) || true

  [ $plan_score -ge 2 ] && echo "plan" || echo ""
}

DETECTED=$(detect_intent "$PROMPT")

if [ -n "$DETECTED" ] && [ "$DETECTED" != "$CURRENT_MODE" ]; then
  CONTEXT="[CCH] 이 요청은 '$DETECTED' 모드에 적합합니다 (현재: $CURRENT_MODE). 모드 전환: bash bin/cch mode $DETECTED"
  if [ "$DETECTED" = "plan" ]; then
    CONTEXT="$CONTEXT [CCH-DOC] 설계 결과물은 docs/plans/에 저장하세요. 파일명: YYYY-MM-DD-<work-id>.md"
  fi
  cat <<HOOK_EOF
{"continue":true,"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"$CONTEXT"}}
HOOK_EOF
else
  echo '{"continue":true,"suppressOutput":true}'
fi
