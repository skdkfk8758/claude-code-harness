---
name: cch-pr
description: Create a pull request with plan references, TODO linking, and structured description.
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep
---

# CCH PR - 구조화된 PR 생성

현재 브랜치의 변경사항을 분석하여 구조화된 PR을 생성합니다. 플랜 문서 및 TODO 참조를 자동 연동합니다.

## 사전 조건 체크

PR 생성 전 다음을 확인합니다:

1. **`gh` CLI 설치 여부**: `gh --version` 실행, 없으면 설치 안내 후 종료
2. **`gh auth status`**: 인증 안 되었으면 `gh auth login` 안내 후 종료
3. **main/master 브랜치 거부**: 현재 브랜치가 `main` 또는 `master` 이면 "feature 브랜치에서 실행하세요" 안내 후 종료
4. **커밋 존재 확인**: `git log main..HEAD` 가 비어있으면 "PR에 포함할 커밋이 없습니다" 안내 후 종료

## Steps

### Step 1 - 수집 (병렬)

다음을 **동시에** 실행합니다:

1. `git rev-parse --abbrev-ref HEAD` (현재 브랜치명)
2. `git log main..HEAD --oneline` (PR에 포함될 커밋 목록)
3. `git diff main...HEAD --stat` (변경 파일 통계)
4. `docs/plans/*.md` 파일 목록 확인 (Glob)

**base 브랜치 자동 감지:**
- `.claude/cch/config/base_branch` 파일이 있으면 해당 내용을 읽어 사용
- 없으면 `bin/cch branch base` 실행 결과 사용 (실패 시 아래 fallback)
- `main` 브랜치가 있으면 `main` 사용
- 없으면 `master` 사용
- 둘 다 없으면 사용자에게 base 브랜치 질문

### Step 2 - 플랜 감지

다음 순서로 관련 플랜 문서를 매칭합니다:

1. **Branch 상태 파일 조회 (우선)**: `.claude/cch/branches/<branch>.yaml` 파일을 읽어 `work_id` 필드 추출
2. **execution-plan.json 조회**: `.claude/cch/execution-plan.json`에서 `work_id` 추출
3. **커밋 트레일러 스캔**: `git log main..HEAD` 에서 `Plan:` 트레일러 추출
4. **수동 입력 (fallback)**: 위 방법으로 찾지 못하면 플랜 없음으로 진행

감지된 work_id로 `docs/plans/` 에서 관련 플랜 문서를 찾아 PR description에 포함합니다.

### Step 3 - PR 내용 생성

다음 섹션으로 구성된 PR 내용을 생성하고 **사용자 확인을 대기**합니다:

```markdown
## Summary
- <1-3줄 핵심 변경 요약>

## Plan
- <관련 플랜 문서 경로 및 work_id. 없으면 "N/A">

## TODO References
- <관련 TODO 항목 번호 및 제목, 없으면 생략>

## Changes
- <커밋별 주요 변경 설명>
- <변경 파일 통계>

## Test Plan
- [ ] <테스트 항목 1>
- [ ] <테스트 항목 2>

Co-Authored-By: Claude <noreply@anthropic.com>
```

**PR 제목 규칙:**
- 70자 이내
- conventional commit 접두사 사용 (feat/fix/refactor/docs/chore)
- work_id scope 포함 (있는 경우): `feat(login-feature): description`

### Step 4 - PR 생성

사용자 승인 후 순차 실행합니다:

1. **Push 확인**: 리모트에 push되지 않은 커밋이 있으면 `git push -u origin <branch>`
2. **PR 생성**: `gh pr create` 실행

```bash
gh pr create --title "<title>" --body "$(cat <<'EOF'
<PR body>
EOF
)"
```

3. **결과 보고**: 생성된 PR URL을 사용자에게 표시

### Step 5 - Merge & Cleanup (선택)

PR 생성 완료 후 사용자에게 다음 두 가지 옵션을 제시합니다:

**옵션 A: PR만 생성 후 종료** (기본)
- 플랜 문서 상태 표시 (연결된 경우)
- 리뷰어 지정, label 추가 등 다음 단계 안내
- 리뷰어 지정, label 추가 등 다음 단계 안내

**옵션 B: Merge + Cleanup 즉시 실행** (사용자 명시적 확인 필수)

사용자가 "merge 진행"을 선택하면 다음을 순차 실행합니다:

1. **PR merge**:
   ```bash
   gh pr merge --squash --delete-branch
   ```
2. **로컬 main 동기화**:
   ```bash
   git checkout <base-branch> && git pull origin <base-branch>
   ```
   - `<base-branch>`는 Step 1에서 감지한 base 브랜치명 사용
3. **로컬 feature 브랜치 삭제**:
   ```bash
   git branch -d <feature-branch>
   ```
4. **Branch 상태 파일 정리** (파일이 존재할 경우):
   - `.claude/cch/branches/<branch>.yaml`을 읽어 `status: merged` 로 업데이트
5. **결과 보고**:
   ```
   ## Merge 완료
   - PR: merged (squash)
   - Branch: <feature-branch> 삭제됨
   - Branch 상태 파일: merged로 업데이트됨
   ```

**실패 처리:**
- `gh pr merge` 실패 시 오류 메시지 표시 후 중단 (이하 단계 실행 안 함)
- `git branch -d` 실패 시 경고만 표시하고 계속 진행 (리모트에서 이미 삭제된 경우 등)

## 안전 규칙

- **main/master 직접 push 금지**: PR은 항상 feature 브랜치에서만 생성
- **force push 금지**: `git push --force` 사용하지 않음
- **사용자 확인 필수**: PR 내용은 반드시 사용자 승인 후 생성
- **기존 PR 감지**: 같은 브랜치에 이미 열린 PR이 있으면 알려주고 새 PR 생성 여부 확인
- **Feature 브랜치 최초 push**: Feature 브랜치는 이 스킬의 Step 4에서 최초 push됨 (생성 시에는 로컬 전용)
