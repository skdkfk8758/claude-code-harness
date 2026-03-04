---
name: cch-sp-receive-review
description: Use when receiving code review feedback, before implementing suggestions. Requires technical evaluation and verification rather than performative agreement or blind implementation.
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep, Write, Edit
argument-hint: [paste review feedback or PR URL]
---

# cch-sp-receive-review

Evaluate code review feedback technically before implementing. Verify against the codebase, push back when wrong, implement when correct — one item at a time.

## Steps

### Prerequisites
1. Find the plugin root by searching for `bin/cch` executable.
2. Run: `bash "<plugin-root>/bin/cch" sources ensure superpowers`
3. Verify superpowers source exists at `.claude/cch/sources/superpowers/`.
4. If missing, report error and stop.

### Execution

Delegates to the superpowers receiving-code-review skill. Follow it exactly:

**Response pattern:**
1. **READ** — complete feedback without reacting.
2. **UNDERSTAND** — restate the requirement in your own words, or ask.
3. **VERIFY** — check against codebase reality.
4. **EVALUATE** — is this technically sound for THIS codebase?
5. **RESPOND** — technical acknowledgment or reasoned pushback.
6. **IMPLEMENT** — one item at a time, test each.

**If any item is unclear: STOP. Ask for clarification on all unclear items before implementing any.**

### Forbidden Responses
- "You're absolutely right!" — explicit violation.
- "Great point!" / "Excellent feedback!" — performative.
- "Let me implement that now" — before verification.
- Any expression of gratitude ("Thanks for...").

### For External Reviewers
Before implementing, check:
- Is this technically correct for THIS codebase?
- Does it break existing functionality?
- Was there a reason for the current implementation?
- Does the reviewer have full context?

YAGNI check: if the reviewer suggests implementing something unused, grep for actual usage first.

### Acknowledging Correct Feedback
```
✅ "Fixed. [Brief description of what changed]"
✅ "Good catch — [specific issue]. Fixed in [location]."
✅ [Just fix it and show the code]
```

### Pushing Back
Push back when:
- Suggestion breaks existing functionality.
- Reviewer lacks full context.
- Violates YAGNI (unused feature).
- Conflicts with prior architectural decisions.

## Integration

**Pairs with:** `cch-sp-code-review` — the requesting skill dispatches the reviewer that generates the feedback.

**Source skill:** `superpowers:receiving-code-review` at `.claude/cch/sources/superpowers/skills/receiving-code-review/SKILL.md`
