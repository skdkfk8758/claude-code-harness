# Plan/TODO 관리 전략 통합 설계

> **목표:** 3중 관리(Beads + TaskList + docs/TODO.md)를 Beads SSOT 단일 체계로 통합하고,
> CCH↔superpowers 경계를 명확히 정의한다.

**작성일:** 2026-03-04
**상태:** 설계 초안

---

## 1. 현재 문제 진단

### 1-1. 3중 관리 상태

```
docs/TODO.md      ← 수동 Markdown, git 추적, 사람이 편집
Beads (.beads/)   ← bd CLI, git 추적, 영속적
TaskList          ← Claude 내장, 세션 종료 시 소멸
```

세 시스템이 각각 독립적으로 동작하며, 동기화 메커니즘이 없다.
`cch-plan` Phase 3의 dual-write(Beads + TaskCreate 동시 작성)는 생성 시점만 동기화하고,
이후 상태 변경은 각자 독립적으로 진행되어 불일치가 발생한다.

### 1-2. SSOT 혼란

- `cch-todo`는 "Beads가 SSOT"라고 선언
- `cch-plan`은 Beads + TaskCreate dual-write
- superpowers `executing-plans`/`subagent-driven-development`는 TaskList만 참조
- `docs/TODO.md`는 어디에도 연결되지 않은 별도 채널

→ 실행 중 실제로 참조되는 것은 **TaskList**이지만, 세션이 끝나면 **소멸**한다.

### 1-3. 래퍼 스킬 오버헤드

`cch-sp-*` 12개 스킬이 superpowers 스킬을 1:1 래핑하지만,
대부분 Beads 연동 없이 단순 위임만 수행한다.
래퍼 유지보수 비용만 발생하고 실질적 가치 추가가 없다.

---

## 2. 설계 원칙

1. **Beads = 유일한 SSOT** — 프로젝트 수준 작업은 Beads에만 존재
2. **TaskList = 세션 실행 뷰** — Beads에서 pull하여 현재 세션 작업만 표시
3. **Pull Model** — dual-write 대신, 필요 시점에 Beads→TaskList 단방향 동기화
4. **CCH는 레이어** — superpowers 위에서 영속성/컨텍스트/편의를 추가
5. **래퍼 금지** — superpowers 스킬을 직접 사용, CCH는 고유 가치가 있는 스킬만 보유

---

## 3. 목표 아키텍처

### 3-1. 저장소 단일화

```
[제거] docs/TODO.md
[유지] .beads/issues.jsonl  ← 유일한 SSOT (영속, git 추적)
[유지] TaskList              ← 세션 실행 뷰 (휘발, Beads에서 hydrate)
```

### 3-2. 데이터 흐름

```
생성 시:
  cch-plan Phase 3 → Beads에만 기록 (TaskCreate 하지 않음)

세션 시작 / 실행 시작 시 (hydrate):
  Beads (bd ready) → TaskCreate로 현재 배치만 로드

실행 중:
  superpowers 스킬이 TaskList 참조 (기존 동작 유지)

태스크 완료 시 (flush):
  TaskList completed → Beads transition done

세션 종료 시:
  TaskList 소멸 (OK — Beads에 상태 이미 반영됨)
  다음 세션에서 bd ready로 미완료 작업 재hydrate
```

### 3-3. Hydrate/Flush 메커니즘

#### Hydrate (Beads → TaskList)

```
cch-plan 실행 시 또는 세션 초반에:

1. bash bin/cch beads ready --limit N --json
2. 결과를 파싱하여 TaskCreate 호출
   - subject: "[Phase코드] <Bead 제목>"
   - description: Bead 상세 + 플랜 문서 참조
   - metadata: { beadId: "<bead-id>" }
3. 의존성 매핑: Beads dep → TaskCreate addBlockedBy
```

#### Flush (TaskList → Beads)

```
태스크 완료 시 (superpowers 스킬 또는 수동):

1. TaskUpdate status: completed
2. metadata.beadId 확인
3. bash bin/cch beads transition <beadId> done
```

→ **핵심:** 이 flush는 `cch-plan` 스킬이나 훅에서 자동 수행.
superpowers 스킬은 TaskList만 쓰면 되고, Beads를 직접 건드리지 않는다.

### 3-4. 레이어 경계

```
┌─────────────────────────────────────────────┐
│  CCH Layer (고유 가치)                        │
│                                             │
│  ┌─────────────┐  ┌──────────┐  ┌────────┐ │
│  │ cch-plan    │  │ cch-todo │  │ cch-   │ │
│  │ (Smart Entry│  │ (통합 뷰) │  │ commit │ │
│  │  + Beads    │  │          │  │        │ │
│  │  hydrate/   │  │          │  │        │ │
│  │  flush)     │  │          │  │        │ │
│  └─────────────┘  └──────────┘  └────────┘ │
│                                             │
│  Beads (.beads/) ← SSOT, 영속 저장           │
├─────────────────────────────────────────────┤
│  Superpowers Layer (실행 엔진)                │
│                                             │
│  brainstorming → writing-plans              │
│  → executing-plans / subagent-driven-dev    │
│  → finishing-branch                         │
│                                             │
│  TaskList ← 세션 실행 뷰 (휘발)              │
└─────────────────────────────────────────────┘
```

---

## 4. 스킬 정리

### 4-1. 제거 대상 (12개)

superpowers 1:1 래퍼. 직접 superpowers 스킬 사용으로 대체.

| 제거 스킬 | 대체 |
|-----------|------|
| `cch-sp-brainstorm` | `superpowers:brainstorming` |
| `cch-sp-write-plan` | `superpowers:writing-plans` |
| `cch-sp-execute-plan` | `superpowers:executing-plans` |
| `cch-sp-subagent-dev` | `superpowers:subagent-driven-development` |
| `cch-sp-tdd` | `superpowers:test-driven-development` |
| `cch-sp-verify` | `superpowers:verification-before-completion` |
| `cch-sp-code-review` | `superpowers:requesting-code-review` |
| `cch-sp-receive-review` | `superpowers:receiving-code-review` |
| `cch-sp-finish-branch` | `superpowers:finishing-a-development-branch` |
| `cch-sp-git-worktree` | `superpowers:using-git-worktrees` |
| `cch-sp-parallel-agents` | `superpowers:dispatching-parallel-agents` |
| `cch-sp-debug` | `superpowers:systematic-debugging` |

### 4-2. 수정 대상 (2개)

| 스킬 | 변경 내용 |
|------|----------|
| `cch-plan` | Phase 3: dual-write → Beads only + hydrate 패턴. 실행 옵션에서 cch-sp-* 참조 제거 |
| `cch-todo` | docs/TODO.md, Roadmap.md 참조 제거. Beads + TaskList 2소스만 표시 |

### 4-3. 유지 (CCH 고유 가치)

| 스킬 | 고유 가치 |
|------|----------|
| `cch-plan` | Smart Entry + Beads 연동 + 3-Phase 통합 |
| `cch-todo` | Beads + TaskList 통합 뷰 |
| `cch-commit` | Beads trailer 연동 커밋 |
| `cch-team` | dev→test→verify 파이프라인 |
| `cch-pinchtab` | PinchTab 오케스트레이터 |
| `cch-full-pipeline` | E2E 파이프라인 |

---

## 5. cch-plan 개선 설계

### 5-1. Phase 3 변경 (핵심)

**Before (dual-write):**
```
Phase 3:
  1. Task 파싱
  2. Beads 생성 (bash bin/cch beads create)
  3. TaskCreate 생성 (동일 데이터)
  → 2곳에 동일 데이터, 이후 동기화 없음
```

**After (Beads only + hydrate):**
```
Phase 3:
  1. Task 파싱
  2. Beads에만 생성 (bash bin/cch beads create)
  3. Beads 의존성 설정 (bash bin/cch beads dep)
  4. Hydrate: bd ready → TaskCreate (현재 실행 가능한 것만)
  → Beads = SSOT, TaskList = 실행 뷰
```

### 5-2. 실행 핸드오프 변경

**Before:**
```
옵션 A: superpowers:subagent-driven-development
옵션 B: superpowers:executing-plans
```

**After:**
```
옵션 A: superpowers:subagent-driven-development 사용
  — 태스크 완료 시 cch-plan flush로 Beads 자동 갱신

옵션 B: superpowers:executing-plans 사용
  — 배치 완료 시 cch-plan flush로 Beads 자동 갱신
```

flush 로직은 cch-plan 내부에 포함하거나,
별도 `cch-flush` 유틸리티 스킬로 분리 가능.

---

## 6. cch-todo 개선 설계

### Before (4소스)
```
1. Beads
2. docs/Roadmap.md
3. docs/plans/*.md
4. TaskList
```

### After (2소스)
```
1. Beads (SSOT) — 프로젝트 전체 작업
2. TaskList — 현재 세션 실행 중인 작업
```

출력 형식:
```
## 작업 목록

### 현재 세션 (TaskList)
| # | 작업 | 상태 | Bead ID |
|---|------|------|---------|
(TaskList에서 in_progress/pending 항목)

### 준비된 작업 (Beads — 미할당, 차단 없음)
| Bead ID | 작업 | Phase | 우선순위 |
|---------|------|-------|---------|
(bd ready 결과)

### Phase별 진행률
| Phase | 완료 | 진행 | 대기 | 차단 |
|-------|------|------|------|------|
(bd list --label phase:X 집계)
```

---

## 7. docs/TODO.md 제거 전략

현재 `docs/TODO.md`에 있는 정보를 Beads로 마이그레이션한 후 파일을 삭제한다.

### 7-1. 마이그레이션 절차

1. `docs/TODO.md`의 미완료 항목([ ])을 파싱
2. 각 항목을 `bash bin/cch beads create` 로 생성
   - `--labels "phase:0"` (Phase 번호 매핑)
   - `--priority` (Phase 순서 기반)
3. 완료 항목([x])은 마이그레이션하지 않음 (git 히스토리에 보존)
4. `docs/TODO.md` 삭제

### 7-2. 대체 조회 방법

```bash
# Phase별 현황 (기존 TODO.md 역할)
bash bin/cch beads list --label "phase:0"
bash bin/cch beads list --label "phase:1"

# 전체 현황
cch-todo 스킬 사용
```

---

## 8. 상태 모델 통합

### 매핑 테이블

| Beads (SSOT) | TaskList (세션) | 전환 시점 |
|-------------|----------------|----------|
| `open` | `pending` | hydrate 시 |
| `in_progress` | `in_progress` | 실행 시작 시 양쪽 동시 |
| `blocked` | (TaskList에 로드 안 함) | — |
| `closed` | `completed` | flush 시 양쪽 동시 |

**규칙:**
- `blocked` 상태의 Bead는 hydrate하지 않음 (bd ready가 자동 필터링)
- TaskList에서 `completed` 처리 시 Beads도 `closed`로 flush
- Beads에서 직접 `transition`해도 정상 동작 (TaskList는 다음 hydrate에서 반영)

---

## 9. 구현 우선순위

| 순서 | 작업 | 난이도 | 영향 |
|------|------|--------|------|
| 1 | `cch-sp-*` 12개 스킬 삭제 | 낮음 | 유지보수 부담 즉시 제거 |
| 2 | `cch-plan` Phase 3 → Beads only + hydrate 전환 | 중간 | SSOT 확립 |
| 3 | `cch-todo` 2소스로 축소 | 낮음 | 조회 단순화 |
| 4 | `docs/TODO.md` → Beads 마이그레이션 + 파일 삭제 | 낮음 | 3중 관리 해소 |
| 5 | flush 메커니즘 구현 (TaskList completed → Beads closed) | 중간 | 양방향 동기화 완성 |

---

## 10. 위험 요소 및 대응

| 위험 | 대응 |
|------|------|
| superpowers 스킬이 TaskList만 참조하여 Beads 상태가 뒤처짐 | flush 메커니즘으로 해결. 태스크 완료 시 자동 Beads 갱신 |
| bd CLI 미설치 환경에서 CCH 사용 불가 | beads_check() 실패 시 graceful fallback: TaskList only 모드 |
| Beads에 대량 항목이 쌓여 bd ready 느려짐 | 완료 항목 주기적 아카이브 (bd archive 또는 수동 정리) |
| 래퍼 삭제 후 기존 사용자 혼란 | CLAUDE.md에 마이그레이션 안내 추가, 래퍼 스킬명으로 검색 시 superpowers 스킬 안내 |

---

## 11. 산출물 요약

| 산출물 | 형태 |
|--------|------|
| `cch-plan` SKILL.md 수정 | Phase 3 재작성 |
| `cch-todo` SKILL.md 수정 | 2소스 축소 |
| `skills/cch-sp-*` 12개 디렉터리 삭제 | 파일 삭제 |
| `docs/TODO.md` 삭제 | 파일 삭제 (Beads 마이그레이션 후) |
| Beads 마이그레이션 스크립트 | 1회성 bash 스크립트 |
| CLAUDE.md 업데이트 | 래퍼 제거 안내 |
