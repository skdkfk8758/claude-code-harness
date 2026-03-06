---
name: plan-cleanup
description: Use when cleaning up accumulated plan documents. Archives completed workflow docs after verifying knowledge indexing status.
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep, Write, AskUserQuestion
argument-hint: "[--force | --dry-run | workflow-name]"
---

# Plan Cleanup

완료된 워크플로우의 플랜 문서를 아카이브하여 `docs/plans/`를 정리합니다.
삭제가 아닌 **아카이브** — 문서를 `docs/plans/archive/`로 이동합니다.

## Path Discovery

Project root: `.`
Plan directory: `docs/plans/`
Archive directory: `docs/plans/archive/`

## Input Resolution

| 인자 | 동작 |
|------|------|
| 없음 | 전체 스캔 → 아카이브 대상 목록 표시 → 사용자 확인 후 실행 |
| `--dry-run` | 아카이브 대상만 표시, 실행하지 않음 |
| `--force` | 사용자 확인 없이 즉시 아카이브 |
| `{workflow-name}` | 해당 워크플로우 문서만 대상 |

## Process

### Phase 1: 문서 스캔

1. `docs/plans/*.md` glob (archive 제외)
2. 파일명에서 워크플로우 식별: `{date}-{name}-{type}.md`
   - 같은 `{date}-{name}` prefix를 가진 파일들을 하나의 워크플로우 문서 세트로 그룹화
   - type: `design`, `plan`, `context`, `tasks`, `review`
3. 문서 세트별 상태 판단:

```
문서 세트 상태 판단:
  1. git log로 해당 문서가 속한 브랜치/PR 확인
  2. 브랜치가 main에 머지됨 → "완료"
  3. 브랜치가 존재하고 활성 → "진행중"
  4. 브랜치 없고 workflow-state.json에도 없음 → "고아(orphan)"
```

### Phase 2: Knowledge Graph 확인

`.claude/knowledge-graph.json`이 존재하면:

1. 각 문서 세트의 파일이 `artifacts` 배열에 등록되어 있는지 확인
2. 인덱싱 상태를 표시:

| 상태 | 의미 |
|------|------|
| `indexed` | knowledge-graph에 artifact로 등록됨 → 안전하게 아카이브 가능 |
| `not-indexed` | 등록 안 됨 → 아카이브 시 지식 손실 가능성 경고 |

knowledge-graph.json이 없으면 이 단계를 건너뛴다.

### Phase 3: 대상 선정 및 표시

아카이브 대상 조건:
- 상태가 "완료" (브랜치 머지됨)
- 또는 상태가 "고아" (브랜치도 없고 워크플로우 상태도 없음)

"진행중" 문서는 **절대 아카이브하지 않음**.

표시 형식:
```
Plan Cleanup
════════════════════════════════════════════

아카이브 대상 (2 sets)
──────────────────────────────────────────
  1. 2026-03-01-cache-layer (완료, indexed)
     • design.md, plan.md, context.md, tasks.md, review.md

  2. 2026-02-28-order-refactor (고아, not-indexed)
     • design.md, plan.md
     ⚠ knowledge-graph에 미등록 — 아카이브 시 지식 손실 가능

제외 (진행중)
──────────────────────────────────────────
  • 2026-03-06-knowledge-ontology (진행중, feature/knowledge-ontology)

아카이브 대상 {N}개 세트 ({M}개 파일)를 이동합니다.
진행할까요? (y/n)
```

### Phase 4: 아카이브 실행

1. `docs/plans/archive/` 디렉터리 생성 (없으면)
2. 대상 파일을 `git mv`로 이동:
   ```
   git mv docs/plans/2026-03-01-cache-layer-design.md docs/plans/archive/
   git mv docs/plans/2026-03-01-cache-layer-plan.md docs/plans/archive/
   ...
   ```
3. `git mv` 사용으로 git history 보존
4. 이동 결과 표시:
   ```
   ✓ 2026-03-01-cache-layer: 5 files → archive/
   ✓ 2026-02-28-order-refactor: 2 files → archive/

   아카이브 완료: {N}개 세트, {M}개 파일 이동
   ```

### Phase 5: not-indexed 문서 처리

not-indexed 상태의 문서가 아카이브 대상에 포함된 경우:

1. 아카이브 전에 경고:
   ```
   ⚠ 다음 문서는 knowledge-graph에 미등록입니다:
     • 2026-02-28-order-refactor (2 files)

   1. 지금 인덱싱 후 아카이브
   2. 인덱싱 없이 아카이브 (지식 손실 감수)
   3. 이 세트는 건너뛰기
   ```
2. 옵션 1 선택 시: 각 문서를 읽고 knowledge-graph.json에 수동 인덱싱 수행
   - SKILL.md의 Knowledge Graph Management > Indexing 추출 지시를 따름
3. 옵션 2 선택 시: 그대로 아카이브
4. 옵션 3 선택 시: 해당 세트 제외

## Rules

- "진행중" 문서는 절대 아카이브하지 않음
- `git mv`로만 이동 — history 보존
- `--force`여도 "진행중" 보호는 유지
- archive 디렉터리의 문서는 재스캔 대상에서 제외
- 커밋은 자동으로 하지 않음 — 사용자가 `/commit`으로 직접 수행
- 빈 `docs/plans/` (아카이브 후 문서가 없는 상태)는 정상 상태

## finishing-branch 연동

이 스킬은 독립 실행되지만, `finishing-branch` 스킬의 Phase 5 (Cleanup)에서
다음 안내를 추가할 수 있습니다:

```
💡 플랜 문서를 정리하려면: /plan-cleanup
```

이 연동은 finishing-branch SKILL.md에 별도로 추가해야 합니다.
