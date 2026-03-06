# External Skill Integration Plan

## Overview

`chacha95/claude-code-harness`의 6개 스킬을 비판적 검토한 결과, 통합 가치가 있는 요소를 추출하여 기존 CCH 워크플로우에 녹이는 플랜.

## 통합 대상 요약

| 원본 스킬 | 추출 요소 | 통합 위치 | 형태 |
|-----------|----------|----------|------|
| `vercel-react-best-practices` | 성능 최적화 규칙 프레임워크 (57개 중 범용 규칙) | `code-quality-reviewer` + 새 cross-cutting 스킬 | 기존 확장 |
| `frontend-design` | 디자인 사고 프레임워크 (미학 강제 제외) | `brainstorming` 스킬 | 기존 확장 |
| `pytest-backend-testing` | 테스트 구조 원칙 (AAA, 네이밍, 레이어별 전략) | `tdd` 스킬 | 기존 확장 |

**제외**: `fastapi-backend-guidelines`, `nextjs-frontend-guidelines`, `web-design-guidelines` — 프로젝트 특화이거나 자기완결성 위반

---

## Task 1: `frontend-perf` cross-cutting 스킬 신설

### 목적
프론트엔드 코드가 포함된 변경에서 성능 안티패턴을 자동 감지하는 가드레일.
`vercel-react-best-practices`의 57개 규칙 중 **프레임워크 무관 범용 규칙**만 추출.

### 소스 분석

원본 8개 카테고리 중 통합 대상:

| 카테고리 | 통합 여부 | 이유 |
|---------|----------|------|
| Eliminating Waterfalls (`async-*`) | **O** | `Promise.all`, `await` 위치 최적화 — 프레임워크 무관 |
| Bundle Size (`bundle-*`) | **부분** | barrel import, dynamic import는 범용. `next/dynamic`은 Next.js 전용이므로 일반화 |
| Server-Side (`server-*`) | **X** | Next.js RSC 전용 |
| Client Data Fetching (`client-*`) | **부분** | SWR 전용 제외, passive event listener/localStorage 패턴은 범용 |
| Re-render Optimization (`rerender-*`) | **부분** | React 전용(`useMemo`, `useRef`) 제외, 일반 원칙(derived state, functional update)만 |
| Rendering Performance (`rendering-*`) | **부분** | CSS content-visibility, SVG 최적화는 범용. Suspense/Activity는 React 전용 |
| JavaScript Performance (`js-*`) | **O** | 전부 범용 — Set/Map 룩업, 루프 최적화, 정규식 호이스팅 등 |
| Advanced Patterns (`advanced-*`) | **X** | React hooks 전용 |

### 산출물

```
skills/
  frontend-perf/
    SKILL.md          # cross-cutting 스킬 정의
```

### SKILL.md 구조

```yaml
---
name: frontend-perf
description: Use when reviewing frontend code changes for performance anti-patterns. Detects waterfall fetches, bundle bloat, unnecessary re-renders, and JS inefficiencies.
user-invocable: false
---
```

**본문 구성:**
1. **Waterfall Prevention** — parallel fetch, deferred await, early promise init
2. **Bundle Optimization** — direct imports (no barrel), lazy loading, deferred third-party
3. **Render Efficiency** — content-visibility, SVG precision, static JSX hoisting
4. **JS Micro-Optimization** — Map/Set lookups, loop combining, regex hoisting, early exit

**각 규칙 형식:**
- Rule ID (예: `WF-01`)
- Bad pattern (before)
- Good pattern (after)
- Severity: CRITICAL / HIGH / MEDIUM / LOW

**Enforcement Verification 섹션 포함** — `enforcement: enforce`로 사용 시 리뷰어 출력에서 체크리스트 증거 확인.

### 워크플로우 연결

`feature-dev.yaml`과 `refactor.yaml`의 `implementation` 단계 `cross-cutting`에 optional로 추가:

```yaml
cross-cutting:
  - name: frontend-perf
    enforcement: suggest    # suggest만 — 백엔드 전용 프로젝트에서 노이즈 방지
```

`code-quality-reviewer`의 `### 7. Performance` 섹션에서 이 스킬을 참조하도록 확장:

```markdown
### 7. Performance
- (기존 내용 유지)
- 프론트엔드 코드 변경 시, `frontend-perf` 스킬의 규칙 체크리스트 참조
```

### 조건부 활성화 로직

`skill-rules.json`에 fileTrigger 추가:

```json
"frontend-perf": {
  "type": "guardrail",
  "enforcement": "suggest",
  "priority": "medium",
  "description": "Frontend performance anti-pattern detection",
  "fileTriggers": {
    "pathPatterns": [
      "**/*.tsx", "**/*.jsx",
      "**/components/**",
      "**/pages/**", "**/app/**",
      "**/*.css", "**/*.scss"
    ]
  }
}
```

이렇게 하면 **프론트엔드 파일이 변경될 때만** 활성화되고, 백엔드 전용 프로젝트에서는 침묵.

---

## Task 2: `brainstorming` 스킬에 디자인 사고 프레임워크 추가

### 목적
`frontend-design`의 "Design Thinking Framework"를 `brainstorming` Phase 2에 통합.
UI/프론트엔드 작업일 때만 활성화되는 **조건부 서브프로세스**.

### 현재 brainstorming Phase 2

```
Phase 2: Option Exploration
1. Generate 2-3 design options
2. For each option: Approach, Pros, Cons, Effort
3. Present as comparison table
```

### 추가할 내용

Phase 2에 **UI/Frontend 감지 시 추가 프레임워크** 삽입:

```markdown
### Phase 2-A: UI Design Framework (UI/프론트엔드 작업 시에만)

Auto-scan 결과 UI 컴포넌트/페이지/스타일 작업으로 판단되면:

1. **Purpose** — 해결하는 문제, 타겟 사용자
2. **Tone** — 미적 방향성 선택 (사용자에게 옵션 제시, 강제하지 않음)
   - minimal, maximalist, retro-futuristic, organic, luxury, playful,
     editorial, brutalist, art deco, soft/pastel, industrial 등
3. **Constraints** — 기술 요구사항 (프레임워크, 성능, 접근성)
4. **Differentiation** — 기억에 남는 차별화 요소

각 디자인 옵션에 추가 평가 축:
- Typography 전략
- Color & Theme 일관성
- Motion/Animation 접근
- Spatial Composition (레이아웃)
```

### 변경 범위

- `skills/brainstorming/SKILL.md` — Phase 2 확장 (약 30줄 추가)
- 기존 Phase 2 로직은 그대로 유지, UI 감지 시에만 추가 프레임워크 적용

### 주의사항

- 원본의 "Inter/Roboto 금지" 같은 **독단적 미학 규칙은 제외**
- 프레임워크만 제공하고 특정 스타일을 강제하지 않음
- 사용자가 디자인 시스템을 이미 가지고 있으면 해당 시스템 우선

---

## Task 3: `tdd` 스킬에 테스트 구조 가이드 보강

### 목적
`pytest-backend-testing`에서 프레임워크 무관한 보편 원칙만 추출하여 `tdd` 스킬의 실용성 강화.

### 추출할 내용

| 원본 요소 | 통합 방식 |
|----------|----------|
| AAA 패턴 (Arrange-Act-Assert) | `tdd`의 RED 단계 가이드에 명시적 AAA 구조 추가 |
| 테스트 네이밍 (`test_<what>_<when>_<expected>`) | Anti-Patterns 테이블에 "Bad naming" 항목 추가 |
| 3-Layer 테스트 전략 (Repository/Service/Router) | 새 섹션 "## Test Scoping by Layer" 추가 |
| Coverage 체크리스트 | Enforcement Verification에 커버리지 확인 옵션 추가 |

### 변경 범위

`skills/tdd/SKILL.md`에 2개 섹션 추가:

```markdown
## Test Structure: AAA Pattern

모든 테스트는 세 파트로 구성:

| Phase | What | Example |
|-------|------|---------|
| **Arrange** | 테스트 데이터, 목, 픽스처 설정 | `const user = createTestUser()` |
| **Act** | 테스트 대상 코드 실행 | `const result = await service.getUser(id)` |
| **Assert** | 기대 결과 검증 | `expect(result.name).toBe('test')` |

빈 줄로 각 파트를 구분할 것. 하나의 테스트에 여러 Act/Assert가 있으면 테스트를 분리.

## Test Naming Convention

```
test_<what>_<when>_<expected>
```

| Bad | Good |
|-----|------|
| `test1`, `it works` | `test_create_user_with_valid_data_returns_user` |
| `test_service` | `test_get_user_when_not_found_raises_404` |
| `should work correctly` | `adds_two_positive_numbers_returns_sum` |
```

### Anti-Patterns 테이블 추가 항목

```markdown
| Testing only happy path | Test error cases, edge cases, boundary conditions |
| No test structure (AAA) | Separate Arrange/Act/Assert with blank lines |
| Vague test names | Use test_<what>_<when>_<expected> pattern |
```

---

## Task 4: `code-quality-reviewer` 에이전트 Performance 섹션 강화

### 목적
현재 `### 7. Performance` 가 3줄로 너무 얕음. `frontend-perf` 스킬과 연동하여 체계적 성능 리뷰 수행.

### 현재 상태

```markdown
### 7. Performance (flag only if obvious)
- No N+1 queries
- No unnecessary loops over large collections
- No blocking calls in async contexts
```

### 변경 후

```markdown
### 7. Performance
- No N+1 queries or waterfall fetches (sequential awaits on independent data)
- No unnecessary loops over large collections
- No blocking calls in async contexts
- No barrel imports (`index.ts` re-exports) that bloat bundles
- No large third-party libs loaded eagerly when defer/lazy is possible
- Object/array lookups in hot paths use Map/Set instead of linear search
- If `frontend-perf` cross-cutting skill is active, reference its checklist for detailed rules
```

### 변경 범위

- `agents/code-quality-reviewer.md` — `### 7. Performance` 섹션 확장 (4줄 추가)

---

## 실행 순서

```
1. Task 1: frontend-perf 스킬 생성
   ├─ skills/frontend-perf/SKILL.md 작성
   ├─ skill-rules.json에 fileTrigger 등록
   └─ 검증: skill-manager validate

2. Task 2: brainstorming Phase 2-A 추가
   ├─ skills/brainstorming/SKILL.md 수정
   └─ 검증: 기존 Phase 2 로직 깨지지 않는지 확인

3. Task 3: tdd 스킬 보강
   ├─ skills/tdd/SKILL.md에 AAA + Naming 섹션 추가
   └─ 검증: Enforcement Verification 호환성 확인

4. Task 4: code-quality-reviewer Performance 강화
   ├─ agents/code-quality-reviewer.md 수정
   └─ 검증: 기존 review-pipeline 호환성 확인

5. Workflow 연결
   ├─ feature-dev.yaml implementation 단계에 frontend-perf suggest 추가
   ├─ refactor.yaml implementation 단계에 frontend-perf suggest 추가
   └─ 검증: workflow-manager validate
```

## 명시적 제외 사항

| 원본 | 제외 이유 |
|------|----------|
| `fastapi-backend-guidelines` 전체 | 프로젝트 특화 (YGS 전용 구조/모델) |
| `nextjs-frontend-guidelines` 전체 | 프로젝트 특화 + 프레임워크 버전 종속 |
| `web-design-guidelines` 전체 | 외부 URL 의존, 자기완결성 위반 |
| `frontend-design`의 미학 금지 규칙 | 독단적 — "Inter 쓰지 마라" 같은 강제는 CCH 철학과 충돌 |
| `vercel-react-best-practices`의 React 전용 규칙 | `server-*`, `advanced-*`, React hooks 전용 `rerender-*` |
| `pytest-backend-testing`의 pytest 전용 코드 | AsyncSession mock, FastAPI TestClient 등 프레임워크 특화 |

## 리스크

| 리스크 | 완화 |
|--------|------|
| `frontend-perf`가 백엔드 프로젝트에서 노이즈 | fileTrigger로 `.tsx/.jsx/components/` 패턴에만 반응 |
| brainstorming Phase 2-A가 비UI 작업에서 오발동 | auto-scan 결과 기반 조건부 — UI 컴포넌트 미감지 시 스킵 |
| tdd 스킬 비대화 | AAA + Naming만 추가 (약 30줄), 레이어별 전략은 별도 참조 파일로 분리 가능 |
| Performance 규칙이 과도한 마이크로 최적화 유도 | severity 구분 (CRITICAL만 blocking, 나머지 advisory) |
