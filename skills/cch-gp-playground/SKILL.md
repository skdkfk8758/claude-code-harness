---
name: cch-gp-playground
description: GPTaku 테스트 플레이그라운드 — 스킬/플러그인 프로토타이핑 및 실험 환경
user-invocable: true
allowed-tools: Bash, Read, Write, Glob, Grep
argument-hint: 테스트할 플러그인 이름 또는 실험 설명
---

# cch-gp-playground

GPTaku 테스트 플레이그라운드 — 스킬 및 플러그인 프로토타이핑을 위한 대화형 실험 환경. 새로운 플러그인 아이디어를 빠르게 검증하고 기존 플러그인 동작을 탐색할 수 있습니다.

## Steps

### Prerequisites
1. Find the plugin root by searching for `bin/cch` executable.
2. Run: `bash "<plugin-root>/bin/cch" sources ensure gptaku_plugins`
3. Run: `bash "<plugin-root>/bin/cch" sources init-submodule gptaku_plugins plugins/test-playground`
4. If either command fails, report the error and stop.

### Execution
1. **Load plugin contents**: Read the test-playground submodule directory to discover available experiment scripts, fixtures, and README documentation.
2. **Parse the user argument**:
   - If a plugin name is given, locate matching files or directories under `plugins/test-playground/` and load their contents.
   - If an experiment description is given, scan for relevant fixtures or templates using Grep.
   - If no argument is given, list all available experiments and prompt the user to choose one.
3. **Run the sandbox**:
   - Display the selected plugin or experiment context to the user.
   - Allow the user to modify inputs, parameters, or plugin code interactively within the session.
   - Use Write to persist any prototype changes to a local scratch area under `.claude/cch/playground/<experiment-name>/`.
4. **Report results**: Summarize what was tested, what worked, and suggest next steps or follow-up experiments.
