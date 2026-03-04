# cch-init 프로젝트 분석/마이그레이션 스킬 구현 계획

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 프로젝트를 깊이 분석하여 Architecture/PRD/Roadmap/TODO를 역산 추출하고, 선택적으로 CCH 구조를 스캐폴딩하는 `/cch-init` 스킬 세트 구현

**Architecture:** 4개 마이크로 스킬 오케스트레이션 패턴. `cch-init`(오케스트레이터)이 `cch-init-scan` → `cch-init-docs` → `cch-init-scaffold`를 순차 호출. 기존 `cch-team` 파이프라인 패턴과 동일한 구조.

**Tech Stack:** Bash (bin/cch), SKILL.md (Claude Code 네이티브 스킬), JSON (scan-result 스키마), Agent tool (서브에이전트 오케스트레이션)

**설계 문서:** `docs/plans/2026-03-03-cch-init-design.md`

---

## Task 1: cch-init-scan 스킬 작성 (#82)

**Files:**
- Create: `skills/cch-init-scan/SKILL.md`

**Step 1: 스킬 파일 생성**

```markdown
---
name: cch-init-scan
description: Scan and analyze a project - detect tech stack, structure, existing docs, and git history
user-invocable: false
allowed-tools: Bash, Read, Glob, Grep, Agent, AskUserQuestion
---

# CCH Init Scan - 프로젝트 스캔/분석

프로젝트를 적응형 2단계로 분석합니다. Quick Scan으로 개요를 파악한 뒤,
사용자가 선택한 영역만 Deep Scan으로 심층 분석합니다.

## 입력

- 현재 작업 디렉터리 (cwd)

## 출력

- `.claude/cch/init/scan-result.json`

## Steps

### Step 1 - 환경 준비

`.claude/cch/init/` 디렉터리를 생성합니다:

\```bash
mkdir -p .claude/cch/init
\```

### Step 2 - Quick Scan (병렬 실행)

다음 4개 분석을 **동시에** 실행합니다:

#### 2-1. 프로젝트 메타데이터 감지

파일 존재 여부로 기술 스택을 감지합니다:

| 파일 | 감지 대상 |
|------|----------|
| `package.json` | Node.js, npm/yarn/pnpm, 프레임워크(dependencies 분석) |
| `pyproject.toml`, `setup.py`, `requirements.txt` | Python, pip/poetry |
| `Cargo.toml` | Rust, cargo |
| `go.mod` | Go |
| `build.gradle`, `pom.xml` | Java/Kotlin, gradle/maven |
| `Gemfile` | Ruby, bundler |
| `Makefile`, `CMakeLists.txt` | C/C++, make/cmake |
| `webpack.config.*`, `vite.config.*` | 빌드 도구 |
| `jest.config.*`, `vitest.config.*`, `pytest.ini`, `conftest.py` | 테스트 프레임워크 |
| `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile` | CI/CD |

Glob 도구로 위 파일들을 **병렬 탐색**합니다.

#### 2-2. 디렉터리 구조 스냅샷

\```bash
# 상위 2-depth 트리 (gitignore 준수)
find . -maxdepth 2 -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/vendor/*' -not -path '*/__pycache__/*' -not -path '*/dist/*' -not -path '*/build/*' | head -200

# 파일 통계
find . -type f -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/vendor/*' | wc -l
\```

주요 진입점 파일을 Glob으로 탐색합니다:
- `**/main.*`, `**/index.*`, `**/app.*`, `**/server.*`, `**/cmd/**`

#### 2-3. 기존 문서 수집

Glob으로 다음 파일들을 탐색합니다:
- `README.md`, `README.*`
- `CONTRIBUTING.md`, `CHANGELOG.md`, `LICENSE`
- `docs/**/*.md`
- `**/openapi.yaml`, `**/swagger.json`
- `**/Architecture.md`, `**/PRD.md`, `**/Roadmap.md`, `**/TODO.md`

존재하는 문서는 Read로 내용을 수집합니다.

#### 2-4. Git 히스토리 개요

git 저장소인 경우에만 실행합니다:

\```bash
# git 저장소 확인
git rev-parse --is-inside-work-tree 2>/dev/null

# 커밋 패턴 분석 (최근 50개)
git log --oneline -50 --format="%s"

# 기여자
git shortlog -sn --no-merges | head -10

# 태그/릴리즈
git tag --sort=-v:refname | head -20

# 활성 브랜치
git branch -r --sort=-committerdate | head -10
\```

### Step 3 - Quick Scan 결과 제시

수집된 정보를 다음 형식으로 사용자에게 요약합니다:

\```
## 프로젝트 Quick Scan 결과

| 항목 | 값 |
|------|-----|
| 프로젝트명 | <디렉터리명 또는 package.json name> |
| 언어 | TypeScript, Python |
| 프레임워크 | Next.js, FastAPI |
| 빌드 도구 | npm, poetry |
| 테스트 | jest, pytest |
| CI/CD | GitHub Actions |
| 파일 수 | 342개 (코드 218개) |
| 기존 문서 | README.md, docs/setup.md |
| Git 커밋 | 1,243개, 5명 기여자 |
| 태그 | v1.0.0, v1.1.0, v2.0.0 |

Deep Scan이 가능한 영역:
1. 아키텍처 분석 (모듈 의존성, 레이어 구조, 디자인 패턴)
2. 기능 분석 (API 엔드포인트, 도메인 모델, 비즈니스 로직)
3. 품질/운영 분석 (테스트, 에러 핸들링, 보안)
4. 로드맵 역산 자료 (마일스톤, TODO/FIXME, 개발 방향)
\```

AskUserQuestion으로 Deep Scan 영역을 선택받습니다 (multiSelect: true).

### Step 4 - Deep Scan (선택 영역만)

사용자가 선택한 영역에 대해 병렬 에이전트로 심층 분석합니다:

#### 4-1. 아키텍처 분석

Explore 에이전트를 사용합니다:
- `mcp__serena__get_symbols_overview`로 주요 파일의 심볼 구조 파악
- `mcp__serena__find_referencing_symbols`로 모듈 간 의존성 추적
- Grep으로 `import`/`require`/`from` 패턴 분석
- 레이어 구조 식별 (controller/handler → service/usecase → repository/model)
- 외부 의존성 식별 (HTTP client, DB driver, MQ 등)

#### 4-2. 기능 분석

- Grep으로 라우팅 패턴 탐색 (`@app.route`, `router.get`, `@Controller` 등)
- API 엔드포인트 목록 추출
- 도메인 모델/엔티티 식별 (`class`, `interface`, `type`, `model` 등)
- 환경변수 목록 (`process.env`, `os.environ`, `.env` 파일)

#### 4-3. 품질/운영 분석

- 테스트 파일 분포 (`test_*`, `*.test.*`, `*.spec.*`)
- 에러 핸들링 패턴 (`try/catch`, `Error`, `Exception`)
- 로깅 패턴 (`logger`, `console.log`, `logging`)
- 인증/인가 패턴 (`auth`, `jwt`, `session`, `middleware`)

#### 4-4. 로드맵 역산 자료

\```bash
# TODO/FIXME/HACK 주석 수집
grep -rn "TODO\|FIXME\|HACK\|XXX" --include="*.ts" --include="*.py" --include="*.go" --include="*.java" --include="*.rs" . | head -100

# git 태그별 주요 변경 (최근 5개 태그)
for tag in $(git tag --sort=-v:refname | head -5); do
  echo "=== $tag ==="
  git log --oneline "$tag"..HEAD 2>/dev/null | head -10 || git log --oneline -10 "$tag"
done

# 최근 활발한 변경 영역
git log --pretty=format: --name-only -50 | sort | uniq -c | sort -rn | head -20
\```

### Step 5 - scan-result.json 저장

모든 분석 결과를 `.claude/cch/init/scan-result.json`에 JSON으로 저장합니다.

스키마:
\```json
{
  "schema_version": "1.0",
  "scanned_at": "<ISO8601>",
  "project": {
    "name": "<string>",
    "root": "<string>",
    "languages": ["<string>"],
    "frameworks": ["<string>"],
    "build_tools": ["<string>"],
    "test_frameworks": ["<string>"],
    "ci_cd": ["<string>"],
    "file_stats": { "total": 0, "code": 0, "loc_estimate": 0 }
  },
  "existing_docs": {
    "readme": "<path | null>",
    "architecture": "<path | null>",
    "prd": "<path | null>",
    "changelog": "<path | null>",
    "api_docs": "<path | null>",
    "other": ["<path>"]
  },
  "git_summary": {
    "total_commits": 0,
    "contributors": 0,
    "tags": ["<string>"],
    "recent_patterns": ["<string>"],
    "active_branches": ["<string>"]
  },
  "deep_scan": {
    "architecture": { "layers": [], "dependencies": [], "patterns": [] },
    "features": { "endpoints": [], "models": [], "env_vars": [] },
    "quality": { "test_coverage": {}, "error_patterns": [], "security": [] },
    "roadmap_hints": { "milestones": [], "todos": [], "active_areas": [] }
  }
}
\```

### Step 6 - 사용자에게 Deep Scan 결과 보고

Deep Scan 결과를 구조화하여 사용자에게 제시합니다.
다음 단계(문서 생성)로의 전환을 안내합니다.
```

**Step 2: 테스트 - 스킬 frontmatter 검증**

Run: `bash scripts/test.sh skill`
Expected: cch-init-scan이 스킬 목록에 포함되어 통과

**Step 3: 커밋**

```bash
git add skills/cch-init-scan/SKILL.md
git commit -m "feat: add cch-init-scan skill for project analysis

Work-Item: w-cch-init
Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 2: cch-init-docs 스킬 작성 (#83)

**Files:**
- Create: `skills/cch-init-docs/SKILL.md`

**Step 1: 스킬 파일 생성**

```markdown
---
name: cch-init-docs
description: Generate Architecture, PRD, Roadmap, and TODO documents from scan results
user-invocable: false
allowed-tools: Bash, Read, Write, Glob, Grep, Agent, AskUserQuestion
---

# CCH Init Docs - 문서 생성

scan-result.json을 기반으로 4개 핵심 문서를 병렬 생성합니다.
기존 문서가 있으면 병합 모드로 동작합니다.

## 입력

- `.claude/cch/init/scan-result.json` (cch-init-scan의 출력)
- 기존 문서 (있으면)

## 출력

- `docs/PRD.md`
- `docs/Architecture.md`
- `docs/Roadmap.md`
- `docs/TODO.md`

## Steps

### Step 1 - scan-result.json 로드

`.claude/cch/init/scan-result.json`을 Read로 읽습니다.
파일이 없으면 "먼저 /cch-init 또는 cch-init-scan을 실행하세요" 안내 후 종료합니다.

### Step 2 - 기존 문서 확인

다음 파일의 존재 여부를 확인합니다:
- `docs/Architecture.md`
- `docs/PRD.md`
- `docs/Roadmap.md`
- `docs/TODO.md`

존재하는 문서는 Read로 내용을 수집합니다.

모드 결정:
| 기존 문서 | 모드 | 동작 |
|-----------|------|------|
| 없음 | 생성 | scan 결과로부터 완전 새로 생성 |
| 있음 | 병합 | 기존 내용 + scan 결과 통합 |

### Step 3 - 4개 문서 병렬 생성

4개 Agent를 **병렬로** 실행합니다. 각 에이전트에게 scan-result.json 내용과
기존 문서(있으면)를 프롬프트로 전달합니다.

#### Agent 1: Architecture.md

subagent_type: "oh-my-claudecode:architect"

프롬프트에 포함할 내용:
- scan-result.json의 `project`, `deep_scan.architecture` 섹션
- 기존 Architecture.md (병합 모드 시)
- CCH Architecture.md 형식 템플릿

생성할 섹션:
1. **아키텍처 목표** ← frameworks + patterns + README
2. **레이어와 컴포넌트** ← 모듈 의존성 + 레이어 구조
3. **컴포넌트 책임** ← 주요 클래스/모듈 심볼
4. **데이터 흐름** ← API + 도메인 모델 + 외부 의존성
5. **기술 스택** ← languages, frameworks, build_tools
6. **인프라/배포** ← CI/CD + 환경변수
7. **테스트 아키텍처** ← 테스트 파일 분포

#### Agent 2: PRD.md (역산)

subagent_type: "oh-my-claudecode:analyst"

생성할 섹션:
1. **제품 정의** ← README + 진입점
2. **해결할 문제** ← README + 도메인 모델
3. **기능 요구사항** ← API 엔드포인트 + 라우팅 + UI 컴포넌트 → F1, F2, ...
4. **비기능 요구사항** ← 에러 핸들링/로깅/인증/성능 패턴
5. **제약조건** ← 의존성, 환경변수, 설정
6. **범위** ← 구현 완료 = In Scope, TODO/FIXME = Out of Scope

#### Agent 3: Roadmap.md (역산)

subagent_type: "oh-my-claudecode:executor"

생성할 섹션:
1. **완료된 마일스톤** ← git 태그 + 릴리즈 히스토리
2. **현재 진행 중** ← 활성 브랜치 + 최근 커밋
3. **예정 항목** ← TODO/FIXME + 미완성 기능
4. **기술 부채** ← HACK 주석 + deprecated 패턴

#### Agent 4: TODO.md (역산)

subagent_type: "oh-my-claudecode:executor"

생성할 섹션:
1. **Critical Path** ← Roadmap 마일스톤 → Phase → 의존성
2. **Phase N** ← 각 마일스톤의 작업 항목 분해
3. **의존성 그래프** ← Phase 간/내 의존성

### Step 4 - 병합 마커 처리 (병합 모드만)

기존 문서와 생성 결과를 비교하여 마커를 삽입합니다:

| 상황 | 마커 |
|------|------|
| 기존과 일치 | (마커 없음) |
| 기존과 불일치 | `<!-- [!코드 불일치] 코드 분석 결과: ... -->` |
| 기존에 없고 코드에서 발견 | `<!-- [코드에서 역산] -->` |
| 기존에 있고 코드에서 미확인 | `<!-- [코드에서 미확인] -->` |

### Step 5 - Cross-validation

4개 문서 간 정합성을 검증합니다:

1. Architecture 컴포넌트 ↔ PRD 기능: 기능별 컴포넌트 매핑 확인
2. Roadmap 마일스톤 ↔ TODO Phase: 1:1 대응 확인
3. TODO 항목 ↔ PRD 기능: 미완료 기능의 TODO 존재 확인
4. 용어 일관성: 4개 문서의 동일 개념 명칭 통일

불일치가 발견되면 사용자에게 보고하고 수정 여부를 확인합니다.

### Step 6 - 문서 저장 및 사용자 리뷰

Write 도구로 `docs/` 에 4개 문서를 저장합니다.
사용자에게 각 문서의 요약을 제시하고 리뷰를 요청합니다.
```

**Step 2: 테스트 - 스킬 frontmatter 검증**

Run: `bash scripts/test.sh skill`
Expected: cch-init-docs가 스킬 목록에 포함되어 통과

**Step 3: 커밋**

```bash
git add skills/cch-init-docs/SKILL.md
git commit -m "feat: add cch-init-docs skill for document generation

Work-Item: w-cch-init
Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 3: cch-init-scaffold 스킬 작성 (#84)

**Files:**
- Create: `skills/cch-init-scaffold/SKILL.md`

**Step 1: 스킬 파일 생성**

```markdown
---
name: cch-init-scaffold
description: Scaffold CCH directory structure, manifests, profiles, and hooks for project migration
user-invocable: false
allowed-tools: Bash, Read, Write, Glob, Grep, Agent
---

# CCH Init Scaffold - CCH 구조 스캐폴딩

scan-result.json과 생성된 문서를 기반으로 CCH 구조 파일을 생성합니다.
migrate 모드에서만 실행됩니다.

## 입력

- `.claude/cch/init/scan-result.json`
- `docs/Architecture.md`, `docs/PRD.md`, `docs/Roadmap.md`, `docs/TODO.md`

## 출력

- `.claude-plugin/plugin.json`
- `manifests/capabilities.json`
- `manifests/sources.json`
- `manifests/health-rules.json`
- `profiles/plan.json`, `profiles/code.json`, `profiles/tool.json`, `profiles/swarm.json`
- `hooks/hooks.json`
- `docs/TODO.md` (Phase/항목 분해 반영)

## Steps

### Step 1 - 기존 CCH 구조 확인

이미 CCH가 설치된 프로젝트인지 확인합니다:

\```bash
ls .claude-plugin/plugin.json 2>/dev/null
ls manifests/ 2>/dev/null
ls profiles/ 2>/dev/null
\```

이미 존재하면 사용자에게 "기존 CCH 구조를 덮어쓰시겠습니까?" 확인합니다.

### Step 2 - plugin.json 생성

scan-result.json의 `project.name`을 기반으로 생성합니다:

\```json
{
  "name": "<project-name>-harness",
  "version": "0.1.0",
  "description": "CCH integration for <project-name>",
  "skills": "skills/",
  "hooks": "hooks/"
}
\```

### Step 3 - manifests/ 생성

#### capabilities.json

scan 결과에서 감지된 소스를 기반으로 생성합니다.
미감지 시 superpowers + omc 기본 세트를 제안합니다.

#### sources.json

Phase 3S `install_type` 체계 호환:
- `plugin`: Claude Code 플러그인 마켓플레이스 기반
- `npm`: Node.js 프로젝트
- `git`: 단순 git clone
- `local`: 로컬 내장

#### health-rules.json

프로젝트에서 감지된 소스에 대해서만 규칙 생성합니다.
기본 규칙 4개:
1. superpowers 미가용 → Degraded
2. omc 미가용 → Degraded
3. 필수 소스 미가용 → Blocked
4. DOT 미가용 → 실험선 비활성

### Step 4 - profiles/ 생성

scan 결과의 기술 스택에 따라 4모드 프로필을 생성합니다:

| 프로젝트 특성 | 프로필 조정 |
|--------------|-----------|
| 프론트엔드 위주 | `code` 모드에 UI capabilities 추가 |
| API 서버 위주 | `tool` 모드에 API 도구 강조 |
| 모노레포 | `swarm` 모드에 병렬 세분화 |
| 단일 모듈 | `swarm` 모드 비활성 권장 |

### Step 5 - hooks/ 생성

CCH 기본 hook 세트를 생성합니다:

\```json
{
  "hooks": [
    {
      "event": "UserPromptSubmit",
      "command": "bash scripts/mode-detector.sh",
      "description": "모드 자동 감지"
    }
  ]
}
\```

프로젝트에 기존 hooks가 있으면 병합합니다.

### Step 6 - Roadmap → TODO Phase 분해

`docs/Roadmap.md`를 파싱하여 `docs/TODO.md`를 업데이트합니다:

1. 완료된 마일스톤 → `- [x] **#N** <제목> _(날짜 완료)_`
2. 진행 중/예정 마일스톤 → `- [ ] **#N** <제목>`
3. Phase 간 의존성: 이전 Phase Gate → 다음 Phase 첫 항목
4. Phase 내 의존성: 순차 의존 (추론 기반)
5. Critical Path 및 의존성 그래프 자동 생성

### Step 7 - 검증

1. `plugin.json` JSON 파싱 성공 확인
2. `manifests/*.json` JSON 파싱 성공 확인
3. `profiles/*.json` 4개 모드 존재 확인
4. `TODO.md` 번호 연속성 + 의존성 순환 없음 확인
5. `docs/` 4개 문서 존재 확인

검증 실패 항목이 있으면 사용자에게 보고합니다.

### Step 8 - 결과 보고

생성된 파일 목록을 사용자에게 표시합니다:

\```
## CCH 스캐폴딩 완료

| 파일 | 상태 |
|------|------|
| .claude-plugin/plugin.json | 생성 |
| manifests/capabilities.json | 생성 |
| manifests/sources.json | 생성 |
| ... | ... |

다음 단계: `/cch-setup` 으로 CCH를 활성화하세요.
\```
```

**Step 2: 테스트 - 스킬 frontmatter 검증**

Run: `bash scripts/test.sh skill`
Expected: cch-init-scaffold가 스킬 목록에 포함되어 통과

**Step 3: 커밋**

```bash
git add skills/cch-init-scaffold/SKILL.md
git commit -m "feat: add cch-init-scaffold skill for CCH structure scaffolding

Work-Item: w-cch-init
Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 4: cch-init 오케스트레이터 스킬 작성 (#85)

**Files:**
- Create: `skills/cch-init/SKILL.md`

**Step 1: 스킬 파일 생성**

```markdown
---
name: cch-init
description: Deep project analysis and CCH migration - scans codebase, generates docs (Architecture/PRD/Roadmap/TODO), optionally scaffolds CCH structure
user-invocable: true
allowed-tools: Bash, Read, Write, Glob, Grep, Agent, AskUserQuestion, TaskCreate, TaskUpdate, TaskList
---

# CCH Init - 프로젝트 분석 및 마이그레이션

프로젝트를 깊이 분석하여 Architecture/PRD/Roadmap/TODO를 역산 추출하고,
선택적으로 CCH 구조를 스캐폴딩합니다.

## 모드

- **onboard**: 프로젝트 분석 + 문서 생성 (범용 온보딩)
- **migrate**: 프로젝트 분석 + 문서 생성 + CCH 구조 스캐폴딩

## Steps

### Step 0 - Pre-check

1. 이미 초기화된 프로젝트인지 확인합니다:
   \```bash
   ls .claude/cch/init/scan-result.json 2>/dev/null
   \```
   - 존재하면 AskUserQuestion으로 "이미 초기화되었습니다. 재실행하시겠습니까?" 확인
   - 사용자가 거부하면 종료

2. git 저장소 여부를 확인합니다:
   \```bash
   git rev-parse --is-inside-work-tree 2>/dev/null
   \```
   - git 저장소가 아니면 "Git 히스토리 분석을 건너뜁니다" 경고 표시

### Step 1 - Scan (cch-init-scan)

TaskCreate로 "[Scan] 프로젝트 분석" 태스크를 생성합니다.

Agent 도구로 스캔 에이전트를 실행합니다:
- subagent_type: "oh-my-claudecode:explore"
- 프롬프트: `skills/cch-init-scan/SKILL.md`의 Steps를 따라 프로젝트를 분석하세요.
  현재 디렉터리를 대상으로 Quick Scan → Deep Scan 순서로 진행합니다.
  결과를 `.claude/cch/init/scan-result.json`에 저장하세요.

에이전트 완료 후:
- scan-result.json 존재 확인
- Task를 completed로 업데이트

### Step 2 - 모드 선택

스캔 결과 요약을 사용자에게 제시한 후,
AskUserQuestion으로 모드를 선택받습니다:

\```
이 프로젝트에 대해 어떤 작업을 하시겠습니까?

1. onboard - 문서만 생성 (Architecture/PRD/Roadmap/TODO)
2. migrate - 문서 생성 + CCH 구조 스캐폴딩
\```

선택된 모드를 `.claude/cch/init/mode`에 저장합니다.

### Step 3 - Docs (cch-init-docs)

TaskCreate로 "[Docs] 문서 생성" 태스크를 생성합니다.

**4개 에이전트를 병렬로** 실행합니다:

1. Architecture.md 생성:
   - subagent_type: "oh-my-claudecode:architect"
   - scan-result.json 내용 + Architecture 템플릿 전달
   - 기존 docs/Architecture.md가 있으면 병합 모드 지시

2. PRD.md 역산:
   - subagent_type: "oh-my-claudecode:analyst"
   - scan-result.json 내용 + PRD 템플릿 전달

3. Roadmap.md 역산:
   - subagent_type: "oh-my-claudecode:executor"
   - scan-result.json 내용 + Roadmap 템플릿 전달

4. TODO.md 역산:
   - subagent_type: "oh-my-claudecode:executor"
   - scan-result.json 내용 + Roadmap.md 결과 + TODO 템플릿 전달

에이전트 완료 후:
- 4개 문서 존재 확인
- Cross-validation 실행 (용어/참조 일관성)
- 사용자에게 문서 요약 제시 + 리뷰 요청
- Task를 completed로 업데이트

### Step 4 - Scaffold (migrate 모드만)

모드가 `onboard`이면 이 단계를 건너뜁니다.

TaskCreate로 "[Scaffold] CCH 구조 생성" 태스크를 생성합니다.

Agent 도구로 스캐폴딩 에이전트를 실행합니다:
- subagent_type: "oh-my-claudecode:executor"
- 프롬프트: `skills/cch-init-scaffold/SKILL.md`의 Steps를 따라
  CCH 구조를 스캐폴딩하세요.
  scan-result.json과 docs/ 문서를 기반으로 합니다.

에이전트 완료 후:
- manifests/, profiles/, hooks/ 존재 확인
- Task를 completed로 업데이트

### Step 5 - 최종 보고

사용자에게 최종 결과를 보고합니다:

\```
## CCH Init 완료

### 모드: <onboard | migrate>

### 생성된 문서
- docs/Architecture.md
- docs/PRD.md
- docs/Roadmap.md
- docs/TODO.md

### CCH 구조 (migrate 모드만)
- .claude-plugin/plugin.json
- manifests/capabilities.json, sources.json, health-rules.json
- profiles/plan.json, code.json, tool.json, swarm.json
- hooks/hooks.json

### 다음 단계
- onboard: "docs/를 확인하고 필요시 수정하세요"
- migrate: "/cch-setup 으로 CCH를 활성화하세요"
\```

migrate 모드에서는 work-item도 등록합니다:
\```bash
bin/cch work create w-cch-init-<project> "CCH Init: <project-name>"
\```
```

**Step 2: 테스트 - 스킬 frontmatter 검증 + 사용자 호출 가능 확인**

Run: `bash scripts/test.sh skill`
Expected: cch-init이 user-invocable: true로 등록, 전체 통과

**Step 3: 커밋**

```bash
git add skills/cch-init/SKILL.md
git commit -m "feat: add cch-init orchestrator skill

Orchestrates scan -> docs -> scaffold pipeline.
Supports onboard (docs only) and migrate (docs + CCH) modes.

Work-Item: w-cch-init
Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 5: 통합 테스트 추가 (#86)

**Files:**
- Create: `tests/test_cch_init.sh`

**Step 1: 테스트 파일 작성**

```bash
#!/usr/bin/env bash
# tests/test_cch_init.sh - cch-init 스킬 통합 테스트
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../scripts/test.sh" 2>/dev/null || true

# === Skill Structure Tests ===

test_cch_init_skills_exist() {
  local skills=(
    "skills/cch-init/SKILL.md"
    "skills/cch-init-scan/SKILL.md"
    "skills/cch-init-docs/SKILL.md"
    "skills/cch-init-scaffold/SKILL.md"
  )
  for skill in "${skills[@]}"; do
    assert_file_exists "$skill" "스킬 파일 존재: $skill"
  done
}

test_cch_init_frontmatter() {
  # 오케스트레이터만 user-invocable: true
  assert_contains "skills/cch-init/SKILL.md" "user-invocable: true" \
    "cch-init은 user-invocable"

  # 서브스킬은 user-invocable: false
  local sub_skills=(
    "skills/cch-init-scan/SKILL.md"
    "skills/cch-init-docs/SKILL.md"
    "skills/cch-init-scaffold/SKILL.md"
  )
  for skill in "${sub_skills[@]}"; do
    assert_contains "$skill" "user-invocable: false" \
      "$(basename $(dirname $skill))은 user-invocable: false"
  done
}

test_cch_init_allowed_tools() {
  # 오케스트레이터는 Agent 도구 필요
  assert_contains "skills/cch-init/SKILL.md" "Agent" \
    "cch-init은 Agent 도구 허용"

  # scan은 Glob, Grep 필요
  assert_contains "skills/cch-init-scan/SKILL.md" "Glob" \
    "cch-init-scan은 Glob 도구 허용"

  # docs는 Write 필요
  assert_contains "skills/cch-init-docs/SKILL.md" "Write" \
    "cch-init-docs는 Write 도구 허용"

  # scaffold는 Write 필요
  assert_contains "skills/cch-init-scaffold/SKILL.md" "Write" \
    "cch-init-scaffold는 Write 도구 허용"
}

test_cch_init_scan_schema_documented() {
  assert_contains "skills/cch-init-scan/SKILL.md" "scan-result.json" \
    "scan 스킬에 출력 스키마 문서화"
  assert_contains "skills/cch-init-scan/SKILL.md" "schema_version" \
    "scan 결과에 schema_version 필드"
}

test_cch_init_docs_templates() {
  assert_contains "skills/cch-init-docs/SKILL.md" "Architecture.md" \
    "docs 스킬에 Architecture 템플릿"
  assert_contains "skills/cch-init-docs/SKILL.md" "PRD.md" \
    "docs 스킬에 PRD 템플릿"
  assert_contains "skills/cch-init-docs/SKILL.md" "Roadmap.md" \
    "docs 스킬에 Roadmap 템플릿"
  assert_contains "skills/cch-init-docs/SKILL.md" "TODO.md" \
    "docs 스킬에 TODO 템플릿"
}

test_cch_init_scaffold_manifests() {
  assert_contains "skills/cch-init-scaffold/SKILL.md" "capabilities.json" \
    "scaffold 스킬에 capabilities 생성 로직"
  assert_contains "skills/cch-init-scaffold/SKILL.md" "sources.json" \
    "scaffold 스킬에 sources 생성 로직"
  assert_contains "skills/cch-init-scaffold/SKILL.md" "health-rules.json" \
    "scaffold 스킬에 health-rules 생성 로직"
}

test_cch_init_modes() {
  assert_contains "skills/cch-init/SKILL.md" "onboard" \
    "cch-init에 onboard 모드"
  assert_contains "skills/cch-init/SKILL.md" "migrate" \
    "cch-init에 migrate 모드"
}

test_cch_init_cross_validation() {
  assert_contains "skills/cch-init-docs/SKILL.md" "Cross-validation" \
    "docs 스킬에 문서 간 정합성 검증"
}

# === Run Tests ===

echo "=== CCH Init Skill Tests ==="
test_cch_init_skills_exist
test_cch_init_frontmatter
test_cch_init_allowed_tools
test_cch_init_scan_schema_documented
test_cch_init_docs_templates
test_cch_init_scaffold_manifests
test_cch_init_modes
test_cch_init_cross_validation
echo "=== All CCH Init Tests Passed ==="
```

**Step 2: 테스트 실행**

Run: `bash tests/test_cch_init.sh`
Expected: All CCH Init Tests Passed

**Step 3: 커밋**

```bash
git add tests/test_cch_init.sh
git commit -m "test: add cch-init skill integration tests

Verifies skill structure, frontmatter, allowed tools,
scan schema, doc templates, scaffold manifests, and modes.

Work-Item: w-cch-init
Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 6: docs/TODO.md 업데이트

**Files:**
- Modify: `docs/TODO.md`

**Step 1: Phase INIT 섹션 추가**

`docs/TODO.md`의 Phase PT 섹션 뒤에 Phase INIT 섹션을 추가합니다.
전체 항목 수 카운터를 갱신합니다 (#1~#87, 완료 60, 미완료 27).
Critical Path에 `Phase INIT` 라인을 추가합니다.
전체 Phase 의존성 요약에 `Phase INIT` 을 추가합니다.

**Step 2: 커밋**

```bash
git add docs/TODO.md
git commit -m "docs: add Phase INIT to TODO.md (#82-#87)

Adds cch-init project analysis and migration skill tasks.

Work-Item: w-cch-init
Co-Authored-By: Claude <noreply@anthropic.com>"
```
