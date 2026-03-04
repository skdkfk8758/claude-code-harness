---
name: cch-gp-skill-builder
description: Build Claude Code skills via 4-persona interview. 5 step types (Prompt/Script/API/MCP/RAG).
user-invocable: true
allowed-tools: Agent, Bash, Read, Glob, Grep, Write, AskUserQuestion
argument-hint: <skill idea or description>
---

# cch-gp-skill-builder

Build Claude Code skills via a structured 4-persona interview process. Supports 5 step types: Prompt, Script, API, MCP, and RAG.

## Steps

### Prerequisites
1. Find the plugin root by searching for `bin/cch` executable.
2. Run: `bash "<plugin-root>/bin/cch" sources ensure gptaku_plugins`
3. Run: `bash "<plugin-root>/bin/cch" sources init-submodule gptaku_plugins plugins/skillers-suda`
4. If either command fails, report the error and stop.

### Execution
1. Read skillers-suda interview protocol from the submodule.
2. **PM Interview**: Ask user about the skill's purpose, target users, and success criteria via AskUserQuestion.
3. **Architect Interview**: Ask about technical approach — which of the 5 types (Prompt/Script/API/MCP/RAG) and tool requirements.
4. **Developer Interview**: Ask about implementation details — edge cases, error handling, integration points.
5. **QA Interview**: Ask about testing criteria, expected inputs/outputs, failure modes.
6. **Spec Generation**: Compile interview data into a skill specification.
7. **SKILL.md Generation**: Generate the SKILL.md file with proper YAML frontmatter (name, description, allowed-tools, argument-hint) and step-by-step instructions.
8. **Validation**: Verify the generated skill follows CCH patterns (frontmatter fields, prerequisites section, step numbering).
9. Save to `skills/<new-skill-name>/SKILL.md` and suggest running `/cch-sync`.
