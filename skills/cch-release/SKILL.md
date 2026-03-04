---
name: cch-release
description: Create a versioned release bundle with tag. Runs pre-flight checks, version bump, build, and git tag.
user-invocable: true
allowed-tools: Bash, Read, Glob
argument-hint: <version>
---

# CCH Release

버전 릴리스 번들을 생성합니다. `bin/cch release <version>` 으로 위임합니다.

## Steps

1. Locate `bin/cch` in the plugin directory.
2. Run:
```bash
bash "<plugin-root>/bin/cch" release <version>
```
   - `<version>` 은 사용자가 전달한 인자를 그대로 사용합니다.
   - 인자가 없으면 사용법을 출력합니다.

3. Report the result to the user:
   - 성공 시: 생성된 태그, 번들 경로, 파일 수 보고
   - 실패 시: 어떤 단계에서 실패했는지 설명하고 롤백 여부 안내
