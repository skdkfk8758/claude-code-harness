# 경량 워크플로우 가이드

CCH 워크플로우를 추가하거나 수정하기 위한 가이드.

## 워크플로우 구조

모든 워크플로우는 `skills/workflow/` 디렉토리에 YAML 파일로 정의된다.

### 필수 필드

```yaml
name: workflow-name          # 고유 이름 (kebab-case)
description: 한 줄 설명       # 워크플로우 목적

steps:                       # 스텝 목록 (순서대로 실행)
  - id: step-id              # 스텝 고유 ID
    type: skill | agent | agent-chain  # 스텝 유형
    description: 설명         # 스텝 설명
```

### 스텝 유형별 필드

#### `type: skill` (Auto-Dispatch — gate 레벨에 따라 처리)
```yaml
- id: design
  type: skill
  skill: brainstorming       # 호출할 스킬 이름
  description: 설명
  input: docs/plans/...      # 선택: 이전 스텝 산출물 경로
  output: docs/plans/...     # 선택: 산출물 저장 경로
  gate: approval             # approval | checkpoint | auto
```

Gate 레벨:
- `approval`: 자동 실행 → 결과 표시 → 사용자 명시적 승인 대기
- `checkpoint`: 자동 실행 → 요약 표시 → 개입 없으면 자동 진행
- `auto`: 자동 실행 → 로그만 출력 → 자동 진행

#### `type: agent` (Auto — 자동 실행)
```yaml
- id: implementation
  type: agent
  agent: code-refactor-master  # 실행할 에이전트
  description: 설명
  input: docs/plans/...
  output: docs/plans/...
  auto: true                   # 자동 실행
  cross-cutting:               # 선택: 크로스커팅 규칙
    - name: tdd
      enforcement: enforce     # enforce | suggest
    - name: verification
      enforcement: enforce
  retry-on-fail:               # 선택: 실패 시 재시도
    fix-agent: code-refactor-master
    max-retries: 2
    trigger-status: "NEEDS_CHANGES"
```

#### `type: agent-chain` (Auto — 에이전트 연쇄 실행)
```yaml
- id: planning
  type: agent-chain
  agents:                      # 순서대로 실행
    - planner
    - plan-reviewer
  description: 설명
  output: docs/plans/...
  auto: true
```

### cross-cutting enforcement 레벨

| 레벨 | 동작 |
|------|------|
| `suggest` | 규칙을 에이전트 프롬프트에 주입. 준수 여부는 에이전트 재량 |
| `enforce` | 규칙 주입 + 완료 후 오케스트레이터가 준수 여부 검증. 미준수 시 재dispatch |

## 경량 워크플로우 설계 원칙

1. **3단계 이하** — 경량의 의미는 빠르게 끝나는 것
2. **Gate는 최소화** — completion은 `approval`, 중간 검증은 `checkpoint`, 절차적 스텝은 `auto`
3. **enforce 활용** — 게이트가 적은 만큼 자동 검증을 강하게
4. **retry-on-fail 필수** — 사람이 개입할 Gate가 적으므로 자동 복구가 중요

## 경량 워크플로우 예시

### quick-fix (기본 제공)
```
구현(enforce) → 리뷰(retry 1회) → 완료(Gate)
```
용도: 단일 파일/함수 수정, 소규모 변경

### 추가 예시: quick-test
```yaml
name: quick-test
description: 테스트 보강 — 기존 코드에 테스트 추가

steps:
  - id: test-writing
    type: agent
    agent: code-refactor-master
    description: 기존 코드 분석 후 테스트 작성
    cross-cutting:
      - name: tdd
        enforcement: enforce
      - name: verification
        enforcement: enforce
    auto: true

  - id: completion
    type: skill
    skill: finishing-branch
    gate: approval
```

### 추가 예시: quick-docs
```yaml
name: quick-docs
description: 문서 정리 — 코드 변경 없이 문서만 업데이트

steps:
  - id: documentation
    type: agent
    agent: documentation-architect
    description: 현재 코드 기반 문서 생성/업데이트
    auto: true

  - id: completion
    type: skill
    skill: finishing-branch
    gate: approval
```

## 워크플로우 추가 절차

1. `skills/workflow/` 에 `{name}.yaml` 생성
2. `skills/workflow/SKILL.md` 의 Available Workflows 목록에 추가
3. `skills/workflow/workflow-router-rules.json` 에 라우터 규칙 추가
4. `README.md` 의 워크플로우 테이블에 추가
5. `/skill-manager validate` 로 검증

## 워크플로우 라우터 규칙 추가

`workflow-router-rules.json`의 `workflows` 객체에 항목 추가:

```json
{
  "new-workflow": {
    "description": "한 줄 설명",
    "signals": {
      "keywords": ["트리거 키워드들"],
      "intentPatterns": ["정규식 패턴들"],
      "complexityIndicators": ["복잡도 신호"]
    }
  }
}
```

- `keywords`: 단순 문자열 매칭 (1점)
- `intentPatterns`: 정규식 매칭 (2점)
- `complexityIndicators`: 추가 신호 (1점)
- `simplicityIndicators`: quick 계열 전용, 다른 워크플로우 점수 감점 (-2점)
- 총점이 `config.minSignalCount` (기본 2) 이상이면 제안
