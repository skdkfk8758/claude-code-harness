# CCH v2 경량화 검토: 더 덜어낼 수 있는 것들

- 작성일: 2026-03-04
- 상태: Draft
- 유형: v2 계획 보완 (경량화 관점)
- 기준 문서: `2026-03-04-cch-v2-harness-renewal.md`

---

## 0. 요약

v2 계획은 이미 **51개 → 18개 스킬**로 축소를 제안하고 있다.
이 문서는 v2 설계 원칙인 **"Build for Deletion"**과 **"Fewer, Better Tools"**를 더 철저히 적용하여,
추가로 덜어낼 수 있는 영역을 식별한다.

```
v1 현재:     51 스킬, 14 매니페스트, 4 모드, 4282줄 CLI, 6 벤더 소스
v2 계획:     18 스킬, ~5 매니페스트, 3 모드, CLI 유지, HRP 4-phase
극한 경량화:  8-10 스킬, 1-2 매니페스트, 모드 폐기, CLI 제거, 단순 스캔
```

---

## 1. Manifests 과잉 (14개 → 1~2개)

### 현황

v1에 14개 매니페스트가 존재하며, v2 계획에서도 ~5개를 유지하려 한다.

### 분석

| 파일 | 런타임 사용 여부 | 판정 | 근거 |
|------|----------------|------|------|
| `capabilities.json` | O (HRP 핵심) | **유지** | Tier/능력 선언의 SSOT |
| `sources.json` | O (벤더 설치) | **제거** | v2에서 "Detect, Don't Install" 원칙 |
| `health-rules.json` | O (건강 평가) | **흡수** | capabilities.json에 인라인 |
| `architecture-levels.json` | △ (init시) | **제거** | 과잉 엔지니어링. 프롬프트로 대체 가능 |
| `ci-gates.json` | X | **제거** | Policy Engine에 인라인하거나 삭제 |
| `command-contract.json` | X | **제거** | v2에서 CLI 축소시 불필요 |
| `kpi-schema.json` | X | **제거** | 측정 인프라가 존재하지 않음 |
| `profile-schema.json` | X | **제거** | JSON Schema 검증은 과잉 |
| `capability-schema.json` | X | **제거** | 동상 |
| `release-channels.json` | X | **제거** | 마켓플레이스에 위임 |
| `release-manifest-schema.json` | X | **제거** | 동상 |
| `resolved-schema.json` | X | **제거** | 동상 |
| `slo-definitions.json` | X | **제거** | 운영 환경이 아님 |
| `error-codes.json` | △ | **선택적 유지** | 에러 코드 참조용 |

### 제안

**14개 → 1~2개**: `capabilities.json` + 선택적으로 `error-codes.json`.

나머지 12개는 **한 번도 런타임에서 사용되지 않는 스키마/정의 파일**이거나,
다른 곳에 인라인할 수 있는 소량의 데이터이다.

v2 계획의 `reinforcements.json`, `workflows.json`, `gates.json`, `pipelines.json`도
**별도 파일이 아닌 capabilities.json의 하위 키**로 통합 가능하다.

---

## 2. bin/cch CLI 존재 자체를 재고 (4,282줄 → 0줄)

### 현황

| 파일 | 줄 수 | 역할 |
|------|-------|------|
| `bin/cch` | 2,069 | CLI 진입점, 명령 라우팅, 상태 관리 |
| `bin/lib/sources.sh` | 918 | 벤더 설치/업데이트/검증 |
| `bin/lib/arch.sh` | 348 | 아키텍처 레벨 관리, TDD 비율 검증 |
| `bin/lib/beads.sh` | 363 | Beads 이슈 트래커 연동 |
| `bin/lib/branch.sh` | 260 | 브랜치 관리, work-item 연결 |
| `bin/lib/kpi.sh` | 83 | KPI 메트릭 수집 |
| `bin/lib/lock.sh` | 54 | 동시 실행 방지 락 |
| `bin/lib/log.sh` | 187 | 로깅 유틸리티 |
| **합계** | **4,282** | |

### 핵심 질문

Claude Code는 **스킬(SKILL.md) + 훅(hooks.json)**으로 모든 사용자 인터랙션을 처리한다.
사용자가 터미널에서 `cch status`를 직접 치는 시나리오보다, `/cch-status`를 Claude 안에서 쓰는 시나리오가 압도적으로 많다.

**별도 shell CLI가 필요한가?**

### 제거 가능 항목

| 파일 | 판정 | 근거 |
|------|------|------|
| `bin/lib/sources.sh` (918줄) | **제거** | v2에서 벤더 설치 관리 완전 폐기 |
| `bin/lib/arch.sh` (348줄) | **제거** | 아키텍처 레벨 시스템 폐기 |
| `bin/lib/kpi.sh` (83줄) | **제거** | 측정 인프라 미존재 |
| `bin/lib/branch.sh` (260줄) | **흡수** | cch-commit 스킬에 필요한 부분만 이동 |
| `bin/lib/beads.sh` (363줄) | **검토** | Beads 유지시 존속, 폐기시 제거 |
| `bin/cch` (2,069줄) | **대폭 축소 또는 제거** | 아래 대안 참조 |

### 대안: CLI-less 아키텍처

```
현재 (v1):
  사용자 → /cch-status → SKILL.md → bin/cch status → 출력
  사용자 → terminal → cch status → bin/cch status → 출력

제안 (v2 경량):
  사용자 → /cch-status → SKILL.md → (스킬 내에서 직접 처리) → 출력
  terminal CLI → 불필요 (Claude Code 밖에서 쓸 일 없음)
```

CLI를 완전 제거하면 **4,282줄**이 사라진다.
만약 최소 CLI가 필요하다면 `bin/cch`를 **100줄 이하의 thin wrapper**로 축소:
`cch scan`, `cch gc`, `cch migrate` 정도만 지원.

### 절감 효과

| 시나리오 | 줄 수 | 절감 |
|---------|-------|------|
| CLI 완전 제거 | 0 | -4,282줄 |
| CLI 최소화 (100줄) | ~100 | -4,182줄 |
| 현재 v2 계획 (유지) | ~2,000+ | 0 |

---

## 3. HRP 4-Phase → 1-Phase 단순화

### 현황 (v2 계획)

```
Scan → Detect → Classify → Integrate
  │       │         │          │
  │       │         │          └─ 강화 매니페스트 매칭, 승인/자동 적용
  │       │         └─ 위험도 3단계 분류 (Safe/Moderate/High)
  │       └─ fingerprint 비교, delta 추출
  └─ 5 레이어 전체 환경 스캔
```

### 과잉 설계 지점

**3-1. Fingerprint + Delta 추적이 불필요**

세션은 stateless에 가깝다. 매번 fresh하게 "지금 뭐가 설치돼 있지?"를 체크하면 된다.
이전 스캔과 비교하여 "무엇이 새로 추가됐는지" 추적하는 delta 시스템은,
플러그인 설치/삭제가 빈번한 환경을 가정하는데 현실적으로 그런 일은 드물다.

**3-2. 위험도 3단계가 과잉**

| v2 계획 | 더 단순한 대안 |
|---------|--------------|
| Safe / Moderate / High | **자동** vs **승인 필요** (2단계) |

"Safe"와 "Moderate"의 경계가 모호하고, 실제로 "High" 위험도 이벤트
(정책/훅 변경)는 사용자가 직접 설정 파일을 수정할 때만 발생한다.

**3-3. Reinforcement Manifest의 현실성**

서드파티 플러그인이 `cch-reinforcement.json`을 제공하여 CCH와 통합하는 시나리오는
**생태계 성숙도가 한참 부족한 현 시점에서 비현실적**이다.
내부 매핑 테이블(하드코딩) 하나면 충분하다.

### 제안: 1-Phase 단순 스캔

```
세션 시작
  └─ checkEnv():
       ├─ plugins 설치 여부 체크 (superpowers? 기타?)
       ├─ MCP 서버 목록 확인
       ├─ CLI 도구 존재 여부 (codex? gemini?)
       └─ → Tier 결정 (0/1/2) + 사용 가능 기능 목록 세팅
```

**구현량 비교:**

| 항목 | v2 계획 (HRP 4-phase) | 단순 스캔 |
|------|----------------------|----------|
| 파일 수 | 4개 (`scanner.mjs`, `detector.mjs`, `classifier.mjs`, `integrator.mjs`) | 1개 (`check-env.mjs`) |
| 매니페스트 | `reinforcements.json` + `capabilities.json` | `capabilities.json` 하나 |
| 런타임 상태 | `scan-result.json` (fingerprint, delta 포함) | 인메모리 또는 간단한 상태 파일 |
| 확장 포인트 | 서드파티 `cch-reinforcement.json` | 내부 매핑 테이블 |
| 예상 코드량 | ~800줄 | ~150줄 |

---

## 4. Tier 시스템 lite/full 이중 구현 문제

### 현황 (v2 계획)

v2에서 4개 코어 스킬이 Tier에 따라 **두 가지 구현 경로**를 가진다:

```
cch-brainstorm: brainstorm-lite (Tier 0) ↔ superpowers brainstorm (Tier 1)
cch-verify:     verify-lite (Tier 0)     ↔ superpowers verifier agent (Tier 1)
cch-review:     review-lite (Tier 0)     ↔ superpowers code-reviewer (Tier 1)
cch-team:       순차 파이프라인 (Tier 0) ↔ superpowers 병렬 에이전트 (Tier 1)
```

### 문제

스킬 수는 51→18로 줄었지만, **각 스킬의 내부 분기가 2배**가 되므로
유지보수 복잡도는 비슷하게 유지된다. 또한 "lite" 버전의 품질이 낮으면
Tier 0 사용자 경험이 나빠지고, "lite"에 투자하면 구현 비용이 증가한다.

### 대안: 프롬프트 분기로 단순화

Claude는 사용 가능한 도구 목록을 자체적으로 인식한다.
superpowers가 없으면 Agent 도구 없이 직접 수행하고, 있으면 Agent 도구를 활용한다.

```markdown
# cch-brainstorm SKILL.md (단일 구현)

## 절차
1. 주제에 대해 3개 이상의 접근 방식을 생성하라
2. 각 접근 방식의 장단점을 비교하라
3. 사용자에게 선택지를 제시하라

## 강화 (사용 가능할 때)
- superpowers Agent 사용 가능시: analyst + architect 에이전트를 병렬로 활용
- superpowers brainstorm 스킬 감지시: 해당 워크플로우를 우선 적용
```

**핵심**: "lite 구현"을 별도로 만들지 않고, 스킬 프롬프트에
**"사용 가능하면 활용하라"**는 조건부 지시를 넣는다.
Claude는 도구 유무에 따라 알아서 최선의 경로를 선택한다.

### 효과

- **구현 경로 2개 → 1개**: 스킬당 유지보수 반감
- **brainstorm-lite, verify-lite 등 별도 구현 불필요**
- **Tier 개념 자체가 implicit**: 명시적 Tier 번호를 관리하지 않아도 됨

---

## 5. Guide 스킬 3개 → docs/ 마크다운으로

### 현황 (v2 계획)

```
skills/
└── guides/
    ├── guide-superpowers/ # superpowers 가이드
    └── guide-extensions/  # 기타 확장 가이드
```

### 문제

"설치 가이드"가 슬래시 커맨드(`/cch-guide-superpowers`)일 필요가 있는가?

- 가이드는 **일회성 참조 자료**이지 반복 실행하는 워크플로우가 아니다
- 스킬 슬롯을 점유하여 스킬 목록을 길게 만든다
- SKILL.md 형태보다 일반 마크다운이 더 자연스럽다

### 대안

```
docs/
└── guides/
    ├── superpowers.md     # superpowers 가이드
    └── extensions.md      # 기타 확장 가이드
```

CLAUDE.md에 한 줄 추가:
```
플러그인 설치 가이드: docs/guides/ 참조
```

Claude는 필요할 때 해당 파일을 Read하면 된다.

### 효과

- 스킬 3개 제거 (18개 → 15개)
- 사용자에게 노출되는 슬래시 커맨드 목록 간소화

---

## 6. Adapter 스킬 3개 → 스캔 로직에 흡수

### 현황 (v2 계획)

```
skills/
└── adapters/
    ├── adapter-sp/        # superpowers 감지 + 기능 연결
    └── adapter-ext/       # CLI/MCP/외부 플러그인 감지
```

### 문제

- 어댑터는 **내부 인프라 로직**이지 사용자가 호출하는 기능이 아니다
- 사용자가 `/cch-adapter-sp`를 직접 실행할 일이 없다
- "감지 + 연결" 로직은 `cch-setup` 또는 `cch-scan`의 내부 함수여야 한다

### 대안

어댑터 로직을 환경 체크 스크립트(`check-env.mjs`)의 내부 함수로 흡수:

```javascript
// check-env.mjs 내부
function detectSuperpowers() { /* ... */ }
function detectExternalTools() { /* ... */ }
```

### 효과

- 스킬 3개 제거 (15개 → 12개)
- 어댑터 개념 자체가 사라져 아키텍처 단순화

---

## 7. 모드 시스템 재고 (3모드 → 폐기 또는 1모드)

### 현황

| 버전 | 모드 |
|------|------|
| v1 | `code`, `plan`, `tool`, `swarm` (4개) |
| v2 계획 | `work`, `plan`, `ops` (3개) |

### 문제

**7-1. Claude Code에 이미 Plan Mode가 내장돼 있다**

`EnterPlanMode` / `ExitPlanMode` 도구가 네이티브로 존재한다.
CCH의 `plan` 모드는 이것과 겹치며, 사용자에게 혼란을 준다.

**7-2. mode-detector 훅의 비용**

매 프롬프트마다 `UserPromptSubmit` 훅으로 mode-detector.sh가 실행된다.
모드 시스템을 위해 **모든 사용자 입력에 3초 타임아웃 훅**이 걸려 있는 것은 과잉이다.

**7-3. `ops` 모드의 실사용 빈도**

scan, gc, diagnose는 개별 스킬 호출로 충분하다.
별도 모드로 분리할 만큼 사용 빈도가 높지 않다.

### 대안 A: 모드 완전 폐기

- 모드 대신 **워크플로우 프리셋**(quick, standard, careful)만 유지
- `cch-plan`은 Claude Code의 `EnterPlanMode`와 자연스럽게 연동
- mode-detector 훅 제거 → 프롬프트당 3초 오버헤드 제거

### 대안 B: 암시적 모드 (Implicit Mode)

- 명시적 모드 전환 없이, 현재 작업 컨텍스트에서 자동 추론
- 사용자가 `/cch-plan`을 호출하면 plan 워크플로우 진입
- 사용자가 `/cch-commit`을 호출하면 work 워크플로우 진입
- 별도 "모드 상태"를 유지하지 않음

### 효과

- `profiles/` 디렉토리 제거
- `mode-detector.sh` 훅 제거 → 프롬프트 응답 속도 개선
- `cch-mode` 스킬 이미 v2에서 흡수 예정이나, 모드 개념 자체가 사라짐

---

## 8. 추가 제거 후보 (개별 항목)

### 8-1. Context Budget Manager

v2 계획의 Context Engine 핵심 기능 중 하나.

**제거 근거:**
- Claude Code는 자체적으로 컨텍스트 윈도우를 관리한다 (자동 압축)
- 토큰 수를 세서 "예산"을 관리하는 것은 모델 네이티브 기능과 겹침
- **"Build for Deletion"** 원칙의 1순위 후보

**유지 근거:**
- Progressive Disclosure (어디서 찾을지만 알려줌)는 여전히 유효
- 프로젝트별 CLAUDE.md 자동 생성은 토큰 예산과 무관하게 가치 있음

**판정:** Budget "계산" 로직은 제거. Progressive Disclosure 개념은 `cch-init`에 남기되,
토큰 수를 세는 코드는 작성하지 않는다.

### 8-2. GC Engine

v2 계획의 Lifecycle Engine 핵심 기능.

**제거 근거:**
- 정리 대상(완료된 TODO, 오래된 plan, 폐기된 work-item)이 CLI-less 구조에서는 최소화됨
- "컨텍스트 드리프트 감지" (CLAUDE.md ↔ 코드 괴리)는 LLM 추론이 필요하여 훅에서 처리 불가
- 세션 시작시 간단한 cleanup 함수 하나면 충분

**판정:** 풀 GC Engine 대신, `cch-setup` 스킬 내에서 `cleanupStaleFiles()` 함수 하나로 대체.

### 8-3. dist/ 디렉토리

소스 레포에 빌드 산출물 2개 버전(0.1.0, 0.2.0)이 커밋돼 있다.

**판정:** `.gitignore`에 `dist/` 추가. CI/릴리스 스크립트에서만 생성.

### 8-4. dot/ 디렉토리

v2 계획에서 이미 DOT 실험선 폐기가 확정됐다.

**판정:** v2 작업 시작과 함께 즉시 제거. `dot/`, `combo.lock`, `combos/` 전체 삭제.

### 8-5. overlays/ 디렉토리

비어있는 디렉토리 (`.gitkeep`만 존재).

**판정:** 즉시 제거.

### 8-6. tests/pinchtab/

PinchTab 관련 시나리오 + 리포트 (스크린샷 포함, ~1.7MB).

**판정:** PinchTab을 별도 플러그인으로 분리하면서 함께 이동.

---

## 9. 코어 스킬 추가 통합 가능성

v2 계획의 코어 12개에서 더 통합할 수 있는 부분:

| v2 코어 스킬 | 추가 통합 제안 | 근거 |
|-------------|--------------|------|
| `cch-setup` | + `cch-scan` 흡수 | scan은 setup의 일부 (세션 시작시 자동) |
| `cch-init` | 유지 | 프로젝트 초기화는 독립 스킬로 가치 충분 |
| `cch-commit` | + `cch-pr` 흡수 (v2에서 이미 계획) | OK |
| `cch-plan` | 유지 | 핵심 워크플로우 |
| `cch-todo` | 유지 | 작업 관리 SSOT |
| `cch-team` | 유지 | 멀티에이전트 오케스트레이션 핵심 |
| `cch-verify` | + `cch-tdd` + `cch-debug` 흡수 (v2에서 이미 계획) | OK |
| `cch-brainstorm` | 유지 | 설계 전 탐색 |
| `cch-review` | 유지 | 품질 게이트 |
| `cch-status` | + `cch-hud` 흡수 (v2에서 이미 계획) | OK |
| `cch-gc` (NEW) | **cch-setup에 흡수** | 별도 스킬 불필요, cleanup 함수면 충분 |
| `cch-scan` (NEW) | **cch-setup에 흡수** | setup 시작시 자동 실행 |

### 결과: 12 코어 → 10 코어

```
최종 코어 스킬 (10개):
  cch-setup       # 환경 설정 + 스캔 + GC (통합)
  cch-init        # 프로젝트 초기화 (Context Engine)
  cch-status      # 상태 + HUD (통합)
  cch-plan        # 설계 → 플래닝 → TODO
  cch-brainstorm  # 구조화 브레인스토밍
  cch-team        # 팀 오케스트레이션 (Tier별 자동 전환)
  cch-commit      # 커밋 + PR + 브랜치 완료 (통합)
  cch-verify      # 검증 + TDD + 디버그 (통합)
  cch-review      # 코드 리뷰 (lite ↔ full 자동)
  cch-todo        # 작업 관리
```

---

## 10. v2 파일 구조 (극한 경량화 버전)

### 제안 구조

```
claude-code-harness/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── skills/                        # 10개 코어 스킬
│   ├── cch-setup/SKILL.md
│   ├── cch-init/SKILL.md
│   ├── cch-status/SKILL.md
│   ├── cch-plan/SKILL.md
│   ├── cch-brainstorm/SKILL.md
│   ├── cch-team/SKILL.md
│   ├── cch-commit/SKILL.md
│   ├── cch-verify/SKILL.md
│   ├── cch-review/SKILL.md
│   └── cch-todo/SKILL.md
├── scripts/                       # 훅 스크립트 (최소)
│   ├── check-env.mjs             # 환경 체크 (HRP 대체, ~150줄)
│   ├── summary-writer.mjs        # 세션 요약 (Context Replay)
│   └── activity-tracker.mjs      # 활동 추적 (선택)
├── hooks/
│   └── hooks.json                 # 훅 정의 (축소)
├── manifests/
│   └── capabilities.json          # 유일한 매니페스트
├── docs/
│   ├── guides/                    # 가이드 (마크다운)
│   │   ├── superpowers.md
│   │   └── extensions.md
│   └── plans/
├── tests/
│   ├── unit/
│   └── integration/
└── README.md
```

### v2 계획 구조와 비교

| 항목 | v2 계획 | 극한 경량화 | 차이 |
|------|---------|------------|------|
| `bin/` | 유지 (`cch` + `lib/`) | **제거** | -4,282줄 |
| `engines/` | 4개 엔진 (context, policy, lifecycle, hrp/) | **제거** (스킬 + scripts로 대체) | 전체 디렉토리 제거 |
| `skills/core/` | 12개 | 10개 | -2 |
| `skills/guides/` | 3개 스킬 | **제거** (docs/guides/) | -3 스킬 |
| `skills/adapters/` | 3개 스킬 | **제거** (check-env.mjs에 흡수) | -3 스킬 |
| `manifests/` | 2개 | 1개 | -1 |
| `policies/` | 3개 (workflows, gates, pipelines) | **제거** (capabilities.json에 인라인) | 전체 디렉토리 제거 |
| `profiles/` | 3개 + presets/ | **제거** (모드 폐기) | 전체 디렉토리 제거 |
| `dot/` | 이미 폐기 | 제거 | - |
| `overlays/` | 이미 폐기 | 제거 | - |

---

## 11. 훅 시스템 경량화

### 현황 (v1: 8개 훅)

| 훅 | 스크립트 | Timeout | 판정 |
|----|---------|---------|------|
| UserPromptSubmit | mode-detector.sh | 3s | **제거** (모드 시스템 폐기) |
| UserPromptSubmit | activity-tracker.mjs | 2s | **선택적 유지** |
| PreToolUse (ExitPlanMode) | plan-doc-reminder.sh | 2s | **유지** (plan 스킬 연동) |
| PreToolUse (TaskCreate) | activity-tracker.mjs | 2s | **선택적 유지** |
| PreToolUse (TaskUpdate) | activity-tracker.mjs | 2s | **선택적 유지** |
| PostToolUse (ExitPlanMode) | plan-bridge.mjs | 5s | **유지** (plan→실행 브릿지) |
| PostToolUse (Bash) | tdd-enforcer.sh | 5s | **검토** (verify에 흡수 가능) |
| Stop | summary-writer.mjs | 2s | **유지** (Context Replay) |

### 제안: 8개 → 3~4개

```json
{
  "hooks": [
    {
      "type": "UserPromptSubmit",
      "matcher": "*",
      "script": "scripts/check-env.mjs",
      "timeout": 2000
    },
    {
      "type": "PreToolUse",
      "matcher": "ExitPlanMode",
      "script": "scripts/plan-doc-reminder.sh",
      "timeout": 2000
    },
    {
      "type": "PostToolUse",
      "matcher": "ExitPlanMode",
      "script": "scripts/plan-bridge.mjs",
      "timeout": 5000
    },
    {
      "type": "Stop",
      "matcher": "*",
      "script": "scripts/summary-writer.mjs",
      "timeout": 2000
    }
  ]
}
```

**변경점:**
- `mode-detector.sh` → `check-env.mjs`로 대체 (모드 감지 대신 환경 체크)
- `activity-tracker.mjs` (3개 훅) → 제거 또는 check-env에 통합
- `tdd-enforcer.sh` → `cch-verify` 스킬 내부 로직으로 이동

---

## 12. 정량 비교 요약

| 항목 | v1 현재 | v2 계획 | 극한 경량화 |
|------|---------|---------|------------|
| 스킬 수 | 51 | 18 (12+3+3) | **10** |
| 매니페스트 | 14 | ~5 | **1** |
| 모드 | 4 | 3 | **0** (워크플로우 프리셋) |
| CLI 줄 수 | 4,282 | ~2,000+ | **0** |
| 엔진 파일 | 0 (v1은 bin에 통합) | 7 (3 engine + 4 hrp) | **0** (스킬+스크립트) |
| 정책 파일 | 0 | 3 | **0** (capabilities에 인라인) |
| 프로파일 | 4 | 3 + presets | **0** |
| 훅 | 8 | ~8 | **3~4** |
| 스크립트 | 6 | ~7 | **2~3** |
| 디렉토리 | 12+ | 10+ | **6** (skills, scripts, hooks, manifests, docs, tests) |

---

## 13. 트레이드오프 분석

### 경량화의 장점

1. **유지보수 비용 최소화** — 10개 스킬만 관리
2. **온보딩 용이** — "스킬 10개 + 매니페스트 1개" = 5분 이내 전체 구조 파악
3. **"Build for Deletion" 충실** — 각 스킬이 독립적이라 개별 삭제 용이
4. **훅 오버헤드 감소** — 프롬프트당 불필요한 훅 실행 제거
5. **기여자 진입 장벽 최소화** — SKILL.md 하나만 수정하면 기여 가능

### 경량화의 리스크

| 리스크 | 영향 | 완화 |
|--------|------|------|
| CLI 제거 시 CI/CD 연동 불가 | 중간 | 필요시 thin CLI (~100줄) 복원 |
| 모드 제거 시 워크플로우 강제력 약화 | 중간 | 스킬 프롬프트 내에서 워크플로우 가이드 |
| 단일 매니페스트의 복잡도 증가 | 낮음 | 섹션 분리로 가독성 유지 |
| HRP 단순화 시 확장성 제한 | 낮음 | MVP 이후 필요시 점진적 확장 |
| lite/full 분기 제거 시 Tier 0 품질 불확실 | 중간 | 스킬 프롬프트 품질에 집중 투자 |

---

## 14. 판정 요약

| 항목 | 판정 | 우선도 | 비고 |
|------|------|--------|------|
| Manifests 12개 제거 | **적용** | 높음 | 런타임 미사용 파일 제거 |
| bin/CLI 제거 또는 최소화 | **적용 (검토 후)** | 높음 | CLI-less vs thin CLI 결정 필요 |
| HRP 4→1 Phase | **적용** | 높음 | 구현량 대폭 감소 |
| Guide 스킬 → docs/ | **적용** | 중간 | 스킬 슬롯 절약 |
| Adapter 스킬 흡수 | **적용** | 중간 | 아키텍처 단순화 |
| Tier lite/full 이중 구현 제거 | **적용 (검토 후)** | 중간 | Tier 0 품질 검증 필요 |
| 모드 시스템 폐기 | **검토 필요** | 중간 | 워크플로우 강제력 vs 단순화 |
| Context Budget Manager 제거 | **적용** | 낮음 | "Build for Deletion" |
| GC Engine → 함수 하나로 | **적용** | 낮음 | 과잉 엔지니어링 방지 |
| cch-gc, cch-scan → cch-setup 흡수 | **적용** | 낮음 | 코어 12→10 |

---

## TODO

### 즉시 적용 (높음)
- [ ] 매니페스트 12개 제거 (런타임 미사용 파일) — 14개 → 1~2개
- [ ] HRP 4-Phase → 1-Phase 단순 스캔으로 축소 (`check-env.mjs` ~150줄)
- [ ] Context Budget Manager의 토큰 계산 로직 제거 (Progressive Disclosure 개념만 유지)
- [ ] GC Engine → `cch-setup` 내 `cleanupStaleFiles()` 함수 하나로 대체
- [ ] `cch-gc`, `cch-scan` → `cch-setup`에 흡수 (코어 12개 → 10개)

### 검토 후 적용 (중간)
- [ ] bin/CLI 제거 vs thin CLI (~100줄) 최종 결정 — CI/CD 시나리오 조사
- [ ] Guide 스킬 3개 → `docs/guides/` 마크다운으로 전환 (스킬 18개 → 15개)
- [ ] Adapter 스킬 3개 → `check-env.mjs` 내부 함수로 흡수 (스킬 15개 → 12개)
- [ ] Tier lite/full 이중 구현 제거 — 단일 프롬프트 + 조건부 지시로 대체
- [ ] 모드 시스템 폐기 여부 결정 — 워크플로우 프리셋 프로토타입

### 검증
- [ ] Tier 0 스킬 품질 검증 — brainstorm-lite, verify-lite 없이 단일 프롬프트로 충분한지 테스트
- [ ] v2 계획 문서 업데이트 — 본 검토 결과를 `cch-v2-harness-renewal.md`에 반영
- [ ] 극한 경량화 파일 구조 (6 디렉토리, 10 스킬, 1 매니페스트) 프로토타입 검증

## 15. 다음 단계

1. **CLI 필요성 최종 결정** — CI/CD, 터미널 직접 사용 시나리오 조사
2. **모드 시스템 폐기 여부 결정** — 워크플로우 프리셋으로 대체 가능한지 프로토타입
3. **Tier 0 스킬 품질 검증** — brainstorm-lite, verify-lite 없이 단일 프롬프트로 충분한지 테스트
4. **v2 계획 문서 업데이트** — 본 검토 결과를 반영하여 `cch-v2-harness-renewal.md` 개정
