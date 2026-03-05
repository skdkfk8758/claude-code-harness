# CCH v3 Renewal - Implementation Plan

- 작성일: 2026-03-05
- 상태: Ready
- 선행 문서: `2026-03-05-v3-renewal-analysis.md`
- Branch: (v3 작업 시 새로 생성)

---

## Phase 0: Archive & Clean Slate

기존 v2 코드/문서를 아카이브하고 클린 베이스라인을 확보한다.

### Tasks

- [ ] T0-1: `archive/v2/` 디렉터리 생성 및 기존 플랜 이동
- [ ] T0-2: `.beads/` 디렉터리 아카이브 후 삭제
- [ ] T0-3: 외부 플러그인 비활성화 (`settings.json` enabledPlugins)
- [ ] T0-4: `archive/v2/` 커밋 (아카이브 보존용)
- [ ] T0-5: v2 아카이브 태그 생성 (`git tag v2-archive`)

---

## Phase 1: External Dependency Removal

외부 플러그인 및 Beads 참조를 코드베이스에서 제거한다.

### Tasks

- [ ] T1-1: `bin/lib/beads.sh` 삭제
- [ ] T1-2: `bin/cch` 에서 beads 서브커맨드 및 Tier 분기 로직 제거
- [ ] T1-3: `bin/lib/skill.sh` 에서 superpowers 캐시 스캔 코드 제거
- [ ] T1-4: `manifests/capabilities.json` 에서 superpowers 소스 제거
- [ ] T1-5: `profiles/code.json`, `profiles/plan.json` 에서 superpowers 참조 제거
- [ ] T1-6: `scripts/check-env.mjs` 에서 superpowers 체크 제거
- [ ] T1-7: `scripts/plan-bridge.mjs` 에서 beads create 호출 제거
- [ ] T1-8: `scripts/lib/core.mjs` 에서 beads list 호출 제거
- [ ] T1-9: `scripts/lib/bridge-output.mjs` 에서 bead_id 참조 제거
- [ ] T1-10: `AGENTS.md` 에서 bd 기반 지시 제거 (Phase 3에서 새로 작성)

---

## Phase 2: Skill Rewrite

스킬에서 Beads/superpowers Enhancement 참조를 제거하고, 핵심 로직을 내재화한다.

### Tasks

- [ ] T2-1: `cch-plan` — Phase 3 Beads -> Markdown-as-State 체크박스 방식으로 전환
  - `bd create` -> 플랜 문서 체크박스
  - `bd dep` -> `blocked-by:` 텍스트
  - `bd ready` -> 플랜 문서 미완료 항목 추출
  - Brainstorming hard gate를 Phase 1 본문으로 승격
- [ ] T2-2: `cch-commit` — `Bead:` 트레일러 -> `Plan:` 트레일러, Enhancement 섹션 제거
- [ ] T2-3: `cch-todo` — `bd ready`/`bd list` -> 플랜 문서 + TaskList 조합
- [ ] T2-4: `cch-pr` — Bead 링크 -> Plan 문서 링크
- [ ] T2-5: `cch-review` — Enhancement 섹션 제거, Two-stage review 핵심만 본문 흡수
- [ ] T2-6: `cch-verify` — Enhancement 섹션 제거
- [ ] T2-7: `cch-team` — `bd create`/`bd close` -> TaskList 전용
- [ ] T2-8: `cch-init-scaffold` — Beads 항목 생성 -> 플랜 문서 체크박스
- [ ] T2-9: `cch-init` — Bead 생성 참조 제거
- [ ] T2-10: `cch-status` — Bead 상태 표시 제거
- [ ] T2-11: `cch-setup` — Enhancement 섹션 제거, Tier 표시 단순화
- [ ] T2-12: `cch-skill-manager` — Enhancement 섹션 제거
- [ ] T2-13: (신규) `cch-debug` 스킬 생성 — systematic-debugging 4단계 직접 기술 (~150줄)

---

## Phase 3: Persistence Layer Setup

네이티브 4층 영속성 구조를 구축한다.

### Tasks

- [ ] T3-1: `CLAUDE.md` 생성 — 프로젝트 규칙 + 세션 프로토콜 + Iron Law 원칙문
- [ ] T3-2: `AGENTS.md` 재작성 — bd 참조 제거, 새 프로토콜 반영
- [ ] T3-3: auto-memory `MEMORY.md` 초기 설정 — 현재 상태 요약 템플릿
- [ ] T3-4: Markdown-as-State 플랜 문서 포맷 표준 정의 (docs/guide/)
- [ ] T3-5: SessionStart 훅 구현 — `git log --oneline -5` + 진행 중 플랜 감지
- [ ] T3-6: 세션 종료 프로토콜을 CLAUDE.md에 명시 (플랜 체크박스 업데이트, memory 갱신)

---

## Phase 4: Test & Config Cleanup

테스트와 설정 파일을 v3 구조에 맞게 정리한다.

### Tasks

- [ ] T4-1: `tests/test_beads.sh` 삭제
- [ ] T4-2: `scripts/test.sh` 에서 beads 테스트 레이어 제거
- [ ] T4-3: `tests/unit/check-env.test.mjs` — superpowers assertions 제거/수정
- [ ] T4-4: `tests/unit/core-tier.test.mjs` — Tier 1 superpowers 테스트 수정
- [ ] T4-5: `tests/test_check_env.sh` — superpowers assert 제거
- [ ] T4-6: `tests/test_workflow.sh` — beads 참조 제거
- [ ] T4-7: 전체 테스트 실행 및 통과 확인

---

## Phase 5: Documentation Update

문서를 v3 구조에 맞게 갱신한다.

### Tasks

- [ ] T5-1: `docs/PRD.md` — Tier 시스템 제거, 영속성 레이어 설명 갱신
- [ ] T5-2: `docs/Architecture.md` — Enhancement/Tier 제거, 4층 영속성 구조 반영
- [ ] T5-3: `docs/Roadmap.md` — superpowers 통합 계획 제거, v3 로드맵 반영
- [ ] T5-4: `docs/plugin-components-reference.md` — superpowers/kkirikkiri 섹션 제거
- [ ] T5-5: `docs/diagrams/cch-workflows.md` — superpowers 분기 제거
- [ ] T5-6: `README.md` — superpowers 설치 가이드 제거, v3 소개로 갱신

---

## Phase 6: External Plugin Cleanup

외부 플러그인 실제 삭제 및 설정 정리.

### Tasks

- [ ] T6-1: `~/.claude/settings.json` 에서 enabledPlugins 정리 (superpowers, kkirikkiri 제거)
- [ ] T6-2: 플러그인 캐시 정리 (superpowers-marketplace, gptaku-plugins 디렉터리)
- [ ] T6-3: `known_marketplaces.json` 정리
- [ ] T6-4: `installed_plugins.json` 정리
- [ ] T6-5: oh-my-claudecode 관련 설정 정리
- [ ] T6-6: `.claude/settings.local.json` (프로젝트) 에서 불필요한 permission 정리

---

## Phase 7: Verification & Tag

최종 검증 후 v3 태그를 생성한다.

### Tasks

- [ ] T7-1: 전체 테스트 스위트 실행 (`bash scripts/test.sh all`)
- [ ] T7-2: 모든 스킬의 Skill tool 호출 정상 확인 (핵심 5개)
- [ ] T7-3: SessionStart 훅 동작 확인 (새 세션에서 컨텍스트 자동 주입)
- [ ] T7-4: 플랜 문서 Markdown-as-State 워크플로우 수동 검증
- [ ] T7-5: git tag v3.0.0 생성

---

## Dependency Graph

```
Phase 0 (Archive)
    |
Phase 1 (Dependency Removal)  ----+
    |                              |
Phase 2 (Skill Rewrite)      Phase 4 (Test Cleanup)
    |                              |
Phase 3 (Persistence Setup)       |
    |                              |
    +--------- Phase 5 (Docs) ----+
                   |
              Phase 6 (Plugin Cleanup)
                   |
              Phase 7 (Verification)
```

- Phase 1, 2, 4는 서로 독립적이므로 병렬 작업 가능
- Phase 3은 Phase 2 완료 후 (스킬이 새 영속성 구조를 참조하므로)
- Phase 5는 Phase 2, 3, 4 모두 완료 후
- Phase 6은 코드 변경이 모두 안정화된 후
- Phase 7은 모든 Phase 완료 후

---

## Decisions Log

| 결정 | 이유 |
|------|------|
| superpowers 14개 스킬 중 2개만 내재화 | 70%가 상식 강제 주입, 나머지는 CCH가 이미 커버 |
| Beads 완전 제거 | 외부 의존성 일관성 + 사용 패턴(98/100 closed) |
| Tier 시스템 제거 | Tier 0만으로 통일. 조건부 분기 제거로 코드 단순화 |
| 4층 영속성 | 모두 Claude Code 네이티브. 추가 도구 0 |
| Markdown-as-State | 사람/AI 모두 읽기 쉽고, git 추적, 추가 파싱 도구 불필요 |
