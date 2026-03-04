---
name: cch-init-scan
description: "프로젝트 심층 분석 — 메타데이터/구조/문서/git/아키텍처 스캔"
user-invocable: false
allowed-tools: [Glob, Grep, Bash, Read, Agent, mcp__serena__get_symbols_overview, mcp__serena__find_symbol, mcp__serena__search_for_pattern, mcp__serena__list_dir]
---

# cch-init-scan

프로젝트를 심층 분석하여 아키텍처, PRD, 로드맵, TODO 정보를 추출합니다. CCH Phase INIT 시스템의 일부로, 기존 프로젝트를 CCH에 온보딩할 때 사용됩니다.

## Steps

### Phase 1: Quick Scan (자동 실행, 병렬)

아래 4개 분석을 병렬로 실행합니다.

#### 1-A. 메타데이터 분석
- `package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`, `pom.xml`, `build.gradle`, `composer.json` 등 프로젝트 매니페스트 파일을 Glob으로 탐색
- 프로젝트 이름, 버전, 설명, 라이선스, 의존성(직접/개발) 추출
- 결과를 `metadata` 객체에 저장

#### 1-B. 구조 분석
- `mcp__serena__list_dir` (depth 2) 또는 `Bash: find . -maxdepth 2 -type d` 로 디렉터리 트리 수집
- 파일 수 및 유형 분포: `Bash: find . -type f | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -20`
- 주요 진입점 식별: `index.*`, `main.*`, `app.*`, `server.*`, `cmd/` 등 Glob으로 탐색
- 결과를 `structure` 객체에 저장

#### 1-C. 문서 분석
- `README*`, `docs/**`, `CHANGELOG*`, `CONTRIBUTING*`, `LICENSE*` 를 Glob으로 탐색
- 발견된 각 문서의 첫 100줄을 Read하여 요약 생성
- 결과를 `documentation` 객체에 저장

#### 1-D. Git 분석
아래 Bash 명령으로 Git 메타데이터 수집:
```bash
# 커밋 수
git rev-list --count HEAD

# 브랜치 수
git branch -a | wc -l

# 최근 10개 커밋 (날짜, 메시지)
git log --oneline --date=short --format="%ad %s" -10

# 주요 기여자 (커밋 수 기준 상위 5명)
git shortlog -sn --no-merges | head -5

# 태그/릴리즈 목록
git tag -l | tail -10

# 최근 활동 일자
git log -1 --format="%ad" --date=iso
```
결과를 `git` 객체에 저장.

---

### Phase 2: Deep Scan (사용자 선택 영역)

Quick Scan 완료 후, 아래 질문으로 사용자가 분석할 영역을 선택하게 합니다:

> "Quick Scan이 완료되었습니다. Deep Scan을 진행할 영역을 선택하세요 (복수 선택 가능):
> 1. 아키텍처 분석 (레이어 구조, 모듈 의존성, 핵심 흐름 추적)
> 2. 기능 분석 (API 엔드포인트, CLI 명령어, 이벤트/훅 시스템)
> 3. 품질 분석 (테스트 커버리지, 린터 설정, CI/CD 파이프라인)
> 4. 로드맵 분석 (TODO/FIXME/HACK 주석, 미완성 기능 식별)
> 5. 전체 (1-4 모두)
> 6. 건너뛰기 (Quick Scan 결과만 저장)"

선택된 항목만 실행합니다.

#### 2-1. 아키텍처 분석 (선택 시)
- `mcp__serena__get_symbols_overview` 로 주요 파일의 심볼 구조 파악
- `mcp__serena__find_symbol` 로 핵심 클래스/함수 탐색
- `mcp__serena__search_for_pattern` 으로 import/require 패턴 분석하여 모듈 의존성 매핑
- 진입점에서 핵심 흐름 추적 (최대 3단계 깊이)
- 레이어 구조 추론: 프레젠테이션 / 비즈니스 로직 / 데이터 접근 / 인프라
- 결과를 `architecture` 객체에 저장

#### 2-2. 기능 분석 (선택 시)
- API 엔드포인트: Grep으로 `app\.(get|post|put|delete|patch)`, `@Get\(`, `@Post\(`, `router\.`, `route(` 패턴 탐색
- CLI 명령어: Grep으로 `commander`, `yargs`, `argv`, `program\.command` 패턴 탐색
- 이벤트/훅 시스템: Grep으로 `addEventListener`, `on\(`, `emit\(`, `EventEmitter`, `hook` 패턴 탐색
- 결과를 `features` 객체에 저장

#### 2-3. 품질 분석 (선택 시)
- 테스트 파일 탐색: `**/*.test.*`, `**/*.spec.*`, `tests/**`, `__tests__/**` Glob
- 테스트 프레임워크 식별: jest, vitest, pytest, go test 등
- 린터 설정 파일: `.eslintrc*`, `.prettierrc*`, `pylintrc`, `golangci*` Glob
- CI/CD 파이프라인: `.github/workflows/**`, `.gitlab-ci*`, `Jenkinsfile`, `.circleci/**` Glob
- 결과를 `quality` 객체에 저장

#### 2-4. 로드맵 분석 (선택 시)
- TODO/FIXME/HACK 주석: `Grep: TODO|FIXME|HACK|XXX|BUG|NOTE` (파일별 카운트 포함)
- 미완성 기능 신호: `not implemented`, `stub`, `placeholder`, `coming soon` Grep
- 버전 마일스톤: CHANGELOG, milestone 파일에서 미완료 항목 탐색
- 결과를 `roadmap_signals` 객체에 저장

---

### Phase 3: 결과 저장

1. 결과 디렉터리 생성:
```bash
mkdir -p .claude/cch/init
```

2. 아래 스키마로 JSON 파일 작성 (`.claude/cch/init/scan-result.json`):
```json
{
  "schema_version": "1.0",
  "project_name": "",
  "scan_type": "quick|deep",
  "scanned_at": "",
  "metadata": {},
  "structure": {},
  "documentation": {},
  "git": {},
  "architecture": {},
  "features": {},
  "quality": {},
  "roadmap_signals": {}
}
```
- `scan_type`: Quick Scan만 실행했으면 `"quick"`, Deep Scan 항목이 하나라도 포함되면 `"deep"`
- `scanned_at`: ISO 8601 형식의 현재 시각
- Deep Scan을 건너뛴 영역의 객체는 `{}` 로 유지

3. 저장 완료 후 요약 리포트를 사용자에게 출력:
   - 프로젝트 이름 및 감지된 기술 스택
   - 스캔 유형 및 완료된 분석 영역
   - 주요 발견사항 (상위 3-5개)
   - 저장 경로: `.claude/cch/init/scan-result.json`
