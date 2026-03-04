# CCH (Claude Code Harness) v2 - Workflow Diagrams

> 전체 워크플로우 시각화 문서. 각 섹션에 Mermaid 다이어그램 포함.
> 버전: v2.1 | 갱신일: 2026-03-04

---

## 1. Master System Overview

전체 CCH v2 시스템의 구성요소와 상호 연결.

```mermaid
graph TB
    subgraph UserLayer["사용자 인터페이스"]
        USER[/"User Prompt"/]
        SLASH[/"/cch-* Slash Commands (18)"/]
    end

    subgraph ClaudeCode["Claude Code Runtime"]
        CC["Claude Code Session"]
        HOOKS["Hook System<br/>(hooks.json)"]
        SKILLS["Skills<br/>(skills/*.md)"]
    end

    subgraph CoreEngine["CCH Core Engine (bin/cch)"]
        SETUP["setup"]
        MODE["mode"]
        STATUS["status"]
        VERSION["version"]
        HELP["help"]
        BEADS["beads"]
        SYNC["sync"]
        LSP["lsp"]
    end

    subgraph HookScripts["Hook Scripts (scripts/)"]
        CHKENV["check-env.mjs"]
        MD["mode-detector.sh"]
        AT["activity-tracker.mjs"]
        PB["plan-bridge.mjs"]
        SW["summary-writer.mjs"]
    end

    subgraph ConfigLayer["Configuration"]
        CAP_JSON["manifests/capabilities.json"]
        PLAN_P["profiles/plan.json"]
        CODE_P["profiles/code.json"]
    end

    subgraph StateLayer[".claude/cch/ State"]
        ST_MODE["mode"]
        ST_HEALTH["health + health_reason"]
        ST_TIER["tier"]
        ST_ACTIVITY["last_activity"]
        ST_SESSIONS["sessions/"]
    end

    subgraph BeadsLayer[".beads/ Task SSOT"]
        ISSUES["issues.jsonl"]
    end

    subgraph TierSystem["Tier System"]
        T0["Tier 0: Core"]
        T1["Tier 1: + Superpowers"]
        T2["Tier 2: + MCP Servers"]
    end

    USER --> CC
    SLASH --> SKILLS
    CC --> HOOKS
    SKILLS --> CoreEngine
    HOOKS --> HookScripts

    SETUP --> ConfigLayer
    MODE --> PLAN_P & CODE_P
    STATUS --> StateLayer
    BEADS --> BeadsLayer

    CHKENV --> ST_TIER
    MD --> ST_MODE
    AT --> ST_ACTIVITY & ST_SESSIONS
    SW --> ST_SESSIONS

    T0 -.-> T1 -.-> T2

    style UserLayer fill:#FFF3E0,stroke:#F57C00
    style CoreEngine fill:#E3F2FD,stroke:#1565C0
    style HookScripts fill:#E8F5E9,stroke:#2E7D32
    style ConfigLayer fill:#FCE4EC,stroke:#C62828
    style StateLayer fill:#F3E5F5,stroke:#6A1B9A
    style BeadsLayer fill:#E0F7FA,stroke:#00838F
    style TierSystem fill:#FFF9C4,stroke:#F9A825
```

---

## 2. Plugin Bootstrap & Setup

CCH 플러그인 초기 셋업 워크플로우.

```mermaid
flowchart TD
    START(["/cch-setup 실행"]) --> READ_SKILL["skills/cch-setup/SKILL.md 읽기"]
    READ_SKILL --> RUN_SETUP["bash bin/cch setup"]

    RUN_SETUP --> MIGRATE["_migrate_v1_to_v2()<br/>(idempotent)"]
    MIGRATE --> CREATE_DIR["상태 디렉토리 생성<br/>.claude/cch/"]
    CREATE_DIR --> CHECK_DIRS{"profiles/, manifests/<br/>존재?"}

    CHECK_DIRS -->|No| ERR_DIR["ERROR: Required dirs missing"]
    CHECK_DIRS -->|Yes| SET_DEFAULTS["기본값 설정<br/>mode=code"]

    SET_DEFAULTS --> CALC_TIER["Tier 감지<br/>check-env.mjs"]
    CALC_TIER --> EVAL_HEALTH["_evaluate_health()"]
    EVAL_HEALTH --> WRITE_STATE["상태 기록<br/>mode, health, tier"]
    WRITE_STATE --> DONE(["셋업 완료"])

    style START fill:#4CAF50,color:white
    style DONE fill:#4CAF50,color:white
    style ERR_DIR fill:#F44336,color:white
```

---

## 3. Mode Switching (plan / code)

2-모드 전환 및 자동 감지 워크플로우.

```mermaid
flowchart LR
    subgraph Modes["CCH v2 모드"]
        PLAN["plan<br/>설계/아키텍처"]
        CODE["code<br/>구현/개발"]
    end

    subgraph AutoDetect["자동 감지 (Hook)"]
        PROMPT["UserPromptSubmit"] --> DETECTOR["mode-detector.sh"]
        DETECTOR --> SCORE["키워드 스코어링"]
        SCORE --> PLAN_KW["architect/design/plan<br/>→ plan_score"]
        SCORE --> CODE_KW["implement/fix/build<br/>→ code_score"]
        PLAN_KW --> INJECT["additionalContext 주입<br/>모드 전환 추천"]
        CODE_KW --> INJECT
    end

    subgraph ManualSwitch["수동 전환"]
        CMD["/cch-mode &lt;target&gt;"] --> VALIDATE{"plan 또는 code?"}
        VALIDATE -->|Yes| WRITE_MODE["모드 기록"]
        VALIDATE -->|No| ERR["ERROR: Invalid mode"]
        WRITE_MODE --> RE_HEALTH["_evaluate_health()"]
    end

    style PLAN fill:#CE93D8,stroke:#6A1B9A
    style CODE fill:#80DEEA,stroke:#00838F
```

---

## 4. Tier System & Health Evaluation

환경 기반 Tier 감지 및 헬스 평가.

```mermaid
flowchart TD
    START(["check-env.mjs / _calculate_tier()"]) --> SCAN["환경 스캔"]

    SCAN --> CHK_SP{"superpowers<br/>플러그인 설치?"}
    CHK_SP -->|No| TIER0["Tier 0: Core Only"]
    CHK_SP -->|Yes| CHK_MCP{"MCP Server<br/>사용 가능?"}
    CHK_MCP -->|No| TIER1["Tier 1: + Superpowers"]
    CHK_MCP -->|Yes| TIER2["Tier 2: + MCP"]

    TIER0 & TIER1 & TIER2 --> WRITE_TIER["tier 상태 기록"]

    WRITE_TIER --> EVAL_HEALTH["_evaluate_health()"]
    EVAL_HEALTH --> READ_CAP["capabilities.json 읽기"]
    READ_CAP --> CHECK_EACH["각 capability 확인"]
    CHECK_EACH --> AVAIL{"사용 가능?"}
    AVAIL -->|Yes| OK["available"]
    AVAIL -->|No| REASON["reason_code 생성"]

    OK & REASON --> WORST["worst health 결정"]
    WORST --> WRITE_HEALTH["health + health_reason 기록"]

    subgraph HealthOutcomes["건강 상태 결과"]
        HEALTHY["Healthy<br/>RC_ALL_OK"]
        DEGRADED["Degraded<br/>RC_SRC_UNAVAILABLE"]
        BLOCKED["Blocked<br/>RC_SRC_BLOCKED"]
    end

    WORST --> HealthOutcomes

    subgraph TierEffects["Tier별 기능"]
        T0E["Tier 0: 스킬 기본 동작"]
        T1E["Tier 1: Enhancement 섹션 활성화<br/>(brainstorming, TDD, verify, review)"]
        T2E["Tier 2: MCP 도구 활용 강화<br/>(Serena, Context7, Slack)"]
    end

    style START fill:#1565C0,color:white
    style HEALTHY fill:#4CAF50,color:white
    style DEGRADED fill:#FF9800,color:white
    style BLOCKED fill:#F44336,color:white
```

---

## 5. Hook Event Pipeline

Claude Code 라이프사이클 이벤트에 연결된 후크 실행 파이프라인.

```mermaid
flowchart LR
    subgraph Events["Claude Code Events"]
        E0["SessionStart<br/>(세션 시작)"]
        E1["UserPromptSubmit<br/>(매 프롬프트)"]
        E2["PreToolUse<br/>TaskCreate/Update"]
        E3["PostToolUse<br/>ExitPlanMode"]
        E4["Stop<br/>(세션 종료)"]
    end

    subgraph Scripts["Hook Scripts"]
        S0["check-env.mjs<br/>⏱ 5s"]
        S1["mode-detector.sh<br/>⏱ 3s"]
        S2["activity-tracker.mjs<br/>⏱ 2s"]
        S3["plan-bridge.mjs<br/>⏱ 2s"]
        S4["summary-writer.mjs<br/>⏱ 2s"]
    end

    subgraph Outputs["출력"]
        O0["Tier 감지 + 환경 리포트"]
        O1["additionalContext<br/>(모드 전환 추천)"]
        O2["last_activity<br/>last_question"]
        O3["plan doc 연결"]
        O4["last_summary<br/>(Q→A 요약)"]
    end

    E0 --> S0 --> O0
    E1 --> S1 --> O1
    E1 --> S2 --> O2
    E2 --> S2
    E3 --> S3 --> O3
    E4 --> S4 --> O4

    style E0 fill:#E3F2FD,stroke:#1565C0
    style E1 fill:#E3F2FD,stroke:#1565C0
    style E2 fill:#E3F2FD,stroke:#1565C0
    style E3 fill:#E3F2FD,stroke:#1565C0
    style E4 fill:#E3F2FD,stroke:#1565C0
```

---

## 6. Activity Tracker State Machine

활동 추적기의 이벤트별 상태 전이.

```mermaid
stateDiagram-v2
    [*] --> Idle

    Idle --> QuestionSaved : UserPromptSubmit<br/>(질문 저장)
    QuestionSaved --> ActivitySet : 활동 기록<br/>(task 미실행 시)

    ActivitySet --> TaskOverride : TaskCreate<br/>(activeForm 덮어쓰기)
    ActivitySet --> InProgress : TaskUpdate(in_progress)<br/>(activeForm 갱신)

    TaskOverride --> InProgress : TaskUpdate(in_progress)
    TaskOverride --> Completed : TaskUpdate(completed)<br/>("done: " 접두사)

    InProgress --> Completed : TaskUpdate(completed)<br/>("done: " 접두사)
    InProgress --> TaskOverride : TaskCreate<br/>(새 task)

    Completed --> QuestionSaved : 다음 UserPromptSubmit

    QuestionSaved --> SummarySaved : Stop<br/>(Q→A 요약 생성)
    ActivitySet --> SummarySaved : Stop
    InProgress --> SummarySaved : Stop
    Completed --> SummarySaved : Stop

    SummarySaved --> [*]
```

---

## 7. Beads Task Tracking

프로젝트 수준 태스크 추적 시스템 (SSOT).

```mermaid
flowchart TD
    subgraph BeadsCLI["bin/cch beads CLI"]
        CREATE["bd create &lt;title&gt;"]
        LIST["bd list [--label key:val]"]
        SHOW["bd show &lt;id&gt;"]
        CLOSE["bd close &lt;id&gt;"]
        EDIT["bd edit &lt;id&gt; [--label/--dep]"]
        READY["bd ready [--limit N]"]
    end

    subgraph Storage[".beads/issues.jsonl"]
        JSONL["각 행 = 1 이벤트<br/>{id, action, title, labels, deps, ...}"]
    end

    subgraph Features["핵심 기능"]
        LABELS["라벨: phase:N, priority:P"]
        DEPS["의존성: blocks/blockedBy"]
        READY_Q["Ready 큐: 의존 풀린 미완료 항목"]
    end

    subgraph Consumers["소비자"]
        TODO["cch-todo<br/>통합 작업 조회"]
        COMMIT["cch-commit<br/>Bead-ID trailer"]
        PR["cch-pr<br/>PR body 연결"]
    end

    CREATE --> JSONL
    LIST --> JSONL
    SHOW --> JSONL
    CLOSE --> JSONL
    EDIT --> JSONL
    READY --> JSONL

    JSONL --> Features
    JSONL --> Consumers

    style Storage fill:#E0F7FA,stroke:#00838F
    style Features fill:#E8F5E9,stroke:#2E7D32
```

---

## 8. Commit Workflow

논리적 분할 커밋 워크플로우.

```mermaid
flowchart TD
    START(["/cch-commit"]) --> COLLECT["Step 1: 정보 수집 (병렬)"]

    COLLECT --> GS["git status"]
    COLLECT --> GD["git diff + diff --cached"]
    COLLECT --> GL["git log -5"]
    COLLECT --> BD["bin/cch beads list"]

    GS & GD & GL & BD --> ANALYZE["Step 2: 분석"]
    ANALYZE --> GROUP["그룹화 기준"]
    GROUP --> G1["feature 단위"]
    GROUP --> G2["module 단위"]
    GROUP --> G3["type 단위"]
    GROUP --> G4["dependency 순서"]

    GROUP --> TYPES["커밋 타입 분류"]
    TYPES --> T_FEAT["feat"]
    TYPES --> T_FIX["fix"]
    TYPES --> T_REF["refactor"]
    TYPES --> T_DOC["docs"]
    TYPES --> T_CHR["chore"]

    TYPES --> CONFIRM["Step 3: 사용자 확인"]
    CONFIRM --> APPROVE{"승인?"}
    APPROVE -->|No| ADJUST["조정"]
    ADJUST --> CONFIRM
    APPROVE -->|Yes| EXECUTE["Step 4: 실행"]

    EXECUTE --> FOR_GROUP["각 그룹마다"]
    FOR_GROUP --> ADD["git add &lt;specific files&gt;"]
    ADD --> COMMIT["git commit -m 'type: msg<br/><br/>Bead-ID: id<br/>Co-Authored-By: Claude'"]
    COMMIT --> FOR_GROUP

    FOR_GROUP -->|완료| REPORT(["Step 5: 결과 리포트"])

    subgraph Safety["안전 장치"]
        S1["Auto-exclude: .env, *.pem, *secret*"]
        S2["Never --no-verify"]
        S3["Hook 실패 시: new commit (not amend)"]
        S4["Never push"]
    end

    style START fill:#1565C0,color:white
    style REPORT fill:#4CAF50,color:white
```

---

## 9. Pull Request Workflow

Beads 연결 PR 생성 워크플로우.

```mermaid
flowchart TD
    START(["/cch-pr"]) --> PRECHECK["사전 체크"]
    PRECHECK --> P1["gh CLI 설치 확인"]
    PRECHECK --> P2["gh auth status"]
    PRECHECK --> P3["main/master 아닌지 확인"]
    PRECHECK --> P4["커밋 존재 확인"]

    P1 & P2 & P3 & P4 --> COLLECT["Step 1: 정보 수집 (병렬)"]
    COLLECT --> BRANCH["현재 브랜치명"]
    COLLECT --> COMMITS["main..HEAD 커밋 로그"]
    COLLECT --> DIFF_STAT["main...HEAD diff stat"]
    COLLECT --> BEADS_LIST["bin/cch beads list"]
    COLLECT --> PLANS["docs/plans/*.md"]

    COLLECT --> DETECT["Step 2: Bead 연결 감지"]
    DETECT --> D1["1. 브랜치명 파싱"]
    DETECT --> D2["2. 커밋 trailer 스캔"]
    DETECT --> D3["3. 활성 Bead 매칭"]

    D1 & D2 & D3 --> GENERATE["Step 3: PR 내용 생성"]
    GENERATE --> SECTIONS["Summary | Bead IDs | Changes | Test Plan"]
    SECTIONS --> TITLE["Title: <70자, conventional prefix"]

    TITLE --> APPROVE{"승인?"}
    APPROVE -->|Yes| CREATE_PR["Step 4: PR 생성"]
    APPROVE -->|No| REVISE["수정"]
    REVISE --> APPROVE

    CREATE_PR --> PUSH["git push -u origin branch"]
    PUSH --> GH_PR["gh pr create --title --body"]

    style START fill:#1565C0,color:white
    style GH_PR fill:#4CAF50,color:white
```

---

## 10. Team Pipeline (Dev → Test → Verify)

멀티 에이전트 순차 실행 파이프라인.

```mermaid
flowchart TD
    START(["/cch-team &lt;task&gt;"]) --> PLAN_DOC["Step 0: Plan Document"]

    PLAN_DOC --> GEN_ID["Bead 생성"]
    GEN_ID --> CREATE_PLAN["docs/plans/YYYY-MM-DD-desc.md 생성"]

    CREATE_PLAN --> DEV["Step 1: Developer Agent"]
    DEV --> DEV_AGENT["Agent: general-purpose<br/>isolation: worktree"]
    DEV_AGENT --> DEV_IMPL["기능 구현"]
    DEV_IMPL --> DEV_DONE["TaskUpdate: completed"]

    DEV_DONE --> TEST["Step 2: Test Engineer Agent"]
    TEST --> TEST_AGENT["Agent: general-purpose"]
    TEST_AGENT --> WRITE_TEST["테스트 작성 + 실행"]
    WRITE_TEST --> FIX_LOOP{"테스트 통과?"}
    FIX_LOOP -->|No| FIX["수정 후 재실행"]
    FIX --> FIX_LOOP
    FIX_LOOP -->|Yes| TEST_DONE["TaskUpdate: completed"]

    TEST_DONE --> VERIFY["Step 3: Verifier Agent"]
    VERIFY --> VERIFY_AGENT["Agent: general-purpose"]
    VERIFY_AGENT --> CHECK["검증 체크리스트"]
    CHECK --> CHANGE_SUMMARY["변경 요약 리포트"]
    CHANGE_SUMMARY --> VERIFY_DONE["TaskUpdate: completed"]

    VERIFY_DONE --> FINALIZE["Step 4: Documentation"]
    FINALIZE --> UPDATE_PLAN["Plan doc 업데이트"]
    FINALIZE --> BEAD_CLOSE["bin/cch beads close"]
    FINALIZE --> REPORT(["사용자에게 리포트"])

    style START fill:#1565C0,color:white
    style DEV fill:#4CAF50,color:white
    style TEST fill:#FF9800,color:white
    style VERIFY fill:#9C27B0,color:white
    style REPORT fill:#1565C0,color:white
```

---

## 11. Test Architecture

7개 테스트 파일, 201+ 테스트.

```mermaid
flowchart TD
    RUNNER["bash tests/harness.sh"] --> CLEAN["clean_state()<br/>rm -rf .claude/cch"]
    CLEAN --> TESTS["테스트 파일 실행"]

    TESTS --> T1["Contract<br/>test_contract.sh (20)"]
    TESTS --> T2["Skill<br/>test_skill.sh (52)"]
    TESTS --> T3["Beads<br/>test_beads.sh (29)"]
    TESTS --> T4["Branch<br/>test_branch.sh (35)"]
    TESTS --> T5["Workflow<br/>test_workflow.sh (9)"]
    TESTS --> T6["Resilience<br/>test_resilience.sh (6)"]
    TESTS --> T7["Integration<br/>test_phase5.sh (13)"]
    TESTS --> T8["Init<br/>test_cch_init.sh (37)"]

    T1 --> T1D["bin/cch 명령 계약:<br/>setup, mode, status, version, help"]
    T2 --> T2D["SKILL.md frontmatter +<br/>Enhancement 섹션 검증"]
    T3 --> T3D["Beads CRUD, 전환,<br/>의존성, ready 큐"]
    T4 --> T4D["브랜치 생성/전환/정리<br/>워크플로우"]
    T5 --> T5D["E2E: setup→mode→<br/>status→beads"]
    T6 --> T6D["복구력: health 지속,<br/>유효값, bad state"]
    T7 --> T7D["Tier/환경스캔/통합<br/>capabilities.json"]
    T8 --> T8D["초기화 스킬 구조<br/>project.yml 스캐폴드"]

    subgraph Assertions["harness.sh Assertions"]
        A1["assert_contains"]
        A2["assert_equals"]
        A3["assert_file_exists"]
        A4["assert_exit_code"]
    end

    subgraph Environment["테스트 환경"]
        ENV1["CCH_STATE_DIR = isolated temp dir"]
        ENV2["각 테스트 파일 전 clean_state"]
        ENV3["colored PASS/FAIL output"]
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

## 12. System Interconnection Diagram

모든 워크플로우 간의 상호 연결 맵.

```mermaid
graph TB
    subgraph UserActions["사용자 액션"]
        UA1["/cch-setup"]
        UA2["/cch-mode"]
        UA3["/cch-commit"]
        UA4["/cch-pr"]
        UA5["/cch-team"]
        UA6["/cch-todo"]
        UA7["/cch-verify"]
        UA8["/cch-review"]
        UA9["/cch-status"]
    end

    subgraph AutoActions["자동 액션 (Hooks)"]
        AA0["check-env.mjs"]
        AA1["mode-detector.sh"]
        AA2["activity-tracker.mjs"]
        AA3["plan-bridge.mjs"]
        AA4["summary-writer.mjs"]
    end

    subgraph Engine["Core Engine (bin/cch)"]
        ENG_SETUP["setup"]
        ENG_MODE["mode"]
        ENG_STATUS["status"]
        ENG_BEADS["beads"]
        ENG_SYNC["sync"]
        ENG_LSP["lsp"]
    end

    subgraph State["State (.claude/cch/)"]
        ST["mode | health | tier<br/>health_reason | last_activity<br/>sessions/ | locks/"]
    end

    subgraph Beads["Beads (.beads/)"]
        BD["issues.jsonl"]
    end

    subgraph Config["Config"]
        CFG["capabilities.json<br/>plan.json | code.json"]
    end

    UA1 --> ENG_SETUP
    UA2 --> ENG_MODE
    UA3 -.-> ENG_BEADS
    UA4 -.-> ENG_BEADS
    UA5 --> ENG_BEADS
    UA6 --> ENG_BEADS
    UA9 --> ENG_STATUS

    ENG_SETUP --> CFG
    ENG_MODE --> CFG
    ENG_STATUS --> ST
    ENG_BEADS --> BD

    AA0 --> ST
    AA1 --> ST
    AA2 --> ST
    AA4 --> ST

    style UserActions fill:#E3F2FD,stroke:#1565C0
    style AutoActions fill:#E8F5E9,stroke:#2E7D32
    style Engine fill:#FFF3E0,stroke:#F57C00
    style State fill:#F3E5F5,stroke:#6A1B9A
    style Beads fill:#E0F7FA,stroke:#00838F
    style Config fill:#FCE4EC,stroke:#C62828
```
