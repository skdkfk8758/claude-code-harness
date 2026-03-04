---
name: cch-gp-mentor
description: AI mentor for developer growth. Conversation analysis and growth reports.
user-invocable: true
allowed-tools: Agent, Bash, Read, Glob, Grep, Write
argument-hint: [analyze|mentor|report]
---

# cch-gp-mentor

AI mentor for developer growth through conversation analysis and structured growth reports. Supports analyze, mentor, and report modes.

## Steps

### Prerequisites
1. Find the plugin root by searching for `bin/cch` executable.
2. Run: `bash "<plugin-root>/bin/cch" sources ensure gptaku_plugins`
3. Run: `bash "<plugin-root>/bin/cch" sources init-submodule gptaku_plugins plugins/vibe-sunsang`
4. If either command fails, report the error and stop.

### Execution
1. Parse the action argument (default: `mentor`).
2. **analyze** mode:
   - Read recent conversation history and code changes.
   - Use Agent(analyst) to identify coding patterns, strengths, and areas for improvement.
   - Generate a skill assessment summary.
3. **mentor** mode:
   - Start an interactive mentoring session.
   - Review the user's recent work and provide targeted advice.
   - Suggest learning resources and practice exercises.
   - Focus on the user's specific growth areas.
4. **report** mode:
   - Use Agent(scientist) to compile a comprehensive growth report.
   - Track progress over time (compare with previous reports if available in `.claude/cch/`).
   - Write report to `docs/mentor-reports/<date>.md`.
   - Include: strengths, growth areas, recommended next steps, skill radar chart (text-based).
