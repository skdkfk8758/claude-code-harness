# cch-commit 스킬 확장 구현 계획

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** cch-commit 스킬에 post-commit simplify(Step 5)와 README 재생성(Step 6)을 추가하고, 보고(Step 7)를 확장한다.

**Architecture:** 기존 SKILL.md의 5단계를 7단계로 확장. Step 4(커밋) 이후에 simplify 에이전트 호출과 README 재생성을 순차 실행. 각 단계는 독립적으로 실패 허용.

**Tech Stack:** SKILL.md (마크다운 스킬 정의), Agent tool (code-simplifier 에이전트), Bash/Glob/Read/Grep

---

### Task 1: allowed-tools에 Agent 추가

**Files:**
- Modify: `skills/cch-commit/SKILL.md:5`

**Step 1: allowed-tools 필드에 Agent 추가**

`skills/cch-commit/SKILL.md` 5행의 allowed-tools를 수정:

```yaml
# 변경 전
allowed-tools: Bash, Read, Glob, Grep

# 변경 후
allowed-tools: Bash, Read, Glob, Grep, Agent, Write
```

`Agent`는 Step 5에서 code-simplifier 서브에이전트 호출에 필요.
`Write`는 Step 6에서 README.md 생성에 필요.

**Step 2: Commit**

```bash
git add skills/cch-commit/SKILL.md
git commit -m "feat(cch-commit): add Agent and Write to allowed-tools

Required for post-commit simplify agent and README generation.

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 2: 기존 Step 5(보고)를 Step 7로 번호 변경

**Files:**
- Modify: `skills/cch-commit/SKILL.md:78-91`

**Step 1: Step 5 → Step 7 번호 변경 및 내용 확장**

기존 `### Step 5 - 보고` 섹션을 `### Step 7 - 보고 (확장)`으로 변경하고 후처리 결과 섹션 추가:

```markdown
### Step 7 - 보고 (확장)

커밋 결과와 후처리 결과를 테이블로 출력합니다:

```
## 커밋 완료

| # | 해시 | 타입 | 설명 | 파일수 |
|---|------|------|------|--------|
| 1 | abc1234 | feat | ... | 2 |
| 2 | def5678 | fix  | ... | 1 |
| 3 | ghi9012 | refactor | simplify recently committed code | 3 |
| 4 | jkl3456 | docs | update README | 1 |

총 N개 커밋 생성

## 후처리 결과
- Simplify: N개 파일 정리됨 (또는 "변경 없음" / "스킵됨" / "오류로 스킵됨")
- README: 갱신됨 (또는 "변경 없음" / "오류로 스킵됨")
```

Step 5~6에서 커밋이 생성되지 않았으면 해당 행을 테이블에서 생략합니다.
```

**Step 2: Commit**

```bash
git add skills/cch-commit/SKILL.md
git commit -m "refactor(cch-commit): rename Step 5 to Step 7, add post-processing report

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 3: Step 5 — Simplify 단계 추가

**Files:**
- Modify: `skills/cch-commit/SKILL.md` (Step 4와 Step 7 사이에 삽입)

**Step 1: Step 5 Simplify 섹션 작성**

Step 4(실행) 바로 아래, Step 7(보고) 위에 다음 내용 삽입:

```markdown
### Step 5 - Simplify (자동 코드 정리)

Step 4에서 생성된 커밋의 코드 파일을 자동으로 정리합니다.

**스킵 조건 (하나라도 해당하면 "Simplify: 스킵됨" 기록 후 Step 6으로):**
- 커밋된 파일이 모두 비코드 파일 (`.md`, `.json`, `.yaml`, `.toml`, `.txt`, `.env*`)
- Step 4 커밋 타입이 모두 `docs:` 또는 `chore:`인 경우

**실행 순서:**

1. Step 4에서 생성한 커밋 수(N)를 기반으로 변경 파일 추출:
   ```
   git diff --name-only HEAD~N..HEAD
   ```
2. 비코드 파일을 필터링하여 코드 파일 목록만 남김
3. `code-simplifier` 서브에이전트를 Agent 도구로 호출:
   - subagent_type: `oh-my-claudecode:code-simplifier`
   - prompt: "다음 파일들만 simplify하세요: <파일 목록>"
4. 에이전트 완료 후 변경 여부 확인:
   ```
   git diff --name-only
   ```
5. 변경이 있으면:
   - `git add <changed-files>` (파일 단위 staging)
   - `git commit` (HEREDOC 형식):
     ```
     refactor: simplify recently committed code

     Co-Authored-By: Claude <noreply@anthropic.com>
     ```
6. 변경이 없으면 "Simplify: 변경 없음" 기록 후 Step 6으로

**실패 처리:**
- 에이전트 오류 시: "Simplify: 오류로 스킵됨" 경고 출력, Step 6으로 계속
- 변경 후 `git diff`로 확인한 파일에 비코드 파일이 섞여 있으면 코드 파일만 staging
```

**Step 2: Commit**

```bash
git add skills/cch-commit/SKILL.md
git commit -m "feat(cch-commit): add Step 5 post-commit simplify via code-simplifier agent

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 4: Step 6 — README 재생성 단계 추가

**Files:**
- Modify: `skills/cch-commit/SKILL.md` (Step 5와 Step 7 사이에 삽입)

**Step 1: Step 6 README 섹션 작성**

Step 5(Simplify) 바로 아래, Step 7(보고) 위에 다음 내용 삽입:

```markdown
### Step 6 - README 재생성

프로젝트 구조를 스캔하여 README.md를 최신 상태로 갱신합니다.

**실행 순서:**

1. 프로젝트 구조를 **병렬로** 스캔:
   - `ls skills/` → 스킬 디렉터리 목록
   - `ls scripts/` → 스크립트 파일 목록
   - `ls bin/` → CLI 도구 목록
   - `ls docs/` → 문서 목록
   - `ls tests/` → 테스트 목록
2. 각 스킬의 메타데이터 수집:
   - `skills/*/SKILL.md`의 frontmatter에서 `name`과 `description` 추출
3. `docs/PRD.md` 첫 번째 섹션에서 프로젝트 설명 추출
4. 아래 템플릿에 수집된 정보를 채워 README.md 생성:

```markdown
# Claude Code Harness (CCH)
> {PRD 1줄 요약}

## 개요
{PRD 기반 2-3줄 설명}

## 스킬 목록
| 스킬 | 설명 |
|------|------|
| cch-commit | Analyze changes and create logical commits |
| ... | ... |

## 스크립트
| 스크립트 | 용도 |
|---------|------|
| test.sh | 6-layer 테스트 실행 |
| ... | ... |

## 설치 및 설정
- [설치 가이드](docs/guide/)

## 문서
- [PRD](docs/PRD.md)
- [Architecture](docs/Architecture.md)
- [Roadmap](docs/Roadmap.md)

## 테스트
`scripts/test.sh all` 로 전체 테스트를 실행합니다.
```

5. 기존 README.md 내용과 비교 (`git diff --no-index` 또는 직접 비교)
6. 변경이 있으면:
   - `git add README.md`
   - `git commit` (HEREDOC 형식):
     ```
     docs: update README

     Co-Authored-By: Claude <noreply@anthropic.com>
     ```
7. 변경이 없으면 "README: 변경 없음" 기록 후 Step 7으로

**실패 처리:**
- 스캔 오류 시: "README: 오류로 스킵됨" 경고 출력, Step 7으로 계속
```

**Step 2: Commit**

```bash
git add skills/cch-commit/SKILL.md
git commit -m "feat(cch-commit): add Step 6 README auto-regeneration from project scan

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 5: 안전 규칙 섹션 확장

**Files:**
- Modify: `skills/cch-commit/SKILL.md` (안전 규칙 섹션)

**Step 1: 기존 안전 규칙에 후처리 관련 규칙 추가**

기존 `## 안전 규칙` 섹션 끝에 다음을 추가:

```markdown
- **Step 5~6은 Step 4 완료 후에만 실행**: 원본 커밋을 먼저 보존한 뒤 후처리 진행
- **Step 5~6 독립 실패 허용**: 하나가 실패해도 다음 단계는 계속 진행
- **불필요한 커밋 생성 금지**: simplify/README 변경이 없으면 커밋하지 않음
- **simplify는 코드 파일에만 적용**: `.md`, `.json`, `.yaml` 등 비코드 파일은 simplify 대상에서 제외
```

**Step 2: Commit**

```bash
git add skills/cch-commit/SKILL.md
git commit -m "feat(cch-commit): extend safety rules for post-commit steps

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

---

### Task 6: 스킬 캐시 동기화

**Step 1: cch-sync 실행**

스킬 수정 후 플러그인 캐시에 반영:

```bash
# cch-sync 스킬을 호출하여 캐시 동기화
```

또는 수동으로:

```bash
cp skills/cch-commit/SKILL.md .claude/plugins/cache/claude-code-harness-marketplace/claude-code-harness/*/skills/cch-commit/SKILL.md
```

**Step 2: 동기화 확인**

```bash
diff skills/cch-commit/SKILL.md .claude/plugins/cache/claude-code-harness-marketplace/claude-code-harness/*/skills/cch-commit/SKILL.md
```

Expected: 차이 없음 (exit code 0)

---

### Task 7: 수동 검증

**Step 1: 스킬 파일 구조 검증**

SKILL.md를 읽어서 7단계가 올바른 순서인지 확인:

```bash
grep "^### Step" skills/cch-commit/SKILL.md
```

Expected output:
```
### Step 1 - 수집 (병렬)
### Step 2 - 분석
### Step 3 - 확인
### Step 4 - 실행
### Step 5 - Simplify (자동 코드 정리)
### Step 6 - README 재생성
### Step 7 - 보고 (확장)
```

**Step 2: frontmatter 검증**

```bash
head -6 skills/cch-commit/SKILL.md
```

Expected: `allowed-tools: Bash, Read, Glob, Grep, Agent, Write`

**Step 3: 안전 규칙 검증**

```bash
grep -c "Step 5\|Step 6\|simplify\|README" skills/cch-commit/SKILL.md
```

Expected: 20+ 매치 (새 단계와 안전 규칙 참조)
