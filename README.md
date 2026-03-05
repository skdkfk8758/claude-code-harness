# Claude Code Harness (CCH)
> Claude Code 경량 오케스트레이션 플러그인

## 개요
CCH는 Claude Code에서 동작하는 경량 오케스트레이션 플러그인이다. Tier 기반 환경 감지, Hook 자동화를 제공하며, 설계→구현→검증 파이프라인을 통합한다.

## Quick Start

```bash
# 1. Claude Code 플러그인 설치
/plugin install claude-code-harness

# 2. 환경 초기화
/cch-setup

# 3. 상태 확인
/cch-status
```

## 스킬 목록

### Core (8개)

| 스킬 | 설명 |
|------|------|
| cch-setup | Initialize Claude Code Harness environment. Checks paths, permissions, creates state directory, and validates capability sources. |
| cch-plan | 설계(인터뷰) → 플래닝 → TODO 작성 통합 워크플로우. Smart Entry로 입력 상태에 따라 적절한 Phase부터 시작. |
| cch-commit | Analyze changes and create logical, well-structured commits with Plan trailers. |
| cch-todo | Show all tasks from plan documents and current session TaskList. |
| cch-verify | Verify implementation before claiming completion. Runs tests, checks output, validates against spec. |
| cch-review | Code review checklist with optional subagent dispatch. Reviews implementation against spec and coding standards. |
| cch-status | Show CCH health status including current mode, tier, health state, and reason codes. |
| cch-pr | Create a pull request with plan references, TODO linking, and structured description. |

### Utility (10개)

| 스킬 | 설명 |
|------|------|
| cch-init | 프로젝트 분석 및 CCH 마이그레이션 — 스캔→문서→스캐폴딩 통합 파이프라인 |
| cch-init-scan | 프로젝트 심층 분석 — 메타데이터/구조/문서/git/아키텍처 스캔 |
| cch-init-docs | 프로젝트 문서 역산 생성 — Architecture/PRD/Roadmap/TODO 4개 문서 자동 생성 |
| cch-init-scaffold | CCH 구조 스캐폴딩 — 디렉터리/매니페스트/프로필/훅 자동 생성 |
| cch-arch-guide | 프로젝트 복잡도 인터뷰를 통한 아키텍처 레벨 결정 및 구조 스캐폴딩 |
| cch-excalidraw | Excalidraw 다이어그램 생성 — 워크플로우, 아키텍처, 개념을 시각화 |
| cch-lsp | Project LSP detection/installation — file scan, interview, LSP server install, Serena config |
| cch-pinchtab | PinchTab 기반 웹 UI 디버깅/테스트/워크플로우 오케스트레이터 |
| cch-team | Run dev->test->verify pipeline with automatic documentation |
| cch-full-pipeline | End-to-end: PRD interview -> team build -> parallel implementation -> verification -> delivery. |

## 스크립트

| 스크립트 | 용도 |
|---------|------|
| test.sh | 테스트 하네스 실행 |
| check-env.mjs | 환경 검증 (Tier/Plugin/MCP 감지) |
| mode-detector.sh | Hook 기반 모드 감지 |
| plan-bridge.mjs | Plan 모드 브릿지 |
| summary-writer.mjs | 세션 Q&A 요약 기록 |
| activity-tracker.mjs | 활동 추적 |

## 설치 및 설정

```bash
# CCH 플러그인 설치
/plugin install claude-code-harness

# 초기화
/cch-init
```

## 문서

- [PRD](docs/PRD.md)
- [Architecture](docs/Architecture.md)
- [Roadmap](docs/Roadmap.md)

## 테스트

```bash
# 전체 테스트 실행
bash scripts/test.sh all

# 개별 레이어
bash scripts/test.sh contract
bash scripts/test.sh skill
bash scripts/test.sh workflow
bash scripts/test.sh resilience
bash scripts/test.sh branch
```

## License

MIT
