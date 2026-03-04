---
name: cch-rf-security
description: Security scanning and CVE remediation.
user-invocable: true
allowed-tools: Agent, Bash, Read, Glob, Grep, Write
argument-hint: <scan|audit|report> [--target path]
---

# cch-rf-security

Security scanning and CVE remediation: scan, audit, and report actions.

## Steps

### Prerequisites
1. Find the plugin root by searching for `bin/cch` executable.
2. Run: `bash "<plugin-root>/bin/cch" sources ensure ruflo`
3. Set: `RUFLO_CLI="$(sources_resolve_path ruflo)/bin/cli.js"` — or resolve manually: `RUFLO_CLI="$(pwd)/.claude/cch/sources/ruflo/bin/cli.js"`
4. Verify: `test -f "$RUFLO_CLI"` — if missing, report error and stop.

### Execution

1. Parse action (scan/audit/report) and optional target path (default: current directory).

2. **scan** action:
   - Run: `node "$RUFLO_CLI" security scan --target "<path>"`
   - Use Agent(security-reviewer) for deep analysis of flagged files.
   - Report: vulnerabilities found, severity levels (critical/high/medium/low), affected files.

3. **audit** action:
   - Run: `node "$RUFLO_CLI" security audit --target "<path>"`
   - Check dependency vulnerabilities (if package.json/requirements.txt exist).
   - Use Grep to scan for common security anti-patterns:
     - Hardcoded secrets/API keys
     - SQL injection vectors
     - XSS vulnerabilities
     - Insecure crypto usage
   - Generate detailed audit report.

4. **report** action:
   - Compile results from scan and audit into a comprehensive security report.
   - Write to `docs/security/<date>-security-report.md`.
   - Include: executive summary, vulnerability inventory, remediation priority list, CVE references where applicable.
