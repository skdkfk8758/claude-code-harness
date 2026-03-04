# Interview-to-Execution Bridge 구현 계획

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** ExitPlanMode 승인 후 plan 문서를 자동 파싱하여 execution-plan.json 생성, work item 생성, 모드 전환, 파이프라인 트리거 지시를 자동 수행하는 PostToolUse 훅을 구현한다.

**Architecture:** PostToolUse:ExitPlanMode 훅에서 `plan-bridge.mjs` Node.js 스크립트를 실행. 이 스크립트는 (1) 오늘 날짜의 plan 문서를 찾아 파싱하고, (2) `.claude/cch/execution-plan.json`에 구조화 데이터를 저장하며, (3) `bin/cch` CLI로 work item 생성/전이/모드 전환을 수행한 뒤, (4) additionalContext로 /cch-team 파이프라인 실행 지시를 주입한다.

**Tech Stack:** Node.js (ESM), `node:fs`, `node:path`, `node:child_process`, bash (`bin/cch`)

**설계 문서:** `docs/plans/2026-03-03-interview-bridge-design.md`

---

### Task 1: plan 문서 파서 테스트 작성

**Files:**
- Create: `tests/unit/plan-parser.test.mjs`

**Step 1: 테스트 파일 생성**

```javascript
#!/usr/bin/env node
/**
 * plan-parser unit tests
 * Run: node tests/unit/plan-parser.test.mjs
 */

import { strict as assert } from "node:assert";
import { parsePlanDocument } from "../../scripts/lib/plan-parser.mjs";

// --- Test fixtures ---

const FULL_PLAN = `# Plan: login-feature

> Created: 2026-03-03
> Work Item: login-feature
> Status: draft

## Goal
사용자 로그인 기능 구현

## Context
JWT 기반 인증 시스템 필요

## Approach

### Phase 1
- [ ] 로그인 API 엔드포인트 구현
- [ ] JWT 토큰 발급 로직
- [x] DB 스키마 설계

### Phase 2
- [ ] 비밀번호 해싱

## Risks
보안 취약점 주의

## Acceptance Criteria
- [ ] 로그인 성공 시 JWT 반환
- [ ] 잘못된 비밀번호 시 401 응답
- [x] DB 연결 확인

## 예상 변경 파일
- \`src/auth/login.ts\`
- \`src/middleware/jwt.ts\`

## Notes
추가 메모
`;

const EMPTY_TEMPLATE = `# Plan: general

> Created: 2026-03-03
> Work Item: general
> Status: draft

## Goal
<!-- What is the objective of this plan? -->

## Context
<!-- Current state, constraints, dependencies -->

## Approach
<!-- Step-by-step approach -->

### Phase 1
- [ ] Step 1

## Acceptance Criteria
- [ ] Criterion 1
`;

const MINIMAL_PLAN = `# Plan: quick-fix

## Goal
버그 수정

- [ ] 파일 A 수정
`;

// --- Tests ---

function testFullPlan() {
  const result = parsePlanDocument(FULL_PLAN, "2026-03-03-login-feature.md");

  assert.equal(result.work_id, "login-feature");
  assert.equal(result.goal, "사용자 로그인 기능 구현");
  assert.equal(result.tasks.length, 4);
  assert.equal(result.tasks[0].description, "로그인 API 엔드포인트 구현");
  assert.equal(result.tasks[0].done, false);
  assert.equal(result.tasks[2].description, "DB 스키마 설계");
  assert.equal(result.tasks[2].done, true);
  assert.equal(result.acceptance_criteria.length, 3);
  assert.equal(result.acceptance_criteria[0], "로그인 성공 시 JWT 반환");
  assert.deepEqual(result.changed_files, ["src/auth/login.ts", "src/middleware/jwt.ts"]);

  console.log("  PASS: testFullPlan");
}

function testEmptyTemplate() {
  const result = parsePlanDocument(EMPTY_TEMPLATE, "2026-03-03-general.md");

  assert.equal(result.work_id, "general");
  assert.equal(result.goal, "");
  assert.equal(result.is_empty_template, true);

  console.log("  PASS: testEmptyTemplate");
}

function testMinimalPlan() {
  const result = parsePlanDocument(MINIMAL_PLAN, "2026-03-03-quick-fix.md");

  assert.equal(result.work_id, "quick-fix");
  assert.equal(result.goal, "버그 수정");
  assert.equal(result.tasks.length, 1);
  assert.deepEqual(result.changed_files, []);

  console.log("  PASS: testMinimalPlan");
}

function testWorkIdExtraction() {
  // 날짜 prefix 제거
  const r1 = parsePlanDocument("## Goal\ntest", "2026-03-03-my-feature.md");
  assert.equal(r1.work_id, "my-feature");

  // 날짜 prefix 없으면 확장자만 제거
  const r2 = parsePlanDocument("## Goal\ntest", "some-plan.md");
  assert.equal(r2.work_id, "some-plan");

  // 복합 slug
  const r3 = parsePlanDocument("## Goal\ntest", "2026-03-03-w-p0-core-stability.md");
  assert.equal(r3.work_id, "w-p0-core-stability");

  console.log("  PASS: testWorkIdExtraction");
}

// --- Run ---
console.log("plan-parser tests:");
testFullPlan();
testEmptyTemplate();
testMinimalPlan();
testWorkIdExtraction();
console.log("All plan-parser tests passed.");
```

**Step 2: 테스트 실행 — 실패 확인**

Run: `node tests/unit/plan-parser.test.mjs`
Expected: FAIL — `Cannot find module '../../scripts/lib/plan-parser.mjs'`

**Step 3: 커밋**

```bash
git add tests/unit/plan-parser.test.mjs
git commit -m "test: add plan-parser unit tests (red phase)"
```

---

### Task 2: plan-parser.mjs 구현

**Files:**
- Create: `scripts/lib/plan-parser.mjs`

**Step 1: 파서 모듈 구현**

```javascript
#!/usr/bin/env node
/**
 * Plan Document Parser
 * Extracts structured data from CCH plan Markdown documents.
 *
 * Exported: parsePlanDocument(markdownContent, filename) → object
 */

/**
 * Extract work_id from plan filename.
 * "2026-03-03-login-feature.md" → "login-feature"
 * "some-plan.md" → "some-plan"
 */
function extractWorkId(filename) {
  const base = filename.replace(/\.md$/i, "");
  // Remove YYYY-MM-DD- prefix if present
  const stripped = base.replace(/^\d{4}-\d{2}-\d{2}-/, "");
  return stripped || base;
}

/**
 * Extract content of a specific ## section.
 * Returns text between the heading and the next ## heading (or EOF).
 */
function extractSection(content, heading) {
  // Match ## Goal, ## Acceptance Criteria, etc. (case-insensitive)
  const pattern = new RegExp(
    `^##\\s+${heading}\\s*$([\\s\\S]*?)(?=^##\\s|$(?!\\s))`,
    "mi"
  );
  const match = content.match(pattern);
  if (!match) return "";
  return match[1].trim();
}

/**
 * Extract all checkbox items from content.
 * Returns: [{ description, done }]
 */
function extractCheckboxes(content) {
  const items = [];
  const re = /^[-*]\s+\[([ xX])\]\s+(.+)$/gm;
  let m;
  while ((m = re.exec(content)) !== null) {
    const text = m[2].trim();
    // Skip template placeholders
    if (/^(Step|Criterion)\s+\d+$/i.test(text)) continue;
    items.push({
      description: text,
      done: m[1] !== " ",
    });
  }
  return items;
}

/**
 * Extract backtick-wrapped file paths from a section.
 * "`src/auth/login.ts`" → "src/auth/login.ts"
 */
function extractFilePaths(sectionContent) {
  const paths = [];
  const re = /`([^`]+\.[a-zA-Z]{1,10})`/g;
  let m;
  while ((m = re.exec(sectionContent)) !== null) {
    paths.push(m[1]);
  }
  return paths;
}

/**
 * Detect if the plan is still an empty template.
 * Checks if Goal section is empty or contains only HTML comments.
 */
function isEmptyTemplate(goalText) {
  if (!goalText) return true;
  const stripped = goalText.replace(/<!--[\s\S]*?-->/g, "").trim();
  return stripped.length === 0;
}

/**
 * Parse a plan Markdown document into structured data.
 *
 * @param {string} content - Markdown content
 * @param {string} filename - Plan filename (e.g., "2026-03-03-login-feature.md")
 * @returns {object} Parsed plan data
 */
export function parsePlanDocument(content, filename) {
  const work_id = extractWorkId(filename);

  // Extract Goal — first non-empty, non-comment line in the section
  const goalSection = extractSection(content, "Goal");
  const goalStripped = goalSection.replace(/<!--[\s\S]*?-->/g, "").trim();
  const goal = goalStripped.split(/\r?\n/)[0]?.trim() || "";

  // Detect empty template
  const is_empty_template = isEmptyTemplate(goalSection);

  // Extract all tasks (checkboxes from Approach/Phase sections, or global)
  const tasks = extractCheckboxes(content);

  // Extract acceptance criteria
  const criteriaSection = extractSection(content, "Acceptance Criteria");
  const criteriaItems = criteriaSection
    ? extractCheckboxes(criteriaSection).map((c) => c.description)
    : [];
  // Fallback: if criteria section has plain list items (no checkboxes)
  if (criteriaItems.length === 0 && criteriaSection) {
    const lines = criteriaSection.split(/\r?\n/);
    for (const line of lines) {
      const m = line.match(/^[-*]\s+(.+)$/);
      if (m) criteriaItems.push(m[1].trim());
    }
  }

  // Extract changed files
  const filesSection =
    extractSection(content, "예상 변경 파일") ||
    extractSection(content, "Changed Files") ||
    extractSection(content, "Files");
  const changed_files = filesSection ? extractFilePaths(filesSection) : [];

  return {
    work_id,
    goal,
    is_empty_template,
    tasks,
    acceptance_criteria: criteriaItems,
    changed_files,
  };
}
```

**Step 2: 테스트 실행 — 통과 확인**

Run: `node tests/unit/plan-parser.test.mjs`
Expected: ALL PASS

**Step 3: 커밋**

```bash
git add scripts/lib/plan-parser.mjs
git commit -m "feat: implement plan document parser (green phase)"
```

---

### Task 3: plan-bridge.mjs 테스트 작성

**Files:**
- Create: `tests/unit/plan-bridge.test.mjs`

**Step 1: 브릿지 출력 로직 테스트 작성**

```javascript
#!/usr/bin/env node
/**
 * plan-bridge output logic tests
 * Tests the buildBridgeOutput function that creates the hook response.
 * Run: node tests/unit/plan-bridge.test.mjs
 */

import { strict as assert } from "node:assert";
import { buildBridgeOutput } from "../../scripts/lib/bridge-output.mjs";

function testSuccessOutput() {
  const plan = {
    work_id: "login-feature",
    goal: "로그인 기능 구현",
    plan_file: "docs/plans/2026-03-03-login-feature.md",
    tasks: [
      { id: 1, description: "API 구현", done: false },
      { id: 2, description: "테스트 작성", done: false },
    ],
    acceptance_criteria: ["JWT 반환", "401 응답"],
    is_empty_template: false,
  };

  const result = buildBridgeOutput(plan, { success: true });

  assert.equal(result.continue, true);
  const ctx = result.hookSpecificOutput.additionalContext;
  assert.ok(ctx.includes("[CCH BRIDGE ACTIVATED]"));
  assert.ok(ctx.includes("login-feature"));
  assert.ok(ctx.includes("로그인 기능 구현"));
  assert.ok(ctx.includes("/cch-team"));
  assert.ok(ctx.includes("작업 수: 2개"));
  assert.ok(ctx.includes("완료 기준: 2개"));

  console.log("  PASS: testSuccessOutput");
}

function testEmptyTemplateWarning() {
  const plan = {
    work_id: "general",
    goal: "",
    plan_file: "docs/plans/2026-03-03-general.md",
    tasks: [],
    acceptance_criteria: [],
    is_empty_template: true,
  };

  const result = buildBridgeOutput(plan, { success: false, reason: "empty_template" });

  assert.equal(result.continue, true);
  const ctx = result.hookSpecificOutput.additionalContext;
  assert.ok(ctx.includes("[CCH BRIDGE WARNING]"));
  assert.ok(!ctx.includes("/cch-team"));

  console.log("  PASS: testEmptyTemplateWarning");
}

function testNoPlanWarning() {
  const result = buildBridgeOutput(null, { success: false, reason: "no_plan_found" });

  assert.equal(result.continue, true);
  const ctx = result.hookSpecificOutput.additionalContext;
  assert.ok(ctx.includes("[CCH BRIDGE WARNING]"));

  console.log("  PASS: testNoPlanWarning");
}

console.log("bridge-output tests:");
testSuccessOutput();
testEmptyTemplateWarning();
testNoPlanWarning();
console.log("All bridge-output tests passed.");
```

**Step 2: 테스트 실행 — 실패 확인**

Run: `node tests/unit/plan-bridge.test.mjs`
Expected: FAIL — `Cannot find module '../../scripts/lib/bridge-output.mjs'`

**Step 3: 커밋**

```bash
git add tests/unit/plan-bridge.test.mjs
git commit -m "test: add bridge-output unit tests (red phase)"
```

---

### Task 4: bridge-output.mjs 구현

**Files:**
- Create: `scripts/lib/bridge-output.mjs`

**Step 1: 출력 빌더 구현**

```javascript
/**
 * Bridge Output Builder
 * Constructs the hook JSON response for plan-bridge.mjs
 */

/**
 * Build the hook output JSON for a successful bridge activation.
 *
 * @param {object|null} plan - Parsed plan data (null if no plan found)
 * @param {object} status - { success: boolean, reason?: string }
 * @returns {object} Hook response JSON
 */
export function buildBridgeOutput(plan, status) {
  const base = {
    continue: true,
    hookSpecificOutput: {
      additionalContext: "",
    },
  };

  if (!status.success) {
    let warning = "[CCH BRIDGE WARNING]\n\n";

    if (status.reason === "no_plan_found") {
      warning += "오늘 날짜의 plan 문서를 찾을 수 없습니다.\n";
      warning += "docs/plans/ 디렉토리에 plan 문서를 먼저 작성하세요.";
    } else if (status.reason === "empty_template") {
      warning += "plan 문서가 빈 템플릿 상태입니다.\n";
      warning += `파일: ${plan?.plan_file || "unknown"}\n`;
      warning += "## Goal 섹션과 체크박스 항목을 작성한 후 다시 시도하세요.";
    } else if (status.reason === "no_tasks") {
      warning += "plan 문서에 체크박스 항목(- [ ] ...)이 없습니다.\n";
      warning += `파일: ${plan?.plan_file || "unknown"}\n`;
      warning += "실행할 작업 항목을 추가한 후 다시 시도하세요.";
    } else {
      warning += `예상하지 못한 문제: ${status.reason || "unknown"}`;
    }

    base.hookSpecificOutput.additionalContext = warning;
    return base;
  }

  // Success — build activation context
  const lines = [
    "[CCH BRIDGE ACTIVATED]",
    "",
    "인터뷰 결과가 자동 처리되었습니다:",
    `- 실행 계획: .claude/cch/execution-plan.json`,
    `- 작업 항목: ${plan.work_id} (status: doing)`,
    "- 모드: code",
    "",
    "지금 즉시 /cch-team 파이프라인을 시작하세요.",
    `작업 ID: ${plan.work_id}`,
    `계획 문서: ${plan.plan_file}`,
    "",
    "실행 계획 요약:",
    `- 목표: ${plan.goal}`,
    `- 작업 수: ${plan.tasks.length}개`,
    `- 완료 기준: ${plan.acceptance_criteria.length}개`,
  ];

  base.hookSpecificOutput.additionalContext = lines.join("\n");
  return base;
}
```

**Step 2: 테스트 실행 — 통과 확인**

Run: `node tests/unit/plan-bridge.test.mjs`
Expected: ALL PASS

**Step 3: 커밋**

```bash
git add scripts/lib/bridge-output.mjs
git commit -m "feat: implement bridge output builder (green phase)"
```

---

### Task 5: plan-bridge.mjs 메인 스크립트 구현

**Files:**
- Create: `scripts/plan-bridge.mjs`

**Step 1: 메인 스크립트 구현**

```javascript
#!/usr/bin/env node
/**
 * CCH Plan Bridge - PostToolUse:ExitPlanMode Hook
 *
 * Automatically bridges the interview/plan phase to execution:
 * 1. Finds today's plan document in docs/plans/
 * 2. Parses it into structured data
 * 3. Saves execution-plan.json
 * 4. Creates work item + transitions to doing
 * 5. Switches mode to code
 * 6. Injects pipeline trigger via additionalContext
 */

import { readFileSync, writeFileSync, readdirSync, statSync, mkdirSync } from "node:fs";
import { join, basename } from "node:path";
import { execSync } from "node:child_process";
import { parsePlanDocument } from "./lib/plan-parser.mjs";
import { buildBridgeOutput } from "./lib/bridge-output.mjs";

const CCH_ROOT = process.env.CLAUDE_PLUGIN_ROOT || join(process.cwd());
const CCH_STATE_DIR = join(process.cwd(), ".claude", "cch");
const PLANS_DIR = join(process.cwd(), "docs", "plans");
const EXEC_PLAN_FILE = join(CCH_STATE_DIR, "execution-plan.json");
const CMD_TIMEOUT = 2000; // 2s per shell command

/**
 * Find the most recently modified plan document for today.
 * Pattern: docs/plans/${today}-*.md
 */
function findTodayPlan() {
  const today = new Date().toISOString().slice(0, 10); // YYYY-MM-DD

  let files;
  try {
    files = readdirSync(PLANS_DIR);
  } catch {
    return null;
  }

  const candidates = files
    .filter((f) => f.startsWith(today) && f.endsWith(".md"))
    .map((f) => ({
      name: f,
      path: join(PLANS_DIR, f),
      mtime: statSync(join(PLANS_DIR, f)).mtimeMs,
    }))
    .sort((a, b) => b.mtime - a.mtime);

  return candidates[0] || null;
}

/**
 * Run a cch CLI command, swallowing errors.
 */
function runCch(args) {
  try {
    execSync(`bash "${join(CCH_ROOT, "bin", "cch")}" ${args}`, {
      timeout: CMD_TIMEOUT,
      cwd: process.cwd(),
      stdio: "pipe",
    });
    return true;
  } catch {
    return false;
  }
}

function main() {
  try {
    // Read stdin (hook provides tool context)
    const input = JSON.parse(readFileSync(0, "utf8"));
    const toolName = input.tool_name || "";

    // Safety check — only run for ExitPlanMode
    if (toolName !== "ExitPlanMode") {
      console.log(JSON.stringify({ continue: true }));
      return;
    }

    // Step 1: Find today's plan document
    const planFile = findTodayPlan();
    if (!planFile) {
      console.log(JSON.stringify(buildBridgeOutput(null, { success: false, reason: "no_plan_found" })));
      return;
    }

    // Step 2: Parse plan document
    const content = readFileSync(planFile.path, "utf8");
    const parsed = parsePlanDocument(content, planFile.name);
    parsed.plan_file = `docs/plans/${planFile.name}`;

    // Step 3: Validate — not an empty template
    if (parsed.is_empty_template) {
      console.log(JSON.stringify(buildBridgeOutput(parsed, { success: false, reason: "empty_template" })));
      return;
    }

    // Step 4: Validate — has tasks
    if (parsed.tasks.length === 0) {
      console.log(JSON.stringify(buildBridgeOutput(parsed, { success: false, reason: "no_tasks" })));
      return;
    }

    // Step 5: Build execution plan JSON
    const execPlan = {
      version: "1",
      created_at: new Date().toISOString(),
      work_id: parsed.work_id,
      plan_file: parsed.plan_file,
      status: "ready",
      goal: parsed.goal,
      tasks: parsed.tasks.map((t, i) => ({ id: i + 1, ...t })),
      acceptance_criteria: parsed.acceptance_criteria,
      changed_files: parsed.changed_files,
      pipeline: "cch-team",
      mode: "code",
    };

    // Step 6: Save execution-plan.json
    mkdirSync(CCH_STATE_DIR, { recursive: true });
    writeFileSync(EXEC_PLAN_FILE, JSON.stringify(execPlan, null, 2), "utf8");

    // Step 7: Create work item + transition (ignore if already exists)
    runCch(`work create "${parsed.work_id}" "${parsed.goal}"`);
    runCch(`work transition "${parsed.work_id}" doing`);

    // Step 8: Switch mode to code
    runCch("mode code");

    // Step 9: Output additionalContext with pipeline trigger
    console.log(JSON.stringify(buildBridgeOutput(parsed, { success: true })));
  } catch {
    // Never block tool execution
    console.log(JSON.stringify({ continue: true }));
  }
}

main();
```

**Step 2: 수동 테스트 — 스크립트가 올바른 JSON을 출력하는지 확인**

Run: `echo '{"tool_name":"ExitPlanMode"}' | node scripts/plan-bridge.mjs`
Expected: `{"continue":true,"hookSpecificOutput":{"additionalContext":"[CCH BRIDGE ..."}}` 형태의 JSON 출력 (plan 문서 유무에 따라 ACTIVATED 또는 WARNING)

**Step 3: 커밋**

```bash
git add scripts/plan-bridge.mjs
git commit -m "feat: implement plan-bridge hook script"
```

---

### Task 6: hooks.json에 PostToolUse 엔트리 추가

**Files:**
- Modify: `hooks/hooks.json:64-75` (PostToolUse 배열)

**Step 1: hooks.json 수정**

기존 PostToolUse 배열에 ExitPlanMode 엔트리를 추가한다.

변경 전 (64-75줄):
```json
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/scripts/todo-sync-check.sh\"",
            "timeout": 5
          }
        ]
      }
    ]
```

변경 후:
```json
    "PostToolUse": [
      {
        "matcher": "ExitPlanMode",
        "hooks": [
          {
            "type": "command",
            "command": "node \"${CLAUDE_PLUGIN_ROOT}/scripts/plan-bridge.mjs\"",
            "timeout": 5
          }
        ]
      },
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "bash \"${CLAUDE_PLUGIN_ROOT}/scripts/todo-sync-check.sh\"",
            "timeout": 5
          }
        ]
      }
    ]
```

**Step 2: JSON 유효성 검증**

Run: `node -e "JSON.parse(require('fs').readFileSync('hooks/hooks.json','utf8')); console.log('Valid JSON')"`
Expected: `Valid JSON`

**Step 3: 커밋**

```bash
git add hooks/hooks.json
git commit -m "feat: register plan-bridge as PostToolUse:ExitPlanMode hook"
```

---

### Task 7: 통합 테스트 작성 및 실행

**Files:**
- Create: `tests/integration/plan-bridge-e2e.test.mjs`

**Step 1: 통합 테스트 작성**

```javascript
#!/usr/bin/env node
/**
 * Plan Bridge Integration Test
 *
 * Simulates the full ExitPlanMode → plan-bridge.mjs flow:
 * 1. Creates a temporary plan document
 * 2. Pipes ExitPlanMode input to plan-bridge.mjs
 * 3. Verifies execution-plan.json was created
 * 4. Verifies the output JSON has correct additionalContext
 *
 * Run: node tests/integration/plan-bridge-e2e.test.mjs
 */

import { strict as assert } from "node:assert";
import { mkdirSync, writeFileSync, readFileSync, rmSync, existsSync } from "node:fs";
import { join } from "node:path";
import { execSync } from "node:child_process";

const CWD = process.cwd();
const PLANS_DIR = join(CWD, "docs", "plans");
const STATE_DIR = join(CWD, ".claude", "cch");
const EXEC_PLAN_FILE = join(STATE_DIR, "execution-plan.json");

const today = new Date().toISOString().slice(0, 10);
const TEST_PLAN_FILE = join(PLANS_DIR, `${today}-bridge-test.md`);

// --- Setup ---
function setup() {
  mkdirSync(PLANS_DIR, { recursive: true });
  writeFileSync(
    TEST_PLAN_FILE,
    `# Plan: bridge-test

> Created: ${today}

## Goal
통합 테스트용 브릿지 검증

## Approach
- [ ] 첫 번째 작업
- [ ] 두 번째 작업

## Acceptance Criteria
- [ ] 브릿지가 정상 동작
`,
    "utf8"
  );

  // Clean previous execution plan
  if (existsSync(EXEC_PLAN_FILE)) {
    rmSync(EXEC_PLAN_FILE);
  }
}

// --- Teardown ---
function teardown() {
  if (existsSync(TEST_PLAN_FILE)) rmSync(TEST_PLAN_FILE);
  if (existsSync(EXEC_PLAN_FILE)) rmSync(EXEC_PLAN_FILE);
  // Clean test work item
  const workDir = join(STATE_DIR, "work-items", "bridge-test");
  if (existsSync(workDir)) rmSync(workDir, { recursive: true });
}

// --- Test ---
function testBridgeFlow() {
  setup();

  try {
    const input = JSON.stringify({ tool_name: "ExitPlanMode" });
    const output = execSync(
      `echo '${input}' | node scripts/plan-bridge.mjs`,
      { cwd: CWD, timeout: 10000, encoding: "utf8" }
    );

    const result = JSON.parse(output.trim());

    // 1. continue is true
    assert.equal(result.continue, true, "continue should be true");

    // 2. additionalContext contains activation marker
    const ctx = result.hookSpecificOutput?.additionalContext || "";
    assert.ok(ctx.includes("[CCH BRIDGE ACTIVATED]"), "should contain ACTIVATED marker");
    assert.ok(ctx.includes("bridge-test"), "should contain work_id");
    assert.ok(ctx.includes("/cch-team"), "should contain pipeline trigger");

    // 3. execution-plan.json was created
    assert.ok(existsSync(EXEC_PLAN_FILE), "execution-plan.json should exist");

    const execPlan = JSON.parse(readFileSync(EXEC_PLAN_FILE, "utf8"));
    assert.equal(execPlan.version, "1");
    assert.equal(execPlan.work_id, "bridge-test");
    assert.equal(execPlan.goal, "통합 테스트용 브릿지 검증");
    assert.equal(execPlan.tasks.length, 2);
    assert.equal(execPlan.pipeline, "cch-team");
    assert.equal(execPlan.status, "ready");

    console.log("  PASS: testBridgeFlow");
  } finally {
    teardown();
  }
}

function testNonExitPlanMode() {
  const input = JSON.stringify({ tool_name: "Write" });
  const output = execSync(
    `echo '${input}' | node scripts/plan-bridge.mjs`,
    { cwd: CWD, timeout: 5000, encoding: "utf8" }
  );

  const result = JSON.parse(output.trim());
  assert.equal(result.continue, true);
  assert.ok(!result.hookSpecificOutput, "should not have hookSpecificOutput for non-ExitPlanMode");

  console.log("  PASS: testNonExitPlanMode");
}

console.log("plan-bridge integration tests:");
testBridgeFlow();
testNonExitPlanMode();
console.log("All plan-bridge integration tests passed.");
```

**Step 2: 통합 테스트 실행**

Run: `node tests/integration/plan-bridge-e2e.test.mjs`
Expected: ALL PASS

**Step 3: 커밋**

```bash
git add tests/integration/plan-bridge-e2e.test.mjs
git commit -m "test: add plan-bridge integration tests"
```

---

### Task 8: 전체 테스트 스위트 실행 및 최종 검증

**Files:**
- 변경 없음 (검증만)

**Step 1: 유닛 테스트 전체 실행**

Run: `node tests/unit/plan-parser.test.mjs && node tests/unit/plan-bridge.test.mjs`
Expected: ALL PASS

**Step 2: 통합 테스트 실행**

Run: `node tests/integration/plan-bridge-e2e.test.mjs`
Expected: ALL PASS

**Step 3: hooks.json 유효성 재확인**

Run: `node -e "JSON.parse(require('fs').readFileSync('hooks/hooks.json','utf8')); console.log('Valid JSON')"`
Expected: `Valid JSON`

**Step 4: 최종 커밋**

```bash
git add -A
git commit -m "feat: complete interview-to-execution bridge implementation

PostToolUse:ExitPlanMode hook auto-bridges plan phase to execution:
- Parses plan documents into structured execution-plan.json
- Auto-creates work items and transitions to doing
- Switches mode to code
- Injects /cch-team pipeline trigger via additionalContext

Resolves: agent stalling after interview completion"
```

---

## 파일 요약

| 구분 | 경로 | 설명 |
|------|------|------|
| 신규 | `scripts/plan-bridge.mjs` | PostToolUse 훅 메인 스크립트 |
| 신규 | `scripts/lib/plan-parser.mjs` | plan 문서 Markdown 파서 |
| 신규 | `scripts/lib/bridge-output.mjs` | 훅 응답 JSON 빌더 |
| 수정 | `hooks/hooks.json` | PostToolUse:ExitPlanMode 엔트리 추가 |
| 신규 | `tests/unit/plan-parser.test.mjs` | 파서 유닛 테스트 |
| 신규 | `tests/unit/plan-bridge.test.mjs` | 출력 빌더 유닛 테스트 |
| 신규 | `tests/integration/plan-bridge-e2e.test.mjs` | 통합 테스트 |
| 자동생성 | `.claude/cch/execution-plan.json` | 실행 시 생성되는 구조화 데이터 |
