---
name: cch-setup
description: Initialize Claude Code Harness environment. Checks paths, permissions, creates state directory, and validates capability sources.
user-invocable: true
allowed-tools: Bash, Read, Glob
---

# CCH Setup

Initialize the Claude Code Harness environment.

## Steps

1. Find the plugin root by searching for the `bin/cch` executable:
   - Use Glob for `**/bin/cch` or check known paths
   - The plugin root is the parent directory of `bin/`

2. Run setup:
```bash
bash "<plugin-root>/bin/cch" setup
```

3. Report results to the user. If setup fails, explain which checks failed.

4. Verify vendor readiness:
   - **Superpowers**: Run `bash "<plugin-root>/bin/cch" sources check superpowers` — if not installed, advise: `claude plugin install superpowers@superpowers-marketplace`
   - **GPTaku**: Check submodule status with `ls "<plugin-root>/.claude/cch/sources/gptaku_plugins/plugins/"` — if directories are empty, run `bash "<plugin-root>/bin/cch" sources init-submodule gptaku_plugins plugins/<name>` for each.
   - **Ruflo**: Check CLI availability with `test -f "<plugin-root>/.claude/cch/sources/ruflo/bin/cli.js"` — report if node_modules is missing.
   - Report summary: installed sources, initialized submodules, synced skill count.

5. On success, suggest running `/cch-mode` to select a working mode.

6. Check architecture level:
```bash
bash "<plugin-root>/bin/cch" arch level
```
   - If not set, suggest: "아키텍처 레벨이 설정되지 않았습니다. `/cch-arch-guide`를 실행하여 프로젝트에 맞는 아키텍처 레벨을 설정하세요."
