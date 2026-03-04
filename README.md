# Claude Code Harness (CCH)

Claude Code에서 동작하는 통합 오케스트레이션 프레임워크.

다중 capability source를 정책(manifest/rules) 기반으로 통합하고, 2가지 운영 모드와 35개 스킬을 제공합니다.

## Quick Start

```bash
# 1. Claude Code 플러그인 설치
/plugin install claude-code-harness

# 2. 환경 초기화
/cch-setup

# 3. 운영 모드 선택
/cch-mode code

# 4. 상태 확인
/cch-status
```

## 운영 모드

CCH는 작업 목적에 따라 2가지 모드를 제공합니다.

| 모드 | 설명 | Primary | Secondary |
|------|------|---------|-----------|
| `code` | 구현 및 개발 | omc, superpowers | — |
| `plan` | 아키텍처 설계 및 작업 분해 | superpowers | — |

```bash
/cch-mode <plan|code>
```

## Vendor(Source) 관리

CCH의 기능은 외부 vendor source에서 확장됩니다. 모든 vendor는 optional이며, 누락 시 해당 기능만 Degraded 상태로 전환됩니다.

### Vendor 목록

| Vendor | 설치 방식 | 설명 |
|--------|-----------|------|
| [oh-my-claudecode](https://github.com/Yeachan-Heo/oh-my-claudecode) | plugin | Claude Code 확장 레이어 |
| [superpowers](https://github.com/obra/superpowers) | plugin | 핵심 스킬 라이브러리 |
| [excalidraw](https://github.com/coleam00/excalidraw-diagram-skill) | npm | 다이어그램 생성 |

### 설치

```bash
# Claude Code 마켓플레이스를 통해 설치
claude plugin install superpowers@superpowers-marketplace
claude plugin install oh-my-claudecode@omc
```

## Health 시스템

CCH는 vendor 가용성에 따라 3단계 건강 상태를 자동 판정합니다.

| 상태 | 의미 |
|------|------|
| **Healthy** | 모든 필수 source 정상 |
| **Degraded** | optional source 누락, 대체 경로 적용 |
| **Blocked** | 필수 source 결손 또는 정책 위반 |

판정 규칙은 `manifests/health-rules.json`에 선언적으로 관리됩니다.

```bash
/cch-status
```

## 스킬

CCH는 35개 스킬을 제공합니다. 모두 `/` 명령으로 실행합니다.

### Core — 프레임워크 관리

| 명령 | 설명 |
|------|------|
| `/cch-setup` | 환경 초기화 |
| `/cch-mode` | 운영 모드 전환 |
| `/cch-status` | 건강 상태 조회 |
| `/cch-update` | 무결성 검증 및 업데이트 |
| `/cch-sync` | 스킬/바이너리 캐시 동기화 |
| `/cch-hud` | 상태바 설정 |
| `/cch-arch-guide` | 아키텍처 레벨 가이드 |

### SP — Superpowers 워크플로우

| 명령 | 설명 |
|------|------|
| `/cch-sp-brainstorm` | 구조화된 설계 대화 |
| `/cch-sp-write-plan` | 구현 계획 작성 |
| `/cch-sp-execute-plan` | 계획 실행 (리뷰 체크포인트 포함) |
| `/cch-sp-tdd` | Red-Green-Refactor TDD 사이클 |
| `/cch-sp-code-review` | 코드 리뷰 디스패치 |
| `/cch-sp-verify` | 완료 전 검증 |
| `/cch-sp-git-worktree` | 격리된 worktree 생성 |
| `/cch-sp-parallel-agents` | 병렬 에이전트 실행 |
| `/cch-sp-subagent-dev` | 서브에이전트 기반 개발 |
| `/cch-sp-finish-branch` | 브랜치 완료 및 정리 |
| `/cch-sp-receive-review` | 코드 리뷰 피드백 수신 |
| `/cch-sp-debug` | 체계적 디버깅 |

### Init — 프로젝트 초기화

| 명령 | 설명 |
|------|------|
| `/cch-init` | 프로젝트 분석 및 문서 생성 |
| `/cch-init-docs` | 문서 역산 생성 |
| `/cch-init-scan` | 프로젝트 심층 분석 |
| `/cch-init-scaffold` | 디렉터리 스캐폴딩 |

### PT — PinchTab 웹 테스팅

| 명령 | 설명 |
|------|------|
| `/cch-pinchtab` | 웹 UI 오케스트레이터 |
| `/cch-pt-infra` | 서버 생명주기 관리 |
| `/cch-pt-test` | 웹 UI 테스트 실행 |
| `/cch-pt-report` | 테스트 보고서 생성 |

### Utility — 공통 도구

| 명령 | 설명 |
|------|------|
| `/cch-commit` | 구조화된 커밋 생성 |
| `/cch-pr` | PR 생성 (Beads 연동) |
| `/cch-todo` | 전체 작업 현황 조회 |
| `/cch-plan` | 설계→플래닝→TODO 워크플로우 |
| `/cch-release` | 버전 릴리즈 번들 생성 |
| `/cch-team` | dev→test→verify 파이프라인 |
| `/cch-full-pipeline` | PRD→구현→검증 E2E 파이프라인 |
| `/cch-excalidraw` | Excalidraw 다이어그램 생성 |

## 프로젝트 구조

```
claude-code-harness/
├── bin/                    # 실행 파일
│   ├── cch                 # 메인 CLI
│   ├── cch-pt              # PinchTab CLI
│   └── lib/                # 공유 라이브러리
├── manifests/              # 정책 선언 파일
│   ├── sources.json        # vendor 정의 (SSOT)
│   ├── capabilities.json   # vendor별 기능/심각도 매핑
│   └── health-rules.json   # 건강 판정 규칙
├── profiles/               # 모드별 설정
│   ├── code.json
│   └── plan.json
├── skills/                 # 35개 스킬 정의
│   ├── cch-sp-*/           # Superpowers 계열
│   ├── cch-pt-*/           # PinchTab 계열
│   └── cch-*/              # Core/Utility
├── scripts/                # 빌드/테스트/유틸리티 스크립트
├── tests/                  # 테스트
├── docs/                   # PRD, Architecture, Roadmap, TODO
│   └── plans/              # 설계/실행 계획 문서
└── README.md
```

## 새 프로젝트에 CCH 도입하기

### 1. 플러그인 설치

```bash
# CCH 메인 플러그인
/plugin install claude-code-harness

# (선택) 추가 vendor 플러그인
/plugin install superpowers@superpowers-marketplace
/plugin install oh-my-claudecode@omc
```

### 2. 초기화

```bash
# 대화형 (모드 선택 프롬프트)
/cch-init

# 직접 지정
/cch-init onboard    # 문서만
/cch-init migrate    # 문서 + 스캐폴딩
```

### 3. 운영 시작

```bash
/cch-setup              # 환경 초기화
/cch-mode code          # 운영 모드 선택
/cch-status             # 상태 확인
```

## 전제 조건

- [Claude Code](https://claude.ai/claude-code) CLI
- Git
- Python + uv (excalidraw vendor 사용 시, 선택사항)

## 테스트

```bash
# 전체 테스트 실행
bash scripts/test.sh all

# 개별 레이어 실행
bash scripts/test.sh contract
bash scripts/test.sh agent
bash scripts/test.sh skill
bash scripts/test.sh workflow
bash scripts/test.sh resilience
```

## License

MIT
