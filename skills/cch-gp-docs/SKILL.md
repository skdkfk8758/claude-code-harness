---
name: cch-gp-docs
description: Fetch documentation for 68+ libraries using llms.txt pattern.
user-invocable: true
allowed-tools: Bash, Read, Glob, WebFetch
argument-hint: <library name or question>
---

# cch-gp-docs

Fetch documentation for 68+ libraries using the llms.txt pattern. Matches queries to a library registry and presents concise, actionable documentation with code examples.

## Steps

### Prerequisites
1. Find the plugin root by searching for `bin/cch` executable.
2. Run: `bash "<plugin-root>/bin/cch" sources ensure gptaku_plugins`
3. Run: `bash "<plugin-root>/bin/cch" sources init-submodule gptaku_plugins plugins/docs-guide`
4. If either command fails, report the error and stop.

### Execution
1. Read the docs_guide plugin's library registry from the submodule to get the list of supported libraries and their documentation URLs.
2. Match the user's query to a library in the registry.
3. If a direct match is found:
   - Fetch the library's `llms.txt` or documentation URL using WebFetch.
   - Parse and present the relevant documentation sections.
4. If no exact match:
   - Show the user a list of similar/related libraries from the registry.
   - Ask which one they meant.
5. Present the documentation in a concise, actionable format with code examples where available.
