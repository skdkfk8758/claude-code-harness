#!/usr/bin/env bash
# CCH Plan Doc Reminder - ExitPlanMode PreToolUse Hook
# Plan 승인 시 docs/plans/에 영구 저장 안내

set -uo pipefail

DATE=$(date +%Y-%m-%d)
CONTEXT="[CCH-DOC] Plan 승인 시 다음을 수행하세요: (1) docs/plans/${DATE}-<work-id>.md 에 영구 저장 (2) bash bin/cch work create <work-id> 로 작업 등록 (3) 문서 경로를 사용자에게 명시"

cat <<EOF
{"continue":true,"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"$CONTEXT"}}
EOF
