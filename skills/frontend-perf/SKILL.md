---
name: frontend-perf
description: Use when reviewing frontend code changes for performance anti-patterns. Detects waterfall fetches, bundle bloat, unnecessary re-renders, and JS inefficiencies.
user-invocable: false
---

# Frontend Performance Guard (Cross-Cutting)

This skill activates when frontend files (`.tsx`, `.jsx`, `.css`, `.scss`, `components/`, `pages/`, `app/`) are changed. It provides a performance anti-pattern checklist for reviewers and implementers.

## Waterfall Prevention

| ID | Rule | Severity |
|----|------|----------|
| WF-01 | **Defer await** — `await`를 실제 값이 필요한 시점까지 지연. 함수 초입에서 즉시 await하지 말 것 | CRITICAL |
| WF-02 | **Parallel fetch** — 독립적인 비동기 작업은 `Promise.all()` 또는 `Promise.allSettled()`로 병렬화 | CRITICAL |
| WF-03 | **Partial dependency chain** — A→B는 의존, C는 독립일 때 A+C 병렬 후 B 실행 | HIGH |
| WF-04 | **Early promise init** — API 핸들러에서 promise를 일찍 생성하고 필요한 분기에서만 await | HIGH |

### Bad

```typescript
// Sequential — total time = A + B + C
const a = await fetchA();
const b = await fetchB();
const c = await fetchC();
```

### Good

```typescript
// Parallel — total time = max(A, B, C)
const [a, b, c] = await Promise.all([fetchA(), fetchB(), fetchC()]);
```

## Bundle Optimization

| ID | Rule | Severity |
|----|------|----------|
| BO-01 | **No barrel imports** — `index.ts` re-export 파일에서 import하지 말 것. 직접 모듈 경로 사용 | CRITICAL |
| BO-02 | **Dynamic import** — 초기 렌더에 불필요한 무거운 컴포넌트는 lazy/dynamic import | CRITICAL |
| BO-03 | **Defer third-party** — 분석/로깅/트래킹 스크립트는 hydration 이후 로드 | HIGH |
| BO-04 | **Conditional loading** — 피처 플래그 뒤의 모듈은 활성화 시점에만 `import()` | MEDIUM |
| BO-05 | **Preload on intent** — 호버/포커스 시 `import()`로 사전 로드하여 체감 속도 개선 | LOW |

### Bad

```typescript
// Barrel import — tree-shaking 불가능한 경우 전체 모듈 번들링
import { Button } from '@/components';
```

### Good

```typescript
// Direct import — 필요한 모듈만 번들링
import { Button } from '@/components/ui/button';
```

## Render Efficiency

| ID | Rule | Severity |
|----|------|----------|
| RE-01 | **CSS content-visibility** — 긴 리스트/오프스크린 요소에 `content-visibility: auto` 적용 | MEDIUM |
| RE-02 | **SVG precision** — SVG 좌표 소수점 2자리 이하로 축소 (`3.14159` → `3.14`) | LOW |
| RE-03 | **Hoist static JSX** — 렌더 함수 외부로 정적 JSX 추출 (매 렌더마다 재생성 방지) | MEDIUM |
| RE-04 | **Derived state** — raw 값을 구독하지 말고 파생된 boolean/값을 구독 | HIGH |
| RE-05 | **Functional state update** — 이전 상태에 의존하는 업데이트는 함수형으로 | MEDIUM |
| RE-06 | **Lazy state init** — 비용이 큰 초기값은 함수로 전달 (`useState(fn)`) | MEDIUM |

### Bad

```typescript
// Static JSX recreated every render
function List({ items }) {
  const header = <h1>Title</h1>;  // recreated each render
  return <div>{header}{items.map(...)}</div>;
}
```

### Good

```typescript
// Hoisted outside — created once
const header = <h1>Title</h1>;

function List({ items }) {
  return <div>{header}{items.map(...)}</div>;
}
```

## JavaScript Micro-Optimization

| ID | Rule | Severity |
|----|------|----------|
| JS-01 | **Set/Map lookups** — 반복 탐색이 필요하면 `Array.includes()` 대신 `Set`/`Map` 사용 (O(1)) | HIGH |
| JS-02 | **Combine iterations** — 여러 `filter().map()` 체인을 단일 `reduce()` 또는 루프로 합침 | MEDIUM |
| JS-03 | **Early exit** — 조건 불충족 시 즉시 return. 깊은 중첩 방지 | MEDIUM |
| JS-04 | **Hoist regex** — 루프 내부에서 정규식을 생성하지 말 것. 외부에 정의 | LOW |
| JS-05 | **Cache property access** — 루프 내 반복적인 객체 프로퍼티 접근은 지역 변수로 캐시 | LOW |
| JS-06 | **Length check first** — 비싼 비교 전에 배열 길이부터 체크 | LOW |
| JS-07 | **Batch DOM/CSS** — CSS 수정은 개별 속성 대신 클래스 토글이나 `cssText`로 일괄 적용 | MEDIUM |

### Bad

```typescript
// Linear search in hot loop — O(n) per lookup
const allowedIds = [1, 2, 3, 4, 5];
items.filter(item => allowedIds.includes(item.id));
```

### Good

```typescript
// Set lookup — O(1) per lookup
const allowedIds = new Set([1, 2, 3, 4, 5]);
items.filter(item => allowedIds.has(item.id));
```

## Enforcement Verification

When this skill is used with `enforcement: enforce` in a workflow step, the orchestrator verifies compliance by reading the reviewer's output.

### Evidence Required
1. Reviewer output must reference at least the CRITICAL rules (WF-01, WF-02, BO-01, BO-02) when frontend files are changed
2. Each flagged issue must cite a specific rule ID and file:line

### Pass Criteria
- All CRITICAL-severity violations are flagged in review output
- No false negatives on waterfall fetches or barrel imports in changed files

### Failure Response
If evidence is missing, re-dispatch the reviewer with:
```
frontend-perf 규칙 미준수: 프론트엔드 파일 변경에 대한 성능 체크리스트가 누락되었습니다.
CRITICAL 규칙(WF-01, WF-02, BO-01, BO-02)을 최소한 확인하고, 위반 시 file:line과 규칙 ID를 포함하여 재보고하세요.
```

## Domain Context

**방법론 근거**: 프론트엔드 성능 최적화는 Google의 Web Vitals 이니셔티브와 Chrome DevTools 팀의 연구에 기반한다. LCP, FID, CLS 등 사용자 체감 성능 지표가 비즈니스 전환율에 직접 영향을 미친다는 실증 연구가 핵심 근거다.

**핵심 원리**: 성능 문제의 80%는 워터폴 요청, 번들 비대화, 불필요한 리렌더링 3가지로 귀결된다. 이 스킬의 규칙은 이 3가지 범주를 체계적으로 탐지한다.

### Further Reading
- [web.dev/vitals](https://web.dev/vitals/) — Google Core Web Vitals 공식 가이드
- Addy Osmani, [JavaScript Performance](https://medium.com/reloading/javascript-start-up-performance-69200f43b201) — JS 로딩 성능 분석
- Philip Walton, [Idle Until Urgent](https://philipwalton.com/articles/idle-until-urgent/) — 메인 스레드 최적화 패턴

## Rules
- CRITICAL/HIGH 위반만 blocking — MEDIUM/LOW는 advisory
- 백엔드 전용 파일 변경에서는 이 스킬을 적용하지 않음
- 기존 코드의 성능 문제는 플래그하지 않음 — 이번 변경에서 도입된 것만 대상
- 프레임워크 특화 규칙 강제 금지 — React/Vue/Svelte 무관하게 적용 가능한 규칙만 포함
