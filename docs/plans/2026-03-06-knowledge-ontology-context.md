# Knowledge Ontology Layer -- Context & Decisions

## Background

CCH의 에이전트들은 매 세션마다 프로젝트를 처음부터 탐색한다. planner가 Glob/Read로 코드베이스를 재스캔하고,
이전 워크플로우에서 내린 설계 결정이나 도메인 지식은 세션 간 전달되지 않는다.
산출물(design/plan/tasks/review)은 flat markdown으로 존재하여 관계 추적이 불가능하다.

이 기능은 워크플로우 오케스트레이터에 knowledge ontology 레이어를 추가하여,
step 완료 시 산출물에서 지식을 자동 추출하고, 에이전트 dispatch 시 관련 지식을 주입한다.
이를 통해 두 번째 이후 워크플로우부터 이전 맥락을 활용할 수 있다.

### 관련 선행 작업

- v3 워크플로우 시스템 (PR #3): 현재 오케스트레이터 구조의 기반
- Session Continuity Fields: `workflow-state.json`의 summary/decisions/issues 자동 추출 -- knowledge indexing과 유사한 패턴
- Cross-cutting rules injection: `## NON-NEGOTIABLE RULES` 주입 패턴 -- context injection의 선례

## Key Decisions

| Decision | Rationale | Alternatives Considered |
|----------|-----------|------------------------|
| Context-enriched Dispatch (Option B) 채택 | 에이전트 프롬프트 무변경, 마크다운 원본 유지, 점진적 도입 가능 | Option A (Index only): 자동 활용 안 됨. Option C (Bidirectional): B 안정 후 확장 예정 |
| 오케스트레이터(LLM)가 직접 추출 수행 | 마크다운 구조가 에이전트마다 다르고 섹션명도 유동적. 규칙 기반 파서로는 커버리지 부족. 이미 summary/decisions 추출 로직이 있어 같은 읽기 패스에서 수행 가능 | 규칙 기반 파서: 구조 변동에 취약 |
| 점진적 축적 (코드 스캔 부트스트랩 없음) | 핵심 원칙 #3과 일치. 첫 워크플로우는 빈 그래프로 시작. 코드 스캔 부트스트랩은 복잡도 대비 가치 낮음 | 코드 스캔 부트스트랩: 초기 비용 높고 Out of Scope 계열 |
| LLM 자동 분류, 사용자 확인 없음 | 핵심 원칙 #4에 의해 잘못 분류해도 기능적 영향 없음. concept type은 참고 정보일 뿐 | 사용자 확인 필수: UX 저하, 게이트 과다 |
| 단일 JSON 파일 저장 | 프로젝트 규모에서 충분. 복잡한 DB 불필요. `.claude/` 디렉터리 내 기존 관례와 일치 | SQLite: 오버엔지니어링. 다중 파일: 병합 복잡도 증가 |
| 컨텍스트 주입 상한 50줄 | 에이전트 컨텍스트 윈도우 보호. Priority 1 > 2 > 3 순으로 절삭하여 가장 관련성 높은 정보만 전달 | 무제한: 컨텍스트 오염 위험 |
| SKILL.md만 수정 (에이전트 프롬프트/YAML 무변경) | 단일 변경점으로 위험 최소화. 기존 I/O 계약 보존. 롤백 용이 | YAML에 indexing 설정 추가: 6개 YAML 수정 필요, 변경 범위 확대 |

## Technical Context

### 현재 오케스트레이터 패턴

오케스트레이터 `skills/workflow/SKILL.md`는 마크다운 프롬프트로 동작한다.
핵심 실행 흐름:

```
step 완료 --> output 파일 확인 --> Auto-Extraction (summary/decisions/issues)
          --> workflow-state.json 업데이트 --> 다음 step dispatch
```

Knowledge indexing은 Auto-Extraction과 같은 시점에 수행되며, 같은 output 읽기 패스를 활용한다.

### 보존해야 할 API 계약

| 계약 | 상세 |
|------|------|
| Agent dispatch prompt 구조 | `agent prompt + previous step output + cross-cutting rules` -- knowledge context는 이 뒤에 추가 |
| workflow-state.json 스키마 | 기존 필드(status, output, summary, decisions, issues) 변경 없음 |
| Gate step 동작 | 사용자가 직접 스킬 호출 -- 오케스트레이터 개입 불가 (context injection 미적용) |
| YAML step 정의 | 기존 6개 YAML의 step 구조 변경 없음 |
| Auto-Extraction Rules | 기존 summary/decisions/issues 추출 로직 유지 |

### SKILL.md 내 삽입 위치

Knowledge Graph Management 섹션은 `## Error Handling` 직전에 삽입한다.
이유: 실행 흐름상 Workflow Execution/Review Pipeline/Retry-on-Fail 이후,
에러 처리 이전이 논리적으로 적합하다.

기존 step type 섹션(`### type: agent`, `### type: agent-chain` 등)에는
context injection 관련 항목만 추가하며, 기존 텍스트는 수정하지 않는다.

### 성능 고려사항

- knowledge-graph.json 읽기/쓰기는 매 step마다 발생하나, 단일 JSON 파일이므로 I/O 부담 미미
- LLM 추출은 이미 수행 중인 Auto-Extraction과 같은 패스에서 병행하므로 추가 LLM 호출 없음
- 50줄 상한으로 dispatch prompt 크기 증가 제한

### 보안 고려사항

- knowledge-graph.json은 `.claude/` 디렉터리 내 저장 -- 기존 workflow-state.json과 동일한 접근 수준
- 민감 정보(API 키, 비밀번호 등)는 추출 대상이 아님 -- 추출 프롬프트에 "명시적으로 언급된 것만 추출" 규칙 포함
- `.gitignore`에 `.claude/` 포함 여부는 프로젝트별 설정 (CCH 자체는 `.claude/` 미추적)

## Open Questions

| # | 질문 | 영향 |
|---|------|------|
| 1 | knowledge-graph.json이 매우 커질 경우 (수십 회 워크플로우 후) LLM의 단일 패스 읽기/쓰기가 가능한가? | 현재 규모에서는 문제 없으나, 장기 운영 시 분할 전략 필요할 수 있음. 당장은 Out of Scope |
| 2 | agent-chain에서 첫 에이전트에만 context injection 시, 두 번째 에이전트(reviewer)가 knowledge를 활용하지 못하는 것이 의도적인가? | 설계 문서에 명시됨. reviewer는 이전 에이전트 output이 컨텍스트이므로 간접 전달. 다만 실제 효과는 검증 필요 |
| 3 | 다중 프로젝트에서 CCH 플러그인 공유 시 knowledge-graph.json 충돌 가능성 | 프로젝트 루트의 `.claude/`에 저장하므로 프로젝트별 분리됨. 다만 projectId 필드의 자동 설정 방식 미정 |
