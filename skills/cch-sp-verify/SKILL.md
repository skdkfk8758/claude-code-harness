---
name: cch-sp-verify
description: Use before claiming any work is complete, fixed, or passing. Run verification commands and confirm output before any success claim, commit, or PR creation.
user-invocable: true
allowed-tools: Bash, Read
argument-hint: [test command or what to verify]
---

# cch-sp-verify

Evidence before claims. Run verification commands and read their output before making any success claim.

## Steps

### Prerequisites
1. Find the plugin root by searching for `bin/cch` executable.
2. Run: `bash "<plugin-root>/bin/cch" sources ensure superpowers`
3. Verify superpowers source exists at `.claude/cch/sources/superpowers/`.
4. If missing, report error and stop.

### Execution

Delegates to the superpowers verification-before-completion skill. Follow the gate function exactly:

**IRON LAW: No completion claims without fresh verification evidence.**

For every claim, apply this gate:
1. **IDENTIFY:** What command proves this claim?
2. **RUN:** Execute the full command fresh (not a previous run).
3. **READ:** Full output, check exit code, count failures.
4. **VERIFY:** Does output confirm the claim?
   - If NO: state actual status with the evidence you have.
   - If YES: state the claim WITH the evidence.
5. **ONLY THEN:** Make the claim.

### Common Verification Patterns

| Claim | Required Evidence |
|-------|------------------|
| Tests pass | Test command output: 0 failures |
| Build succeeds | Build command: exit 0 |
| Bug fixed | Test for original symptom: passes |
| Requirements met | Line-by-line checklist against plan |
| Agent completed | VCS diff shows actual changes |

### Red Flags — Stop

- Using "should", "probably", "seems to" — these require verification.
- About to commit/push/PR without running verification commands.
- Trusting an agent's success report without independently verifying.
- Expressing satisfaction ("Done!", "Perfect!") before showing evidence.

## Integration

**Called before:** `cch-sp-finish-branch` — verify before completing development.

**Called after:** `cch-sp-debug` — verify fix worked before claiming success.

**Source skill:** `superpowers:verification-before-completion` at `.claude/cch/sources/superpowers/skills/verification-before-completion/SKILL.md`
