---
name: experiment-analysis
description: Use when analyzing A/B test results or experiment data. Performs statistical analysis and produces Ship/Extend/Stop decisions.
user-invocable: true
allowed-tools: Read, Bash, Glob, Grep, AskUserQuestion, Write
argument-hint: "<test-data-or-description>"
---

# Experiment Analysis Gate

A/B 테스트 또는 실험 결과를 통계적으로 분석하여 의사결정을 돕는 게이트.
metric-design에서 정의한 지표 프레임워크를 기반으로 실험 결과를 해석한다.

## Input

다음 중 하나 이상:
- 실험 결과 데이터 (CSV, JSON, 텍스트 요약)
- 실험 플랫폼 스크린샷
- 사용자의 구두 설명 (샘플 수, 전환율 등)
- `docs/plans/*-metrics.md` (metric-design 산출물, 있으면 자동 참조)

## Process

### Phase 1: Experiment Context

1. 기존 메트릭 프레임워크가 있으면 읽기 (`docs/plans/*-metrics.md`)
2. 실험 기본 정보 수집:

```
실험 정보를 확인합니다:
- 가설: {추출 또는 질문}
- 변형(Variants): Control vs Treatment(s)
- 주요 지표: {metrics.md에서 추출 또는 질문}
- 실험 기간: {기간}
- 샘플 크기: Control {N} / Treatment {N}
```

### Phase 2: Data Integrity Check

실험 데이터의 신뢰성을 먼저 검증:

| Check | 방법 | Pass 기준 |
|-------|------|----------|
| **SRM (Sample Ratio Mismatch)** | chi-squared test on sample sizes | p > 0.01 |
| **Minimum Sample Size** | n ≥ (Z²α/2 × 2 × p × (1-p)) / MDE² | 계산된 최소 표본 충족 |
| **Duration** | 최소 1 full business cycle (보통 7일) | 실험 기간 ≥ 7일 |
| **Novelty/Primacy Effect** | 시간 경과에 따른 효과 변화 확인 | 효과가 안정적 |

SRM 실패 시:
```
⚠️ SRM 감지: 샘플 비율이 기대값과 유의하게 다릅니다.
Control: {N} ({%}) vs Treatment: {N} ({%})
이 실험의 결과는 신뢰할 수 없습니다. 실험 설정을 점검하세요.
원인 가능성: 트래픽 할당 버그, 봇 트래픽, 리다이렉트 이슈
```

### Phase 3: Statistical Analysis

#### 이항 지표 (전환율, 클릭률 등)

| 항목 | 공식 |
|------|------|
| **z-statistic** | z = (p₁ - p₂) / √(p̂(1-p̂)(1/n₁ + 1/n₂)) |
| **p-value** | 양측 검정, α = 0.05 |
| **95% CI** | (p₁ - p₂) ± Z₀.₀₂₅ × SE |
| **Relative lift** | (Treatment - Control) / Control × 100% |

#### 연속 지표 (수익, 체류 시간 등)

| 항목 | 공식 |
|------|------|
| **t-statistic** | t = (x̄₁ - x̄₂) / √(s₁²/n₁ + s₂²/n₂) |
| **p-value** | Welch's t-test, α = 0.05 |
| **95% CI** | (x̄₁ - x̄₂) ± t₀.₀₂₅ × SE |

#### 결과 표시

```markdown
| Metric | Control | Treatment | Lift | 95% CI | p-value | Significant? |
|--------|---------|-----------|------|--------|---------|-------------|
| {지표} | {값} | {값} | {%} | [{lo}, {hi}] | {p} | {Yes/No} |
```

### Phase 4: Decision Matrix

분석 결과에 기반한 의사결정:

| 시나리오 | 조건 | 결정 | 후속 조치 |
|---------|------|------|----------|
| **Clear Win** | p < 0.05, lift > MDE, counter-metric 안정 | **Ship** | 전체 배포 |
| **Marginal Win** | p < 0.05, lift < MDE | **Extend** | 실험 연장 또는 추가 분석 |
| **Inconclusive** | p ≥ 0.05, 표본 부족 | **Extend** | 표본 크기 증가 후 재분석 |
| **Neutral** | p ≥ 0.05, 충분한 표본 | **Stop** | 다른 가설 탐색 |
| **Clear Loss** | p < 0.05, negative lift | **Stop** | 원인 분석 후 재설계 |

### Phase 5: Counter-Metric Check

metric-design에서 정의한 Counter-Metric이 있으면 확인:

```
Counter-Metric 체크:
- {counter-metric}: {변화} — {정상/주의/위험}

⚠️ Primary metric은 개선되었으나 counter-metric이 악화되었습니다.
Trade-off를 검토하세요.
```

### Phase 6: Business Impact Estimate

통계적으로 유의한 결과에 대해 비즈니스 임팩트 추정:

```
예상 비즈니스 임팩트 (연간 기준):
- 현재 baseline: {값}
- 예상 개선: {lift}% → {절대값 변화}
- 보수적 추정 (CI 하한): {값}
- 낙관적 추정 (CI 상한): {값}
```

## Output

`docs/plans/{date}-{name}-experiment.md`에 저장:

```markdown
# Experiment Analysis: {experiment name}

## Summary
- **Decision**: {Ship/Extend/Stop}
- **Primary Metric**: {metric} — {lift}% lift (p={p-value})
- **Counter-Metrics**: {status}

## Data Integrity
{SRM, sample size, duration checks}

## Statistical Results
{결과 테이블}

## Decision Rationale
{왜 이 결정인지 1-2문장}

## Business Impact
{연간 임팩트 추정}

## Next Steps
- {구체적 후속 조치 1}
- {구체적 후속 조치 2}
```

완료 메시지:
```
✅ Experiment analysis complete: docs/plans/{date}-{name}-experiment.md
Decision: {Ship/Extend/Stop}

다음 단계 제안:
- Ship → 구현 배포 진행
- Extend → 실험 기간 연장 후 재분석
- Stop → 새 가설로 /workflow feature-dev 시작
```

## Domain Context

**방법론 근거**: A/B 테스트의 통계적 분석은 Ronald Fisher의 가설 검정 이론(1925)에 기반하며, 현대 제품 개발에서는 Ron Kohavi의 *Trustworthy Online Controlled Experiments* (2020)가 실무 표준을 정립했다.

**핵심 원리**: 통계적 유의성(p < 0.05)은 필요조건이지 충분조건이 아니다. 실무적 유의성(MDE 초과 여부), 비즈니스 임팩트, counter-metric 안정성을 모두 확인해야 올바른 의사결정이 가능하다.

### Further Reading
- Ron Kohavi, Diane Tang & Ya Xu, *Trustworthy Online Controlled Experiments* (Cambridge, 2020)
- Evan Miller, [A/B Test Calculator](https://www.evanmiller.org/ab-testing/) — 표본 크기 계산 도구
- Alex Deng et al., "Improving the Sensitivity of Online Controlled Experiments" (KDD 2013) — SRM 탐지 기법

## Rules
- SRM이 감지되면 **어떤 결과도 신뢰하지 않음** — 실험 설정 점검 우선
- p-value만으로 결정하지 않음 — lift 크기, CI, counter-metric을 함께 확인
- "거의 유의한" (p = 0.06 등)을 유의한 것으로 해석하지 않음 — Extend 결정
- 데이터가 부족하면 추정하지 않음 — "표본 부족" 명시
- 이 스킬은 분석 게이트이므로 코드를 작성하지 않음
