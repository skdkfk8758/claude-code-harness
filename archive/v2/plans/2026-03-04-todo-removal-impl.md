# docs/TODO.md 삭제 — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** docs/TODO.md를 삭제하고 Beads를 유일한 태스크 SSOT로 확정한다.

**Architecture:** 미완료 항목 Beads 마이그레이션 → 3개 문서 참조 정리 → TODO.md 삭제.

**Tech Stack:** Bash (beads CLI), Markdown 편집

---

### Task 1: 미완료 항목 Beads 마이그레이션

**Files:**
- Modify: `.beads/issues.jsonl` (via CLI)

**Step 1: #110을 Bead로 생성**

```bash
bash bin/cch beads create "beads.sh JSON 헬퍼 → core.mjs 위임 (_bd_json_field sed 패턴 제거)" --priority 3 --labels "phase:P1,tech-debt"
```

Expected: `Created: cch-xxx`

**Step 2: #32 드롭 확인**

#32 (Version Gate)는 "보류" 상태이며 v2 전용 운영이 확정되었으므로 Bead를 생성하지 않는다.
필요 시 미래에 새 Bead로 생성.

**Step 3: Beads 목록 확인**

```bash
bash bin/cch beads list
```

Expected: 새 Bead가 목록에 포함됨

**Step 4: 커밋**

```bash
git add .beads/issues.jsonl
git commit -m "chore(beads): migrate TODO.md #110 to beads"
```

**의존:** 없음

---

### Task 2: 참조 문서 정리

**Files:**
- Modify: `README.md:79`
- Modify: `docs/Architecture.md:190`
- Modify: `docs/Roadmap.md:71`

**Step 1: README.md에서 TODO 링크 제거**

`README.md` 79번 줄 삭제:
```
- [TODO](docs/TODO.md)
```

**Step 2: Architecture.md에서 TODO 참조를 Beads로 교체**

`docs/Architecture.md` 190번 줄:
```
Before: 4. `docs/TODO.md` — 전체 작업 항목 추적
After:  4. `.beads/issues.jsonl` — 전체 작업 항목 추적 (`bash bin/cch beads list`)
```

**Step 3: Roadmap.md에서 TODO 참조를 Beads로 교체**

`docs/Roadmap.md` 71번 줄:
```
Before: 5. `docs/TODO.md` — 전체 작업 항목 추적
After:  5. `.beads/issues.jsonl` — 전체 작업 항목 추적 (`bash bin/cch beads list`)
```

**Step 4: 변경 확인**

```bash
grep -rn "TODO\.md" README.md docs/Architecture.md docs/Roadmap.md
```

Expected: 매칭 없음

**Step 5: 커밋**

```bash
git add README.md docs/Architecture.md docs/Roadmap.md
git commit -m "docs: replace TODO.md references with Beads in README, Architecture, Roadmap"
```

**의존:** 없음

---

### Task 3: docs/TODO.md 삭제

**Files:**
- Delete: `docs/TODO.md`

**Step 1: 파일 삭제**

```bash
git rm docs/TODO.md
```

**Step 2: 삭제 확인**

```bash
ls docs/TODO.md 2>&1
```

Expected: `No such file or directory`

**Step 3: 전체 참조 최종 확인**

```bash
grep -rn "docs/TODO\.md" --include="*.md" --include="*.json" --include="*.sh" . | grep -v "docs/plans/"
```

Expected: 매칭 없음 (docs/plans/ 히스토리 문서 제외)

**Step 4: 커밋**

```bash
git commit -m "chore: remove docs/TODO.md — Beads is now sole SSOT for task tracking"
```

**의존:** Task 1, Task 2
