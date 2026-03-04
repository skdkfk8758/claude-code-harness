# CCH v2: Agent Harness Renewal Plan

- 작성일: 2026-03-04
- 상태: Draft
- 유형: Architecture Renewal (v1 → v2)
- 범위: 전체 재설계 (처음부터 다시)
- 배포: Claude Code Plugin
- 기준: v1 설계서(`2026-03-03-cch-framework-v2-design.md`), 에이전트 하네스 리서치

---

## 1. 비전과 정체성

### 1.1 핵심 정의

> **CCH = Claude Code의 운영체제(OS)**
>
> 모델이 CPU라면, CCH는 커널 + 드라이버 + 셸이다.
> 플러그인들을 "앱"으로 취급하고, CCH는 그것들이 잘 돌아가는 환경을 제공한다.

### 1.2 v1에서 v2로의 전환

| 관점 | v1 | v2 |
| --- | --- | --- |
| 정체성 | 다중 통합 플러그인 → 프레임워크 | 에이전트 하네스 (Agent Harness) |
| 벤더 관계 | 직접 설치/관리 (패키지 매니저) | 감지/연결 (하네스) |
| 핵심 가치 | 정책 기반 오케스트레이션 | Context Engineering + Policy Engine + Lifecycle Management |
| 스킬 수 | 51개 (벤더 래퍼 포함) | ~21개 (코어 + 가이드 + 어댑터) |
| 벤더 없을 때 | Degraded/Blocked | Tier 0 코어로 독립 동작 |
| 새 도구 추가시 | 수동 설정 | HRP로 자동 감지/통합 |

### 1.3 v2가 아닌 것 (비범위)

1. AI 모델 런타임 또는 추론 엔진
2. 범용 에이전트 프레임워크 (LangChain 대체가 아님)
3. 패키지 매니저 (벤더 설치는 사용자 몫)
4. IDE 또는 에디터 플러그인

---

## 2. 리서치 기반 설계 원칙

### 2.1 에이전트 하네스 생태계 현황

Harrison Chase(LangChain CEO)가 정리한 분류:

| 계층 | 역할 | 예시 |
| --- | --- | --- |
| Framework | 개발자용 툴킷 | LangChain, OpenAI Agents SDK |
| Runtime | 실행 엔진, 상태 지속 | LangGraph, Temporal |
| Harness | 배터리 포함 래퍼 | Deep Agents SDK, Claude Code |
| Orchestrator | 목표→하위작업 분해 | 멀티에이전트 코디네이터 |

CCH v2는 **Harness + Orchestrator** 위치. Claude Code(기존 Harness) 위에 얹는 메타-하네스.

### 2.2 OpenAI Harness Engineering 3대 기둥

OpenAI가 에이전트로 100만 줄 코드를 작성하며 도출한 핵심:

1. **Context Engineering** — 에이전트에게 최적의 컨텍스트를 체계적으로 제공
2. **Architectural Constraints** — 구조적 제약으로 에이전트 행동을 가이드
3. **Garbage Collection** — 자동 정리로 품질 드리프트 방지

### 2.3 v2 설계 원칙

1. **Build for Deletion** — 모델이 네이티브로 지원하게 되면 삭제할 수 있어야 함
2. **Fewer, Better Tools** — 도구 수를 줄이고 각 도구의 품질을 높임 (Vercel: 15개→2개로 정확도 80%→100%)
3. **Progressive Disclosure** — 모든 걸 주입하지 말고 "어디서 찾을지"를 알려줌
4. **Policy over Hardcode** — 결정 로직은 코드가 아닌 선언적 정책으로
5. **Detect, Don't Install** — 벤더를 설치하지 않고, 감지하고 연결만 함

---

## 3. 아키텍처

### 3.1 3-Layer Harness Architecture

```
┌─────────────────────────────────────────────────────┐
│                 Harness Interface                     │
│   Skills (slash commands) + Hooks + HUD              │
├─────────────────────────────────────────────────────┤
│                 Harness Engine                        │
│                                                       │
│  ┌─────────────┐ ┌────────────┐ ┌────────────────┐  │
│  │   Context    │ │  Policy    │ │  Lifecycle     │  │
│  │   Engine     │ │  Engine    │ │  Engine        │  │
│  │             │ │            │ │                │  │
│  │ • budget    │ │ • modes    │ │ • session      │  │
│  │ • disclose  │ │ • rules    │ │ • GC/cleanup   │  │
│  │ • project   │ │ • gates    │ │ • team coord   │  │
│  │   analysis  │ │ • tiers    │ │ • pipeline     │  │
│  │ • enrichment│ │ • workflow │ │ • state persist│  │
│  └─────────────┘ └────────────┘ └────────────────┘  │
├─────────────────────────────────────────────────────┤
│                 Adapter Layer (HRP)                   │
│   Scan → Detect → Classify → Integrate               │
│                                                       │
│   omc? ──→ adapter     superpowers? ──→ adapter      │
│   codex? ──→ adapter   slack-mcp? ──→ adapter        │
│   (감지→활성화, 없으면 코어 폴백)                     │
└─────────────────────────────────────────────────────┘
```

### 3.2 컴포넌트 책임

| 컴포넌트 | 계층 | 책임 |
| --- | --- | --- |
| Context Engine | Engine | 프로젝트 분석, 컨텍스트 예산 관리, Progressive Disclosure, CLAUDE.md/AGENTS.md 생성 |
| Policy Engine | Engine | 모드 관리, 워크플로우 규칙, 품질 게이트, Tier별 정책 적용 |
| Lifecycle Engine | Engine | 세션 상태, GC/정리, 팀 조율, 파이프라인 실행, 상태 지속 |
| HRP Scanner | Adapter | 환경 스캔 (플러그인/MCP/CLI/스킬/프로젝트) |
| HRP Detector | Adapter | 이전 스캔과 비교하여 변화(delta) 감지 |
| HRP Classifier | Adapter | 감지된 변화를 위험도별로 분류 (Safe/Moderate/High) |
| HRP Integrator | Adapter | 분류 결과에 따라 통합 실행 (자동 또는 승인 후) |

### 3.3 v1 컴포넌트와의 관계

| v1 컴포넌트 | v2 대응 | 변화 |
| --- | --- | --- |
| Command Router | Harness Interface | 유지 (간소화) |
| Mode Engine | Policy Engine | 흡수 (정책 엔진의 일부) |
| Resolver Engine | HRP | 대체 (감지 기반으로 전환) |
| Health Evaluator | HRP Classifier | 흡수 (Tier + 위험도 기반) |
| DOT Gate Controller | 제거 | v2에서 실험선 개념 폐기 |
| Evidence Writer | Lifecycle Engine | 흡수 (세션 라이프사이클의 일부) |
| Source Manager | 제거 | 벤더 설치 관리 완전 폐기 |
| Update Manager | 제거 | 플러그인 마켓플레이스에 위임 |

---

## 4. Progressive Harness Model (Tier 시스템)

### 4.1 Tier 정의

```
┌──────────────────────────────────────┐
│  Tier 2: Full Harness                │
│  +gptaku +ruflo +excalidraw          │
│  → 전문 워크플로우 (SPARC, hive,     │
│    pumasi, research, diagram)        │
├──────────────────────────────────────┤
│  Tier 1: Enhanced Harness            │
│  +omc +superpowers (감지시)          │
│  → 멀티에이전트, TDD, brainstorm,    │
│    code-review, parallel agents      │
├──────────────────────────────────────┤
│  Tier 0: Core Harness (CCH only)     │
│  Context Engine, Policy Engine,      │
│  Lifecycle Engine, 코어 스킬         │
│  → 벤더 0개로도 완전한 가치 제공     │
└──────────────────────────────────────┘
```

### 4.2 Tier별 기능 매트릭스

| 기능 | Tier 0 (Core) | Tier 1 (Enhanced) | Tier 2 (Full) |
| --- | --- | --- | --- |
| 프로젝트 초기화 | `cch init` (자체 스캔) | + 심층 분석 | + SPARC 방법론 |
| 브레인스토밍 | brainstorm-lite (구조화 질문) | superpowers brainstorm | + 멀티모델 합의 |
| 플래닝 | plan (자체 구현) | + superpowers write-plan | + hive 합의 기반 |
| 구현 | 단일 에이전트 순차 | omc executor/deep-executor | + Codex/Gemini 병렬 |
| TDD | verify-lite (테스트 실행) | superpowers TDD 강제 | + 크로스 모델 검증 |
| 코드 리뷰 | review-lite (체크리스트) | omc code-reviewer | + 보안 리뷰 |
| 팀 실행 | 순차 파이프라인 | omc native teams (병렬) | + tmux 멀티 CLI |
| 커밋 | cch commit (자체) | + 자동 검증 | + 슬랙/디코 알림 |
| 컨텍스트 관리 | CLAUDE.md 자동 생성 | + 에이전트별 컨텍스트 | + 라이브러리 문서 참조 |
| GC | 상태 파일 정리 | + 컨텍스트 드리프트 감지 | + 자동 리팩터링 제안 |

### 4.3 Tier 전환 규칙

- 상위 Tier의 기능은 하위 Tier에서 **lite 버전**으로 항상 사용 가능
- Tier 승격은 자동 (HRP 감지시), Tier 강등은 자동 (플러그인 제거 감지시)
- 동일한 슬래시 커맨드(`/cch-brainstorm`)가 Tier에 따라 구현이 달라짐
- 사용자는 Tier 차이를 의식할 필요 없음 (투명한 업/다운그레이드)

---

## 5. Harness Reinforcement Protocol (HRP)

### 5.1 개요

> 하네스에 새로운 능력이 추가되면, 하네스가 스스로 강화된다.
> 설치만 하면 환경이 자동으로 최적화되는 자기 강화 시스템.

```
HRP 루프:
  Scan ──→ Detect ──→ Classify ──→ Integrate
   ↑                                    │
   └────────────────────────────────────┘
            (세션 시작시 자동 반복)
```

### 5.2 Phase 1: Scan (전체 환경 스캔)

세션 시작시 또는 `cch scan` 실행시 5개 레이어를 스캔:

```
Layer 1: Claude Code Plugins
  → ~/.claude/plugins/installed_plugins.json
  → 각 플러그인의 skills/, hooks/, agents/

Layer 2: MCP Servers
  → .claude/settings.local.json mcpServers
  → ~/.claude/settings.json 글로벌 MCP
  → 각 서버의 tools 목록

Layer 3: Local Skills
  → .claude/commands/ (프로젝트 로컬)
  → ~/.claude/commands/ (글로벌 커스텀)

Layer 4: CLI Tools
  → which codex, which gemini (PATH 스캔)
  → which docker, which kubectl 등 인프라 도구

Layer 5: Project Context
  → package.json, pyproject.toml 등 프로젝트 메타
  → .github/workflows/ (CI/CD)
  → 기존 CLAUDE.md, AGENTS.md
```

### 5.3 Phase 2: Detect (변화 감지)

이전 스캔 결과(fingerprint)와 비교하여 delta 추출:

```jsonc
// .claude/cch/scan-result.json
{
  "timestamp": "2026-03-04T10:00:00Z",
  "fingerprint": "sha256:abc...",
  "tier": 1,
  "capabilities": {
    "plugins": {
      "oh-my-claudecode": { "version": "4.6.0", "status": "active" },
      "superpowers": { "version": "1.2.0", "status": "new" }
    },
    "mcp_servers": {
      "context7": { "tools": 2, "status": "active" },
      "slack": { "tools": 8, "status": "new" }
    },
    "cli_tools": {
      "codex": { "path": "/usr/local/bin/codex", "status": "active" },
      "gemini": { "path": null, "status": "absent" }
    },
    "local_skills": { "count": 3, "status": "active" },
    "project": { "type": "node", "framework": "next.js" }
  },
  "delta": {
    "added": ["plugins/superpowers", "mcp/slack"],
    "removed": [],
    "changed": []
  }
}
```

### 5.4 Phase 3: Classify (통합 분류)

감지된 변화를 위험도 + 통합 유형으로 분류:

| 위험도 | 통합 유형 | 행동 | 예시 |
| --- | --- | --- | --- |
| **Safe** | Capability 확장 | 자동 활성화 | MCP 도구 추가, CLI 감지, Tier 승격 |
| **Moderate** | Workflow 변경 | 추천 후 승인 | 새 플러그인, 훅 추가, 워크플로우 확장 |
| **High** | Policy/Hook 변경 | 반드시 승인 | 에이전트 행동 변경, 정책 오버라이드 |

### 5.5 Phase 4: Integrate (통합 실행)

5가지 Integration Action:

**1. Tier Upgrade**
```
omc 감지 → Tier 0 → Tier 1 자동 승격
  → cch-brainstorm: brainstorm-lite → superpowers brainstorm
  → cch-verify: self_verify → omc verifier agent
  → cch-team: 순차 → 병렬 에이전트
```

**2. Skill Enhancement**
```
slack MCP 감지 → cch-commit에 "슬랙 알림" 옵션 추가
serena MCP 감지 → cch-review에 LSP 기반 심층 분석 추가
context7 감지 → cch-plan에 라이브러리 문서 자동 참조 추가
```

**3. Workflow Composition**
```
codex CLI + omc 감지 → "Claude + Codex 병렬 실행 워크플로우 활성화?"
docker + CI 감지 → "컨테이너 기반 테스트 파이프라인 추가?"
```

**4. Hook Injection**
```
superpowers TDD 감지 → PostToolUse(Bash)에 tdd-enforcer 훅 제안 (승인 필요)
```

**5. Context Enrichment**
```
새 MCP 도구 감지 → CLAUDE.md에 사용 가이드 자동 추가
새 플러그인 감지 → 정책에 관련 규칙 제안
```

### 5.6 Reinforcement Manifest

```jsonc
// manifests/reinforcements.json
{
  "reinforcements": [
    {
      "id": "omc-core",
      "detect": { "type": "plugin", "id": "oh-my-claudecode" },
      "tier_upgrade": 1,
      "risk": "safe",
      "enhancements": [
        {
          "target": "cch-team",
          "action": "upgrade_backend",
          "from": "sequential",
          "to": "parallel_agents"
        },
        {
          "target": "cch-verify",
          "action": "upgrade_backend",
          "from": "self_verify",
          "to": "omc_verifier_agent"
        },
        {
          "target": "cch-brainstorm",
          "action": "upgrade_backend",
          "from": "brainstorm_lite",
          "to": "superpowers_brainstorm"
        }
      ]
    },
    {
      "id": "slack-notify",
      "detect": { "type": "mcp", "name": "slack" },
      "risk": "moderate",
      "enhancements": [
        {
          "target": "cch-commit",
          "action": "add_post_hook",
          "hook": "notify_slack_on_commit"
        }
      ]
    },
    {
      "id": "codex-worker",
      "detect": { "type": "cli", "command": "codex" },
      "risk": "moderate",
      "enhancements": [
        {
          "target": "cch-team",
          "action": "add_worker_type",
          "worker": "codex"
        }
      ]
    }
  ]
}
```

### 5.7 서드파티 확장 포인트

플러그인 개발자가 CCH 통합을 제공할 때:

```jsonc
// 플러그인의 .claude-plugin/cch-reinforcement.json
{
  "plugin": "my-awesome-plugin",
  "reinforcements": [
    {
      "target": "cch-review",
      "action": "add_reviewer",
      "reviewer_type": "security",
      "risk": "moderate",
      "description": "보안 취약점 자동 스캔 추가"
    }
  ]
}
```

CCH가 이 파일을 감지하면 reinforcement 목록에 자동 추가.
플러그인이 CCH를 알 필요 없이, CCH가 플러그인을 이해하는 구조.

---

## 6. Harness Engine 상세 설계

### 6.1 Context Engine

에이전트에게 최적의 컨텍스트를 체계적으로 제공하는 엔진.

**6.1.1 Project Context Pipeline (`cch init`)**

```
cch init
  ├── scan: 프로젝트 메타데이터, 구조, 기술스택 분석
  ├── docs: Architecture/PRD/Roadmap/TODO 역산 생성
  ├── context: 계층적 CLAUDE.md + 폴더별 AGENTS.md 자동 생성
  └── policy: 프로젝트 특성에 맞는 정책 프로파일 추천
```

**6.1.2 Context Budget Manager**

```
컨텍스트 예산 = 모델 윈도우 - 시스템 프롬프트 - 도구 정의 - 안전 마진
```

기능:
- 프로젝트 크기/복잡도에 따른 컨텍스트 전략 결정
- 토큰 사용량 추적 (세션별, 도구별)
- 컨텍스트 우선순위 관리 (현재 작업 관련 정보 우선)

**6.1.3 Progressive Disclosure**

```
Level 0: 루트 CLAUDE.md (프로젝트 개요, 핵심 규칙)
Level 1: 폴더별 CLAUDE.md (모듈별 규칙)
Level 2: AGENTS.md (에이전트별 컨텍스트)
Level 3: 온디맨드 (필요시 검색/참조)
```

원칙: "모든 걸 주입하지 말고, 어디서 찾을지만 알려줌"

### 6.2 Policy Engine

선언적 정책으로 에이전트 행동을 제어하는 엔진.

**6.2.1 모드 시스템 (v2)**

v1의 4모드(code/plan/tool/swarm)에서 간소화:

| 모드 | 목적 | 기본 워크플로우 |
| --- | --- | --- |
| `work` | 구현/코딩 (기본) | brainstorm → plan → implement → verify |
| `plan` | 설계/분석 | interview → design → document |
| `ops` | 운영/관리 | scan → diagnose → fix |

모드는 확장 가능. 정책 파일로 커스텀 모드 정의 가능:

```jsonc
// profiles/work.json
{
  "mode": "work",
  "workflow": {
    "default": ["brainstorm", "plan", "implement", "verify"],
    "shortcuts": {
      "quick": ["implement", "verify"],
      "careful": ["brainstorm", "plan", "tdd", "implement", "review", "verify"]
    }
  },
  "gates": {
    "commit": { "require": ["verify"] },
    "pr": { "require": ["verify", "review"] }
  }
}
```

**6.2.2 Workflow Rules**

```jsonc
// policies/workflows.json
{
  "rules": [
    {
      "when": { "action": "implement", "scope": "multi-file" },
      "then": ["brainstorm", "plan", "tdd"],
      "unless": { "flag": "skip-workflow" }
    },
    {
      "when": { "action": "commit" },
      "then": ["verify"],
      "gate": { "tests": "pass" }
    },
    {
      "when": { "action": "pr" },
      "then": ["verify", "review"],
      "gate": { "tests": "pass", "review": "approved" }
    }
  ]
}
```

**6.2.3 Quality Gates**

```jsonc
// policies/gates.json
{
  "gates": {
    "pre-commit": {
      "checks": ["test_pass", "lint_clean"],
      "enforcement": "block"
    },
    "pre-pr": {
      "checks": ["test_pass", "review_complete", "no_todo_regression"],
      "enforcement": "warn"
    }
  }
}
```

### 6.3 Lifecycle Engine

세션, 팀, 상태의 전체 라이프사이클을 관리하는 엔진.

**6.3.1 Session Lifecycle**

```
SessionStart → HRP Scan → Context Load → Work → GC → SessionEnd
     │              │            │          │      │
     └─ state load  └─ delta     └─ budget  │      └─ cleanup
                       detect      manage   └─ evidence write
```

**6.3.2 Team Pipeline**

Tier에 따라 실행 백엔드가 달라지는 팀 파이프라인:

```
Tier 0: Sequential Pipeline
  plan(자체) → implement(자체) → verify(자체)
  → 한 에이전트가 역할을 바꿔가며 순차 수행

Tier 1: Parallel Agent Pipeline (omc 감지시)
  plan(planner) → implement(executor×N) → verify(verifier)
  → omc native teams로 병렬 에이전트 실행

Tier 2: Multi-CLI Pipeline (codex/gemini 감지시)
  plan(architect) → implement(claude+codex+gemini) → verify(verifier)
  → tmux 기반 멀티 CLI 워커
```

파이프라인 정의:

```jsonc
// policies/pipelines.json
{
  "pipelines": {
    "standard": {
      "stages": ["plan", "implement", "verify"],
      "on_failure": { "max_retries": 2, "strategy": "fix_and_retry" }
    },
    "full": {
      "stages": ["brainstorm", "plan", "implement", "review", "verify"],
      "on_failure": { "max_retries": 3, "strategy": "escalate" }
    }
  }
}
```

**6.3.3 Garbage Collection**

```
GC 대상:
  ├── 세션 상태: 완료된 TODO, 오래된 plan, 폐기된 work-item
  ├── 컨텍스트: CLAUDE.md ↔ 실제 코드 괴리 감지 (drift detection)
  ├── 스캔 결과: 오래된 scan-result.json 정리
  └── 로그: 기간 초과 실행 로그 아카이브

GC 트리거:
  ├── 세션 시작시 (자동, lightweight)
  ├── cch gc (수동, full)
  └── 일정 기간 경과시 (정책 기반)

GC 보고:
  → "3개의 완료된 TODO 정리, CLAUDE.md에서 2개의 드리프트 감지"
```

---

## 7. 스킬 구조 재편

### 7.1 디렉토리 구조

```
skills/
├── core/                  # Tier 0 - 벤더 무관, 독립 동작
│   ├── cch-init/          # 프로젝트 컨텍스트 엔진
│   ├── cch-commit/        # 커밋 워크플로우
│   ├── cch-plan/          # 설계→플래닝→TODO 통합
│   ├── cch-todo/          # 작업 관리 (docs/TODO.md SSOT)
│   ├── cch-team/          # 팀 오케스트레이션 (Tier별 백엔드)
│   ├── cch-verify/        # 검증 (lite ↔ full 자동 전환)
│   ├── cch-brainstorm/    # 브레인스토밍 (lite ↔ full)
│   ├── cch-review/        # 코드 리뷰 (lite ↔ full)
│   ├── cch-setup/         # 설정 + HRP 초기 스캔
│   ├── cch-status/        # 상태 + Tier 표시
│   ├── cch-gc/            # 가비지 컬렉션 (NEW)
│   └── cch-scan/          # 환경 스캔 (NEW, HRP Phase 1)
│
├── guides/                # 설치 가이드 + 사용 가이드
│   ├── guide-omc/         # omc 설치/설정/활용 가이드
│   ├── guide-superpowers/ # superpowers 가이드
│   └── guide-extensions/  # gptaku, ruflo, excalidraw 등
│
└── adapters/              # Tier 1/2 어댑터 (HRP)
    ├── adapter-omc/       # omc 감지 + 기능 연결
    ├── adapter-sp/        # superpowers 감지 + 기능 연결
    └── adapter-ext/       # CLI/MCP/외부 플러그인 감지
```

### 7.2 v1 → v2 스킬 매핑

| v1 스킬 | v2 대응 | 변화 |
| --- | --- | --- |
| `cch-setup` | `core/cch-setup` | 유지 + HRP 초기 스캔 추가 |
| `cch-mode` | `core/cch-setup` | 흡수 (모드 전환을 setup/status에 통합) |
| `cch-status` | `core/cch-status` | 유지 + Tier/HRP 상태 표시 |
| `cch-commit` | `core/cch-commit` | 유지 (Tier별 후처리 확장) |
| `cch-plan` | `core/cch-plan` | 유지 (interview→design→document) |
| `cch-todo` | `core/cch-todo` | 유지 |
| `cch-team` | `core/cch-team` | 유지 + Tier별 백엔드 전환 |
| `cch-init` | `core/cch-init` | 유지 (Context Engine 핵심) |
| `cch-init-scan` | `core/cch-scan` | 분리 (HRP 전용 스캔으로 확장) |
| `cch-init-docs` | `core/cch-init` | 흡수 (init 파이프라인의 일부) |
| `cch-init-scaffold` | `core/cch-init` | 흡수 |
| `cch-sp-brainstorm` | `core/cch-brainstorm` | 통합 (lite+full, Tier 자동 전환) |
| `cch-sp-tdd` | `core/cch-verify` | 통합 (verify의 TDD 모드) |
| `cch-sp-code-review` | `core/cch-review` | 통합 (lite+full, Tier 자동 전환) |
| `cch-sp-verify` | `core/cch-verify` | 통합 |
| `cch-sp-write-plan` | `core/cch-plan` | 흡수 (plan의 일부) |
| `cch-sp-execute-plan` | `core/cch-team` | 흡수 (team pipeline으로) |
| `cch-sp-parallel-agents` | `core/cch-team` | 흡수 |
| `cch-sp-debug` | `core/cch-verify` | 흡수 (verify의 디버그 모드) |
| `cch-sp-finish-branch` | `core/cch-commit` | 흡수 (commit의 branch 완료 모드) |
| `cch-sp-git-worktree` | `core/cch-team` | 흡수 (team의 격리 실행 모드) |
| `cch-sp-receive-review` | `core/cch-review` | 흡수 |
| `cch-sp-subagent-dev` | `core/cch-team` | 흡수 |
| `cch-gp-*` (9개) | `guides/guide-extensions` | 가이드로 전환 (직접 래핑 제거) |
| `cch-rf-*` (6개) | `guides/guide-extensions` | 가이드로 전환 |
| `cch-excalidraw` | `guides/guide-extensions` | 가이드로 전환 |
| `cch-full-pipeline` | `core/cch-team` | 흡수 (team pipeline의 "full" 프리셋) |
| `cch-pr` | `core/cch-commit` | 흡수 (commit의 PR 모드) |
| `cch-release` | 제거 | 플러그인 마켓플레이스에 위임 |
| `cch-update` | 제거 | 플러그인 마켓플레이스에 위임 |
| `cch-sync` | 제거 | 플러그인 시스템이 처리 |
| `cch-dot` | 제거 | 실험선 개념 폐기 |
| `cch-hud` | `core/cch-status` | 흡수 |
| `cch-pinchtab` | 제거 | 별도 플러그인으로 분리 |
| `cch-pt-*` (3개) | 제거 | 별도 플러그인으로 분리 |
| `cch-arch-guide` | `core/cch-init` | 흡수 |

**결과: 51개 → 12 코어 + 3 가이드 + 3 어댑터 = 18개**

---

## 8. 사용자 경험

### 8.1 온보딩 여정

```
Step 1: 설치
  $ claude plugin install claude-code-harness

Step 2: 초기 설정
  > /cch-setup
  [CCH] 환경 스캔 중...
  [CCH] Tier 0 (Core Harness) 활성화
  [CCH] 설치된 플러그인: 없음
  [CCH] 사용 가능한 기능: init, commit, plan, todo, brainstorm, verify, review, team
  [CCH] 💡 omc를 설치하면 멀티에이전트 기능이 활성화됩니다 (/cch-guide-omc)

Step 3: 프로젝트 초기화
  > /cch-init
  [CCH] 프로젝트 분석 중...
  [CCH] 기술스택: Next.js + TypeScript
  [CCH] CLAUDE.md 생성 완료 (계층적)
  [CCH] 정책 프로파일 추천: "web-frontend"
  [CCH] TODO.md 초기화 완료

Step 4: 작업 시작
  > /cch-brainstorm  (Tier 0: brainstorm-lite)
  > /cch-plan        (Tier 0: 자체 구현)
  > /cch-commit      (Tier 0: 자체 구현)
```

### 8.2 Tier 승격 경험

```
$ claude plugin install oh-my-claudecode
$ claude  (새 세션)

[CCH] 환경 스캔 중...
[CCH] 변화 감지:
  ✅ oh-my-claudecode v4.6.0 설치됨 (NEW)

[CCH] 자동 적용 (Safe):
  • Tier 0 → Tier 1 승격
  • cch-brainstorm: superpowers 브레인스토밍으로 강화
  • cch-verify: omc verifier 에이전트로 강화
  • cch-team: 병렬 에이전트 실행 활성화

[CCH] 승인 필요 (Moderate):
  ? TDD enforcer 훅을 활성화할까요? [Y/n]

[CCH] 하네스 강화 완료. 현재: Tier 1 Enhanced
```

### 8.3 MCP 서버 추가시

```
(사용자가 settings.json에 slack MCP 서버 추가)
$ claude  (새 세션)

[CCH] 환경 스캔 중...
[CCH] 변화 감지:
  ✅ slack MCP 서버 추가됨 (8 tools)

[CCH] 승인 필요 (Moderate):
  ? cch-commit에 슬랙 알림 기능을 추가할까요? [Y/n]
  → 커밋 완료시 #dev-log 채널에 자동 알림

[CCH] 하네스 강화 완료.
```

---

## 9. 추가 아이디어 및 보완사항 (심층 분석)

### 9.1 Harness Health Score

프로젝트의 "에이전트 친화도"를 수치화.

**MVP 범위 (Phase 1):** 이진 지표(binary indicators)만 제공

```
Harness Health Check:
  ✅ CLAUDE.md 존재
  ✅ tests/ 디렉토리 존재
  ⚠️ 3개 파일이 500줄 초과 — 에이전트 이해도 저하 우려
  ❌ src/utils/에 AGENTS.md 없음

💡 개선 제안:
  • src/utils/ 디렉토리에 AGENTS.md 추가 권장
  • 대형 파일 분리 고려: src/app.ts (823줄)
```

**Post-MVP (Phase 3+):** 정량 점수 시스템

```
Harness Health Score: 78/100
  ├── Context Quality:  85/100  (CLAUDE.md 충실도, 구조화 수준)
  ├── Test Coverage:    70/100  (테스트 존재 여부, 실행 가능성)
  ├── Documentation:    75/100  (코드↔문서 일치도)
  ├── Structure:        82/100  (파일 구조, 모듈 분리도)
  └── Agent Readiness:  78/100  (에이전트가 이해하기 쉬운 정도)
```

**실현 가능성 분석:**

| 지표 | 측정 방법 | 난이도 | 비고 |
| --- | --- | --- | --- |
| Context Quality | CLAUDE.md 존재 + 섹션 수 + 토큰 수 | Low | 정적 분석 가능 |
| Test Coverage | `arch.sh`의 `min_test_ratio` 로직 재활용 | Low | v1에 이미 구현됨 (`bin/lib/arch.sh`) |
| Documentation | 파일 존재 여부만 (코드↔문서 일치는 LLM 필요) | Medium | LLM 없이는 "존재" 수준 |
| Structure | 파일 크기, 디렉토리 깊이, 모듈 수 | Low | 정적 분석 가능 |
| Agent Readiness | 파일당 줄 수, 순환 복잡도 등 프록시 지표 | Medium | 외부 도구(eslint) 또는 자체 구현 필요 |

**리스크:**
- 점수 게이밍: 의미 없는 CLAUDE.md로 점수 인플레이션 가능
- False confidence: 수치가 실제 에이전트 친화도를 반영하지 못할 수 있음
- 프로젝트 유형별 가중치가 다르므로 Harness Profile과 연동 필요

**판정: Post-MVP.** MVP에서는 이진 지표(존재/부재/임계값 초과), Post-MVP에서 점수 시스템.
v1의 `bin/lib/arch.sh` test_ratio 로직을 `engines/health-scorer.mjs`로 포팅하여 구현.

### 9.2 Context Replay

이전 세션의 컨텍스트를 다음 세션에 이어가는 메커니즘.

**기술적 제약 분석:**

1. **`UserPromptSubmit` 훅으로 컨텍스트 자동 주입 가능** — 이미 `mode-detector.sh`가 이 방식 사용 중 (`hooks/hooks.json:3-18`)
2. **"이어서 하시겠습니까?" 인터랙션 불가** — Claude Code 훅은 `block`/`continue` 응답만 지원하며 사용자 질문을 던질 수 없음. 자동 주입 방식으로 변경 필요.
3. **`Stop` 훅 타임아웃 제한** — 현재 `summary-writer.mjs`가 2초 타임아웃으로 실행됨 (`hooks/hooks.json:55`). LLM 기반 세션 요약은 이 시간 내 불가능.

**MVP 범위 (축소):**

```jsonc
// .claude/cch/sessions/latest.json
{
  "session_id": "s-20260304-001",
  "branch": "feat/auth-module",
  "mode": "work",
  "tier": 1,
  "modified_files": ["src/auth/jwt.ts", "src/auth/middleware.ts"],
  "pending_todos": ["refresh_token_impl", "test_auth_flow"],
  "ended_at": "2026-03-04T15:30:00Z"
}
```

MVP 구현: `summary-writer.mjs`를 확장하여 git diff + TODO.md에서 기계적으로 추출 (LLM 호출 불필요).
세션 시작시 `UserPromptSubmit` 훅에서 `sessions/latest.json`을 읽어 `additionalContext`로 자동 주입:

```
[CCH] 이전 세션 (3시간 전, feat/auth-module):
  수정 파일: src/auth/jwt.ts, src/auth/middleware.ts
  미완료 작업: refresh_token_impl, test_auth_flow
```

**Post-MVP:**
- LLM 기반 세션 요약 (`Stop` 훅 타임아웃 확장 필요)
- 브랜치별 세션 분리 (다른 브랜치의 컨텍스트 주입 방지)
- `decisions_made` 추적 (세션 중 의사결정 자동 기록)

**리스크:**
- Stale context: 다른 도구/수동 편집으로 파일이 변경된 경우 부정확
- Multi-branch: 브랜치 전환 후 이전 브랜치의 컨텍스트 주입 → 혼란 가능
- Privacy: `modified_files`에 민감 파일 경로 노출 가능

**판정: MVP (축소 범위).** `summary-writer.mjs` 확장 + `UserPromptSubmit` 훅 연동으로 저비용 구현 가능.

### 9.3 Harness Profiles (프로젝트 유형별 프리셋)

**실현 가능성: 높음.** v1의 `profiles/*.json`을 자연스럽게 확장하는 구조.

모드(work/plan/ops)와 프리셋(web-frontend/backend-api/monorepo)은 직교하는 두 축:
- 모드 = "무엇을 하고 있는가" (작업 유형)
- 프리셋 = "어떤 프로젝트인가" (프로젝트 특성)

```jsonc
// profiles/presets/web-frontend.json
{
  "preset": "web-frontend",
  "detect": {
    "indicators": [
      { "file": "package.json", "field": "dependencies", "match": ["react", "next", "vue", "svelte", "angular"] },
      { "directory": "components/" },
      { "directory": "pages/" }
    ],
    "min_match": 1
  },
  "config": {
    "modes": ["work", "plan"],
    "default_workflow": "quick",
    "gates": { "commit": ["lint", "test"] },
    "context": { "focus": ["src/", "components/", "app/"] }
  }
}

// profiles/presets/backend-api.json
{
  "preset": "backend-api",
  "detect": {
    "indicators": [
      { "file": "go.mod" },
      { "file": "requirements.txt" },
      { "file": "Cargo.toml" },
      { "file": "package.json", "field": "dependencies", "match": ["express", "fastify", "hono", "nestjs"] }
    ],
    "min_match": 1
  },
  "config": {
    "modes": ["work", "plan", "ops"],
    "default_workflow": "careful",
    "gates": { "commit": ["lint", "test", "typecheck"], "pr": ["review"] },
    "context": { "focus": ["src/", "api/", "db/", "internal/"] }
  }
}

// profiles/presets/monorepo.json
{
  "preset": "monorepo",
  "detect": {
    "indicators": [
      { "file": "package.json", "field": "workspaces" },
      { "directory": "packages/" },
      { "file": "pnpm-workspace.yaml" },
      { "file": "turbo.json" }
    ],
    "min_match": 1
  },
  "config": {
    "modes": ["work", "plan", "ops"],
    "default_workflow": "standard",
    "gates": { "commit": ["affected_test"] },
    "context": { "strategy": "per-package" }
  }
}
```

**구현:**
1. `cch init` 시 `detect.indicators`를 순회하며 프로젝트 유형 자동 감지
2. 감지된 프리셋을 `.claude/cch/state/preset`에 저장
3. Policy Engine에서 프리셋 로드 시 모드 프로파일과 병합

**리스크:**
- monorepo 안에 frontend+backend 공존 시 감지 혼란 → 복수 프리셋 허용 또는 사용자 선택
- 프리셋 폭증 방지: 코어 3개 + 사용자 커스텀만 허용

**판정: MVP.** 구현 비용이 낮고 `cch init`의 핵심 가치를 크게 높임.

### 9.4 Capability Discovery Protocol

HRP의 확장으로, 감지된 도구의 능력을 자동으로 파악.

**실현 가능성 분석:**

MCP 서버의 tool 목록과 description은 런타임에 조회 가능하나, **"tool description → CCH 스킬 매칭"은 사실상 LLM 추론이 필요.**

예: `lsp_diagnostics`라는 tool이 `cch-verify`에 "LSP 기반 코드 분석"을 추가할 수 있다는 판단은 정적 매칭으로 불가능.

**접근 방식 비교:**

| 접근 | 정확도 | 비용 | MVP 적합 |
| --- | --- | --- | --- |
| 하드코딩 매핑 (`reinforcements.json`) | 100% | 유지보수 | **적합** |
| 키워드 기반 분류 (tool name/desc에서 추출) | 70-80% | 낮음 | 부분 적합 |
| LLM 기반 분석 (세션 시작 시) | 90%+ | 높음 (API 비용) | 부적합 |

**리스크:**
- 과도한 통합 제안: MCP 도구가 많으면 사용자에게 10개+ "통합 제안"이 쏟아짐
- 잘못된 매칭이 사용자 신뢰를 해침
- MCP 서버가 설정에만 있고 실제 비가동인 경우 false positive

**판정: Post-MVP.** MVP에서는 `reinforcements.json`의 하드코딩된 매핑으로 충분.
자동 발견은 매핑 테이블이 성숙한 후 키워드 기반 1차 분류부터 점진적 도입.

```
Post-MVP 구현 로드맵:
  1. settings.local.json에서 mcpServers 파싱
  2. 각 서버의 tool name/description 수집
  3. 키워드 → 카테고리 매핑 테이블 (test/lint/format/deploy/notify → 스킬 연결)
  4. 분류 결과를 reinforcement 후보로 제안 (반드시 사용자 승인)
```

### 9.5 Migration Helper

v1 사용자를 위한 자동 마이그레이션 도구.

**실현 가능성: 높음.** v1의 상태 구조가 단순(평문 파일)하여 변환이 직관적.

**마이그레이션 대상 상세:**

```
데이터 마이그레이션 매핑:
───────────────────────────────────────────────────────
v1 경로                         v2 경로                  변환 유형
───────────────────────────────────────────────────────
.claude/cch/mode               .claude/cch/state/mode    파일 이동
.claude/cch/health             .claude/cch/state/health   파일 이동
.claude/cch/health_reason      .claude/cch/state/health   병합 (health에 통합)
.claude/cch/dot_enabled        (삭제)                     폐기
.claude/cch/dot_compiled       (삭제)                     폐기
.claude/cch/.resolved/         .claude/cch/scan-result.json  구조 변환
.claude/cch/integrity.json     (삭제)                     폐기
.claude/cch/branches/*.yaml    .claude/cch/state/branches/  파일 이동
.claude/cch/work-items/        .claude/cch/state/work-items/ 파일 이동
.claude/cch/metrics/           (삭제 또는 아카이브)        폐기/아카이브
.claude/cch/rollbacks/         (삭제)                     폐기

profiles/code.json             profiles/work.json         이름+내용 변환
profiles/plan.json             profiles/plan.json         내용 변환
profiles/tool.json             profiles/ops.json          이름+내용 변환
profiles/swarm.json            (삭제)                     폐기

manifests/sources.json         (삭제)                     폐기
manifests/capabilities.json    manifests/capabilities.json 구조 재편
manifests/health-rules.json    policies/workflows.json     구조 변환
```

**v1→v2 프로파일 변환 예시:**

```jsonc
// v1: profiles/code.json
{
  "mode": "code",
  "capabilities": {
    "primary": ["omc", "superpowers"],
    "secondary": ["gptaku_plugins", "ruflo"],
    "fallback": []
  },
  "dot": { "eligible": true, "sources": ["dot"], "default": false }
}

// v2: profiles/work.json (변환 결과)
{
  "mode": "work",
  "workflow": {
    "default": ["brainstorm", "plan", "implement", "verify"],
    "shortcuts": {
      "quick": ["implement", "verify"],
      "careful": ["brainstorm", "plan", "tdd", "implement", "review", "verify"]
    }
  },
  "gates": {
    "commit": { "require": ["verify"] },
    "pr": { "require": ["verify", "review"] }
  }
}
// 참고: primary/secondary 벤더 목록은 HRP가 자동 감지하므로 프로파일에서 제거
```

**v1 스킬 호환성 레이어 (필수):**

51개 → 18개로 축소 시 33개 커맨드가 사라지므로, 과도기 리다이렉트 필요:

```
# 호환성 레이어 예시 (skills/compat/cch-sp-brainstorm/SKILL.md)
> 이 스킬은 v2에서 `/cch-brainstorm`으로 통합되었습니다.
> `/cch-brainstorm`을 대신 사용해주세요.
```

**구현:**

```
> /cch-setup --migrate-v1

[CCH] v1 환경 감지...
[CCH] 마이그레이션 분석:
  ├── 상태 파일: 4개 이동, 2개 병합, 3개 폐기
  ├── 프로파일: 3개 변환, 1개 폐기 (swarm.json)
  ├── 매니페스트: 1개 변환, 2개 폐기
  ├── 스킬: 33개 → 호환성 리다이렉트 생성
  └── 훅: 구조 유지, 스크립트 경로 업데이트

[CCH] 마이그레이션 실행할까요?
  • 기존 파일은 .claude/cch/v1-backup/ 에 보존됩니다
  • 롤백: /cch-setup --rollback-v1 으로 복원 가능
  [Y/n]
```

**롤백 메커니즘:**

```
마이그레이션 전:
  1. .claude/cch/ 전체를 .claude/cch/v1-backup.tar.gz로 아카이브
  2. profiles/, manifests/ 사본을 v1-backup/에 복사

롤백 시 (/cch-setup --rollback-v1):
  1. .claude/cch/v1-backup.tar.gz에서 복원
  2. v1-backup/profiles/, v1-backup/manifests/ 복원
  3. 플러그인 버전을 v1으로 다운그레이드 (마켓플레이스 의존)
```

**리스크:**
- 사용자 커스터마이징 손실: profiles/manifests를 수정한 경우 자동 변환이 덮어쓸 수 있음 → 커스텀 감지 후 사용자 확인
- 부분 마이그레이션 중단: 트랜잭션성 보장 필요 (전부 성공 or 전부 롤백)
- v1 백업에 sources/ (git clone된 벤더)가 포함되면 수백 MB → sources/ 제외 명시

**판정: MVP (필수).** v1 사용자가 존재하므로 마이그레이션 경로 없으면 채택 장벽.

### 9.6 아이디어 우선순위 종합

| 아이디어 | MVP/Post-MVP | 복잡도 | 근거 |
| --- | --- | --- | --- |
| **9.3 Harness Profiles** | MVP | Low | 구현 쉽고 init 가치 극대화 |
| **9.5 Migration Helper** | MVP (필수) | Medium | v1 사용자 전환 필수 |
| **9.2 Context Replay** | MVP (축소) | Medium | summary-writer.mjs 확장으로 저비용 |
| **9.1 Health Score** | Post-MVP | Medium-High | 지표 방법론 검증 필요 |
| **9.4 Capability Discovery** | Post-MVP | High | 하드코딩 매핑이 MVP에 충분 |

---

## 10. 기술 스택

### 10.1 결정 요소

| 요소 | Bash | Node.js/TS | Hybrid |
| --- | --- | --- | --- |
| 런타임 의존성 | 없음 | Node.js 필요 | Node.js (선택) |
| 타입 안전성 | 없음 | 우수 | 부분적 |
| 테스트 용이성 | 어려움 | 우수 | 부분적 |
| Claude Code 호환 | 네이티브 | 네이티브 | 네이티브 |
| 개발 속도 | 빠름 | 보통 | 보통 |
| 정책 JSON 처리 | jq 의존 | 네이티브 | 혼합 |

### 10.2 추천: Hybrid (Bash core + mjs engines)

```
bin/cch                    # Bash: CLI 진입점, 라우팅, 간단한 상태 관리
scripts/context-engine.mjs # Node.js: 컨텍스트 분석, 예산 관리
scripts/policy-engine.mjs  # Node.js: 정책 파싱, 워크플로우 규칙
scripts/hrp-scanner.mjs    # Node.js: HRP 환경 스캔, delta 감지
scripts/lifecycle.mjs      # Node.js: GC, 세션 관리
```

이유:
- v1의 bash 코어를 재활용하면서 점진적으로 전환 가능
- JSON 정책 처리는 Node.js가 자연스러움
- Claude Code 환경에 Node.js는 사실상 항상 존재
- 스킬(SKILL.md)은 기술 스택에 무관 (프롬프트 파일)

---

## 11. v1 → v2 마이그레이션 전략

### 11.1 마이그레이션 원칙

1. **Big Bang이 아닌 Strangler Fig** — v1을 한번에 교체하지 않고, v2 기능을 하나씩 구축하여 점진적으로 대체
2. **v1 자산 재활용** — bin/cch의 라우팅 로직, 정책 JSON 구조, 테스트 패턴은 재활용
3. **병렬 운영 기간** — v1과 v2가 일정 기간 공존 가능해야 함
4. **롤백 가능** — v2 전환 실패시 v1으로 즉시 복귀 가능

### 11.2 마이그레이션 Phase

**Phase 0: Foundation (1주)**
- v2 디렉토리 구조 생성
- HRP 스캐너 프로토타입 구현
- Tier 0 코어 스킬 3개 작성 (setup, status, scan)
- v1 백업 메커니즘 구현

**Phase 1: Core Engine (1-2주)**
- Context Engine 구현 (init 파이프라인)
- Policy Engine 구현 (모드, 워크플로우 규칙)
- Tier 0 코어 스킬 완성 (12개)
- v1 sources 관련 코드 제거 시작

**Phase 2: HRP (1-2주)**
- HRP 4단계 전체 구현 (Scan → Detect → Classify → Integrate)
- reinforcements.json 작성
- Tier 1 어댑터 구현 (omc, superpowers)
- 가이드 스킬 작성

**Phase 3: Lifecycle & GC (1주)**
- Lifecycle Engine 구현
- GC 시스템 구현
- 팀 파이프라인 구현 (Tier별)
- Session replay 구현

**Phase 4: Polish & Migration (1주)**
- v1→v2 자동 마이그레이션 도구
- 문서 업데이트 (Architecture, PRD, Roadmap)
- 통합 테스트
- 플러그인 마켓플레이스 제출 준비

### 11.3 v1에서 폐기되는 것

| 폐기 대상 | 이유 | 대체 |
| --- | --- | --- |
| `bin/lib/sources.sh` | 벤더 설치 관리 불필요 | HRP (감지만) |
| `manifests/sources.json` | 벤더 정의 불필요 | `reinforcements.json` |
| `manifests/release.lock` | 벤더 버전 고정 불필요 | 플러그인 마켓플레이스 |
| `overlays/` | 폴백 디렉토리 불필요 | Tier 0 폴백 |
| `dot/` | 실험선 개념 폐기 | 정책 기반 A/B |
| DOT 관련 코드 | combo.lock, combos/ 등 | 제거 |
| 33개 벤더 래퍼 스킬 | 직접 래핑 불필요 | 가이드 + 어댑터 |

### 11.4 v1에서 재활용하는 것

| 재활용 대상 | 용도 |
| --- | --- |
| `bin/cch` 라우팅 로직 | v2 CLI 진입점 기반 |
| `manifests/health-rules.json` 구조 | Policy Engine 규칙 형식 참고 |
| `profiles/*.json` 구조 | v2 프로파일 형식 참고 |
| `hooks/hooks.json` | v2 훅 시스템 기반 |
| `scripts/plan-bridge.mjs` | Lifecycle Engine 참고 |
| `skills/cch-commit/` | 코어 스킬 기반 |
| `skills/cch-plan/` | 코어 스킬 기반 |
| `skills/cch-todo/` | 코어 스킬 기반 |
| 테스트 패턴 (`tests/`) | v2 테스트 기반 |

---

## 12. 성공 기준

### 12.1 출시 조건

1. Tier 0 코어 스킬 12개가 벤더 없이 완전 동작
2. HRP가 omc/superpowers 감지시 Tier 1 자동 승격
3. `cch init`이 프로젝트를 분석하여 CLAUDE.md 자동 생성
4. `cch scan`이 전체 환경을 스캔하고 delta 감지
5. GC가 오래된 상태/로그를 자동 정리
6. v1→v2 마이그레이션 도구가 기존 환경을 변환

### 12.2 품질 기준

1. 코어 스킬 테스트 커버리지 80% 이상
2. HRP 스캔 성능: 5초 이내
3. Tier 전환 지연: 사용자가 인지하지 못하는 수준
4. 정책 변경만으로 워크플로우 커스터마이징 가능
5. v1 사용자가 5분 이내에 v2로 마이그레이션 가능

### 12.3 "Build for Deletion" 체크리스트

v2의 각 컴포넌트에 대해:

| 컴포넌트 | 삭제 조건 | 현재 필요성 |
| --- | --- | --- |
| Context Budget Manager | Claude Code가 자체 컨텍스트 관리 | 높음 (미지원) |
| Policy Engine | Claude Code에 네이티브 정책 시스템 | 높음 (미지원) |
| HRP Scanner | 플러그인 간 네이티브 연동 | 높음 (미지원) |
| GC System | 모델이 자체 정리 | 중간 (부분 지원) |
| Team Pipeline | Claude Code 네이티브 팀 강화 | 중간 (부분 지원) |
| Tier System | 모든 기능이 네이티브 제공 | 높음 (미지원) |
| Session Replay | Claude Code 네이티브 세션 이어가기 | 중간 (부분 지원) |

---

## 13. 파일 구조 (v2 목표)

```
claude-code-harness/
├── .claude-plugin/
│   ├── plugin.json              # 플러그인 매니페스트
│   └── marketplace.json         # 마켓플레이스 메타
├── bin/
│   ├── cch                      # CLI 진입점 (Bash)
│   └── lib/
│       ├── router.sh            # 명령 라우팅
│       ├── state.sh             # 상태 관리
│       └── util.sh              # 유틸리티
├── engines/
│   ├── context-engine.mjs       # Context Engine
│   ├── policy-engine.mjs        # Policy Engine
│   ├── lifecycle-engine.mjs     # Lifecycle Engine
│   └── hrp/
│       ├── scanner.mjs          # HRP 스캐너
│       ├── detector.mjs         # HRP 변화 감지
│       ├── classifier.mjs       # HRP 위험도 분류
│       └── integrator.mjs       # HRP 통합 실행
├── skills/
│   ├── core/                    # Tier 0 코어 스킬 (12개)
│   ├── guides/                  # 설치/사용 가이드 (3개)
│   └── adapters/                # Tier 1/2 어댑터 (3개)
├── manifests/
│   ├── reinforcements.json      # HRP 통합 정의
│   └── capabilities.json        # 기능 매트릭스 (Tier별)
├── policies/
│   ├── workflows.json           # 워크플로우 규칙
│   ├── gates.json               # 품질 게이트
│   └── pipelines.json           # 팀 파이프라인
├── profiles/
│   ├── work.json                # work 모드 정의
│   ├── plan.json                # plan 모드 정의
│   ├── ops.json                 # ops 모드 정의
│   └── presets/                 # 프로젝트 유형별 프리셋
│       ├── web-frontend.json
│       ├── backend-api.json
│       └── monorepo.json
├── hooks/
│   └── hooks.json               # Claude Code 훅
├── tests/
│   ├── unit/                    # 엔진 유닛 테스트
│   ├── integration/             # 스킬 통합 테스트
│   └── e2e/                     # 사용자 시나리오 테스트
├── docs/
│   ├── Architecture.md
│   ├── PRD.md
│   ├── Roadmap.md
│   ├── TODO.md
│   └── plans/
└── README.md
```

### 런타임 디렉토리 (자동 생성, gitignored)

```
.claude/cch/
├── state/
│   ├── mode                     # 현재 모드
│   ├── tier                     # 현재 Tier
│   └── health                   # 현재 헬스
├── scan-result.json             # HRP 스캔 결과
├── sessions/
│   └── latest.json              # 최근 세션 컨텍스트
├── gc/
│   └── last-run.json            # GC 마지막 실행
└── logs/
    └── <date>.jsonl             # 실행 로그
```

---

## 14. 리스크와 완화

| 리스크 | 영향 | 확률 | 완화 |
| --- | --- | --- | --- |
| Tier 0 코어만으로 충분한 가치 제공 실패 | 치명적 | 중간 | brainstorm-lite, verify-lite의 품질에 집중 투자 |
| HRP 스캔 성능 문제 (5초 초과) | 높음 | 낮음 | fingerprint 캐시, delta-only 스캔 |
| v1 사용자 마이그레이션 실패 | 높음 | 중간 | 자동 마이그레이션 + v1 백업 보존 |
| 플러그인 API 변경으로 어댑터 파손 | 중간 | 높음 | 어댑터를 최소 표면으로 유지, 버전 체크 |
| 정책 복잡도 폭증 | 중간 | 중간 | 정책 검증기, 린터, 기본값 우선 원칙 |

---

## 15. 갭 해소 설계 (G1-G7)

### G1. v1/v2 네임스페이스 충돌 방지

**문제**: v1의 `.claude/cch/`와 v2가 동일 경로를 사용하면 마이그레이션 시 데이터 손실 위험.

**설계: Version Gate 패턴**

```text
.claude/cch/
├── version              # "2" (v2 마커)
├── v1-backup/           # 마이그레이션 시 v1 상태 백업
└── ...v2 구조...
```

동작 규칙:
1. `cch setup` 실행 시 `.claude/cch/version` 파일 확인
2. 파일 없음 → v1으로 간주 → 마이그레이션 프롬프트
3. `version=1` → v1 상태를 `v1-backup/`으로 복사 후 v2 구조 생성
4. `version=2` → 정상 진행

```bash
_version_gate() {
  local ver_file="$CCH_STATE/version"
  if [[ ! -f "$ver_file" ]]; then
    echo "v1 환경 감지. 마이그레이션을 시작합니다."
    _migrate_v1_to_v2
    echo "2" > "$ver_file"
  elif [[ "$(cat "$ver_file")" == "1" ]]; then
    _migrate_v1_to_v2
    echo "2" > "$ver_file"
  fi
}
```

롤백: `cch rollback-to-v1` 명령으로 `v1-backup/` 복원 가능.

---

### G2. 9개 코어 스킬 스펙 정의

**문제**: Tier 0 코어 스킬의 구체적 입출력 스펙이 없으면 구현 기준이 모호.

**설계: Tier-Aware Skill Template**

각 코어 스킬은 `SKILL.md` + `adapter.sh` 구조:

```yaml
# skills/cch-brainstorm/SKILL.md
name: cch-brainstorm
tier: [0, 1, 2]
trigger: "brainstorm|ideate|explore ideas"
input: topic (string, required)
output: structured_ideas (markdown)
tier_behavior:
  0: "내장 프롬프트 체인 (Claude 단독)"
  1: "omc planner/analyst 연동"
  2: "멀티 에이전트 합의 (ralplan)"
```

**9개 코어 스킬 스펙 요약:**

| # | 스킬 | Tier 0 동작 | Tier 1 확장 | Tier 2 확장 |
|---|------|------------|------------|------------|
| 1 | `cch-brainstorm` | 구조화된 프롬프트 체인 | omc planner 연동 | 멀티 에이전트 합의 |
| 2 | `cch-plan` | 마크다운 계획서 생성 | architect 에이전트 | consensus planning |
| 3 | `cch-commit` | 변경 분석 + 커밋 | work-item 연동 | 자동 PR 생성 |
| 4 | `cch-todo` | TODO.md CRUD | beads 연동 | 팀 태스크 동기화 |
| 5 | `cch-verify` | 테스트 실행 + 확인 | verifier 에이전트 | 다중 검증 파이프라인 |
| 6 | `cch-review` | 셀프 리뷰 체크리스트 | code-reviewer 에이전트 | 보안+품질+성능 리뷰 |
| 7 | `cch-debug` | 에러 분석 프롬프트 | debugger 에이전트 | 병렬 원인 분석 |
| 8 | `cch-tdd` | red-green-refactor 가이드 | test-engineer 에이전트 | 커버리지 자동 추적 |
| 9 | `cch-setup` | 환경 스캔 + 초기화 | 플러그인 감지 + Tier 판정 | HRP 풀 스캔 |

---

### G3. Tier 상태 일관성 보장

**문제**: 런타임 중 플러그인이 제거되면 Tier가 강등되는데, 진행 중인 작업이 상위 Tier 기능에 의존하면 장애 발생.

**설계: Tier State Machine + Graceful Degradation**

```text
상태 전이:
  Tier2 → Tier1: 가능 (경고 + 대체 경로)
  Tier1 → Tier0: 가능 (경고 + 기능 제한 안내)
  TierN → TierN+1: HRP 스캔 시에만 (세션 중간 불가)
```

핵심 규칙:
1. **세션 내 Tier 잠금**: 세션 시작 시 결정된 Tier는 세션 종료까지 유지
2. **강등은 다음 세션부터**: 플러그인 제거 감지 시 `pending_downgrade` 마킹
3. **긴급 강등 예외**: 플러그인 크래시 → 즉시 해당 기능만 비활성화 (Tier 자체는 유지)

```bash
_check_tier_consistency() {
  local current_tier=$(cat "$CCH_STATE/state/tier")
  local scan_tier=$(_calculate_tier)

  if [[ "$scan_tier" -lt "$current_tier" ]]; then
    echo "pending_downgrade=$scan_tier" >> "$CCH_STATE/state/tier_pending"
    _log "warn" "Tier 강등 예정: $current_tier → $scan_tier (다음 세션부터 적용)"
  fi
}
```

**preserved_config 패턴**: Tier 강등 시에도 사용자 설정(정책, 워크플로우 커스터마이징)은 보존. 재승급 시 자동 복원.

---

### G4. HRP 5초 성능 보장

**문제**: 전체 환경 스캔이 5초를 초과하면 사용자 경험 저하.

**설계: 3-Layer Scan Budget**

```text
총 예산: 5,000ms
├── Layer 1: Fingerprint Check (500ms)
│   └── .claude/cch/scan-result.json의 해시 비교
│   └── 변경 없으면 → 캐시 반환 (즉시 완료)
├── Layer 2: Delta Scan (2,000ms)
│   └── 변경된 디렉터리만 스캔
│   └── 새 파일/삭제 파일 감지
└── Layer 3: Deep Probe (2,500ms)
    └── 새로 발견된 소스만 능력 테스트
    └── timeout 시 partial result 반환
```

최적화 기법:
1. **Fingerprint 캐시**: `find` 결과의 MD5를 저장, 변경 없으면 스캔 스킵
2. **병렬 프로브**: 각 소스 검증을 백그라운드로 실행
3. **타임아웃 안전 장치**: 5초 초과 시 현재까지 결과로 Tier 판정
4. **점진적 갱신**: 이전 스캔 결과를 기반으로 delta만 업데이트

```bash
_hrp_scan_with_budget() {
  local start_ms=$(date +%s%3N)
  local budget_ms=5000

  # Layer 1: Fingerprint
  if _fingerprint_unchanged; then
    cat "$CCH_STATE/scan-result.json"
    return 0
  fi

  # Layer 2: Delta scan
  local remaining=$((budget_ms - $(date +%s%3N) + start_ms))
  _delta_scan "$remaining" &
  local scan_pid=$!

  # Layer 3: Deep probe (남은 시간만큼)
  wait $scan_pid
  remaining=$((budget_ms - $(date +%s%3N) + start_ms))
  if [[ $remaining -gt 500 ]]; then
    _deep_probe "$remaining"
  fi

  _save_scan_result
}
```

---

### G5. 스킬 테스트 커버리지

**문제**: v2 코어 스킬 9개의 테스트 전략이 없으면 회귀 방지 불가.

**설계: 3-Layer Skill Test**

```text
Layer 1: Contract Test (각 스킬당 1개)
  - SKILL.md의 입출력 스펙 검증
  - trigger 패턴 매칭 검증
  - tier_behavior 키 존재 검증

Layer 2: Behavior Test (각 스킬당 Tier별 1개)
  - Tier 0 동작 검증 (벤더 없이 동작하는지)
  - Tier 1 동작 검증 (mock 플러그인으로)
  - Tier 2 동작 검증 (mock 풀 환경으로)

Layer 3: Integration Test (워크플로우 단위)
  - setup → brainstorm → plan → commit 파이프라인
  - Tier 전환 시 스킬 동작 변화
  - HRP 스캔 후 스킬 목록 갱신
```

테스트 파일 구조:
```text
tests/
├── skills/
│   ├── test_skill_contract.sh      # Layer 1: 전체 스킬 계약
│   ├── test_brainstorm_tier0.sh    # Layer 2: 개별 스킬
│   ├── test_brainstorm_tier1.sh
│   └── ...
├── test_workflow_pipeline.sh       # Layer 3: 통합
└── harness.sh                      # 테스트 프레임워크 (v1 재사용)
```

목표: **스킬당 최소 3개 테스트** (contract + tier0 behavior + integration 참여) = 최소 27개 테스트 케이스.

---

### G6. 엔진 호출 체인 명세

**문제**: Hook → CLI → Engine 간의 호출 흐름이 불명확하면 디버깅과 확장이 어려움.

**설계: 3-Stage Call Chain**

```text
Stage 1: Hook Layer (hooks.json)
  ├── PreToolUse → context injection
  ├── PostToolUse → evidence collection
  └── SessionStart → HRP scan trigger

Stage 2: CLI Layer (bin/cch)
  ├── 명령 파싱 + 인자 검증
  ├── Tier 확인 + 정책 로드
  └── Engine 디스패치

Stage 3: Engine Layer (scripts/*.mjs)
  ├── Context Engine → 토큰 예산 관리
  ├── Policy Engine → 워크플로우 실행
  ├── Lifecycle Engine → 세션/태스크 상태
  └── HRP Scanner → 능력 감지
```

호출 예시 (`/cch-brainstorm "topic"`):
```text
1. Hook: SessionStart → _hrp_scan_with_budget()
2. Hook: PreToolUse(Skill) → tier context injection
3. CLI: bin/cch skill brainstorm "topic"
4. CLI: _load_policy("workflows.json") → brainstorm 워크플로우 로드
5. CLI: _check_tier() → Tier 0/1/2 분기
6. Engine(Tier0): scripts/brainstorm-engine.mjs → 프롬프트 체인 실행
7. Engine(Tier1): scripts/brainstorm-engine.mjs → omc planner 에이전트 호출
8. Hook: PostToolUse(Skill) → 결과 로깅
```

계약: 모든 Engine 함수는 `{success: bool, result: any, duration_ms: number}` 반환.

---

### G7. v1 → v2 기능 역검증 체크리스트

**문제**: v2가 v1의 필수 기능을 누락하면 기존 사용자가 피해를 입음.

**설계: Feature Parity Matrix**

| v1 기능 | v1 구현 위치 | v2 대응 | 상태 |
|---------|------------|---------|------|
| `cch setup` | bin/cch:503-583 | `cch setup` (Tier 판정 추가) | 대체 |
| `cch mode <m>` | bin/cch:585-640 | 정책 기반 모드 전환 | 대체 |
| `cch status` | bin/cch:710-820 | `cch status` (Tier/HRP 정보 추가) | 대체 |
| `cch status --json` | bin/cch:822-901 | 동일 | 유지 |
| `cch doctor` | bin/cch:903-1190 | `cch status`에 통합 | 흡수 |
| `cch dot on/off` | bin/cch:1192-1330 | 제거 (DOT 실험 종료) | 삭제 |
| `cch update check` | bin/cch:1451-1550 | `cch update check` (간소화) | 대체 |
| `cch update apply` | bin/cch:1550-1650 | `cch update apply` | 유지 |
| `cch update rollback` | bin/cch:1650-1750 | `cch update rollback` | 유지 |
| source 설치/관리 | bin/lib/sources.sh | 제거 (HRP로 대체) | 삭제 |
| KPI 추적 | bin/lib/kpi.sh | Lifecycle Engine 흡수 | 흡수 |
| health 규칙 | manifests/health-rules.json | policies/health.json | 이전 |
| 51개 스킬 | skills/cch-* | 18개 스킬 (Tier-aware) | 축소 |
| 6-layer 테스트 | tests/*.sh | 3-layer + 스킬 테스트 | 재편 |

검증 방법:
1. v1 `bin/cch` 의 모든 `cmd_*` 함수를 추출
2. 각 함수에 대해 v2 대응 여부를 이 매트릭스에서 확인
3. "삭제" 항목은 삭제 사유 문서화 필수
4. MVP 전에 이 매트릭스의 "대체"/"유지" 항목 100% 구현 확인

---

## 16. 제거 및 최적화 계획

### 16.1 제거 대상 인벤토리

#### 디렉터리 전체 삭제

| 디렉터리 | 파일 수 | 총 라인 | 사유 |
|---------|--------|--------|------|
| `dot/` | 4 | ~68 | DOT 실험 종료 |
| `overlays/` | 1 | 0 | .gitkeep만 존재, 사용처 없음 |
| `src/` | 0 | 0 | 빈 디렉터리 |
| `profiles/swarm.json` 외 불필요 프로필 | - | - | 팀 파이프라인으로 흡수 |

#### 코어 파일 삭제/변환

| 파일 | 라인 수 | 처리 | 사유 |
|------|--------|------|------|
| `bin/lib/sources.sh` | 918 | **삭제** | 벤더 설치/관리 전체 (HRP로 대체) |
| `bin/lib/kpi.sh` | 83 | **삭제** | Lifecycle Engine에 흡수 |
| `scripts/build-release.sh` | 76 | **삭제** | 릴리즈 파이프라인 재설계 |
| `scripts/mode-detector.sh` | 116 | **삭제** | HRP Scanner가 대체 |
| `scripts/tdd-enforcer.sh` | - | **삭제** | cch-tdd 스킬로 대체 |
| `scripts/todo-sync-check.sh` | - | **삭제** | cch-todo 스킬로 통합 |
| `scripts/plan-doc-reminder.sh` | - | **삭제** | cch-plan 스킬로 통합 |
| `bin/lib/log.sh` | 187 | **유지** | 공용 로깅 유틸리티 |
| `bin/lib/lock.sh` | 54 | **유지** | 동시성 제어 |
| `bin/lib/beads.sh` | 363 | **유지** | Lifecycle Engine 기반 |
| `bin/lib/branch.sh` | 260 | **유지** | 브랜치 관리 |
| `bin/lib/arch.sh` | 348 | **부분 유지** | test_ratio → Health Score로 변환 |

#### 매니페스트 정리 (14 → 4)

**삭제 (10개):**
- `manifests/sources.json` (61줄) — 벤더 정의
- `manifests/kpi-schema.json` — KPI 스키마
- `manifests/release-channels.json` — 릴리즈 채널
- `manifests/release-manifest-schema.json` — 릴리즈 스키마
- `manifests/slo-definitions.json` — SLO 정의
- `manifests/architecture-levels.json` — 아키텍처 레벨
- `manifests/capability-schema.json` — 능력 스키마
- `manifests/resolved-schema.json` — resolve 스키마
- `manifests/health-rules.json` (87줄) — `policies/health.json`으로 이전
- `manifests/capabilities.json` (51줄) — Tier 시스템으로 재구조화

**유지 (2개):**
- `manifests/command-contract.json` (22줄)
- `manifests/error-codes.json` (20줄)

**신규 (2개):**
- `policies/workflows.json` — 워크플로우 정책
- `policies/health.json` — 헬스 규칙 (health-rules.json 이전)

#### 프로필 정리 (4 → 3)

| 프로필 | 처리 | 사유 |
|--------|------|------|
| `profiles/plan.json` | 유지 | plan 모드 |
| `profiles/code.json` | `profiles/work.json`으로 리네임 | code → work 통합 |
| `profiles/tool.json` | 유지 | tool 모드 |
| `profiles/swarm.json` | **삭제** | 팀 파이프라인으로 흡수 |

#### 스킬 삭제 (51 → 18, 33개 삭제)

**벤더 래퍼 삭제 (29개):**
- `cch-sp-*` 12개: brainstorm, code-review, debug, execute-plan, finish-branch, git-worktree, parallel-agents, receive-review, subagent-dev, tdd, verify, write-plan
- `cch-gp-*` 9개: docs, git-learn, mentor, playground, prd, pumasi, research, skill-builder, team
- `cch-rf-*` 6개: doctor, hive, memory, security, sparc, swarm
- `cch-pt-*` 3개 (PinchTab): infra, report, test (단, `cch-pinchtab` 가이드는 유지)

**유틸리티 삭제 (10개):**
- `cch-dot`, `cch-release`, `cch-update`, `cch-sync`
- `cch-hud`, `cch-mode`, `cch-pinchtab`
- `cch-pt-infra`, `cch-pt-report`, `cch-pt-test`

**유지/변환 (18개):**
- 코어 9개: `cch-brainstorm`(신규), `cch-plan`, `cch-commit`, `cch-todo`, `cch-verify`(신규), `cch-review`(신규), `cch-debug`(신규), `cch-tdd`(신규), `cch-setup`
- 가이드 4개: `cch-init`, `cch-init-scan`, `cch-init-scaffold`, `cch-init-docs`
- 하네스 3개: `cch-status`, `cch-arch-guide`, `cch-team`
- 특수 2개: `cch-excalidraw`, `cch-pr`

#### 테스트 파일 정리

**삭제 (5개):**
- `tests/test_source_types.sh` — 벤더 소스 타입 테스트
- `tests/test_vendor_integration.sh` — 벤더 통합 테스트
- `tests/test_dot_gate.sh` — DOT 게이트 테스트
- `tests/test_gptaku_skills.sh` — GPTaku 스킬 테스트
- `tests/test_ruflo_skills.sh` — Ruflo 스킬 테스트

**유지:**
- `tests/harness.sh` — 테스트 프레임워크 (v1 재사용)
- `tests/test_contract.sh` — 명령 계약 테스트 (수정)
- `tests/test_skill.sh` — 스킬 테스트 (수정)
- `tests/test_workflow.sh` — 워크플로우 테스트 (수정)
- `tests/test_resilience.sh` — 복원력 테스트 (수정)
- `tests/test_agent.sh` — 에이전트 테스트 (수정)

---

### 16.2 bin/cch 내부 배선 제거 상세

`bin/cch`는 현재 2,069줄. v2에서 ~500줄로 축소 (76% 감소).

| 코드 블록 | 라인 범위 | 라인 수 | 처리 |
|----------|----------|--------|------|
| 상태 헬퍼 함수 | 30-63 | 33 | **유지** |
| JSON 파서 (bash) | 110-118 | 8 | **삭제** (mjs로 대체) |
| `_list_available_sources` | 120-190 | 70 | **삭제** (HRP Scanner) |
| `check_source_available` | 191-300 | 109 | **삭제** (HRP Scanner) |
| `_compute_source_hash` | 301-367 | 66 | **삭제** (HRP fingerprint) |
| `_do_resolve` | 368-491 | 123 | **삭제** (Tier 기반으로 대체) |
| `_apply_fallback_order` | 492-502 | 10 | **삭제** |
| `cmd_setup` | 503-583 | 80 | **변환** (~50줄로 축소) |
| `cmd_mode` | 585-640 | 55 | **변환** (~30줄로 축소) |
| `cmd_status` + `cmd_status_json` | 710-901 | 191 | **변환** (~80줄로 축소) |
| `cmd_doctor` | 903-1190 | 287 | **삭제** (status에 통합) |
| DOT 관련 함수들 | 1192-1330 | 138 | **삭제** (DOT 제거) |
| KPI 관련 함수들 | 1336-1449 | 113 | **삭제** (Lifecycle 흡수) |
| 업데이트/릴리즈/싱크 | 1451-1899 | 448 | **변환** (~100줄로 축소) |
| 메인 디스패처 | 1900-2069 | 169 | **변환** (~60줄로 축소) |

**제거 소계:** ~1,374줄 삭제 + ~625줄 → ~320줄로 변환 = **최종 ~500줄**

---

### 16.3 안전한 제거 순서

의존성 분석에 기반한 4단계 제거:

**Phase 1: 독립 디렉터리/파일 (의존성 없음)**
1. `dot/` 디렉터리 삭제
2. `overlays/` 디렉터리 삭제
3. `src/` 디렉터리 삭제
4. `manifests/kpi-schema.json` 삭제
5. `manifests/slo-definitions.json` 삭제
6. `manifests/architecture-levels.json` 삭제
7. `manifests/release-channels.json` 삭제
8. `manifests/release-manifest-schema.json` 삭제

**Phase 2: 벤더 래퍼 스킬 (bin/cch와 약한 참조)**
9. `skills/cch-sp-*` 12개 삭제
10. `skills/cch-gp-*` 9개 삭제
11. `skills/cch-rf-*` 6개 삭제
12. `skills/cch-pt-*` 3개 삭제 (cch-pinchtab 가이드는 유지)
13. 유틸리티 스킬 10개 삭제

**Phase 3: 코어 라이브러리 (bin/cch 직접 참조)**
14. `bin/lib/sources.sh` 삭제 → `bin/cch`에서 `source` 라인 제거
15. `bin/lib/kpi.sh` 삭제 → `bin/cch`에서 KPI 함수 호출 제거
16. `scripts/mode-detector.sh` 삭제
17. `scripts/build-release.sh` 삭제
18. 벤더 관련 테스트 5개 삭제

**Phase 4: bin/cch 내부 리팩터링 (마지막)**
19. `bin/cch`에서 삭제 대상 함수 블록 제거 (~1,374줄)
20. 남은 함수 변환 (setup, mode, status, update → v2 인터페이스)

> **원칙**: Phase N+1은 Phase N 완료 후 실행. 각 Phase 후 `scripts/test.sh` 실행하여 잔여 기능 검증.

---

### 16.4 최적화 항목

#### bin/cch 슬리밍

| 항목 | 현재 | 목표 | 방법 |
|------|------|------|------|
| 총 라인 수 | 2,069 | ~500 | 불필요 함수 삭제 + 변환 |
| source 명령 | 5개 lib | 3개 lib | sources.sh, kpi.sh 제거 |
| 서브커맨드 | 12개 | 7개 | doctor/dot/kpi/sync/release 제거 |
| JSON 처리 | bash 내장 | mjs 위임 | 복잡한 JSON은 scripts/*.mjs로 |

#### 매니페스트 통합 (14 → 4)

```text
현재 (14개):                    v2 (4개):
├── sources.json          ──→   (삭제)
├── capabilities.json     ──→   (삭제, Tier 시스템으로)
├── health-rules.json     ──→   policies/health.json
├── command-contract.json ──→   manifests/command-contract.json (유지)
├── error-codes.json      ──→   manifests/error-codes.json (유지)
├── kpi-schema.json       ──→   (삭제)
├── slo-definitions.json  ──→   (삭제)
├── architecture-levels   ──→   (삭제)
├── release-channels      ──→   (삭제)
├── release-manifest-*    ──→   (삭제)
├── capability-schema     ──→   (삭제)
├── resolved-schema       ──→   (삭제)
└── (신규)                ──→   policies/workflows.json
                          ──→   policies/health.json
```

#### 정책 디렉터리 신설

```text
policies/
├── workflows.json        # 워크플로우 정의 (brainstorm→plan→code→verify)
├── health.json            # 헬스 판정 규칙 (health-rules.json에서 이전)
├── gates.json             # 품질 게이트 정의 (선택)
└── tier-requirements.json # Tier별 필수 조건 (선택)
```

#### 훅 최적화 (7 → 3)

현재 7개 훅 스크립트 → 3개로 통합:

| 현재 | v2 | 사유 |
|------|-----|------|
| `scripts/activity-tracker.mjs` | **유지** | Lifecycle Engine 기반 |
| `scripts/summary-writer.mjs` | **유지** | Context Replay 기반 |
| `scripts/plan-bridge.mjs` | **유지** | Plan 워크플로우 |
| `scripts/mode-detector.sh` | **삭제** | HRP Scanner로 대체 |
| `scripts/tdd-enforcer.sh` | **삭제** | cch-tdd 스킬로 대체 |
| `scripts/todo-sync-check.sh` | **삭제** | cch-todo 스킬로 통합 |
| `scripts/plan-doc-reminder.sh` | **삭제** | cch-plan 스킬로 통합 |

---

### 16.5 수치 요약

| 카테고리 | 현재 (v1) | 목표 (v2) | 감소율 |
|---------|----------|----------|--------|
| `bin/cch` | 2,069줄 | ~500줄 | 76% |
| `bin/lib/*.sh` | 6개 (2,213줄) | 4개 (~1,212줄) | 45% |
| 매니페스트 | 14개 | 4개 | 71% |
| 프로필 | 4개 | 3개 | 25% |
| 스킬 | 51개 | 18개 | 65% |
| 테스트 | 12개 | 7개 | 42% |
| 훅 스크립트 | 7개 | 3개 | 57% |
| **전체 코드베이스** | **~100%** | **~40%** | **~60% 감소** |

---

## 17. 결론

CCH v2의 핵심은 한 문장으로 요약된다:

> **"에이전트가 잘 일할 수 있는 환경을 자동으로 구성하고, 새로운 능력이 추가되면 스스로 강화되는 하네스."**

v1이 "여러 플러그인을 하나로 묶는 통합 프레임워크"였다면,
v2는 "설치된 환경에서 최적의 에이전트 경험을 자동으로 만드는 하네스"이다.

핵심 전환:
1. **패키지 매니저 → 하네스**: 설치 관리에서 환경 최적화로
2. **벤더 래핑 → 자기 강화**: 얇은 래퍼에서 HRP 기반 자동 통합으로
3. **고정 기능 → 적응형 Tier**: 51개 고정 스킬에서 Tier별 자동 전환으로
4. **수동 설정 → 자동 감지**: 사용자 개입 최소화, 하네스가 알아서 최적화
