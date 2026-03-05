# Roadmap: Claude Code Harness v3

- 버전: v3.0
- 갱신일: 2026-03-05
- 현재 상태: v3.0 Renewal In Progress

## 1) 완료된 마일스톤

### v2 → v3 리뉴얼 (2026-03-05)

외부 의존성(Beads, superpowers) 완전 제거 및 기능 내재화.

| Phase | 내용 | 상태 |
|-------|------|------|
| Phase 0 | v2 아카이브 (plans, beads, config snapshots) | Done |
| Phase 1 | 외부 의존성 제거 (bin/, scripts/, manifests/, profiles/) | Done |
| Phase 2 | 스킬 재작성 (13개 스킬 beads/superpowers/Enhancement 제거) | Done |
| Phase 3 | 문서 갱신 (AGENTS.md, README, Architecture, PRD, Roadmap) | Done |
| Phase 4 | 테스트 정리 및 전체 통과 확인 | In Progress |
| Phase 5 | 문서 최종 정리 | Pending |
| Phase 6 | 외부 플러그인 설정/캐시 정리 | Pending |
| Phase 7 | 최종 검증 + v3.0.0 태그 | Pending |

### v1 → v2 리뉴얼 (2026-03-03 ~ 2026-03-04)

전체 Phase 0~11 완료. v2 아키텍처 확립.

| Phase | 내용 | 상태 |
|-------|------|------|
| Phase 0 | v2 설계 확정 및 LW 경량화 방향 결정 | Done |
| Phase 1 | v1 코드 제거 (DOT, Resolver, 4-mode, sources) | Done |
| Phase 2 | 매니페스트 단일화 (capabilities.json) | Done |
| Phase 3 | Beads 태스크 시스템 도입 | Done |
| Phase 4 | Tier 시스템 + check-env.mjs | Done |
| Phase 5 | 코어 스킬 구현 | Done |
| Phase 6 | Hook/Engine 통합 | Done |
| Phase 7 | v1→v2 마이그레이션 | Done |
| Phase 8 | 테스트 스위트 v2 갱신 | Done |
| Phase 9 | 프로필 최적화 | Done |
| Phase 10 | 문서 동기화 | Done |
| Phase 11 | Superpowers 통합 | Done |

## 2) 현재 상태

- **버전**: 0.2.0 → 3.0.0 (진행 중)
- **모드**: plan / code (2-mode)
- **Tier**: 0 (Core) / 1 (+Plugin) / 2 (+MCP)
- **스킬**: 18개 (코어 8 + 유틸리티 10)
- **태스크 추적**: 플랜 문서 (`docs/plans/`)

## 3) 향후 로드맵

### 단기 (다음 마일스톤)

1. **v3.0.0 릴리스**: 외부 의존성 제거 완료 + 태그 발행
2. **cch-init 안정화**: 프로젝트 초기화 워크플로우 개선
3. **LSP 통합 강화**: cch-lsp 스킬 자동 감지/설치 완성도 향상

### 중기

1. **CI/CD 게이트**: PR/merge 단계별 테스트 범위 정의
2. **릴리스 자동화**: dist/ 번들 빌드 스크립트 개선
3. **PinchTab 연동**: 웹 UI 자동화 서브시스템 안정화

### 장기

1. **멀티 프로젝트**: 여러 프로젝트 동시 관리
2. **메트릭 대시보드**: 생산성/품질 지표 수집 및 시각화
3. **플러그인 마켓플레이스**: 커뮤니티 스킬 공유

## 4) 추적 문서

1. `docs/plans/2026-03-05-v3-renewal-plan.md` — v3 리뉴얼 계획
2. `docs/plans/2026-03-05-v3-execution-design.md` — v3 실행 설계
3. `docs/plans/2026-03-05-v3-cleanup-guide.md` — v3 정리 가이드
4. `archive/v2/plans/` — v2 설계 문서 (아카이브)
