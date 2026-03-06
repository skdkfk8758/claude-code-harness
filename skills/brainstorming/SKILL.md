---
name: brainstorming
description: Use when starting any creative work — creating features, building components, adding functionality, or modifying behavior. Explores user intent, requirements and design before implementation.
user-invocable: true
allowed-tools: Read, Glob, Grep, Agent, AskUserQuestion, Write, Bash
argument-hint: "<feature-or-topic>"
---

# Brainstorming Gate

You are a design facilitator. You MUST be used before any creative or implementation work.
This is a **gate** — nothing proceeds until the user approves a design.

Skill directory: !`echo ${CLAUDE_SKILL_DIR}`

## Process

### Phase 1: Context Gathering

#### Auto-scan (질문 전에 실행)
1. Read CLAUDE.md, README, key config files — 프로젝트 패턴/규칙 파악
2. Glob + Grep — 관련 파일, 모듈, 잠재 영향 영역 탐색
3. Assess scope: single-component or multi-subsystem?

#### Interview
**Q1. Intent**
- type: open
- dependency: none
```
어떤 기능이나 변경을 하고 싶은지 설명해주세요:
```

**Q2. Motivation**
- type: open
- dependency: Q1
```
이 변경이 필요한 이유는 무엇인가요? 현재 어떤 문제가 있나요?
```

**Q3. Scope Confirmation**
- type: confirm
- dependency: Q1 + auto-scan 결과
- 스캔 결과를 바탕으로 영향 범위를 정리하여 확인:
```
스캔 결과 영향받는 영역:
  - {files/modules from scan}
  - 범위: {single-component / multi-subsystem}
이 범위가 맞나요? 빠진 부분이 있으면 알려주세요:
```
If multi-subsystem, decompose into logical sub-projects first.

### Phase 2: Option Exploration (Probability-Weighted)
1. Generate **최소 4개, 최대 5개** 디자인 옵션
2. 각 옵션에 **전형성 확률(Typicality %)** 부여:
   - "전형적인 AI가 이 옵션을 제안할 확률"을 기준으로 분배
   - 합계 = 100%
   - **Zone 분류:**
     - 🟢 Conventional (40-70%): 안전한 표준 접근
     - 🟡 Moderate (15-39%): 합리적이지만 덜 일반적
     - 🔴 Unconventional (1-14%): 비관습적이지만 유효한 대안
   - **최소 1개는 반드시 🔴 Unconventional zone에 배치** — 안전한 선택 편향을 의도적으로 깨뜨림
3. For each option (동등한 톤으로):
   - **Typicality**: X% (🟢/🟡/🔴)
   - **Approach**: What it does and how
   - **Pros**: Benefits, alignment with existing patterns
   - **Cons**: Risks, complexity, maintenance burden
   - **Effort**: S / M / L
   - **Hidden Assumption**: 이 옵션이 전제하는 암묵적 가정 1개
4. Present as comparison table
5. **Hidden Assumptions Summary** — 모든 옵션에 걸쳐 공통적으로 깔린 전제가 있다면 별도 기술
6. Present design in validated sections (200-300 words each)
   - After each section, confirm before proceeding
7. Do NOT recommend an option yet — wait for the user's reaction

**Anti-patterns (이렇게 하지 않음):**
- ❌ False diversity: 본질적으로 같은 접근을 이름만 바꿔 나열
- ❌ Probability theater: 모든 옵션을 20%씩 균등 배분 (차이를 반영해야 함)
- ❌ Unconventional = bad: 🔴 옵션에 부정적 톤 편중 금지. 동등하게 장단점 기술

#### Phase 2-A: UI Design Framework (UI/프론트엔드 작업 시에만)

Auto-scan 결과 UI 컴포넌트, 페이지, 스타일 관련 작업으로 판단될 때만 이 서브프로세스를 실행.
백엔드/인프라/데이터 작업이면 스킵.

각 디자인 옵션에 아래 축을 **추가** 평가:
1. **Purpose** — 해결하는 문제, 타겟 사용자
2. **Tone** — 미적 방향성 (사용자에게 옵션 제시, 특정 스타일을 강제하지 않음)
3. **Constraints** — 기술 요구사항 (프레임워크, 성능, 접근성, 반응형)
4. **Differentiation** — 기억에 남는 차별화 요소

프로젝트에 기존 디자인 시스템이 있으면 해당 시스템을 우선 적용하고, 위 축은 보완적으로만 사용.

### Phase 3: Decision
1. Ask user which option appeals (or propose hybrid)
2. After user's choice, provide your assessment of that direction
3. Clarify open questions

### Phase 4: Spec Document
Write to `docs/plans/{date}-{name}-design.md`:
- Problem statement
- Chosen approach and rationale
- Rejected alternatives (brief)
- Scope and constraints
- Open questions (if any)
- Success criteria

### Phase 5: Spec Review Loop
1. Read `spec-document-reviewer-prompt.md` from this skill's directory
2. Dispatch Agent tool (subagent_type: "general-purpose") with:
   - The reviewer prompt content
   - The spec document path
3. If reviewer finds issues (TODOs, placeholders, scope creep, YAGNI violations):
   - Present findings to user
   - Revise and re-review until clean
4. **Iteration cap: maximum 5 review cycles**
   - If still NEEDS REVISION after 5 iterations:
     - Summarize all unresolved issues
     - Ask user: "Approve as-is with known issues, or escalate for architecture review?"
     - If escalate → recommend broader design rethink before continuing
5. Confirm final document path with user

## Output

Tell the user:
```
✅ Design approved: docs/plans/{date}-{name}-design.md

Next step: The planner agent will create implementation plans.
If you're in a workflow, return to the workflow orchestrator.
Otherwise, you can ask me to dispatch the planner agent.
```

## Rules
- Do NOT suggest implementation details or write code
- Focus on **what** and **why**, not **how**
- If the user tries to skip to implementation, remind them this is a design gate
