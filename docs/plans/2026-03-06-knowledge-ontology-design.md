# Knowledge Ontology Layer Design

## Problem Statement

현재 CCH의 에이전트들은 매 세션마다 프로젝트를 0부터 탐색한다.
- planner가 Glob/Read로 코드베이스를 매번 재스캔
- 이전 워크플로우에서 내린 설계 결정, 도메인 지식이 세션 간 전달되지 않음
- 산출물(design/plan/tasks/review)이 flat markdown으로 존재하여 관계 추적 불가
- "Order 개념을 수정했을 때 어떤 모듈이 영향받는가" 같은 의미적 질의 불가능

## Chosen Approach: Context-enriched Dispatch (Option B)

기존 마크다운 산출물과 에이전트 I/O 계약을 100% 유지하면서,
`.claude/knowledge-graph.json`이 산출물 위에 메타 레이어로 존재한다.

### 핵심 원칙
1. **마크다운이 원본** — knowledge-graph는 인덱스이자 어노테이션이지 원본이 아님
2. **에이전트 프롬프트 무변경** — 오케스트레이터가 dispatch 시 컨텍스트를 주입
3. **점진적 축적** — 워크플로우 step 완료 시마다 자동 인덱싱, 코드 스캔 부트스트랩 없음
4. **그래프 손실 무해** — 삭제해도 마크다운에서 재생성 가능, stale 데이터 허용

## Rejected Alternatives

| 대안 | 기각 이유 |
|------|----------|
| 순수 모델 2 (Knowledge Graph = 문서 자체) | 10개 에이전트 프롬프트 + 워크플로우 YAML 전면 재설계 필요, 사용자 UX 저하 |
| 모델 1 (Index only) | 지식이 쌓이기만 하고 자동 활용 안 됨 |
| 모델 3 (Annotation) | 마크다운 파싱 복잡도 증가, 구조적 쿼리 제한 |
| 옵션 C (Bidirectional) | B 안정 후 점진 확장 예정 (백로그) |

## Architecture

```
[Workflow Step 완료]
       |
       v
[Knowledge Indexer] ──── 산출물 마크다운 읽기
       |                  LLM이 구조화된 JSON 추출
       |                  기존 그래프와 병합
       v
[.claude/knowledge-graph.json] ← 단일 파일, JSON
       |
       v
[Orchestrator Dispatch] ──── 다음 step의 에이전트에게
       |                      관련 knowledge context 주입
       v
[Agent receives]
  ## Project Knowledge Context       ← 새로 주입되는 섹션
  ### Related Concepts: ...
  ### Past Decisions: ...
  ### Change History: ...

  ## NON-NEGOTIABLE RULES (tdd)      ← 기존 cross-cutting 주입
  ...
```

### 통합 지점 상세

#### 1. Indexing Hook (워크플로우 오케스트레이터)

현재 오케스트레이터의 step 완료 후 흐름:
```
step 완료 → output 파일 확인 → workflow-state.json 업데이트 → 다음 step
```

변경 후:
```
step 완료 → output 파일 확인 → workflow-state.json 업데이트
         → knowledge-graph 인덱싱 (새 단계)
         → 다음 step
```

오케스트레이터 SKILL.md에 추가할 섹션:
```
## Knowledge Indexing

각 step 완료 후:
1. step의 output 파일을 읽는다
2. 아래 추출 규칙에 따라 개념/결정/관계를 파싱한다
3. .claude/knowledge-graph.json을 업데이트한다
4. 중복 개념은 병합한다 (name 기준)
```

#### 2. Context Injection (에이전트 dispatch 시)

현재 오케스트레이터의 dispatch 구조:
```
dispatch prompt = agent prompt + previous step output + cross-cutting rules
```

변경 후:
```
dispatch prompt = agent prompt
                + previous step output
                + cross-cutting rules
                + knowledge context (새 단계)
```

기존 cross-cutting 주입 패턴(`## NON-NEGOTIABLE RULES`)과 동일한 방식으로:
```
## Project Knowledge Context (from knowledge-graph)

### Domain Concepts Related to This Task
- Order: 주문 엔티티, src/order/ 하위 모듈, Payment와 1:1 관계
- Payment: 결제 처리, src/payment/gateway.ts

### Relevant Past Decisions
- [2026-03-01] "캐시 무효화는 이벤트 기반으로 처리" (design: cache-layer)
- [2026-02-28] "Order 상태 머신은 enum으로 관리" (design: order-system)

### Change History for Affected Concepts
- Order: 3회 수정 (최근: 2026-03-05, workflow: order-refactor)
```

#### 3. Step Type별 Context Injection 적용 규칙

| Step Type | Indexing (step 완료 후) | Context Injection (dispatch 시) |
|-----------|------------------------|-------------------------------|
| `type: skill` (Gate) | 적용 — 사용자 승인 후 output 인덱싱 | 미적용 — 사용자가 직접 스킬 호출하므로 오케스트레이터가 개입 불가 |
| `type: agent` | 적용 — 에이전트 완료 후 output 인덱싱 | 적용 — dispatch prompt에 knowledge context 추가 |
| `type: agent-chain` | 적용 — 체인 전체 완료 후 최종 output 인덱싱 | 적용 — 체인의 첫 번째 에이전트 dispatch에만 주입 (후속 에이전트는 이전 에이전트 output이 컨텍스트) |
| `type: parallel` | 적용 — 모든 sub-step 완료 후 각각 인덱싱 | 적용 — 각 sub-step dispatch에 독립적으로 주입 |
| `type: conditional` | 적용 — 실행된 branch의 output 인덱싱 | 적용 — 선택된 branch의 에이전트 dispatch에 주입 |

#### 4. 관련성 판단 로직

모든 지식을 주입하면 컨텍스트가 비대해지므로 3단계 매칭으로 필터링:

**Priority 1: Artifact 매칭**
- 현재 step의 input 필드에 명시된 artifact path → 해당 artifact가 참조하는 concepts

**Priority 2: Workflow 내부 매칭**
- 현재 workflow의 이전 step에서 생성된 decisions, concepts
- workflow-state.json의 decisions 필드와 교차 참조

**Priority 3: Git diff 기반 매칭**
- `git diff --name-only main..HEAD`로 변경된 파일 목록 수집
- 변경된 파일과 concept.files의 교집합으로 관련 concepts 식별
- implementation, review step에서 주로 활용

**주입 상한**: 최대 50줄. 초과 시 Priority 1 > 2 > 3 순으로 잘라냄.
관련 concept이 없으면 이 섹션을 생략 (빈 컨텍스트 주입 안 함).

## Knowledge Graph Schema

```json
{
  "version": "1.0",
  "lastUpdated": "2026-03-06T10:00:00Z",
  "projectId": "my-project",

  "concepts": [
    {
      "id": "concept-order",
      "name": "Order",
      "type": "entity",
      "description": "주문 엔티티 — 생성, 취소, 완료 상태 관리",
      "files": ["src/order/model.ts", "src/order/service.ts"],
      "relations": [
        { "target": "concept-payment", "type": "has-one" },
        { "target": "concept-user", "type": "belongs-to" },
        { "target": "concept-order-item", "type": "has-many" }
      ],
      "firstSeen": "2026-02-15",
      "lastModified": "2026-03-05",
      "modifiedCount": 3
    }
  ],

  "decisions": [
    {
      "id": "decision-001",
      "date": "2026-03-01",
      "workflow": "feature-dev:cache-layer",
      "step": "design",
      "content": "캐시 무효화는 이벤트 기반으로 처리",
      "rationale": "TTL 기반은 정합성 보장 불가",
      "concepts": ["concept-cache", "concept-event-bus"],
      "artifact": "docs/plans/2026-03-01-cache-layer-design.md"
    }
  ],

  "artifacts": [
    {
      "id": "artifact-001",
      "path": "docs/plans/2026-03-01-cache-layer-design.md",
      "type": "design",
      "workflow": "feature-dev:cache-layer",
      "concepts": ["concept-cache", "concept-redis"],
      "createdAt": "2026-03-01",
      "derivedFrom": null
    },
    {
      "id": "artifact-002",
      "path": "docs/plans/2026-03-01-cache-layer-plan.md",
      "type": "plan",
      "workflow": "feature-dev:cache-layer",
      "concepts": ["concept-cache", "concept-redis"],
      "createdAt": "2026-03-01",
      "derivedFrom": "artifact-001"
    }
  ],

  "changelog": [
    {
      "date": "2026-03-05",
      "workflow": "refactor:order-cleanup",
      "conceptsAffected": ["concept-order"],
      "filesChanged": ["src/order/service.ts"],
      "summary": "Order 서비스에서 레거시 상태 전이 로직 제거"
    }
  ]
}
```

### Node Types

| Type | 설명 | 추출 시점 |
|------|------|----------|
| `concept` | 도메인 엔티티, 서비스, 패턴 | design.md, plan.md, 코드 분석 |
| `decision` | 설계/구현 결정과 근거 | design.md, context.md, workflow-state decisions |
| `artifact` | 산출물 파일과 메타데이터 | 모든 step 완료 시 |
| `changelog` | 개념별 변경 이력 | implementation, review step 완료 시 |

### Concept Types

| Type | 예시 |
|------|------|
| `entity` | User, Order, Product |
| `service` | PaymentGateway, AuthService |
| `pattern` | EventBus, Repository, Saga |
| `module` | src/order/, src/auth/ |
| `infrastructure` | Redis, PostgreSQL, S3 |

### Artifact Types

| Type | 설명 | 생성 step |
|------|------|----------|
| `design` | 설계 문서 (brainstorming 산출물) | design (Gate) |
| `plan` | 전략 플랜 (planner 산출물) | planning (Auto) |
| `context` | 컨텍스트 & 결정 문서 (planner 산출물) | planning (Auto) |
| `tasks` | 태스크 분해 목록 (writing-plans 산출물) | task-breakdown (Gate) |
| `review` | 아키텍처 리뷰 리포트 (reviewer 산출물) | review (Auto) |

### Relation Types

| Type | 의미 | 예시 |
|------|------|------|
| `has-one` | 1:1 관계 | Order → Payment |
| `has-many` | 1:N 관계 | Order → OrderItem |
| `belongs-to` | 소유 관계 | Order → User |
| `uses` | 의존/사용 | OrderService → PaymentGateway |
| `extends` | 확장/상속 | AdminUser → User |
| `derived-from` | 산출물 파생 | plan.md → design.md |

### Stale Data 전략

concept.files는 시간이 지나면 파일 이름 변경/삭제로 stale해질 수 있다.
핵심 원칙 #4("그래프 손실 무해")에 따라 stale 데이터를 명시적으로 허용한다:

- **정리 시점**: implementation step의 indexing 시, `git diff --name-only`에 파일 rename/delete가 포함되면 해당 concept.files를 업데이트
- **미정리 시 영향**: context injection에서 존재하지 않는 파일이 언급될 수 있으나, 에이전트는 어차피 실제 파일을 직접 읽으므로 기능적 문제 없음
- **전체 정리**: knowledge-graph.json 삭제 후 워크플로우를 거듭하며 재축적 (비용 낮음)

## Extraction Rules

### 실행 주체: LLM (오케스트레이터 자신)

추출은 규칙 기반 파서가 아닌 **오케스트레이터(LLM)가 직접 수행**한다.
오케스트레이터는 step 완료 후 output 마크다운을 읽고, 아래 지시에 따라 구조화된 JSON을 생성한다.

이유:
- 마크다운 구조가 에이전트마다 다르고, 섹션 이름도 유동적 → 규칙 기반 파서로는 커버리지 부족
- 오케스트레이터는 이미 output을 읽고 summary/decisions를 추출하는 로직이 있음 (workflow-state의 auto-extraction) → 같은 읽기 패스에서 knowledge 추출을 함께 수행
- concept type 분류도 LLM이 자동 수행 (사용자 확인 불필요 — 그래프 손실 무해 원칙상 잘못 분류해도 기능에 영향 없음)

### 추출 프롬프트 구조

오케스트레이터가 step output을 읽은 후 내부적으로 수행하는 추출 지시:

```
다음 마크다운 산출물에서 knowledge-graph 항목을 추출하라.

산출물 유형: {design | plan | context | tasks | review}
산출물 경로: {path}
현재 워크플로우: {workflow-name}

추출할 항목:
1. concepts — 도메인 엔티티, 서비스, 패턴, 모듈, 인프라 중 해당하는 것
   - name, type, description (1줄), files (언급된 파일 경로), relations
2. decisions — 설계/구현 결정과 근거
   - content, rationale, 관련 concepts
3. changelog — 이 step에서 변경/영향받은 개념과 파일
   - conceptsAffected, filesChanged, summary (1줄)

규칙:
- 이미 knowledge-graph에 존재하는 concept은 name으로 매칭하여 병합
- 새 concept만 신규 생성, 기존 concept은 files/relations를 합집합으로 업데이트
- 불확실한 추출은 하지 않음 — 명시적으로 언급된 것만 추출
```

### 산출물 유형별 추출 초점

| 산출물 유형 | 주요 추출 대상 | 파싱 힌트 |
|------------|--------------|----------|
| design.md | concepts (아키텍처 구성요소), decisions (Decision Summary 테이블) | "## Architecture", "## Components", "## Decision Summary" |
| plan.md | concepts 보강 (파일 매핑), artifact 연결 | "## Architecture Impact", "## Task Overview" |
| context.md | decisions (Key Decisions 테이블) | "## Key Decisions", "## Technical Context" |
| tasks.md | concept-file 매핑 강화, changelog 준비 | 각 Task의 "Files" 목록 |
| review.md | changelog (실제 변경 이력), 이슈 기록 | "## Blocking Issues", "## Verification Drift" |

## Orchestrator Integration Spec

### workflow SKILL.md에 추가할 섹션

```markdown
## Knowledge Graph Management

### Indexing (step 완료 후)

각 step 완료 후 output 파일이 존재하면:
1. `.claude/knowledge-graph.json` 읽기 (없으면 빈 그래프 초기화: `{"version":"1.0","concepts":[],"decisions":[],"artifacts":[],"changelog":[]}`)
2. output 마크다운을 읽고, 추출 프롬프트 구조에 따라 concepts/decisions/changelog 추출
3. 기존 concept과 name 매칭 — 있으면 병합(files, relations 합집합), 없으면 신규 생성
4. artifact 노드 추가 (derivedFrom은 이전 step의 artifact)
5. knowledge-graph.json 저장
6. 인덱싱 실패 시 (파일 I/O 에러 등) 경고만 출력하고 워크플로우는 계속 진행

Step type별 적용:
- skill (Gate): 사용자 승인 후 output 인덱싱. dispatch 시 context injection 미적용.
- agent: output 인덱싱 + dispatch 시 context injection 적용.
- agent-chain: 체인 완료 후 최종 output 인덱싱. 첫 에이전트 dispatch에만 context injection.
- parallel: 각 sub-step 완료 후 개별 인덱싱. 각 sub-step dispatch에 독립 context injection.
- conditional: 실행된 branch의 output 인덱싱. 선택된 branch dispatch에 context injection.

### Context Injection (agent dispatch 시)

에이전트 dispatch prompt 구성 시:
1. knowledge-graph.json 읽기 (없으면 생략)
2. 3단계 관련성 매칭으로 concepts 필터:
   - P1: 현재 step의 input artifact가 참조하는 concepts
   - P2: 현재 workflow의 이전 step에서 생성된 decisions/concepts
   - P3: git diff --name-only의 변경 파일과 concept.files 교집합
3. 관련 concepts의 최근 decisions (최대 5개) 수집
4. 관련 concepts의 changelog (최대 3개) 수집
5. 50줄 이내로 포맷하여 dispatch prompt에 추가:

   ## Project Knowledge Context (auto-injected)
   {formatted context}

6. 관련 concept이 없으면 이 섹션을 생략

### Resume 시 Knowledge 활용

resume 시 기존 흐름에 추가:
knowledge-graph.json에서 현재 workflow의 concepts 요약 출력:
"이 워크플로우에서 다루는 주요 개념: Order, Payment (관련 결정 3건)"
```

## Decisions (Previously Open Questions)

| # | 질문 | 결정 | 근거 |
|---|------|------|------|
| 1 | 초기 부트스트랩 방식 | 점진적 축적 (코드 스캔 부트스트랩 없음) | 핵심 원칙 #3과 일치. 첫 워크플로우에서는 빈 그래프로 시작하고, step 완료마다 축적. 코드 스캔 부트스트랩은 복잡도 대비 가치 낮음 (Out of Scope의 "코드 변경 시 실시간 concept 업데이트"와 같은 계열) |
| 2 | concept 분류 자동화 수준 | LLM 자동 분류, 사용자 확인 없음 | 핵심 원칙 #4에 의해 잘못 분류해도 기능적 영향 없음. concept type은 context injection 시 참고 정보일 뿐, 워크플로우 로직에 영향 안 줌 |

## Scope and Constraints

### In Scope
- knowledge-graph.json 스키마 정의
- 오케스트레이터에 indexing hook 추가 (step type별 적용 규칙 포함)
- 오케스트레이터에 context injection 추가 (3단계 관련성 매칭)
- resume 시 knowledge 요약 추가

### Out of Scope (백로그)
- 에이전트가 직접 knowledge-graph를 읽고 쓰는 것 (옵션 C)
- 별도 knowledge 조회 스킬/커맨드
- 코드 변경 시 실시간 concept 업데이트
- 그래프 시각화 도구
- 다중 프로젝트 간 knowledge 공유
- 코드 스캔 기반 초기 부트스트랩

### Constraints
- knowledge-graph.json은 단일 JSON 파일 (프로젝트 규모에서 충분)
- 컨텍스트 주입 상한 50줄 (에이전트 컨텍스트 윈도우 보호)
- 그래프 삭제 시 기능 손실 없음 (마크다운이 원본)
- 스키마 버전 관리 포함 (향후 마이그레이션 대비)
- 인덱싱 실패 시 워크플로우 중단 안 함 (경고만 출력)

## Success Criteria

1. 기존 워크플로우 6종(feature-dev, bugfix, refactor, quick-fix, planning-only, skill-creation)이 knowledge-graph 없이도 동일하게 동작 (하위 호환)
2. knowledge-graph가 있을 때 context injection 대상 step type(agent, agent-chain, parallel, conditional)의 dispatch에 `## Project Knowledge Context` 섹션이 포함됨
3. 두 번째 워크플로우의 planner dispatch prompt에 첫 번째 워크플로우에서 추출된 concepts/decisions가 주입됨 (주입 여부로 관찰 가능)
4. resume 시 knowledge 요약이 step 이력과 함께 출력됨
5. knowledge-graph.json을 삭제해도 모든 워크플로우가 정상 동작
6. 인덱싱 과정에서 에러가 발생해도 워크플로우가 중단되지 않음
