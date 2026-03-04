# CCH + OMC 통합 설계

> CCH 워크플로우/스킬과 OMC v4.6.0 오케스트레이션 계층의 통합 방안

- 작성일: 2026-03-04
- 상태: Draft
- 관련: OMC v4.6.0, CCH v0.1.0

---

## 1. 현황: 이중 워크플로우 런타임

CCH와 OMC는 **모두 Claude Code 플러그인**으로 등록되어 있으며, `~/.claude/settings.json`에서 둘 다 `enabled: true`이므로 **동일 이벤트에 대해 양쪽 hooks가 동시에 발화**한다.

### 1.1 이벤트별 실행 맵

| 이벤트 | CCH 훅 | OMC 훅 | 관계 |
|--------|--------|--------|------|
| SessionStart | (없음) | session-start, project-memory-session | OMC 단독 |
| UserPromptSubmit | mode-detector, activity-tracker | keyword-detector, skill-injector | **양쪽 발화** |
| PreToolUse:* | (없음) | pre-tool-enforcer | OMC 단독 |
| PreToolUse:ExitPlanMode | plan-doc-reminder | context-safety | **양쪽 발화** |
| PreToolUse:TaskCreate | activity-tracker | pre-tool-enforcer | **양쪽 발화** |
| PreToolUse:TaskUpdate | activity-tracker | pre-tool-enforcer | **양쪽 발화** |
| PermissionRequest:Bash | (없음) | permission-handler | OMC 단독 |
| PostToolUse:* | (없음) | post-tool-verifier, project-memory | OMC 단독 |
| PostToolUse:ExitPlanMode | plan-bridge | + OMC:post-tool-verifier, project-memory | **양쪽 발화** |
| PostToolUse:Write\|Edit | todo-sync-check | + OMC:post-tool-verifier, project-memory | **양쪽 발화** |
| PostToolUseFailure | (없음) | post-tool-use-failure | OMC 단독 |
| SubagentStart/Stop | (없음) | subagent-tracker, verify-deliverables | OMC 단독 |
| PreCompact | (없음) | pre-compact, project-memory-precompact | OMC 단독 |
| Stop | summary-writer | context-guard-stop, persistent-mode, code-simplifier | **양쪽 발화** |
| SessionEnd | (없음) | session-end | OMC 단독 |

### 1.2 역할 분리

두 시스템은 **보완 관계**이며 기능적 충돌은 없다:

- **CCH (7개 훅)**: 프로젝트 고유 워크플로우
  - 의도 감지 (mode-detector) → 활동 기록 (activity-tracker) → 플랜 브릿지 (plan-bridge) → TODO 동기화 (todo-sync-check) → 세션 요약 (summary-writer)
  - 상태 저장: `.claude/cch/`

- **OMC (16개 훅)**: 오케스트레이션 인프라
  - 키워드 감지 → 스킬 주입 → 도구 강제 → 메모리 관리 → 서브에이전트 추적 → 컴팩션 복원 → 영속 모드
  - 상태 저장: `.omc/`

```
사용자 프롬프트
    │
    ├─ CCH: mode-detector (의도 분류) ─→ .claude/cch/mode
    ├─ CCH: activity-tracker (활동 기록) ─→ .claude/cch/last_activity
    ├─ OMC: keyword-detector (매직 키워드) ─→ system-reminder 주입
    └─ OMC: skill-injector (스킬 매칭) ─→ system-reminder 주입
```

### 1.3 주의사항: 토큰 오버헤드

**PostToolUse:Write|Edit** 이벤트에서 양쪽 모두 `system-reminder`를 주입한다:
- CCH: `todo-sync-check.sh` — TODO.md 변경 감지 시 리마인더
- OMC: `post-tool-verifier.mjs` — 도구 사용 후 검증 컨텍스트
- OMC: `project-memory-posttool.mjs` — 프로젝트 메모리 업데이트

**영향**: 파일 쓰기/편집이 빈번한 작업에서 매 도구 호출마다 3개의 system-reminder가 추가되어 컨텍스트 윈도우 소비가 증가한다. 특히 대규모 리팩토링이나 다수 파일 편집 시 컨텍스트 압축(compaction)이 더 빨리 발생할 수 있다.

**완화 방안**:
- CCH의 `todo-sync-check.sh`에 경량화 로직 추가 (TODO.md와 무관한 파일 편집 시 빈 응답 반환)
- 대규모 작업 시 `OMC_SKIP_HOOKS=post-tool-verifier` 환경변수로 선택적 비활성화 가능

---

## 2. OMC v4.6.0 신규 기능 분석

| 기능 | 설명 | 저장소 | 활용 대상 |
|------|------|--------|-----------|
| **Notepad Wisdom** | `.omc/notepad.md`에 우선·작업·수동 메모 저장. 컴팩션에도 보존 | MCP: notepad_* | 스킬, 워크플로우 |
| **Task Decomposer** | Task 생성 시 자동 분해 + 의존성 설정 | MCP: TaskCreate enhanced | 스킬 |
| **Remember Tags** | `<remember>`, `<remember priority>` 태그로 7일/영구 메모 | Hook: post-tool-verifier | 워크플로우 |
| **Beads Context** | `bd` CLI와 연동한 태스크 컨텍스트 관리 | .omc-config.json | 인프라 (설정만) |
| **Background Task Manager** | 장기 실행 작업 백그라운드 관리 | MCP: state_* | 스킬, 워크플로우 |

---

## 3. CCH 스킬 통합 설계

### 3.1 통합 우선순위 매트릭스

| 우선순위 | CCH 스킬 | 통합 대상 OMC 기능 | 효과 |
|----------|----------|-------------------|------|
| **P0** | cch-plan | Notepad Wisdom, Task Decomposer | Phase 진행 상태 컴팩션 복원, Task 자동 분해 |
| **P0** | cch-team | Background Task Manager, Notepad | 팀 실행 상태 추적, 병렬 에이전트 모니터링 |
| **P1** | cch-full-pipeline | Notepad Wisdom, Background Task Manager | 5단계 파이프라인 상태 영속화 |
| **P1** | cch-todo | Notepad Wisdom | 조회 결과 요약을 notepad에 캐싱 |
| **P2** | cch-rf-sparc | Remember Tags, Notepad | SPARC 5단계 진행 상태 보존 |
| **P2** | cch-commit | Remember Tags | 커밋 패턴 학습 메모리 |
| **P3** | cch-status | state_get_status | OMC 상태 통합 대시보드 |
| **P3** | cch-hud | state_read | HUD에 OMC 모드 상태 표시 |

### 3.2 P0 스킬 통합 상세

#### cch-plan + Notepad Wisdom

**현재**: Phase 간 상태 전달이 변수(`DESIGN_DOC`, `PLAN_DOC`)에 의존. 컴팩션 발생 시 유실 위험.

**통합 후**: 각 Phase 완료 시 `notepad_write_working`으로 진행 상태를 기록.

```
Phase 1 완료 시:
  notepad_write_working("cch-plan Phase 1 완료. DESIGN_DOC=docs/plans/2026-03-04-xxx-design.md")

Phase 2 완료 시:
  notepad_write_working("cch-plan Phase 2 완료. PLAN_DOC=docs/plans/2026-03-04-xxx-impl.md")

Phase 3 완료 시:
  notepad_write_working("cch-plan Phase 3 완료. TODO #N+1~#N+M 추가, Phase XX")
```

**SKILL.md 변경점**: 각 Phase 마지막에 `notepad_write_working` MCP 도구 호출 지시 추가.

**전제조건**: `allowed-tools`에 MCP 도구를 직접 추가할 수 없음 (Claude Code가 MCP 도구는 자동 허용). SKILL.md 본문에 지시문으로 작성.

#### cch-plan + Task Decomposer

**현재**: Phase 3에서 수동으로 TaskCreate를 반복 호출하고 blockedBy를 수동 설정.

**통합 후**: OMC의 Task Decomposer가 TaskCreate 시 자동 분해를 지원하므로, Phase 3의 TaskCreate 지시를 단순화. 다만 cch-plan은 이미 플랜 문서에서 정밀하게 파싱하므로, Task Decomposer의 자동 분해보다 **명시적 생성이 더 적합**. 통합 효과는 제한적.

**결론**: cch-plan에서 Task Decomposer 통합은 **스킵**. Notepad Wisdom만 적용.

#### cch-team + Background Task Manager

**현재**: cch-team은 dev→test→verify 파이프라인을 실행하지만, 상태 추적이 세션 내부에 한정.

**통합 후**: `state_write(mode: "team")`으로 팀 실행 상태를 영속화. 중간 중단 후 재개 가능.

```
파이프라인 시작 시:
  state_write(mode: "team", current_phase: "dev", active: true)

단계 전환 시:
  state_write(mode: "team", current_phase: "test", iteration: 1)

완료 시:
  state_write(mode: "team", active: false, completed_at: "2026-03-04T...")
```

---

## 4. CCH 워크플로우 훅 통합 설계

### 4.1 통합 대상 훅

| CCH 훅 | 통합 대상 OMC 기능 | 변경 유형 |
|--------|-------------------|-----------|
| summary-writer.mjs | Notepad Wisdom | 출력 추가 |
| activity-tracker.mjs | Remember Tags | 출력 추가 |
| plan-bridge.mjs | state_write | 상태 영속화 |
| mode-detector.sh | (불필요) | 변경 없음 |
| todo-sync-check.sh | (불필요) | 경량화만 |
| plan-doc-reminder.sh | (불필요) | 변경 없음 |

### 4.2 상세 설계

#### summary-writer.mjs + Notepad Wisdom

**현재**: Stop 이벤트에서 Q→A 세션 요약을 `.claude/cch/last_summary`에 저장.

**통합 후**: 동일 요약을 `notepad_write_working`으로도 기록. 컴팩션 후 다음 세션에서 이전 세션 맥락을 자동 복원.

**구현**: summary-writer.mjs에서 요약 생성 후, `.omc/notepad.md`의 Working Memory 섹션에 직접 append.

```javascript
// summary-writer.mjs 변경
const summary = generateSummary(lastQuestion, toolResults);
// 기존: .claude/cch/ 에 저장
writeFileSync(summaryPath, summary);
// 추가: .omc/notepad.md Working Memory에도 기록
appendToNotepad(worktreeRoot, `Session summary: ${summary}`);
```

**주의**: OMC MCP 도구를 직접 호출할 수 없으므로(hooks는 shell 명령), `.omc/notepad.md` 파일에 직접 쓰기로 구현.

#### activity-tracker.mjs + Remember Tags

**현재**: UserPromptSubmit/TaskCreate/TaskUpdate에서 `.claude/cch/last_activity`에 기록.

**통합 후**: 중요 활동(Task 생성/완료)을 `<remember>` 태그 형태로 출력하면 OMC의 post-tool-verifier가 자동 수집. 그러나 activity-tracker는 **hook 스크립트**이므로 `<remember>` 태그를 직접 출력할 수 없음.

**대안**: activity-tracker가 `.omc/notepad.md`에 직접 기록.

```javascript
// 중요 활동만 선별 기록
if (toolName === 'TaskCreate' || toolName === 'TaskUpdate') {
  appendToNotepad(worktreeRoot, `Activity: ${toolName} - ${subject}`);
}
```

**결론**: 빈도가 높아 토큰 오버헤드 우려. **P2로 격하** — 필요 시 적용.

#### plan-bridge.mjs + state_write

**현재**: ExitPlanMode 후 플랜 문서를 파싱하여 execution-plan.json 생성, 브랜치/워크아이템 자동 생성.

**통합 후**: 브릿지 실행 상태를 OMC state에 기록하여 중단 후 재개 가능.

```javascript
// plan-bridge.mjs 변경
// 브릿지 시작 시
writeStateFile(worktreeRoot, 'team', {
  active: true,
  current_phase: 'plan-bridge',
  plan_path: planDocPath
});

// 브릿지 완료 시
writeStateFile(worktreeRoot, 'team', {
  active: false,
  current_phase: 'plan-bridge-done',
  plan_path: planDocPath,
  completed_at: new Date().toISOString()
});
```

#### todo-sync-check.sh 경량화

**현재**: 모든 Write|Edit 이벤트에 발화. TODO.md와 무관한 파일 편집 시에도 실행.

**개선**: 편집 대상 파일 경로를 확인하여, `docs/TODO.md` 또는 `docs/plans/` 하위 파일이 아니면 즉시 종료.

```bash
# todo-sync-check.sh 변경
TOOL_INPUT="$CLAUDE_TOOL_USE_INPUT"
FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // .path // empty')

# TODO 관련 파일이 아니면 즉시 종료 (토큰 절약)
case "$FILE_PATH" in
  */docs/TODO.md|*/docs/plans/*) ;;
  *) exit 0 ;;
esac
```

---

## 5. 구현 전략

### 5.1 2단계 접근

**Stage A: 스킬 통합 (SKILL.md 지시문 추가)**
- 코드 변경 없음. SKILL.md 본문에 OMC MCP 도구 호출 지시를 추가.
- 대상: cch-plan, cch-team, cch-full-pipeline
- 리스크: 낮음 (기존 동작 변경 없음, 추가 지시만)

**Stage B: 워크플로우 훅 통합 (스크립트 수정)**
- hooks 스크립트에 `.omc/notepad.md` 직접 쓰기 로직 추가.
- 대상: summary-writer.mjs, plan-bridge.mjs, todo-sync-check.sh
- 리스크: 중간 (파일 I/O 추가, 경합 가능성)

### 5.2 구현 순서

```
Stage A (스킬):
  A1. cch-plan SKILL.md에 notepad_write_working 지시 추가
  A2. cch-team SKILL.md에 state_write 지시 추가
  A3. cch-full-pipeline SKILL.md에 notepad + state 지시 추가

Stage B (워크플로우):
  B1. todo-sync-check.sh 경량화 (파일 경로 필터)
  B2. summary-writer.mjs에 notepad append 추가
  B3. plan-bridge.mjs에 state 기록 추가
```

### 5.3 테스트 전략

- Stage A: 각 스킬을 dry-run으로 실행하여 notepad/state 기록 확인
- Stage B:
  - todo-sync-check.sh: 비 TODO 파일 편집 시 빈 응답 확인
  - summary-writer.mjs: Stop 이벤트 후 `.omc/notepad.md`에 항목 추가 확인
  - plan-bridge.mjs: ExitPlanMode 후 `.omc/state/team-state.json` 생성 확인

---

## 6. 미적용 항목 (의도적 스킵)

| 항목 | 스킵 이유 |
|------|-----------|
| mode-detector.sh 통합 | OMC keyword-detector와 역할 분리가 명확. 통합 시 복잡도만 증가 |
| plan-doc-reminder.sh 통합 | 단순 리마인더. 상태 영속화 불필요 |
| Task Decomposer + cch-plan | cch-plan이 이미 플랜 문서에서 정밀 파싱. 자동 분해보다 명시적 생성이 적합 |
| activity-tracker + notepad | 빈도 높아 토큰 오버헤드 우려. P2로 보류 |
| Beads Context 통합 | 인프라 레벨 설정. CCH 스킬에서 직접 활용할 인터페이스 없음 |
| OMC 훅 비활성화 | 충돌 없으므로 비활성화 불필요. 토큰 절약이 필요한 경우에만 선택적 적용 |

---

## 7. 산출물 맵

| 단계 | 파일 | 변경 유형 |
|------|------|-----------|
| A1 | `skills/cch-plan/SKILL.md` | 지시문 추가 |
| A2 | `skills/cch-team/SKILL.md` (기존 `cch-team/SKILL.md`) | 지시문 추가 |
| A3 | `skills/cch-full-pipeline/SKILL.md` | 지시문 추가 |
| B1 | `scripts/todo-sync-check.sh` | 경량화 |
| B2 | `scripts/summary-writer.mjs` | notepad append 추가 |
| B3 | `scripts/plan-bridge.mjs` | state 기록 추가 |
