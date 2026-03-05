# CCH (Claude Code Harness) v3 — Skill & Workflow Reference

> 전체 스킬 카탈로그, 워크플로우, 의존성 맵 시각화 문서
> 버전: v3.0 | 갱신일: 2026-03-05

---

## 1. Skill Catalog (18 Skills)

### 1.1 카테고리별 분류

```mermaid
graph TB
    subgraph Core["Core Skills (8)"]
        direction TB
        S_SETUP["cch-setup<br/>환경 초기화"]
        S_PLAN["cch-plan<br/>설계→플래닝→TODO"]
        S_COMMIT["cch-commit<br/>논리 단위 커밋"]
        S_TODO["cch-todo<br/>통합 작업 조회"]
        S_VERIFY["cch-verify<br/>구현 검증"]
        S_REVIEW["cch-review<br/>코드 리뷰"]
        S_STATUS["cch-status<br/>헬스 상태"]
        S_PR["cch-pr<br/>PR 생성"]
    end

    subgraph Init["Init Skills (4)"]
        direction TB
        S_INIT["cch-init<br/>통합 파이프라인"]
        S_SCAN["cch-init-scan<br/>프로젝트 스캔"]
        S_DOCS["cch-init-docs<br/>문서 생성"]
        S_SCAFFOLD["cch-init-scaffold<br/>구조 스캐폴딩"]
    end

    subgraph Utility["Utility Skills (6)"]
        direction TB
        S_TEAM["cch-team<br/>Dev→Test→Verify"]
        S_PIPE["cch-full-pipeline<br/>E2E 파이프라인"]
        S_ARCH["cch-arch-guide<br/>아키텍처 레벨"]
        S_EXCALI["cch-excalidraw<br/>다이어그램 생성"]
        S_LSP["cch-lsp<br/>LSP 설치/관리"]
        S_PINCH["cch-pinchtab<br/>웹 UI 테스트"]
    end

    style Core fill:#E3F2FD,stroke:#1565C0
    style Init fill:#E8F5E9,stroke:#2E7D32
    style Utility fill:#FFF3E0,stroke:#F57C00
```

### 1.2 전체 스킬 목록

| # | 스킬 | 카테고리 | 설명 | user-invocable |
|---|------|---------|------|:-:|
| 1 | `cch-setup` | Core | 환경 초기화, 경로/권한 확인, Tier 감지 | O |
| 2 | `cch-plan` | Core | 설계(인터뷰) → 플래닝 → TODO 통합 워크플로우 | O |
| 3 | `cch-commit` | Core | 변경사항 분석 → 논리 단위 그룹화 → Plan 트레일러 커밋 | O |
| 4 | `cch-todo` | Core | 플랜 문서 + TaskList 통합 작업 조회 | O |
| 5 | `cch-verify` | Core | 테스트 실행, 출력 확인, 스펙 대비 검증 | O |
| 6 | `cch-review` | Core | 코드 리뷰 체크리스트 + 서브에이전트 디스패치 | O |
| 7 | `cch-status` | Core | 모드/Tier/헬스 상태 표시 | O |
| 8 | `cch-pr` | Core | 플랜 연동 PR 생성 + 선택적 Merge & Cleanup | O |
| 9 | `cch-init` | Init | 스캔→문서→스캐폴딩 통합 파이프라인 | O | - |
| 10 | `cch-init-scan` | Init | 메타데이터/구조/문서/git/아키텍처 스캔 | - | - |
| 11 | `cch-init-docs` | Init | Architecture/PRD/Roadmap 문서 역산 생성 | - | - |
| 12 | `cch-init-scaffold` | Init | 디렉터리/매니페스트/프로필/훅 스캐폴딩 | - | - |
| 13 | `cch-team` | Utility | Dev→Test→Verify 멀티에이전트 파이프라인 | O | - |
| 14 | `cch-full-pipeline` | Utility | PRD→팀빌딩→병렬구현→검증→딜리버리 E2E | O | - |
| 15 | `cch-arch-guide` | Utility | 복잡도 인터뷰 → 아키텍처 레벨 결정/스캐폴딩 | O | - |
| 16 | `cch-excalidraw` | Utility | Excalidraw 다이어그램 생성 (CCH 컨텍스트 주입) | O | - |
| 17 | `cch-lsp` | Utility | LSP 서버 감지/설치/Serena 설정 | O | - |
| 18 | `cch-pinchtab` | Utility | PinchTab 기반 웹 UI 디버깅/테스트 | O | - |

---

## 2. Skill Dependency Graph

스킬 간 호출/참조 관계.

```mermaid
graph LR
    subgraph CoreFlow["Core Workflow Chain"]
        PLAN["cch-plan"]
        COMMIT["cch-commit"]
        VERIFY["cch-verify"]
        REVIEW["cch-review"]
        PR["cch-pr"]
        TODO["cch-todo"]
    end

    subgraph InitFlow["Init Pipeline"]
        INIT["cch-init"]
        SCAN["cch-init-scan"]
        DOCS["cch-init-docs"]
        SCAFFOLD["cch-init-scaffold"]
    end

    subgraph AgentPipelines["Agent Pipelines"]
        TEAM["cch-team"]
        FULL["cch-full-pipeline"]
    end

    subgraph Standalone["Standalone"]
        SETUP["cch-setup"]
        STATUS["cch-status"]
        ARCH["cch-arch-guide"]
        LSP["cch-lsp"]
        EXCALI["cch-excalidraw"]
        PINCH["cch-pinchtab"]
    end

    subgraph SharedInfra["Shared Infrastructure"]
        PLANS[("Plan Docs<br/>docs/plans/")]
        ENGINE["bin/cch"]
        STATE[(".claude/cch/<br/>state")]
    end

    %% Core Flow dependencies
    PLAN -->|"Phase 3: TaskList 생성"| PLANS
    PLAN -.->|"다음 단계 제안"| COMMIT
    COMMIT -->|"Plan trailer"| PLANS
    COMMIT -->|"arch level 조회"| ARCH
    COMMIT -.->|"push는 PR에서"| PR
    VERIFY -.->|"검증 후 커밋"| COMMIT
    REVIEW -.->|"리뷰 후 PR"| PR
    PR -->|"플랜 감지"| PLANS
    TODO -->|"태스크 조회"| PLANS

    %% Init Flow
    INIT -->|"Agent"| SCAN
    INIT -->|"Agent"| DOCS
    INIT -->|"Agent"| SCAFFOLD
    SCAN -.->|"scan-result.json"| DOCS
    SCAN -.->|"scan-result.json"| SCAFFOLD

    %% Agent Pipelines
    TEAM -->|"플랜 문서 추적"| PLANS
    FULL -->|"플랜 문서 생성"| PLANS

    %% Standalone to Infra
    SETUP --> ENGINE
    STATUS --> ENGINE
    ARCH --> ENGINE

    style CoreFlow fill:#E3F2FD,stroke:#1565C0
    style InitFlow fill:#E8F5E9,stroke:#2E7D32
    style AgentPipelines fill:#FFF3E0,stroke:#F57C00
    style Standalone fill:#F3E5F5,stroke:#6A1B9A
    style SharedInfra fill:#FFF9C4,stroke:#F9A825
```

---

## 3. Tier System

### 3.1 Tier 감지 흐름

```mermaid
flowchart TD
    START(["SessionStart / cch setup"]) --> SCAN["check-env.mjs<br/>환경 스캔"]

    SCAN --> CHK_PLUGIN{"~/.claude/plugins/cache/<br/>플러그인 존재?"}
    CHK_PLUGIN -->|No| TIER0["Tier 0<br/>CCH Core Only"]
    CHK_PLUGIN -->|Yes| CHK_MCP{"~/.claude/mcp.json<br/>서버 1개 이상?"}
    CHK_MCP -->|No| TIER1["Tier 1<br/>+ Plugins"]
    CHK_MCP -->|Yes| TIER2["Tier 2<br/>+ MCP Servers"]

    TIER0 --> WRITE["tier 상태 기록<br/>.claude/cch/tier"]
    TIER1 --> WRITE
    TIER2 --> WRITE

    style START fill:#1565C0,color:white
    style TIER0 fill:#ECEFF1,stroke:#607D8B
    style TIER1 fill:#E8F5E9,stroke:#2E7D32
    style TIER2 fill:#E3F2FD,stroke:#1565C0
```

---

## 4. Hook Event Pipeline

Claude Code 라이프사이클 이벤트에 연결된 후크 파이프라인.

```mermaid
flowchart LR
    subgraph Events["Claude Code Lifecycle Events"]
        E0["SessionStart<br/>(세션 시작)"]
        E1["UserPromptSubmit<br/>(매 프롬프트)"]
        E2["PreToolUse<br/>(TaskCreate/TaskUpdate)"]
        E3["PostToolUse<br/>(ExitPlanMode)"]
        E4["Stop<br/>(세션 종료)"]
    end

    subgraph Scripts["Hook Scripts"]
        S0["check-env.mjs<br/>timeout: 5s"]
        S1a["mode-detector.sh<br/>timeout: 3s"]
        S1b["activity-tracker.mjs<br/>timeout: 2s"]
        S2["activity-tracker.mjs<br/>timeout: 2s"]
        S3["plan-bridge.mjs<br/>timeout: 5s"]
        S4["summary-writer.mjs<br/>timeout: 2s"]
    end

    subgraph Outputs["State / Context 출력"]
        O0[".claude/cch/tier<br/>+ Tier/Plugin/MCP 리포트"]
        O1["additionalContext<br/>모드 전환 추천"]
        O1b[".claude/cch/last_activity<br/>last_question"]
        O2["활동 추적 갱신"]
        O3["플랜 문서 연결"]
        O4[".claude/cch/last_summary<br/>Q→A 요약"]
    end

    E0 --> S0 --> O0
    E1 --> S1a --> O1
    E1 --> S1b --> O1b
    E2 --> S2 --> O2
    E3 --> S3 --> O3
    E4 --> S4 --> O4

    style E0 fill:#E3F2FD,stroke:#1565C0
    style E1 fill:#E3F2FD,stroke:#1565C0
    style E2 fill:#E3F2FD,stroke:#1565C0
    style E3 fill:#E3F2FD,stroke:#1565C0
    style E4 fill:#E3F2FD,stroke:#1565C0
```

---

## 5. Mode System (plan / code)

```mermaid
flowchart LR
    subgraph Modes["2-Mode System"]
        PLAN["plan 모드<br/>설계/아키텍처/리서치"]
        CODE["code 모드<br/>구현/테스트/커밋"]
    end

    subgraph AutoDetect["자동 감지 (Hook)"]
        PROMPT["UserPromptSubmit"] --> DETECTOR["mode-detector.sh"]
        DETECTOR --> SCORE["키워드 스코어링"]
        SCORE --> PLAN_KW["architect/design/plan<br/>→ plan_score"]
        SCORE --> CODE_KW["implement/fix/build<br/>→ code_score"]
        PLAN_KW --> INJECT["additionalContext<br/>모드 전환 추천"]
        CODE_KW --> INJECT
    end

    subgraph ManualSwitch["수동 전환"]
        CMD["cch mode plan/code"] --> WRITE_MODE["모드 기록"]
        WRITE_MODE --> AUTO_DOC{"plan?"}
        AUTO_DOC -->|Yes| CREATE_PLAN["docs/plans/ 문서 자동 생성"]
        AUTO_DOC -->|No| DONE["완료"]
    end

    style PLAN fill:#CE93D8,stroke:#6A1B9A
    style CODE fill:#80DEEA,stroke:#00838F
```

---

## 6. Core Workflow: Plan → Code → Commit → PR

전체 개발 라이프사이클.

```mermaid
flowchart TD
    START(["기능 요청"]) --> PLAN

    subgraph PLAN_PHASE["Phase 1: /cch-plan"]
        PLAN["Smart Entry<br/>(입력 분석)"]
        PLAN --> P1["Phase 1: Design<br/>인터뷰 + 설계 문서"]
        P1 --> P2["Phase 2: Plan<br/>TDD Task 분해"]
        P2 --> P3["Phase 3: TODO Sync<br/>TaskList 생성"]
    end

    P3 --> IMPL

    subgraph CODE_PHASE["Phase 2: 구현"]
        IMPL["구현 시작"]
        IMPL --> OPT_A["옵션 A: cch-team<br/>(Dev→Test→Verify)"]
        IMPL --> OPT_B["옵션 B: 수동 구현<br/>(직접 코드 작성)"]
    end

    OPT_A & OPT_B --> VERIFY_PHASE

    subgraph VERIFY_PHASE_BOX["Phase 3: /cch-verify"]
        VERIFY_PHASE["테스트 실행 + 검증"]
        VERIFY_PHASE --> PASS{"VERIFIED?"}
        PASS -->|No| DEBUG["실패 분석<br/>(systematic debugging)"]
        DEBUG --> VERIFY_PHASE
        PASS -->|Yes| VERIFIED["검증 완료"]
    end

    VERIFIED --> COMMIT_PHASE

    subgraph COMMIT_PHASE_BOX["Phase 4: /cch-commit"]
        COMMIT_PHASE["변경사항 수집"]
        COMMIT_PHASE --> ANALYZE["논리 단위 그룹화"]
        ANALYZE --> TDD_CHECK["TDD Pre-Check"]
        TDD_CHECK --> USER_CONFIRM["사용자 승인"]
        USER_CONFIRM --> EXECUTE["순차 커밋 실행"]
        EXECUTE --> SIMPLIFY["Simplify + README"]
    end

    SIMPLIFY --> REVIEW_PHASE

    subgraph REVIEW_PHASE_BOX["Phase 5: /cch-review"]
        REVIEW_PHASE["코드 리뷰"]
        REVIEW_PHASE --> CHECKLIST["체크리스트<br/>(기능/품질/안전/테스트)"]
        CHECKLIST --> RESULT{"APPROVED?"}
        RESULT -->|No| FIX["수정 필요"]
        RESULT -->|Yes| APPROVED["리뷰 통과"]
    end

    APPROVED --> PR_PHASE

    subgraph PR_PHASE_BOX["Phase 6: /cch-pr"]
        PR_PHASE["PR 내용 생성"]
        PR_PHASE --> PLAN_LINK["플랜 연동"]
        PLAN_LINK --> GH_PR["gh pr create"]
        GH_PR --> MERGE_OPT["선택: PR만 / Merge+Cleanup"]
    end

    MERGE_OPT --> DONE(["완료"])

    style START fill:#1565C0,color:white
    style DONE fill:#4CAF50,color:white
    style PLAN_PHASE fill:#F3E5F5,stroke:#6A1B9A
    style CODE_PHASE fill:#E8F5E9,stroke:#2E7D32
    style VERIFY_PHASE_BOX fill:#FFF3E0,stroke:#F57C00
    style COMMIT_PHASE_BOX fill:#E3F2FD,stroke:#1565C0
    style REVIEW_PHASE_BOX fill:#FCE4EC,stroke:#C62828
    style PR_PHASE_BOX fill:#E0F7FA,stroke:#00838F
```

---

## 7. cch-plan 상세 워크플로우

가장 복잡한 Core 스킬의 내부 흐름.

```mermaid
flowchart TD
    START(["/cch-plan [input]"]) --> SMART["Step 0: Smart Entry<br/>입력 분석"]

    SMART --> CHK1{"*-design.md?"}
    CHK1 -->|Yes| START_P2["Phase 2부터"]
    CHK1 -->|No| CHK2{"*-impl.md?"}
    CHK2 -->|Yes| START_P3["Phase 3부터"]
    CHK2 -->|No| START_P1["Phase 1부터"]

    START_P1 --> P1["Phase 1: Design Interview"]
    P1 --> P1_CTX["컨텍스트 탐색 (병렬)<br/>Architecture.md, PRD.md,<br/>plans/, git log"]
    P1_CTX --> P1_Q["명확화 질문<br/>(1-4회, AskUserQuestion)"]
    P1_Q --> P1_APPROACH["2-3 접근법 제안<br/>+ 추천 선택"]
    P1_APPROACH --> P1_DOC["섹션별 설계 문서 작성<br/>각 섹션 사용자 승인 (HARD-GATE)"]
    P1_DOC --> P1_SAVE["저장: docs/plans/<br/>YYYY-MM-DD-topic-design.md"]

    P1_SAVE & START_P2 --> P2["Phase 2: Plan"]
    P2 --> P2_READ["설계 문서 읽기"]
    P2_READ --> P2_EXPLORE["코드베이스 탐색<br/>(기존 패턴/파일 파악)"]
    P2_EXPLORE --> P2_TASKS["Task 분해<br/>(2-5분 단위 bite-sized)"]
    P2_TASKS --> P2_TDD["각 Task: TDD 포맷<br/>실패 테스트→구현→통과→커밋"]
    P2_TDD --> P2_SAVE["저장: docs/plans/<br/>YYYY-MM-DD-topic-impl.md"]

    P2_SAVE & START_P3 --> P3["Phase 3: TODO Sync (항상 실행)"]
    P3 --> P3_PARSE["### Task N: 패턴 파싱"]
    P3_PARSE --> P3_TASKS["TaskList 생성<br/>TaskCreate + addBlockedBy"]
    P3_TASKS --> P3_REPORT["세션 작업 목록 로드"]
    P3_HYDRATE --> REPORT["완료 보고<br/>+ 실행 옵션 제안"]

    style START fill:#1565C0,color:white
    style REPORT fill:#4CAF50,color:white
    style P1 fill:#F3E5F5,stroke:#6A1B9A
    style P2 fill:#E3F2FD,stroke:#1565C0
    style P3 fill:#E8F5E9,stroke:#2E7D32
```

---

## 8. cch-commit 상세 워크플로우

논리 단위 분할 커밋 + 후처리.

```mermaid
flowchart TD
    START(["/cch-commit"]) --> COLLECT["Step 1: 수집 (병렬)"]
    COLLECT --> C1["git status --porcelain"]
    COLLECT --> C2["git diff / diff --cached"]
    COLLECT --> C3["git log --oneline -5"]
    COLLECT --> C4[".claude/cch/branches/*.yaml<br/>→ bead_id 결정"]
    COLLECT --> C5["git rev-parse --abbrev-ref HEAD"]

    C1 & C2 & C3 & C4 & C5 --> ANALYZE["Step 2: 분석<br/>논리 단위 그룹화"]

    ANALYZE --> CONFIRM["Step 3: 커밋 계획 표시<br/>사용자 승인 대기"]
    CONFIRM --> TDD["Step 3.5: TDD Pre-Check<br/>arch level + test ratio 검증"]

    TDD --> EXECUTE["Step 4: 순차 커밋 실행"]
    EXECUTE --> LOOP["각 그룹마다:<br/>git add files → git commit<br/>(Plan + Co-Authored-By trailer)"]

    LOOP --> SIMPLIFY{"Step 5: Simplify<br/>코드 파일만?"}
    SIMPLIFY -->|"비코드만/docs/chore"| SKIP_S["스킵"]
    SIMPLIFY -->|"코드 파일 있음"| RUN_S["code-simplifier<br/>Agent 실행"]
    RUN_S --> S_RESULT{"변경?"}
    S_RESULT -->|Yes| S_COMMIT["refactor: simplify 커밋"]
    S_RESULT -->|No| S_NONE["변경 없음"]

    SKIP_S & S_COMMIT & S_NONE --> README["Step 6: README 재생성"]
    README --> R_SCAN["프로젝트 구조 스캔"]
    R_SCAN --> R_RESULT{"변경?"}
    R_RESULT -->|Yes| R_COMMIT["docs: update README 커밋"]
    R_RESULT -->|No| R_NONE["변경 없음"]

    R_COMMIT & R_NONE --> REPORT(["Step 7: 결과 보고<br/>커밋 테이블 + 후처리 요약"])

    subgraph Safety["안전 장치"]
        S_EXCL["민감 파일 자동 제외<br/>.env, *.pem, *secret*"]
        S_NOVER["--no-verify 금지"]
        S_NOPUSH["push 금지<br/>(push는 /cch-pr)"]
        S_NEWCOMMIT["hook 실패 시 new commit<br/>(amend 아님)"]
    end

    style START fill:#1565C0,color:white
    style REPORT fill:#4CAF50,color:white
```

---

## 9. cch-pr 워크플로우

플랜 연동 PR 생성 + 선택적 Merge.

```mermaid
flowchart TD
    START(["/cch-pr"]) --> PRE["사전 체크"]
    PRE --> P1["gh CLI 설치?"]
    PRE --> P2["gh auth 인증?"]
    PRE --> P3["main/master 아닌가?"]
    PRE --> P4["커밋 존재?"]

    P1 & P2 & P3 & P4 --> COLLECT["Step 1: 수집 (병렬)"]
    COLLECT --> BRANCH["브랜치명"]
    COLLECT --> COMMITS["main..HEAD 커밋"]
    COLLECT --> STAT["diff stat"]
    COLLECT --> PLANS["docs/plans/*.md"]

    COLLECT --> PLAN_DETECT["Step 2: 플랜 감지"]
    PLAN_DETECT --> PD1["1. branches/*.yaml"]
    PLAN_DETECT --> PD2["2. execution-plan.json"]
    PLAN_DETECT --> PD3["3. 커밋 Plan: trailer"]

    PD1 & PD2 & PD3 --> GENERATE["Step 3: PR 내용 생성"]
    GENERATE --> BODY["Summary / Plan /<br/>TODO References / Changes /<br/>Test Plan"]
    BODY --> APPROVE{"사용자 승인?"}
    APPROVE -->|No| REVISE["수정"]
    REVISE --> APPROVE
    APPROVE -->|Yes| CREATE["Step 4: PR 생성"]

    CREATE --> PUSH["git push -u origin branch"]
    PUSH --> GH["gh pr create"]

    GH --> OPTION["Step 5: Merge 옵션"]
    OPTION --> OPT_A["A: PR만 생성 (기본)"]
    OPTION --> OPT_B["B: Merge + Cleanup"]

    OPT_B --> MERGE["gh pr merge --squash"]
    MERGE --> SYNC["로컬 main 동기화"]
    SYNC --> DEL["로컬 branch 삭제"]
    DEL --> BR_UPDATE["branch 상태 파일 업데이트"]

    style START fill:#1565C0,color:white
    style GH fill:#4CAF50,color:white
```

---

## 10. cch-team 파이프라인

Dev → Test → Verify 멀티에이전트 순차 실행.

```mermaid
flowchart TD
    START(["/cch-team task"]) --> SETUP["Step 0: Plan Document"]
    SETUP --> PLAN_DOC["docs/plans/ 문서 생성"]

    PLAN_DOC --> DEV["Step 1: Developer Agent"]
    DEV --> DEV_A["Agent: general-purpose<br/>isolation: worktree"]
    DEV_A --> DEV_IMPL["기능 구현"]
    DEV_IMPL --> DEV_DONE["Task: completed"]

    DEV_DONE --> TEST["Step 2: Test Engineer Agent"]
    TEST --> TEST_A["Agent: general-purpose"]
    TEST_A --> TEST_WRITE["테스트 작성"]
    TEST_WRITE --> TEST_RUN{"통과?"}
    TEST_RUN -->|No| TEST_FIX["수정 + 재실행"]
    TEST_FIX --> TEST_RUN
    TEST_RUN -->|Yes| TEST_DONE["Task: completed"]

    TEST_DONE --> VER["Step 3: Verifier Agent"]
    VER --> VER_A["Agent: general-purpose"]
    VER_A --> VER_CHK["LSP 진단 + 테스트 확인<br/>+ 변경 요약"]
    VER_CHK --> VER_DONE["Task: completed"]

    VER_DONE --> FINAL["Step 4: Documentation"]
    FINAL --> UPDATE["Plan doc 업데이트"]
    FINAL --> REPORT(["결과 리포트"])

    style START fill:#1565C0,color:white
    style DEV fill:#4CAF50,color:white
    style TEST fill:#FF9800,color:white
    style VER fill:#9C27B0,color:white
    style REPORT fill:#1565C0,color:white
```

---

## 11. cch-init 파이프라인

프로젝트 분석 → 문서 생성 → 스캐폴딩.

```mermaid
flowchart TD
    START(["/cch-init"]) --> PRE["Pre-check<br/>기존 실행 감지"]
    PRE --> MODE_SEL{"모드?"}
    MODE_SEL -->|"onboard"| ONBOARD["기존 프로젝트 분석"]
    MODE_SEL -->|"migrate"| MIGRATE["CCH 마이그레이션"]

    ONBOARD & MIGRATE --> SCAN["cch-init-scan (Agent)"]

    subgraph SCAN_BOX["스캔 단계"]
        SCAN --> QS["Quick Scan (병렬)"]
        QS --> QS1["A: 메타데이터"]
        QS --> QS2["B: 디렉터리 구조"]
        QS --> QS3["C: 문서 요약"]
        QS --> QS4["D: Git 메타데이터"]
        QS1 & QS2 & QS3 & QS4 --> DS["Deep Scan (선택)"]
        DS --> DS1["아키텍처 분석<br/>(Serena)"]
        DS --> DS2["기능 분석"]
        DS --> DS3["품질 분석"]
        DS --> DS4["로드맵 신호"]
    end

    DS1 & DS2 & DS3 & DS4 --> SAVE_SCAN["scan-result.json 저장"]

    SAVE_SCAN --> DOCS_PHASE["cch-init-docs (Agent)"]
    subgraph DOCS_BOX["문서 생성 단계"]
        DOCS_PHASE --> DOC_A["Agent A:<br/>Architecture.md"]
        DOCS_PHASE --> DOC_B["Agent B:<br/>PRD.md + Roadmap.md"]
        DOC_A & DOC_B --> CROSS["교차 검증"]
    end

    CROSS --> SCAFFOLD_CHK{"migrate 모드?"}
    SCAFFOLD_CHK -->|No| FINAL["최종 보고"]
    SCAFFOLD_CHK -->|Yes| SCAFFOLD["cch-init-scaffold (Agent)"]

    subgraph SCAFFOLD_BOX["스캐폴딩 단계"]
        SCAFFOLD --> SC1["디렉터리 구조 생성"]
        SCAFFOLD --> SC2["매니페스트 생성"]
        SCAFFOLD --> SC3["프로필 생성"]
        SCAFFOLD --> SC4["Hook 설정"]
    end

    SC1 & SC2 & SC3 & SC4 --> FINAL
    FINAL --> DONE(["완료 리포트"])

    style START fill:#1565C0,color:white
    style DONE fill:#4CAF50,color:white
    style SCAN_BOX fill:#E8F5E9,stroke:#2E7D32
    style DOCS_BOX fill:#E3F2FD,stroke:#1565C0
    style SCAFFOLD_BOX fill:#FFF3E0,stroke:#F57C00
```

---

## 12. cch-full-pipeline (E2E)

PRD 인터뷰 → 팀 빌딩 → 병렬 구현 → 합의 검증 → 딜리버리.

```mermaid
flowchart TD
    START(["/cch-full-pipeline"]) --> P1

    subgraph P1_BOX["Phase 1: PRD Generation"]
        P1["반복 인터뷰<br/>(AskUserQuestion)"]
        P1 --> P1_OUT["산출물 4개:<br/>PRD, User Stories,<br/>Tech Spec, API Design"]
    end

    P1_OUT --> P2

    subgraph P2_BOX["Phase 2: Team Building"]
        P2["PRD 분석 → 역할 매핑"]
        P2 --> TASKS["TaskCreate:<br/>작업 단위 생성"]
    end

    TASKS --> P3

    subgraph P3_BOX["Phase 3: Parallel Implementation"]
        P3["Architect Agent:<br/>스펙 분해"]
        P3 --> WORKERS["병렬 Worker Agents<br/>(isolation: worktree)"]
        WORKERS --> INTEGRATE["통합 + 충돌 해결"]
    end

    INTEGRATE --> P4

    subgraph P4_BOX["Phase 4: Consensus Verification"]
        P4["3 Review Agents (병렬)"]
        P4 --> R1["정확성 리뷰"]
        P4 --> R2["보안 리뷰"]
        P4 --> R3["품질 리뷰"]
        R1 & R2 & R3 --> CONSENSUS{"2/3 합의?"}
        CONSENSUS -->|No| FIX["수정 (최대 2회)"]
        FIX --> P4
        CONSENSUS -->|Yes| PASS["검증 통과"]
    end

    PASS --> P5

    subgraph P5_BOX["Phase 5: Delivery"]
        P5["Writer Agent:<br/>README/API docs/changelog"]
        P5 --> REPORT["파이프라인 실행 보고서"]
    end

    REPORT --> DONE(["딜리버리 완료"])

    style START fill:#1565C0,color:white
    style DONE fill:#4CAF50,color:white
    style P1_BOX fill:#F3E5F5,stroke:#6A1B9A
    style P2_BOX fill:#E3F2FD,stroke:#1565C0
    style P3_BOX fill:#E8F5E9,stroke:#2E7D32
    style P4_BOX fill:#FFF3E0,stroke:#F57C00
    style P5_BOX fill:#FCE4EC,stroke:#C62828
```

---

## 13. Plan Document Task Tracking

프로젝트 수준 태스크 SSOT는 플랜 문서(`docs/plans/`)이다.

```mermaid
flowchart TD
    subgraph PlanDocs["docs/plans/ (SSOT)"]
        DESIGN["*-design.md<br/>설계 문서"]
        IMPL["*-impl.md<br/>구현 플랜 (Task 정의)"]
    end

    subgraph SessionView["세션 실행 뷰"]
        TASKLIST["TaskList<br/>(휘발, 세션 단위)"]
        TASKCREATE["TaskCreate<br/>Task 생성"]
    end

    subgraph Consumers["소비자 스킬"]
        TODO["cch-todo — 통합 조회"]
        PLAN_S["cch-plan — Phase 3 생성"]
        COMMIT_S["cch-commit — Plan trailer"]
        PR_S["cch-pr — PR body 연결"]
        TEAM_S["cch-team — 파이프라인 추적"]
    end

    IMPL -->|"Task 파싱"| TASKCREATE
    TASKCREATE --> TASKLIST
    TASKLIST --> Consumers
    IMPL --> Consumers

    style PlanDocs fill:#E0F7FA,stroke:#00838F
    style SessionView fill:#E8F5E9,stroke:#2E7D32
    style Consumers fill:#FFF3E0,stroke:#F57C00
```

---

## 14. cch-verify + cch-review 품질 게이트

```mermaid
flowchart LR
    subgraph Verify["/cch-verify"]
        V1["대상 파악<br/>(테스트 명령/파일/자동)"]
        V1 --> V2["테스트 실행<br/>(자동 러너 감지)"]
        V2 --> V3{"PASS?"}
        V3 -->|No| V4["실패 분석<br/>(가설 수립→검증)"]
        V3 -->|Yes| V5["VERIFIED"]
    end

    subgraph Review["/cch-review"]
        R1["리뷰 범위 결정<br/>(PR/커밋/브랜치)"]
        R1 --> R2["체크리스트 리뷰<br/>기능/품질/안전/테스트"]
        R2 --> R3{"APPROVED?"}
        R3 -->|No| R4["CHANGES_REQUESTED"]
        R3 -->|Yes| R5["APPROVED"]
    end

    V5 -.->|"검증 후"| COMMIT["/cch-commit"]
    R5 -.->|"리뷰 후"| PR["/cch-pr"]

    style Verify fill:#FFF3E0,stroke:#F57C00
    style Review fill:#FCE4EC,stroke:#C62828
```

---

## 15. Activity Tracker State Machine

```mermaid
stateDiagram-v2
    [*] --> Idle

    Idle --> QuestionSaved : UserPromptSubmit<br/>(질문 저장)
    QuestionSaved --> ActivitySet : 활동 기록

    ActivitySet --> TaskOverride : TaskCreate<br/>(activeForm 덮어쓰기)
    ActivitySet --> InProgress : TaskUpdate(in_progress)

    TaskOverride --> InProgress : TaskUpdate(in_progress)
    TaskOverride --> Completed : TaskUpdate(completed)

    InProgress --> Completed : TaskUpdate(completed)
    InProgress --> TaskOverride : TaskCreate (새 task)

    Completed --> QuestionSaved : 다음 UserPromptSubmit

    QuestionSaved --> SummarySaved : Stop (Q→A 요약)
    ActivitySet --> SummarySaved : Stop
    InProgress --> SummarySaved : Stop
    Completed --> SummarySaved : Stop

    SummarySaved --> [*]
```

---

## 16. System Architecture Overview

전체 레이어와 상호 연결.

```mermaid
graph TB
    subgraph UserLayer["Interface Layer"]
        USER[/"User Prompt"/]
        SLASH[/"/cch-* Slash Commands (18)"/]
    end

    subgraph Runtime["Claude Code Runtime"]
        CC["Claude Code Session"]
        HOOKS["Hook System<br/>(hooks/hooks.json)"]
        SKILLS["Skills Engine<br/>(skills/*/SKILL.md)"]
    end

    subgraph Engine["Execution Layer"]
        BIN["bin/cch<br/>(bash CLI)"]
        SCRIPTS["scripts/<br/>(Node.js modules)"]
        CORE["scripts/lib/core.mjs"]
    end

    subgraph Config["Configuration Layer"]
        CAP["manifests/capabilities.json"]
        PROF_P["profiles/plan.json"]
        PROF_C["profiles/code.json"]
    end

    subgraph State["State Layer"]
        CCH_STATE[".claude/cch/<br/>mode | health | tier<br/>branches/ | sessions/ | locks/"]
        PLANS_ST["docs/plans/<br/>(Task SSOT)"]
    end

    subgraph Tier["Tier System"]
        T0["Tier 0: Core"]
        T1["Tier 1: + Plugins"]
        T2["Tier 2: + MCP Servers"]
    end

    USER --> CC
    SLASH --> SKILLS
    CC --> HOOKS
    SKILLS --> Engine
    HOOKS --> SCRIPTS

    BIN --> Config
    BIN --> State
    CORE --> Config & State
    SCRIPTS --> CCH_STATE

    T0 -.-> T1 -.-> T2
    T1 -.->|"추가 기능 감지"| SKILLS

    style UserLayer fill:#FFF3E0,stroke:#F57C00
    style Engine fill:#E3F2FD,stroke:#1565C0
    style Config fill:#FCE4EC,stroke:#C62828
    style State fill:#F3E5F5,stroke:#6A1B9A
    style Tier fill:#FFF9C4,stroke:#F9A825
```

---

## 17. Test Architecture

6개 테스트 레이어 + 유닛 테스트.

```mermaid
flowchart TD
    RUNNER["bash scripts/test.sh all"] --> CLEAN["clean_state()"]
    CLEAN --> TESTS["테스트 실행"]

    TESTS --> T1["Contract<br/>bin/cch 명령 계약"]
    TESTS --> T2["Skill<br/>SKILL.md frontmatter"]
    TESTS --> T4["Branch<br/>브랜치 워크플로우"]
    TESTS --> T5["Workflow<br/>E2E 통합"]
    TESTS --> T6["Resilience<br/>복구력/결함 허용"]
    TESTS --> T8["Init<br/>초기화 스킬 구조"]
    TESTS --> T9["Node Unit<br/>Tier/환경/플랜파서"]

    subgraph Harness["harness.sh"]
        A1["assert_contains"]
        A2["assert_equals"]
        A3["assert_file_exists"]
        A4["assert_exit_code"]
    end

    style T1 fill:#E3F2FD
    style T2 fill:#FFF3E0
    style T3 fill:#E0F7FA
    style T4 fill:#E8F5E9
    style T5 fill:#FCE4EC
    style T6 fill:#F3E5F5
    style T7 fill:#FFF9C4
    style T8 fill:#EFEBE9
```

---

## 18. File Map

### Core Engine

| 파일 | 역할 |
|------|------|
| `bin/cch` | CLI 엔진 — 명령 파싱/디스패치, 모드 전환, Tier 감지, 마이그레이션 |
| `bin/lib/branch.sh` | 브랜치 워크플로우 관리 |
| `bin/lib/log.sh` | 실행 로그 기록/조회 |
| `bin/lib/lock.sh` | 동시성 제어 (락 파일) |

### Scripts

| 파일 | 역할 | 트리거 |
|------|------|--------|
| `scripts/check-env.mjs` | 환경 스캔 + Tier 감지 | SessionStart Hook |
| `scripts/mode-detector.sh` | plan/code 모드 추천 | UserPromptSubmit Hook |
| `scripts/activity-tracker.mjs` | 활동 추적 | UserPromptSubmit, PreToolUse Hook |
| `scripts/plan-bridge.mjs` | 플랜 문서 연결 | PostToolUse(ExitPlanMode) Hook |
| `scripts/summary-writer.mjs` | 세션 요약 생성 | Stop Hook |
| `scripts/lib/core.mjs` | JSON 파싱, 상태 R/W, Tier 계산 | 다른 스크립트에서 import |

### Configuration

| 파일 | 역할 |
|------|------|
| `manifests/capabilities.json` | capability 정의 + 건강 규칙 + 에러 코드 |
| `profiles/plan.json` | plan 모드 프로필 |
| `profiles/code.json` | code 모드 프로필 |
| `hooks/hooks.json` | Hook 이벤트 → 스크립트 바인딩 |

### State

| 경로 | 역할 |
|------|------|
| `.claude/cch/mode` | 현재 모드 (plan/code) |
| `.claude/cch/health` | 헬스 상태 |
| `.claude/cch/health_reason` | reason_code (쉼표 구분) |
| `.claude/cch/tier` | Tier 레벨 (0/1/2) |
| `.claude/cch/branches/` | 브랜치별 상태 (YAML) |
| `.claude/cch/sessions/` | 세션별 상태 |
| `.claude/cch/locks/` | 동시성 제어 |
| `docs/plans/` | 프로젝트 태스크 SSOT (플랜 문서) |
