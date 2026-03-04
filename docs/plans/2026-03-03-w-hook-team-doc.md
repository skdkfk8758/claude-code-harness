# CCH 지능형 모드 감지 + 팀 워크플로우 + 문서 자동화

- 작업 ID: w-hook-team-doc
- TODO 항목: #50, #51, #52
- 생성일: 2026-03-03
- 상태: doing

## 배경

CCH의 모드 전환이 수동(`/cch-mode`)으로만 가능하고,
`hooks/hooks.json`이 비어있어 사용자 메시지에 대한 자동 처리가 없었음.
개발 작업 시 dev → test → verify 파이프라인이 구조화되어 있지 않고,
작업 중 생성되는 PLAN/TODO는 휘발성 context에만 존재하여 세션 종료 시 소실됨.

## 구현 범위

- [x] #50 `w-hook-mode-detect`: UserPromptSubmit 모드 자동 감지 hook
  - `scripts/mode-detector.sh`: 한국어/영어 키워드 기반 의도 분석
  - `hooks/hooks.json`: UserPromptSubmit hook 등록
  - system-reminder로 모드 추천 주입, Claude가 최종 판단

- [x] #51 `w-team-pipeline`: /cch-team 순차 파이프라인 스킬
  - `skills/cch-team/SKILL.md`: Developer → Test Engineer → Verifier
  - Step 0에서 `docs/plans/<work-id>.md` 자동 생성 + 경로 명시
  - `bin/cch work create` 연동으로 작업 항목 자동 등록

- [x] #52 `w-doc-auto-persist`: 문서 자동 영구화 + 경로 명시
  - `scripts/plan-doc-reminder.sh`: ExitPlanMode 시 문서 저장 안내
  - `/cch-team` Step 4에서 결과 문서 업데이트 + 경로 보고
  - 기존 네이밍 규칙 준수: `docs/plans/YYYY-MM-DD-<work-id>.md`

## 변경 파일

| 파일 | 유형 | 관련 # | 설명 |
|------|------|--------|------|
| `scripts/mode-detector.sh` | 신규 | #50 | 모드 감지 + 팀 추천 + 문서화 안내 hook |
| `scripts/plan-doc-reminder.sh` | 신규 | #52 | ExitPlanMode 시 문서 영구화 안내 hook |
| `hooks/hooks.json` | 수정 | #50,#52 | UserPromptSubmit + PreToolUse hook 등록 |
| `skills/cch-team/SKILL.md` | 신규 | #51 | 문서화 통합 팀 파이프라인 스킬 |
| `docs/TODO.md` | 수정 | #50,#51,#52 | 신규 작업 항목 3건 추가 |
| `dist/.../scripts/*` | 신규 | — | dist 동기화 |
| `dist/.../hooks/hooks.json` | 수정 | — | dist 동기화 |
| `dist/.../skills/cch-team/` | 신규 | — | dist 동기화 |

## 아키텍처

```
사용자 메시지
     │
     ▼
┌─ UserPromptSubmit Hooks ────────────────────────┐
│  CCH: mode-detector.sh → 모드 추천 + 팀 추천   │
│         (#50)            + 문서화 안내 (#52)     │
└──────────────────────┬──────────────────────────┘
                       ▼
┌─ Claude (AI) 판단 ──────────────────────────────┐
│  - 모드 전환? → bash bin/cch mode <mode>         │
│  - 팀 파이프라인? → /cch-team (#51) 실행         │
│  - Plan Mode? → EnterPlanMode                    │
└──────────────────────┬──────────────────────────┘
                       ▼
┌─ /cch-team 실행 시 (#51) ───────────────────────┐
│  Step 0: docs/plans/<work-id>.md 생성            │
│  Step 1: Developer agent (executor, worktree)    │
│  Step 2: Test Engineer agent                     │
│  Step 3: Verifier agent                          │
│  Step 4: 문서 업데이트 + work transition done    │
└──────────────────────┬──────────────────────────┘
                       ▼
┌─ ExitPlanMode 시 (#52) ────────────────────────┐
│  PreToolUse hook: plan-doc-reminder.sh          │
│  → "docs/plans/에 영구 저장하세요" 안내         │
└─────────────────────────────────────────────────┘
```

## 파이프라인 결과

| 단계 | 상태 | 요약 |
|------|------|------|
| mode-detector.sh (#50) | done | 4가지 테스트 케이스 통과 |
| plan-doc-reminder.sh (#52) | done | JSON 출력 정상 |
| cch-team SKILL.md (#51) | done | frontmatter 검증 통과 |
| dist 동기화 | done | scripts/hooks/skills 복사 완료 |
| TODO.md 갱신 | done | #50~#52 추가, Critical Path 갱신 |
| work item 등록 | done | 3건 생성 완료 |

## 완료
- 완료일: 2026-03-03
