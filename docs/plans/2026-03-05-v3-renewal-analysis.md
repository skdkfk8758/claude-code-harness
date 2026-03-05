# CCH v3 Renewal - Analysis Document

- 작성일: 2026-03-05
- 상태: Approved
- 범위: 외부 플러그인 제거, Beads 제거, 자체 영속성 구축, 스킬 재설계

---

## 1. 배경

CCH v2는 외부 플러그인(superpowers, kkirikkiri, oh-my-claudecode)과 외부 도구(Beads/bd CLI)에 의존하는 구조로 발전했다. 이로 인해:

1. **외부 의존성 리스크** - 버전 호환, breaking change, 마켓플레이스 가용성
2. **이중 추적 복잡성** - Beads(SSOT) + TaskList(세션 뷰) 동기화 부담
3. **Tier 분기 복잡도** - 동일 스킬이 Tier 0/1/2에 따라 다른 경로를 가짐
4. **실제 사용 패턴과의 괴리** - Beads 100개 중 98개 closed (단일 세션 패턴)

## 2. 결정사항

### 2-1. 삭제 대상

| 대상 | 유형 | 이유 |
|------|------|------|
| **superpowers** | 외부 플러그인 (v4.3.1) | 14개 스킬의 70%는 상식의 강제 주입. 나머지 30% 핵심만 내재화 |
| **kkirikkiri** | 외부 플러그인 (v0.8.0) | Agent Teams 실험적 기능 의존. 독립적이라 제거 영향 낮음 |
| **oh-my-claudecode** | 외부 플러그인 | Serena MCP가 동일 기능 커버 |
| **Beads (bd CLI)** | 외부 도구 (v0.44.0) | 외부 바이너리 의존. 네이티브 레이어 조합으로 대체 |
| **Tier 시스템** | 내부 아키텍처 | Tier 0만으로 통일. 분기 로직 전부 제거 |

### 2-2. 내재화 대상 (superpowers에서 가져올 것)

| 항목 | 원본 | 흡수 방식 | 예상 규모 |
|------|------|----------|----------|
| Iron Law 원칙 | TDD, Verification, Debugging 등 14개 스킬 공통 패턴 | CLAUDE.md 원칙문 4-5줄 | 5줄 |
| systematic-debugging 4단계 | superpowers:systematic-debugging | cch-debug 스킬로 직접 기술 | ~150줄 |
| Two-stage review | superpowers:subagent-driven-development | cch-subagent-dev 스킬에 직접 기술 | ~50줄 |
| SessionStart 스킬 안내 | superpowers:using-superpowers | CCH 자체 SessionStart 훅 | ~30줄 |
| Brainstorming hard gate | superpowers:brainstorming | cch-plan Phase 1 본문으로 승격 (이미 90% 구현) | ~20줄 수정 |

**총 신규 작성량: ~250줄** (superpowers 3,800줄 대비 93% 절감)

### 2-3. 영속성 대체 아키텍처

Beads 제거 후 네이티브 레이어 4층 구조:

```
Layer 1: CLAUDE.md            -- 프로젝트 규칙 + 세션 프로토콜 (항상 자동 로드)
Layer 2: auto-memory          -- "지금 뭘 하고 있었는지" 상태 요약 (자동 로드, 200줄)
Layer 3: docs/plans/*.md      -- 설계 + 진행 상태 + 결정 + Dead Ends (git 영속)
Layer 4: git log/branch       -- 실행 이력 (이미 있음)
```

| Layer | 답하는 질문 | 갱신 시점 | 영속성 |
|-------|-----------|----------|--------|
| CLAUDE.md | "이 프로젝트에서 어떻게 일하는가?" | 프로젝트 설정 시 | git |
| auto-memory | "지금 뭘 하다 끊겼는가?" | 매 세션 종료 시 | 로컬 |
| docs/plans/ | "왜 이렇게 결정했고 뭐가 남았는가?" | 작업 완료마다 | git |
| git | "실제로 뭘 했는가?" | 커밋마다 | git |

### Markdown-as-State 플랜 문서 포맷

```markdown
# Plan: <feature-name>
Status: draft | in-progress | done | abandoned
Branch: feat/<name>
Started: YYYY-MM-DD

## Tasks
- [x] Phase 1: 제목 <- commit:abc1234
- [ ] Phase 2: 제목 (blocked-by: Phase 1)
- [ ] Phase 3: 제목

## Decisions
- <질문> -> <결정> (<이유>)

## Dead Ends
- <시도한 것> -> <실패 이유>
```

## 3. superpowers 스킬별 상세 판정

### 삭제 (별도 스킬 불필요 - 상식 또는 이미 커버)

| 스킬 | 줄 수 | 판정 이유 |
|------|------|----------|
| test-driven-development | 372 | Red-Green-Refactor는 CLAUDE.md 원칙문으로 충분 |
| verification-before-completion | 140 | "증거 없이 완료 금지" — CLAUDE.md 한 문단 |
| receiving-code-review | 214 | "맹목적 수용 금지" — 상식 |
| dispatching-parallel-agents | 181 | Agent 도구 사용법 설명 수준 |
| executing-plans | 85 | 가장 얇은 래퍼. 내재화 가치 없음 |
| finishing-a-development-branch | 201 | git 워크플로우 상식 |
| using-git-worktrees | 219 | 유틸리티. 필요 시 CLAUDE.md에 가이드 |
| using-superpowers | 300 | 메타 스킬. CCH 자체 훅으로 대체 |
| requesting-code-review | 105 | 템플릿 기반 디스패치. cch-review에 흡수 |
| writing-skills | 656 | skill-manager에 이미 일부 재구현 |
| writing-plans | 117 | cch-plan Phase 2가 이미 재구현 |
| brainstorming | 299 | cch-plan Phase 1이 이미 90% 재구현 |

### 내재화 (핵심 로직만 추출)

| 스킬 | 추출할 것 | 대상 |
|------|----------|------|
| systematic-debugging | 4단계 구조 + "3회 실패=아키텍처 문제" 임계값 | 신규 cch-debug |
| subagent-driven-development | Two-stage review (spec compliance -> code quality 순서) | cch-subagent-dev 또는 cch-review |

## 4. kkirikkiri 핵심 패턴 기록

삭제하지만, 향후 팀 기능 구현 시 참고할 패턴:

| 패턴 | 설명 |
|------|------|
| Shared Memory 외부화 | TEAM_PLAN/PROGRESS/FINDINGS를 파일로 관리하여 컨텍스트 윈도우 한계 극복 |
| DEAD_ENDS 로깅 | 실패 접근법 기록으로 2라운드 반복 방지 |
| Quality Validation Loop | 3단계 에스컬레이션 (팀 보강/교체/멤버 교체) |
| Preset + Interview + Environment | 단순 템플릿이 아닌 상황 적응형 동적 팀 구성 |

## 5. Beads 제거 시 영향 매핑

| 현재 Beads 사용처 | 대체 방안 |
|-------------------|----------|
| cch-plan Phase 3: `bd create` | 플랜 문서 체크박스 `- [ ] Task` |
| cch-plan: `bd dep` | `blocked-by:` 텍스트 |
| cch-plan: `bd ready` -> TaskList hydrate | 플랜 문서에서 미완료+비차단 항목 직접 추출 |
| cch-commit: `Bead:` 트레일러 | `Plan: <plan-name>` 트레일러 |
| cch-todo: `bd ready` + `bd list` | 플랜 문서 체크박스 파싱 |
| cch-pr: Bead 링크 | Plan 문서 링크 |
| cch-team: `bd create`/`bd close` | TaskList만 사용 (단일 세션) |
| bin/lib/beads.sh (364줄) | 삭제 |
| AGENTS.md: bd onboard 안내 | 새 프로토콜로 교체 |

## 6. 영향받는 파일 총 목록

### 삭제 대상

```
bin/lib/beads.sh                    # Beads 어댑터 (364줄)
.beads/                             # Beads 데이터 디렉터리 전체
AGENTS.md                           # bd 기반 에이전트 지시 (새로 작성)
tests/test_beads.sh                 # Beads 테스트
```

### 수정 대상 (Beads 참조 제거)

```
skills/cch-plan/SKILL.md            # Phase 3 Beads -> Markdown-as-State
skills/cch-commit/SKILL.md          # Bead 트레일러 -> Plan 트레일러
skills/cch-todo/SKILL.md            # bd ready -> 플랜 문서 파싱
skills/cch-pr/SKILL.md              # Bead 링크 -> Plan 링크
skills/cch-team/SKILL.md            # bd create/close -> TaskList
skills/cch-init-scaffold/SKILL.md   # Beads 항목 생성 -> 체크박스
skills/cch-init/SKILL.md            # Bead 생성 참조 제거
skills/cch-status/SKILL.md          # Bead 상태 표시 제거
scripts/plan-bridge.mjs             # beads create -> 플랜 문서 업데이트
scripts/lib/core.mjs                # beads list 호출 제거
scripts/lib/bridge-output.mjs       # bead_id 참조 제거
bin/cch                             # beads 서브커맨드 제거, Tier 로직 단순화
bin/lib/branch.sh                   # bead_id 참조 제거
```

### 수정 대상 (superpowers/Tier 참조 제거)

```
manifests/capabilities.json         # superpowers 소스 제거
profiles/code.json                  # superpowers 의존 제거
profiles/plan.json                  # superpowers 의존 제거
scripts/check-env.mjs               # superpowers 체크 제거
bin/lib/skill.sh                    # superpowers 캐시 스캔 제거
skills/cch-commit/SKILL.md          # Enhancement 섹션 -> 본문 승격 또는 제거
skills/cch-verify/SKILL.md          # Enhancement 섹션 제거
skills/cch-review/SKILL.md          # Enhancement 섹션 제거
skills/cch-todo/SKILL.md            # Enhancement 섹션 제거
skills/cch-setup/SKILL.md           # Enhancement 섹션 제거
skills/cch-skill-manager/SKILL.md   # Enhancement 섹션 제거
```

### 수정 대상 (테스트)

```
tests/unit/check-env.test.mjs       # superpowers assertions 제거
tests/unit/core-tier.test.mjs       # Tier 1 superpowers 테스트 수정
tests/test_check_env.sh             # superpowers assert 제거
tests/test_workflow.sh              # beads 참조 제거
scripts/test.sh                     # beads 테스트 레이어 제거
```

### 문서 갱신

```
docs/PRD.md                         # Tier 시스템, Beads SSOT 설명 갱신
docs/Architecture.md                # Enhancement 섹션, Tier 설명 갱신
docs/Roadmap.md                     # superpowers 통합 계획 제거
docs/plugin-components-reference.md # superpowers/kkirikkiri 섹션 제거
docs/diagrams/cch-workflows.md      # superpowers 체크 분기 제거
README.md                           # superpowers 설치 가이드 제거
```
