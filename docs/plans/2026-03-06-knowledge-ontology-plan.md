# Knowledge Ontology Layer -- Strategic Plan

## Overview

CCH 워크플로우 오케스트레이터(`skills/workflow/SKILL.md`)에 knowledge ontology 레이어를 추가한다.
워크플로우 step 완료 시 산출물에서 도메인 개념/결정/변경이력을 자동 추출하여 `.claude/knowledge-graph.json`에 축적하고,
에이전트 dispatch 시 관련 지식을 컨텍스트로 주입한다. 에이전트 프롬프트는 변경하지 않으며,
knowledge-graph 파일이 없어도 기존 워크플로우가 동일하게 동작한다.

## Architecture Impact

### 수정 대상 파일 (1개)

| 파일 | 변경 내용 |
|------|----------|
| `skills/workflow/SKILL.md` | Knowledge Graph Management 섹션 추가 (Indexing Hook, Context Injection, Resume 연동) |

### 신규 생성 파일 (런타임)

| 파일 | 생성 시점 |
|------|----------|
| `.claude/knowledge-graph.json` | 첫 번째 step 완료 시 오케스트레이터가 자동 생성 |

### 변경 없음

- 에이전트 프롬프트 10종 (`agents/*.md`) -- 변경 없음
- 워크플로우 YAML 6종 (`skills/workflow/*.yaml`) -- 변경 없음
- 기타 스킬 (`skills/*/SKILL.md`) -- 변경 없음
- 패키지/의존성 -- 변경 없음

## Implementation Strategy

### Phase 구조

이 기능은 `skills/workflow/SKILL.md` 단일 파일에 마크다운 섹션을 추가하는 작업이다.
코드가 아닌 프롬프트 기반이므로, 논리적 단위로 섹션을 나누어 순차 작성한다.

### Phase 1: Knowledge Graph 스키마 및 Indexing Hook

SKILL.md에 `## Knowledge Graph Management` 섹션의 전반부를 추가한다.

**작성 내용:**
1. 스키마 정의 (version, concepts, decisions, artifacts, changelog)
2. 빈 그래프 초기화 로직
3. Step 완료 후 Indexing 프로세스 (추출 프롬프트 구조 포함)
4. Step type별 Indexing 적용 규칙 (skill/agent/agent-chain/parallel/conditional)
5. 기존 concept 병합 규칙 (name 기준 합집합)
6. 인덱싱 실패 시 경고 처리 (워크플로우 중단 안 함)

**삽입 위치:**
- `## Error Handling` 섹션 직전

### Phase 2: Context Injection

SKILL.md의 Knowledge Graph Management 섹션 후반부를 추가한다.

**작성 내용:**
1. 3단계 관련성 매칭 로직 (P1: artifact, P2: workflow 내부, P3: git diff)
2. 50줄 상한 및 Priority별 절삭 규칙
3. Dispatch prompt 구성 시 주입 위치 (cross-cutting rules 다음)
4. 주입 포맷 (`## Project Knowledge Context (auto-injected)`)
5. 관련 concept 없을 때 섹션 생략 규칙

**기존 섹션 수정:**
- `### type: agent (Executor)` 의 dispatch prompt 구성 목록에 knowledge context 항목 추가
- `### type: agent-chain` 에 첫 에이전트에만 주입하는 규칙 명시
- `### type: parallel` 에 각 sub-step 독립 주입 규칙 명시
- `### type: conditional` 에 선택된 branch에 주입 규칙 명시

### Phase 3: Resume 연동 및 하위 호환성 보장

**작성 내용:**
1. Resume 시 knowledge-graph.json에서 현재 workflow concepts 요약 출력
2. Resume context summary에 knowledge 요약 라인 추가

**기존 섹션 수정:**
- `### Resume with Context Recovery` 에 knowledge 요약 출력 단계 추가

### 권장 구현 순서

```
Phase 1 (Indexing) --> Phase 2 (Injection) --> Phase 3 (Resume)
```

Phase 1이 완료되어야 knowledge-graph.json이 생성되고, Phase 2의 injection이 동작한다.
Phase 3은 Phase 1에만 의존하므로 Phase 2와 병렬 가능하나, 단일 파일 수정이므로 순차가 안전하다.

### Risk Areas

| 리스크 | 영향 | 완화 |
|--------|------|------|
| SKILL.md 길이 증가로 오케스트레이터 컨텍스트 부담 | 오케스트레이터 성능 저하 가능 | 섹션을 간결하게 유지, 스키마 예시는 최소화 |
| Indexing 추출 품질 불안정 | 잘못된 concept이 축적될 수 있음 | 핵심 원칙 #4로 커버 (그래프 손실 무해) |
| Context injection이 에이전트 프롬프트와 충돌 | 에이전트가 혼란할 수 있음 | 기존 cross-cutting 주입 패턴과 동일한 형식 사용 |
| 기존 step type 섹션 수정 시 기존 로직 훼손 | 워크플로우 동작 변경 | 추가만 하고 기존 텍스트는 수정하지 않음 |

## Verification Strategy

### Phase 1 검증

- knowledge-graph.json 없이 기존 워크플로우 6종 시작/resume 정상 동작 확인
- feature-dev 워크플로우의 design step 완료 후 `.claude/knowledge-graph.json` 생성 확인
- 생성된 JSON이 스키마 구조(version, concepts, decisions, artifacts, changelog)를 준수하는지 확인
- 두 번째 step 완료 후 기존 concept이 병합(합집합)되는지 확인

### Phase 2 검증

- agent type step dispatch 시 `## Project Knowledge Context` 섹션이 포함되는지 확인
- knowledge-graph.json이 없을 때 context injection 섹션이 생략되는지 확인
- skill (Gate) type step에서는 context injection이 적용되지 않는지 확인
- 주입된 컨텍스트가 50줄 이내인지 확인

### Phase 3 검증

- resume 시 knowledge 요약이 step 이력과 함께 출력되는지 확인
- knowledge-graph.json이 없을 때 resume가 기존과 동일하게 동작하는지 확인

### 통합 검증 (수동)

1. feature-dev 워크플로우를 처음부터 끝까지 실행하여 knowledge-graph.json 축적 확인
2. 동일 프로젝트에서 두 번째 워크플로우 시작 시 첫 번째 워크플로우의 knowledge가 주입되는지 확인
3. knowledge-graph.json 삭제 후 워크플로우 정상 동작 확인
4. 인덱싱 중 의도적 오류 유발 시 워크플로우 계속 진행 확인

## Rollback Plan

- `skills/workflow/SKILL.md`의 변경을 git revert하면 완전 복원
- `.claude/knowledge-graph.json`은 삭제해도 기능 영향 없음 (설계 원칙)
- 에이전트 프롬프트, YAML 파일은 변경하지 않으므로 독립적으로 revert 불필요
- Phase별 독립 revert 가능: Phase 3만 제거하면 resume 연동만 해제, Phase 2만 제거하면 injection만 해제

## Plan Review

### Status: APPROVED (조건부)

### Critical Issues (구현 전 반드시 수정)

| # | 영역 | 이슈 | 권장 조치 |
|---|------|------|----------|
| C1 | `.gitignore` 누락 | `.claude/knowledge-graph.json`이 `.gitignore`에 포함되어 있지 않다. 현재 `.gitignore`는 `.claude/` 전체가 아닌 개별 파일(`workflow-state.json`, `settings.local.json`, `skills/`)만 무시한다. knowledge-graph.json이 git에 추적되면 다른 개발자와 충돌하거나, 프로젝트별로 의미 없는 그래프가 커밋된다. | Phase 1 시작 전에 `.gitignore`에 `.claude/knowledge-graph.json` 추가를 플랜에 명시. 또는 context 문서에서 "프로젝트별 설정"이라고 했으나, CCH 자체 리포에서는 반드시 추가해야 한다. 수정 대상 파일 테이블에 `.gitignore`를 추가할 것. |
| C2 | Step type 섹션 헤딩 불일치 | Phase 2에서 수정 대상으로 `### type: agent (Executor)`, `### type: agent-chain`, `### type: parallel`, `### type: conditional`을 언급하지만, 실제 SKILL.md의 헤딩은 백틱 포함 형식이다: `` ### `type: agent` (Executor — automatic) ``, `` ### `type: agent-chain` (Chained Executors — automatic) `` 등. 구현 시 정확한 헤딩을 찾지 못해 잘못된 위치에 삽입할 위험이 있다. | 플랜의 Phase 2 섹션에서 수정 대상 헤딩을 SKILL.md의 실제 헤딩(라인 193, 205, 214, 247)과 정확히 일치시킬 것. |

### Important Considerations (반드시 고려할 사항)

| # | 영역 | 이슈 | 권장 조치 |
|---|------|------|----------|
| I1 | Dispatch prompt 주입 순서 모호 | 디자인 문서의 아키텍처 다이어그램에서는 `Project Knowledge Context`가 `NON-NEGOTIABLE RULES` **위에** 배치되어 있지만, context 문서에서는 "cross-cutting rules 다음"이라고 명시한다. 플랜의 Phase 2에서도 "cross-cutting rules 다음"이라고 하지만, 실제 SKILL.md의 `type: agent` 섹션(라인 197-200)에서는 dispatch prompt 구성이 3단계(agent prompt, previous output, cross-cutting)이고, knowledge context를 어디에 추가할지 정확한 삽입 위치(몇 번째 단계 다음인지)가 불명확하다. | Phase 2에서 SKILL.md 라인 197-200의 "Build the dispatch prompt" 목록에 4번째 항목으로 knowledge context를 추가한다는 것을 명시적으로 기술할 것. 예: `- Append knowledge context (see Knowledge Graph Management > Context Injection)` |
| I2 | SKILL.md 길이 증가 정량 추정 부족 | 현재 SKILL.md는 449줄이다. Knowledge Graph Management 섹션 추가 시 디자인 문서의 Orchestrator Integration Spec (약 40줄)과 추출 규칙, 스키마 예시 등을 포함하면 80-120줄 증가가 예상된다. 리스크 테이블에서 "간결하게 유지"라고 했으나, 구체적 상한이 없다. | 추가 섹션의 목표 줄 수를 명시할 것 (예: "80줄 이내"). 스키마 JSON 예시는 최소한으로 줄이고, 디자인 문서를 참조하도록 유도. |
| I3 | `skill-creation` 워크플로우 누락 | README에는 `planning-only`, `skill-creation`이 나열되어 있고, YAML 파일로도 `skill-creation.yaml`이 존재한다. 그러나 플랜의 검증 전략(Phase 1)에서 "기존 워크플로우 6종"이라고 하면서, Available Workflows 목록(SKILL.md)에는 5종만 기재되어 있다. `skill-creation` 워크플로우의 호환성 검증이 빠져 있을 수 있다. | 검증 전략에서 6종 목록을 명시적으로 나열할 것: feature-dev, bugfix, refactor, quick-fix, planning-only, skill-creation. |
| I4 | Context injection의 `input` 필드 참조 | Phase 2의 P1 매칭에서 "현재 step의 input 필드에 명시된 artifact path"를 언급하나, 현재 워크플로우 YAML의 step 정의에 `input` 필드가 표준으로 존재하는지 확인이 필요하다. YAML 스키마에 이 필드가 없으면 P1 매칭이 실제로 동작하지 않는다. | 실제 YAML 파일(feature-dev.yaml 등)에서 `input` 필드 존재 여부를 확인하고, 없다면 P1 매칭 로직을 "이전 step의 output 파일"로 대체하거나, YAML에 input 필드를 추가하는 작업을 플랜에 포함할 것. |
| I5 | agent-chain 첫 에이전트만 주입의 한계 | Open Questions #2에서 인정했듯이, agent-chain에서 reviewer(두 번째 에이전트)에 knowledge context가 주입되지 않는다. planning step의 plan-reviewer가 이전 워크플로우의 결정사항을 모른 채 리뷰하면, 이미 결정된 사항을 다시 문제 제기할 수 있다. | 최소한 agent-chain의 모든 에이전트에 knowledge context를 주입하는 옵션을 Phase 2에서 고려할 것. 아니면 이 제한을 "Known Limitations"으로 플랜에 명시하여 구현자가 인지하도록 할 것. |

### Alternative Approaches

이 플랜은 이미 가장 단순한 접근 방식을 택하고 있다(단일 파일 수정, 프롬프트 기반, 코드 변경 없음). 더 단순한 대안은 없다. 다만 두 가지 변형을 고려할 수 있다:

1. **Indexing을 별도 섹션이 아닌 Auto-Extraction Rules 확장으로 구현**: 현재 SKILL.md에 이미 `### Auto-Extraction Rules` (라인 140)가 있다. knowledge indexing도 본질적으로 "step 완료 후 자동 추출"이므로, 별도 `## Knowledge Graph Management` 섹션 대신 Auto-Extraction Rules를 확장하는 방식이 구조적으로 더 자연스러울 수 있다. 다만 관심사 분리 관점에서 현재 플랜의 별도 섹션 접근이 더 명확하므로, 현재 방식을 유지하되 Auto-Extraction Rules에서 Knowledge Graph Management 섹션을 참조하는 한 줄을 추가하는 것을 권장한다.

2. **Context injection을 cross-cutting rules 패턴으로 통합**: knowledge context 주입을 별도 로직이 아닌, 가상의 cross-cutting skill처럼 처리하면 기존 주입 메커니즘을 재활용할 수 있다. 다만 이는 knowledge-graph가 동적 컨텐츠인 반면 cross-cutting rules는 정적 프롬프트라는 차이가 있어 현재 플랜의 접근이 더 적합하다.

### Research Findings

- **기존 패턴 일치**: SKILL.md의 Session Continuity Fields/Auto-Extraction 패턴과 knowledge indexing이 같은 시점(step 완료 후)에 동작하므로, 구현 시 기존 패턴을 자연스럽게 확장할 수 있다.
- **삽입 위치 검증**: `## Error Handling`은 SKILL.md 라인 443에 위치한다. 라인 416(`## Progress Display`) 이후, 라인 425(`## Agent Dispatch Red Flags`) 이후에 `## Error Handling`이 온다. Knowledge Graph Management 섹션을 Error Handling 직전에 넣으면, Agent Dispatch Red Flags와 Error Handling 사이에 위치하게 되는데, 이는 논리적으로 적합하다(실행 흐름 관련 섹션들 사이).
- **SKILL.md 현재 구조 확인**: 현재 449줄. 주요 섹션 순서: Path Discovery -> Available Workflows -> Input Resolution -> Startup -> Workflow Router -> State Management -> Workflow Execution (step types) -> Cross-Cutting Rules -> Review Pipeline -> Retry-on-Fail -> Progress Display -> Agent Dispatch Red Flags -> Error Handling.

### Summary

이 플랜은 전반적으로 잘 설계되어 있다. 단일 파일(SKILL.md) 수정으로 범위를 한정하고, 하위 호환성을 핵심 원칙으로 설정한 점, 실패 시 워크플로우를 중단하지 않는 설계, 그리고 Phase별 독립 롤백 가능성은 모두 건전하다. 3개 문서(디자인/컨텍스트/플랜) 간 일관성도 높다.

Critical issue 2건(`.gitignore` 누락, 섹션 헤딩 불일치)은 구현 전에 플랜 문서를 수정하면 해결되는 경미한 수준이다. Important considerations 중 I4(input 필드 존재 여부)는 실제 YAML을 확인한 후 P1 매칭 로직을 조정해야 할 수 있으므로, Phase 2 착수 전에 확인이 필요하다. 이 조건들을 반영하면 구현을 시작해도 좋다.
