# Roadmap: Claude Code Harness v2

- 버전: v2.1
- 갱신일: 2026-03-04
- 현재 상태: v2.0 Renewal Complete

## 1) 완료된 마일스톤

### v1 → v2 리뉴얼 (2026-03-03 ~ 2026-03-04)

전체 Phase 0~11 완료. 52개 Bead 전부 클로즈.

| Phase | 내용 | 상태 |
|-------|------|------|
| Phase 0 | v2 설계 확정 및 LW 경량화 방향 결정 | Done |
| Phase 1 | v1 코드 제거 (DOT, Resolver, 4-mode, sources) | Done |
| Phase 2 | 매니페스트 단일화 (capabilities.json) | Done |
| Phase 3 | Beads 태스크 시스템 마이그레이션 | Done |
| Phase 4 | Tier 시스템 + check-env.mjs | Done |
| Phase 5 | 코어 스킬 구현 (Enhancement 섹션 패턴) | Done |
| Phase 6 | Hook/Engine 통합 (SessionStart 추가) | Done |
| Phase 7 | v1→v2 마이그레이션 함수 | Done |
| Phase 8 | 테스트 스위트 v2 갱신 (201 tests) | Done |
| Phase 9 | 프로필 최적화 (plan.json, code.json) | Done |
| Phase 10 | 문서 동기화 (PRD, Architecture v2.1) | Done |
| Phase 11 | Superpowers 통합 (Enhancement 섹션) | Done |
| LW | 경량화 정리 (불필요 코드/파일 제거) | Done |

### v1 기반 마일스톤 (2026-03-03 이전)

v2에서 흡수/제거된 항목:

- M0~M6: Design, Plugin Contract, Install, Work Record, Release Bundle, Baseline Engine, Update Governance
- M7~M9.5: Core Stability, Policy/Status, Release Validation, Hook/Team/Doc

## 2) 현재 상태

- **버전**: 0.2.0
- **모드**: plan / code (2-mode)
- **Tier**: 0 (Core) / 1 (+Superpowers) / 2 (+MCP)
- **테스트**: 8개 파일, 201 assertions, 전부 통과
- **스킬**: 18개 (코어 8 + 유틸리티 10)
- **태스크 추적**: Beads (.beads/issues.jsonl)

## 3) 향후 로드맵

### 단기 (다음 마일스톤)

1. **cch-init 안정화**: project.yml 기반 프로젝트 초기화 워크플로우 개선
2. **LSP 통합 강화**: cch-lsp 스킬 자동 감지/설치 완성도 향상
3. **PinchTab 연동**: 웹 UI 자동화 서브시스템 안정화

### 중기

1. **CI/CD 게이트**: PR/merge 단계별 테스트 범위 정의
2. **릴리스 자동화**: dist/ 번들 빌드 스크립트 개선
3. **Beads 확장**: 마일스톤 그룹핑, 타임라인 뷰

### 장기

1. **멀티 프로젝트**: 여러 프로젝트 동시 관리
2. **메트릭 대시보드**: 생산성/품질 지표 수집 및 시각화
3. **플러그인 마켓플레이스**: 커뮤니티 스킬 공유

## 4) 추적 문서

1. `.beads/` — 태스크 SSOT (`bd ready`로 조회)
2. `docs/plans/2026-03-04-cch-v2-harness-renewal.md` — v2 리뉴얼 설계
3. `docs/plans/2026-03-04-cch-v2-lightweight-review.md` — 경량화 검토
4. `docs/plans/2026-03-04-superpowers-integration.md` — Superpowers 통합
5. `docs/TODO.md` — 전체 작업 항목 추적
