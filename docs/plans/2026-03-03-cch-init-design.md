# 설계: cch-init 프로젝트 분석/마이그레이션 스킬

- 작업 ID: w-cch-init
- 생성일: 2026-03-03
- 상태: approved
- 접근방식: B (마이크로 스킬 오케스트레이션)

## 배경

현재 CCH는 잘 정의된 문서 체계(PRD/Architecture/Roadmap/TODO)를 갖추고 있으나,
다른 프로젝트에 CCH를 적용하거나 새 프로젝트를 빠르게 이해하기 위한 도구가 없다.

**목적**: 프로젝트를 깊이 분석하여 Architecture/PRD/Roadmap/TODO를 역산 추출하고,
선택적으로 CCH 구조를 스캐폴딩하는 통합 스킬 제공.

## 요구사항 (인터뷰 결과)

| 항목 | 결정 |
|------|------|
| 사용 시나리오 | 범용 온보딩 + CCH 마이그레이션 모두 |
| 분석 깊이 | 적응형 (빠른 스캔 → 사용자 선택 → 심층 분석) |
| 출력 형식 | CCH 문서 형식 (PRD/Architecture/Roadmap/TODO) |
| 실행 방식 | 파이프라인 (서브에이전트 활용) |
| 대상 범위 | 현재 작업 디렉터리 (cwd) |
| 스킬 네이밍 | `/cch-init` 단일 진입점 |
| 기존 문서 처리 | 병합 (기존 + 코드 역산 통합) |
| 마이그레이션 범위 | 문서 + CCH 스캐폴딩 + TODO 분해 |

## 스킬 구조

### 파일 구성 (4개 스킬)

```
skills/
  cch-init/SKILL.md          ← 오케스트레이터 (진입점)
  cch-init-scan/SKILL.md     ← Phase 1: 프로젝트 스캔/분석
  cch-init-docs/SKILL.md     ← Phase 2: 문서 생성
  cch-init-scaffold/SKILL.md ← Phase 3: CCH 구조 스캐폴딩
```

### 실행 흐름

```
사용자: /cch-init
    │
    ├─ Pre-check
    │   ├─ 이미 초기화된 프로젝트인지 확인 (.claude/cch/init/scan-result.json 존재?)
    │   │   ├─ YES → "이미 초기화되었습니다. 재실행하시겠습니까?" 확인
    │   │   └─ NO  → 진행
    │   └─ git 저장소인지 확인
    │       ├─ YES → git 분석 포함
    │       └─ NO  → git 분석 스킵, 경고 표시
    │
    ├─ Step 1: Scan (cch-init-scan)
    │   └─ 출력: .claude/cch/init/scan-result.json
    │
    ├─ 모드 선택: onboard(문서만) / migrate(문서+스캐폴딩+TODO)
    │
    ├─ Step 2: Docs (cch-init-docs, 병렬 에이전트)
    │   └─ 출력: docs/PRD.md, docs/Architecture.md, docs/Roadmap.md, docs/TODO.md
    │
    ├─ Step 3: Scaffold (cch-init-scaffold, migrate 모드만)
    │   └─ 출력: manifests/, profiles/, hooks/ + TODO.md 갱신
    │
    └─ Step 4: 최종 보고 + work-item 등록
```

### 중간 상태 저장

```
.claude/cch/init/
  scan-result.json    ← 스캔 결과 (Step 2/3의 입력)
  mode                ← 선택된 모드 (onboard | migrate)
  progress            ← 현재 진행 단계
```

## cch-init-scan 상세 설계

### Phase A: Quick Scan (항상 실행)

1. **프로젝트 메타데이터**
   - 언어/프레임워크 감지 (package.json, pyproject.toml, Cargo.toml, go.mod 등)
   - 빌드 도구 감지 (webpack, vite, gradle, make 등)
   - 테스트 프레임워크 감지 (jest, pytest, go test 등)
   - CI/CD 감지 (.github/workflows, .gitlab-ci.yml 등)

2. **디렉터리 구조 스냅샷**
   - 상위 2-depth 트리
   - 주요 진입점 파일 식별 (main, index, app, server 등)
   - 파일 규모 통계 (총 파일 수, 코드 파일 수, LOC 추정)

3. **기존 문서 수집**
   - README.md, CONTRIBUTING.md, CHANGELOG.md
   - docs/ 디렉터리 전체
   - API 문서 (openapi.yaml, swagger 등)
   - 기존 Architecture/PRD 문서 존재 여부

4. **Git 히스토리 개요**
   - 최근 50개 커밋 메시지 분석 (패턴/카테고리 추출)
   - 주요 기여자, 태그/릴리즈 히스토리, 활성 브랜치

### Phase B: Deep Scan (사용자 선택 영역만)

5. **아키텍처 분석**: 모듈/패키지 의존성, 레이어 구조, 외부 의존성, 디자인 패턴
6. **기능 분석**: API 엔드포인트, 도메인 모델, 비즈니스 로직 흐름, 설정/환경변수
7. **품질/운영 분석**: 테스트 커버리지, 에러 핸들링, 로깅/모니터링, 보안 패턴
8. **로드맵 역산 자료**: git 태그 → 마일스톤, TODO/FIXME/HACK 주석, 최근 변경 영역

### scan-result.json 스키마

```json
{
  "schema_version": "1.0",
  "scanned_at": "ISO8601",
  "project": {
    "name": "string",
    "root": "string",
    "languages": ["string"],
    "frameworks": ["string"],
    "build_tools": ["string"],
    "test_frameworks": ["string"],
    "ci_cd": ["string"],
    "file_stats": { "total": 0, "code": 0, "loc_estimate": 0 }
  },
  "existing_docs": {
    "readme": "string | null",
    "architecture": "string | null",
    "prd": "string | null",
    "changelog": "string | null",
    "api_docs": "string | null",
    "other": ["string"]
  },
  "git_summary": {
    "total_commits": 0,
    "contributors": 0,
    "tags": ["string"],
    "recent_patterns": ["string"],
    "active_branches": ["string"]
  },
  "deep_scan": {
    "architecture": {},
    "features": {},
    "quality": {},
    "roadmap_hints": {}
  }
}
```

### 사용 도구

| 분석 항목 | 도구 |
|-----------|------|
| 디렉터리 스캔 | Glob, `mcp__serena__list_dir` |
| 심볼 분석 | `mcp__serena__get_symbols_overview`, `mcp__serena__find_symbol` |
| 패턴 검색 | Grep, `mcp__serena__search_for_pattern` |
| Git 분석 | Bash (`git log`, `git tag`) |
| 문서 수집 | Read |

## cch-init-docs 상세 설계

### 문서 생성 전략

```
입력: scan-result.json + 기존 문서(있으면)
    │
    ├─ 기존 문서 존재?
    │   ├─ YES → 병합 모드
    │   └─ NO  → 생성 모드
    │
    ↓ 4개 병렬 에이전트
    │
    ├─ Architecture.md (architect 에이전트)
    ├─ PRD.md (analyst 에이전트)
    ├─ Roadmap.md (planner 에이전트)
    └─ TODO.md (executor 에이전트)
    │
    ↓ Cross-validation (순차)
```

### 문서별 생성 매핑

#### Architecture.md

| 섹션 | 소스 |
|------|------|
| 아키텍처 목표 | frameworks + design patterns + README |
| 레이어와 컴포넌트 | 모듈 의존성 그래프 + 레이어 구조 |
| 컴포넌트 책임 | 주요 클래스/모듈 심볼 분석 |
| 데이터 흐름 | API 엔드포인트 + 도메인 모델 + 외부 의존성 |
| 기술 스택 | languages, frameworks, build_tools, test_frameworks |
| 인프라/배포 | CI/CD + Dockerfile + 환경변수 |
| 테스트 아키텍처 | 테스트 파일 분포 + 테스트 프레임워크 |

#### PRD.md (역산)

| 섹션 | 소스 |
|------|------|
| 제품 정의 | README + 진입점 분석 |
| 해결할 문제 | README + 기존 문서 + 도메인 모델 |
| 기능 요구사항 (F1, F2...) | API 엔드포인트 + 라우팅 + UI 컴포넌트 |
| 비기능 요구사항 | 에러 핸들링/로깅/인증/성능 패턴 |
| 제약조건 | 의존성, 환경변수, 설정 파일 |
| 범위 | 현재 구현 = In Scope, TODO/FIXME = Out of Scope 후보 |

#### Roadmap.md (역산)

| 섹션 | 소스 |
|------|------|
| 완료된 마일스톤 | git 태그 + 릴리즈 히스토리 |
| 현재 진행 중 | 활성 브랜치 + 최근 커밋 패턴 |
| 예정 항목 | TODO/FIXME 주석 + 미완성 기능 |
| 기술 부채 | HACK 주석 + deprecated 패턴 |

#### TODO.md (역산)

| 섹션 | 소스 |
|------|------|
| Critical Path | Roadmap 마일스톤 → Phase → 의존성 그래프 |
| Phase N | 각 마일스톤의 작업 항목 분해 |
| 의존성 그래프 | Phase 간/내 의존성 |

### 병합 모드 동작

| 상황 | 동작 |
|------|------|
| 기존 문서에 있고, 코드와 일치 | 기존 내용 유지 |
| 기존 문서에 있지만, 코드와 불일치 | `[!코드 불일치]` 마커 + 코드 기반 보강 |
| 기존 문서에 없고, 코드에서 발견 | 새 섹션 추가 + `[코드에서 역산]` 마커 |
| 기존 문서에 있지만, 코드에서 미확인 | `[코드에서 미확인]` 마커 유지 |

### Cross-validation

1. Architecture 컴포넌트 <-> PRD 기능: 모든 기능이 컴포넌트에 매핑되는가?
2. Roadmap 마일스톤 <-> TODO Phase: 1:1 대응하는가?
3. TODO 항목 <-> PRD 기능: 모든 미완료 기능이 TODO에 있는가?
4. 용어 일관성: 4개 문서에서 같은 개념을 같은 이름으로 부르는가?

## cch-init-scaffold 상세 설계

### 생성 구조 (migrate 모드 전용)

```
<project-root>/
  .claude-plugin/
    plugin.json              ← 프로젝트 메타 기반 자동 생성
  hooks/
    hooks.json               ← 기본 hook 등록
  manifests/
    capabilities.json        ← 감지된 소스 기반 생성
    sources.json             ← 외부 소스 정의
    health-rules.json        ← 기본 헬스 규칙
  profiles/
    plan.json                ← 4모드 프로필
    code.json
    tool.json
    swarm.json
```

### manifests 생성 규칙

#### capabilities.json

| scan 결과 | capabilities 반영 |
|-----------|------------------|
| `.claude/plugins/`에 플러그인 감지 | `check_strategy: "plugin"` |
| `node_modules/` 기반 도구 감지 | `check_strategy: "npm"` |
| git submodule 감지 | `check_strategy: "git"` |
| 로컬 내장 도구 | `check_strategy: "local"` |
| 미감지 (기본) | superpowers + omc 기본 세트 제안 |

#### sources.json

Phase 3S (`#56`)의 `install_type` 체계와 완전 호환:
- `plugin`, `npm`, `git`, `local` 4개 설치 유형 지원

#### health-rules.json

프로젝트에서 감지된 소스에 대해서만 규칙 생성. 없는 소스는 규칙도 없음.

### profiles 생성 규칙

| 프로젝트 특성 | 프로필 조정 |
|--------------|-----------|
| 프론트엔드 위주 | `code` 모드에 UI capabilities 추가 |
| API 서버 위주 | `tool` 모드에 API 도구 capabilities 강조 |
| 모노레포 | `swarm` 모드에 병렬 작업 세분화 |
| 단일 모듈 | `swarm` 모드 비활성 권장 |

### hooks 생성

CCH 기본 hook 세트 복사. 프로젝트 기존 hooks가 있으면 병합.

### Roadmap → TODO 자동 분해

```
Roadmap.md 파싱
    ├─ 완료된 마일스톤 → - [x] **#N** <제목> _(날짜 완료)_
    ├─ 진행 중 마일스톤 → - [ ] **#N** <제목>
    └─ 예정 마일스톤 → - [ ] **#N** <제목>

의존성 자동 생성:
    ├─ Phase 간: 이전 Phase Gate → 다음 Phase 첫 항목
    └─ Phase 내: 순차 의존 (추론, 사용자 확인 권장)
```

### 검증 체크리스트

1. plugin.json 유효성 (필수 필드 존재)
2. manifests/*.json JSON 파싱 성공
3. profiles/*.json 4개 모드 존재
4. TODO.md 번호 연속성 + 의존성 순환 없음
5. docs/ 4개 문서 존재 + 상호 참조 유효
6. cch setup 실행 가능 여부 (dry-run)

## TODO 통합 (Phase INIT)

### 신규 항목

```
- [ ] #82 cch-init-scan 스킬 구현
  - 의존: #21

- [ ] #83 cch-init-docs 스킬 구현
  - 의존: #82

- [ ] #84 cch-init-scaffold 스킬 구현
  - 의존: #83

- [ ] #85 cch-init 오케스트레이터 스킬 구현
  - 의존: #82, #83, #84

- [ ] #86 cch-init 통합 테스트
  - 의존: #85
```

### 의존성 그래프

```
#21 (테스트 6레이어)
 └─ #82 cch-init-scan
     └─ #83 cch-init-docs
         └─ #84 cch-init-scaffold
             └─ #85 cch-init 오케스트레이터
                 └─ #86 cch-init 통합 테스트
```

### 기존 Phase 연동

| Phase INIT | 기존 Phase | 연동 |
|-----------|-----------|------|
| #82 (scan) | #56 (sources.json) | install_type 체계 참조 |
| #84 (scaffold) | #32 (health-rules.json) | 동일 스키마 사용 |
| #84 (scaffold) | #56~#60 (Phase 3S) | sources.json 호환 |
| #85 (orchestrator) | #51 (cch-team) | 동일 파이프라인 패턴 |
