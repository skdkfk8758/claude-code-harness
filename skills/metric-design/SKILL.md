---
name: metric-design
description: Use when defining success metrics for a feature or product. Designs North Star Metric, input metrics, counter-metrics, and alert thresholds.
user-invocable: true
allowed-tools: Read, Glob, Grep, AskUserQuestion, Write
argument-hint: "<feature-or-product>"
---

# Metric Design Gate

설계 완료 후 "성공을 어떻게 측정할 것인가"를 정의하는 게이트.
brainstorming/writing-plans 이후, 구현 전에 실행하는 것을 권장.

## Input

다음 중 하나 이상을 입력으로 받음:
- 설계 문서 (`docs/plans/*-design.md`)
- 플랜 문서 (`docs/plans/*-plan.md`)
- 사용자의 자연어 설명

## Process

### Phase 1: Context Gathering

1. 설계/플랜 문서가 있으면 읽고 핵심 목표 추출
2. 사용자에게 확인:

```
이 기능의 핵심 목표를 확인합니다:
- 목표: {문서에서 추출한 목표}
- 대상 사용자: {추출 또는 질문}
맞나요? 보정할 부분이 있으면 알려주세요.
```

### Phase 2: North Star Metric 정의

#### 2-1. 제품 게임 분류

| 게임 | 특징 | NSM 방향 | 예시 |
|------|------|----------|------|
| **Attention** | 사용자 시간/관심이 가치 | 참여 시간, DAU | Netflix, Instagram |
| **Transaction** | 거래 완료가 가치 | 거래 건수, GMV | Shopify, Airbnb |
| **Productivity** | 작업 효율이 가치 | 완료된 태스크, 절약 시간 | Slack, Notion |

사용자에게 제품/기능이 어떤 게임에 해당하는지 확인.

#### 2-2. NSM 후보 도출

1. 게임 유형에 맞는 NSM 후보 2-3개 생성
2. 각 후보에 **7대 검증 기준** 적용:

| # | 기준 | 질문 |
|---|------|------|
| 1 | Value reflection | 이 지표가 올라가면 사용자가 실제로 가치를 얻는가? |
| 2 | Leading indicator | 매출/성장보다 먼저 움직이는 선행 지표인가? |
| 3 | Actionable | 팀이 이 지표를 직접 개선할 수 있는가? |
| 4 | Understandable | 모든 팀원이 이 지표를 이해하는가? |
| 5 | Measurable | 현재 인프라로 측정 가능한가? |
| 6 | Not gameable | 쉽게 조작할 수 없는가? (Goodhart's Law 방지) |
| 7 | Comparable | 시간 경과에 따라 비교 가능한가? |

검증 결과를 테이블로 표시하고, 가장 적합한 NSM 1개를 사용자와 함께 선정.

### Phase 3: Input Metrics 정의

NSM을 움직이는 하위 지표 3-5개 도출:

```
NSM: {선정된 North Star Metric}
  ├── Input 1: {지표명} — {설명}
  ├── Input 2: {지표명} — {설명}
  ├── Input 3: {지표명} — {설명}
  └── (선택) Input 4-5
```

각 Input Metric에 대해:
- 측정 방법 (이벤트, 쿼리 등)
- 현재 기대 baseline (추정 또는 "측정 필요")
- 목표 방향 (증가/감소/유지)

### Phase 4: Counter-Metrics 정의

NSM 추구 시 부작용을 탐지하는 견제 지표 1-2개:

| Counter-Metric | 견제 대상 | 경고 기준 |
|---------------|----------|----------|
| {지표명} | "NSM을 올리려고 {부작용}이 발생할 수 있음" | {threshold} |

**Goodhart's Law 경고**: "지표가 목표가 되는 순간, 좋은 지표이기를 멈춘다." Counter-Metric은 이 현상을 탐지하는 안전장치.

### Phase 5: Alert Thresholds & Review Cadence

| 지표 | 정상 범위 | 주의 (Yellow) | 위험 (Red) | 리뷰 주기 |
|------|----------|--------------|-----------|----------|
| NSM | {range} | {threshold} | {threshold} | 주간 |
| Input 1 | {range} | {threshold} | {threshold} | 일간 |
| Counter 1 | {range} | {threshold} | {threshold} | 주간 |

## Output

`docs/plans/{date}-{name}-metrics.md`에 저장:

```markdown
# Metric Framework: {feature/product}

## North Star Metric
- **NSM**: {metric}
- **Game**: {Attention/Transaction/Productivity}
- **Validation**: {7대 기준 통과 요약}

## Input Metrics
{테이블}

## Counter-Metrics
{테이블}

## Alert Thresholds
{테이블}

## Review Cadence
- 일간: Input Metrics 모니터링
- 주간: NSM + Counter-Metrics 리뷰
- 월간: 프레임워크 전체 재검토
```

완료 메시지:
```
✅ Metric framework approved: docs/plans/{date}-{name}-metrics.md

Next step: 구현 시 이 지표를 추적할 이벤트/로깅을 포함하세요.
워크플로우 중이라면 orchestrator로 돌아가세요.
```

## Domain Context

**방법론 근거**: North Star Metric 프레임워크는 Sean Ellis(*Hacking Growth*, 2017)와 Amplitude 팀이 정립한 제품 성장 지표 체계다. "하나의 핵심 지표"에 집중하여 팀 정렬을 달성하되, Counter-Metric으로 Goodhart's Law의 부작용을 방지한다.

**핵심 원리**: 좋은 지표는 (1) 사용자 가치를 반영하고, (2) 팀이 직접 움직일 수 있으며, (3) 비즈니스 성과의 선행 지표여야 한다.

### Further Reading
- Sean Ellis & Morgan Brown, *Hacking Growth* (Currency, 2017) — NSM과 성장 루프
- John Cutler, [North Star Playbook](https://amplitude.com/north-star) (Amplitude) — NSM 설계 실무 가이드
- Charles Goodhart, "Goodhart's Law" — 지표가 목표가 되면 좋은 지표가 아니게 되는 현상

## Rules
- NSM은 반드시 1개만 선정 — 복수 NSM은 팀 정렬을 해침
- Input Metrics는 3-5개 — 너무 적으면 커버리지 부족, 너무 많으면 집중력 분산
- Counter-Metric은 최소 1개 — Goodhart's Law 방지 필수
- 측정 불가능한 지표를 선정하지 않음 — "측정 필요"로 표기하되, 구현 시 추적 계획을 포함
- 이 스킬은 설계 게이트이므로 코드를 작성하지 않음
