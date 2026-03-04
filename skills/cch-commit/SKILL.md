---
name: cch-commit
description: Analyze changes and create logical, well-structured commits with Bead trailers.
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep, Agent, Write
---

# CCH Commit - 논리 단위 자동 분할 커밋

변경사항을 분석하여 논리적 단위로 그룹화하고, Bead 트레일러가 포함된 커밋을 생성합니다.

## Steps

### Step 1 - 수집 (병렬)

다음을 **동시에** 실행합니다:

1. `git status --porcelain` (변경 파일 목록)
2. `git diff` (unstaged 변경 내용)
3. `git diff --cached` (staged 변경 내용)
4. `git log --oneline -5` (최근 커밋 메시지 스타일 파악)
5. `.claude/cch/execution-plan.json` 읽기 (bead_id 확인)
6. `git rev-parse --abbrev-ref HEAD` (현재 브랜치명)

Step 1 완료 후 **브랜치명을 이용해 bead를 결정**합니다 (순서대로 시도):

1. `.claude/cch/branches/<branch>.yaml` 파일이 있으면 읽어 `bead_id` 필드 추출 → 이후 단계에서 이 값을 사용
2. 없으면 `.claude/cch/execution-plan.json`에서 `bead_id` 추출
3. 둘 다 없으면 bead 없음으로 진행

결정된 bead 정보는 Step 4 커밋 트레일러 및 Step 7 보고에 사용됩니다.

변경사항이 없으면 "커밋할 변경사항이 없습니다" 를 보고하고 종료합니다.

### Step 2 - 분석

변경사항을 논리 단위로 그룹화합니다:

**그룹화 기준 (우선순위 순):**
1. **기능 단위**: 하나의 기능/버그픽스를 구성하는 파일들
2. **모듈 단위**: 같은 디렉터리/모듈의 관련 변경
3. **타입 단위**: feat/fix/refactor/docs/chore 등 변경 성격
4. **의존 순서**: 하위 모듈 → 상위 모듈 순으로 커밋

**커밋 메시지 규칙:**
- 최근 커밋 로그의 스타일(conventional commits 등)을 따름
- 한글/영어는 기존 커밋 메시지와 동일한 언어 사용
- "why" 에 초점을 맞춘 간결한 메시지 (1-2 문장)

### Step 3 - 확인

커밋 계획을 아래 형식으로 사용자에게 표시하고 **승인을 대기**합니다:

```
## 커밋 계획

| # | 타입 | 설명 | 파일 |
|---|------|------|------|
| 1 | feat | ... | file1, file2 |
| 2 | fix  | ... | file3 |

Bead: <활성 bead ID 또는 "없음">
```

사용자가 수정을 요청하면 계획을 조정합니다. 승인하면 Step 3.5로 진행합니다.

### Step 3.5 - TDD Pre-Check

커밋 실행 전에 TDD 정책을 검증합니다:

1. 아키텍처 레벨 확인:
```bash
bash "<plugin-root>/bin/cch" arch level
```

2. 레벨이 설정되어 있으면 해당 레벨의 `min_test_ratio`를 적용하여 커밋 대상 소스 파일에 대응 테스트가 있는지 검증합니다:
   - 테스트 파일 패턴: `test_<name>.*`, `<name>.test.*`, `<name>.spec.*`
   - 비소스 파일(`.md`, `.json`, `.yaml`, `.toml`, `.env`, `.lock`)은 검증 대상에서 제외

3. 결과 표시:
   - 모든 소스 파일에 테스트가 있으면: `✅ TDD Check: N/N 파일 테스트 존재`
   - 누락이 있으면: `⚠️ TDD Check: N개 파일에 대응 테스트 없음` + 파일 목록
   - 누락 시에도 **차단하지 않음** — 경고만 표시하고 사용자 확인 후 Step 4로 진행

### Step 4 - 실행

각 그룹별로 순차 실행합니다:

1. `git add <files>` (파일 단위로 staging, `git add .` 사용 금지)
2. `git commit` (HEREDOC 형식으로 메시지 전달)

**커밋 메시지 형식:**
```
<type>: <description>

<optional body>

Bead: <bead-id>
Co-Authored-By: Claude <noreply@anthropic.com>
```

- bead가 감지되면 `Bead:` 트레일러 포함
- `Co-Authored-By` 트레일러 항상 포함

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
   - subagent_type: `general-purpose`
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
- 에이전트가 에러를 반환하거나 응답하지 않으면: "Simplify: 오류로 스킵됨" 경고 출력, Step 6으로 계속
- 변경 후 `git diff`로 확인한 파일에 비코드 파일이 섞여 있으면 코드 파일만 staging

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
   - frontmatter가 없거나 `name`/`description`이 누락된 스킬은 건너뛰고 경고 출력
3. `docs/PRD.md` 첫 번째 섹션에서 프로젝트 설명 추출
4. 아래 템플릿에 수집된 정보를 채워 README.md 생성:

````markdown
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
| test.sh | 테스트 스위트 실행 |
| ... | ... |

## 설치 및 설정
- [설치 가이드](docs/guide/)

## 문서
- [PRD](docs/PRD.md)
- [Architecture](docs/Architecture.md)
- [Roadmap](docs/Roadmap.md)

## 테스트
`scripts/test.sh all` 로 전체 테스트를 실행합니다.
````

5. 기존 README.md와 비교
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

### Step 7 - 보고 (확장)

커밋 결과와 후처리 결과를 테이블로 출력합니다:

```
## 커밋 완료

Branch: <현재 브랜치명> (bead: <연결된 bead ID 또는 "없음">)

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

## 안전 규칙

- **민감 파일 자동 제외**: `.env`, `.env.*`, `credentials.*`, `*.pem`, `*.key`, `*secret*` 패턴의 파일은 staging에서 제외하고 경고 표시
- **`--no-verify` 금지**: pre-commit hook을 항상 실행
- **hook 실패 시 새 커밋**: amend가 아닌 새 커밋으로 재시도 (이전 커밋 보존)
- **force push 금지**: push는 하지 않음 (push는 `/cch-pr` 에서 처리)
- **빈 커밋 금지**: 변경사항이 없는 그룹은 건너뜀
- **Step 5~6은 Step 4 완료 후에만 실행**: 원본 커밋을 먼저 보존한 뒤 후처리 진행
- **Step 5~6 독립 실패 허용**: 하나가 실패해도 다음 단계는 계속 진행
- **불필요한 커밋 생성 금지**: simplify/README 변경이 없으면 커밋하지 않음
- **simplify는 코드 파일에만 적용**: `.md`, `.json`, `.yaml` 등 비코드 파일은 simplify 대상에서 제외

## Enhancement (Tier 1+)

> superpowers 플러그인이 설치되어 있으면 다음 강화 기능을 활용합니다.

- **Tier 1+**: Step 3.5 TDD Pre-Check에서 `superpowers:test-driven-development` 기준 적용
- **Tier 1+**: Step 5 Simplify에서 `superpowers:requesting-code-review` 관점으로 코드 정리
- **Tier 1+**: 커밋 전 `superpowers:verification-before-completion` 체크리스트 자동 검증
