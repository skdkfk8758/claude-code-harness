# Claude Code Harness (CCH)
> Claude Code 워크플로우 오케스트레이션 플러그인

## 개요

CCH는 Claude Code에서 동작하는 워크플로우 오케스트레이션 플러그인이다.
**스킬은 게이트(관문)**, **에이전트는 실행자** 패턴으로 설계→구현→검증 파이프라인을 구조화한다.

## 설계 원칙

- **스킬 = 게이트**: 사용자 승인이 필요한 의사결정 체크포인트. 사용자가 `/skill-name`으로 직접 호출
- **에이전트 = 실행자**: 승인된 산출물 기반 역할 수행. 워크플로우 오케스트레이터가 자동 dispatch
- **워크플로우 = 선언적 정의**: YAML로 단계 순서, 게이트/에이전트 타입, 자동 실행 여부 정의
- **크로스커팅 룰**: TDD, 검증, 디버깅 규칙이 에이전트 dispatch 시 자동 주입

## Quick Start

```bash
# 1. 플러그인 설치
/plugin install claude-code-harness

# 2. 환경 초기화 (HUD, 건강체크, v2 정리)
/setup

# 3. 워크플로우 시작
/workflow feature-dev
```

## 실행 가이드

### `/workflow feature-dev` 실행 시 흐름

```
Step 1/9 [Gate] design
  → 오케스트레이터: brainstorming 스킬 자동 dispatch
  → 다관점 스트레스 테스트 (Architect/End-User/Domain/Adversary) 포함
  → 산출물: docs/plans/2026-03-06-my-feature-design.md
  → 사용자: "승인"

Step 2/9 [Cond] tech-research (선택적)
  → design.md에 "research-needed:" 마커가 있을 때만 실행
  → web-research-specialist가 문서 fallback 체인으로 공식 문서 조회 + 교차 검증
  → 산출물: *-research.md

Step 3/9 [Auto] planning (agent-chain)
  → 오케스트레이터: planner 에이전트 자동 dispatch (리서치 결과 자동 주입)
  → 산출물: *-plan.md, *-context.md
  → 오케스트레이터: plan-reviewer 에이전트 자동 dispatch
  → NEEDS_REVISION이면 planner 재호출 (최대 2회)

Step 4/9 [Gate] task-breakdown
  → 오케스트레이터: writing-plans 스킬 자동 dispatch
  → 태스크별 복잡도(🟢🟡🔴)/리스크(🟢🟡🔴) 지표 포함
  → 🔴 Risky 태스크 자동 배치 격리
  → 산출물: *-tasks.md (배치 구분된 태스크 목록)
  → 사용자: "승인"

Step 5/9 [Auto] implementation
  → 오케스트레이터: code-refactor-master 에이전트 dispatch
  → 3태스크마다 체크포인트
  → 태스크마다 2단계 리뷰 (spec-reviewer → code-quality-reviewer)

Step 6/9 [Auto] review
  → 오케스트레이터: code-architecture-reviewer 에이전트 dispatch
  → 산출물: *-review.md

Step 7/9 [Cond] code-optimization
  → PASS_WITH_NOTES일 때만 실행 (PASS면 스킵)
  → advisory 항목 기반 중복 제거, 단순화, 재사용성 개선

Step 8/9 [Auto] documentation (optional)
  → 오케스트레이터: documentation-architect 에이전트 dispatch

Step 9/9 [Gate] completion
  → 오케스트레이터: finishing-branch 스킬 자동 dispatch
  → 4옵션: merge / PR / keep / discard
```

### 핵심: 사용자가 해야 할 것
1. `/workflow feature-dev` 시작
2. 게이트(Gate)에서 해당 스킬 호출 (`/brainstorming`, `/writing-plans`, `/finishing-branch`)
3. 산출물 확인 후 "승인" 응답
4. 나머지는 오케스트레이터가 자동 처리

### 상태 관리 + 세션 연속성
- `.claude/workflow-state.json`에 진행 상태 + 결정사항 + 이슈 자동 기록
- `/workflow feature-dev resume`으로 중단된 곳부터 재개 (컨텍스트 자동 복구)
- 각 스텝 완료 시 summary, decisions, issues를 자동 추출하여 저장
- resume 시 이전 결정사항 요약 출력 + 산출물 파일 재로드

### 워크플로우 라우터
- 사용자 입력을 분석하여 적합한 워크플로우를 자동 제안
- 규칙 기반 분류 (2개 이상 신호 매칭 시에만 제안, 피로감 방지)
- `workflow-router-rules.json`에서 분류 규칙 커스터마이징 가능

## 워크플로우 4종

### feature-dev (9단계)
| Step | Type | Component | Action |
|------|------|-----------|--------|
| 1 | Gate | `/brainstorming` | 설계 승인 (다관점 스트레스 테스트 포함) |
| 2 | Cond | web-research-specialist | 기술 조사 (design.md에 research-needed 마커 시) |
| 3 | Auto | planner → plan-reviewer | 플랜 생성 + 리뷰 (리서치 결과 자동 주입) |
| 4 | Gate | `/writing-plans` | 태스크 분해 승인 (복잡도/리스크 지표 포함) |
| 5 | Auto | code-refactor-master | 구현 (배치+2단계 리뷰, tdd/verification enforce) |
| 6 | Auto | code-architecture-reviewer | 아키텍처 리뷰 + 검증 드리프트 탐지 (retry-on-fail) |
| 7 | Cond | code-refactor-master | 리뷰 advisory 있을 때만 전역 최적화 |
| 8 | Auto | documentation-architect | 문서 정리 (선택) |
| 9 | Gate | `/finishing-branch` | 완료 처리 |

### bugfix (6단계)
| Step | Type | Component | Action |
|------|------|-----------|--------|
| 1 | Gate | `/systematic-debugging` | 근본원인 조사 |
| 2 | Auto | planner | 수정 계획 |
| 3 | Auto | code-refactor-master | TDD 기반 수정 (tdd/verification enforce) |
| 4 | Auto | code-architecture-reviewer | 리뷰 + 검증 드리프트 (retry-on-fail) |
| 5 | Cond | code-refactor-master | 리뷰 advisory 있을 때만 최적화 |
| 6 | Gate | `/finishing-branch` | 완료 처리 |

### refactor (9단계)
| Step | Type | Component | Action |
|------|------|-----------|--------|
| 1 | Auto | refactor-planner | 코드 분석 |
| 2 | Gate | `/brainstorming` | 리팩토링 전략 승인 |
| 3 | Auto | planner → plan-reviewer | 플랜 생성 + 리뷰 |
| 4 | Gate | `/writing-plans` | 태스크 분해 승인 |
| 5 | Auto | code-refactor-master | 구현 (tdd/verification enforce) |
| 6 | Auto | code-architecture-reviewer | 리뷰 + 검증 드리프트 (retry-on-fail) |
| 7 | Cond | code-refactor-master | 리뷰 advisory 있을 때만 전역 최적화 |
| 8 | Auto | documentation-architect | 문서 정리 |
| 9 | Gate | `/finishing-branch` | 완료 처리 |

### quick-fix (4단계)
| Step | Type | Component | Action |
|------|------|-----------|--------|
| 1 | Auto | code-refactor-master | 구현 (tdd/verification enforce) |
| 2 | Auto | code-architecture-reviewer | 리뷰 (retry-on-fail 1회) |
| 3 | Cond | code-refactor-master | 리뷰 advisory 있을 때만 최적화 |
| 4 | Gate | `/finishing-branch` | 완료 처리 |

## 스킬 (11)

### 게이트 (4)
| 스킬 | 호출 | 역할 |
|------|------|------|
| workflow | `/workflow <name>` | 오케스트레이터 — YAML 기반 진행 관리 |
| brainstorming | `/brainstorming <topic>` | 설계 게이트 — 옵션 비교, spec-reviewer 리뷰 루프 |
| writing-plans | `/writing-plans <file>` | 태스크 분해 게이트 — 2-5분 단위, plan-reviewer 리뷰 |
| finishing-branch | `/finishing-branch` | 완료 게이트 — merge/PR/keep/discard |

### 크로스커팅 (3)
| 스킬 | 호출 | 적용 |
|------|------|------|
| verification | `/verification` | 완료 주장 전 실제 명령 실행 필수 |
| tdd | `/tdd` | RED-GREEN-REFACTOR 강제 |
| systematic-debugging | `/systematic-debugging` | 근본원인 조사 4단계 |

### 매니저 (2)
| 스킬 | 호출 | 역할 |
|------|------|------|
| workflow-manager | `/workflow-manager <cmd>` | 워크플로우 YAML CRUD |
| skill-manager | `/skill-manager <cmd>` | 스킬/에이전트 CRUD + 의존성 분석 |

### 유틸리티 (2)
| 스킬 | 호출 | 역할 |
|------|------|------|
| setup | `/setup` | 환경 초기화 — HUD 배포, 건강체크, v2 정리 |
| cch-lsp | `/cch-lsp` | LSP 감지/설치 — Serena 설정 |

## 에이전트 (10)

| 에이전트 | 역할 |
|---------|------|
| planner | 3종 문서 생성 (전략/컨텍스트/체크리스트) |
| plan-reviewer | 플랜 비판적 리뷰, DB 영향/대안 평가 |
| code-refactor-master | 배치 실행 + 2단계 리뷰, TDD 강제 |
| spec-reviewer | 구현 vs spec 일치 검증 (구현자 불신 원칙) |
| code-quality-reviewer | 코드 품질 리뷰 |
| code-architecture-reviewer | 전체 아키텍처 리뷰 |
| documentation-architect | 4단계 문서 업데이트 |
| web-research-specialist | 기술 조사 |
| refactor-planner | 코드 스멜/SOLID 분석 |
| implementer-prompt-template | 서브에이전트 dispatch 템플릿 |

## 디렉터리 구조

```
skills/
  workflow/                        # 오케스트레이터
    SKILL.md
    feature-dev.yaml               # 워크플로우 정의
    bugfix.yaml
    refactor.yaml
    quick-fix.yaml                 # 경량 워크플로우
    workflow-router-rules.json     # 워크플로우 라우터 분류 규칙
  brainstorming/                   # 설계 게이트
    SKILL.md
    spec-document-reviewer-prompt.md
  writing-plans/                   # 태스크 분해 게이트
    SKILL.md
    plan-document-reviewer-prompt.md
  finishing-branch/SKILL.md        # 완료 게이트
  verification/SKILL.md            # 크로스커팅
  tdd/SKILL.md
  systematic-debugging/SKILL.md
  setup/SKILL.md                   # 환경 초기화
  cch-lsp/SKILL.md                 # LSP 설정
  skill-rules.json                 # 스킬 자동 활성화 트리거
agents/                            # 에이전트 (실행자)
  planner.md
  plan-reviewer.md
  code-refactor-master.md
  spec-reviewer.md
  code-quality-reviewer.md
  code-architecture-reviewer.md
  documentation-architect.md
  web-research-specialist.md
  refactor-planner.md
  implementer-prompt-template.md
docs/
  plans/                           # 산출물 (프로젝트별 생성)
  lightweight-workflow-guide.md    # 경량 워크플로우 추가 가이드
.claude/workflow-state.json        # 워크플로우 상태 (자동 생성)
```

## License

MIT
