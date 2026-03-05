# CCH 스킬 중복 정리 — 구현 계획

> **For Claude:** REQUIRED SUB-SKILL: Use cch-sp-execute-plan to implement this plan task-by-task.

**Goal:** CCH 스킬 생태계의 확인된 중복 6개 삭제, 2건 통합, repo↔marketplace 동기화
**Architecture:** marketplace skills/ 디렉터리가 canonical. repo skills/는 개발 원본. dist는 sync로 자동 반영.
**Design Doc:** `docs/plans/2026-03-04-skill-dedup-design.md`

**Marketplace 경로:** `/Users/carpdm/.claude/plugins/marketplaces/claude-code-harness-marketplace/skills/`
**Repo 경로:** `/Users/carpdm/Workspace/Github/claude-code-harness/skills/`

---

## Phase A: 확실한 중복 삭제 (6개)

### Task 1: Trivial 래퍼 스킬 3개 삭제

**Files:**
- Delete: `marketplace/skills/cch-dot/`
- Delete: `marketplace/skills/cch-update/`
- Delete: `marketplace/skills/cch-release/`

**Step 1: 삭제 전 참조 확인**
Run: `grep -r "cch-dot\|cch-update\|cch-release" marketplace/skills/ --include="*.md" -l`
Expected: 자기 자신의 SKILL.md만 매칭 (외부 참조 없음 확인됨)

**Step 2: 디렉터리 삭제**
```bash
rm -rf marketplace/skills/cch-dot
rm -rf marketplace/skills/cch-update
rm -rf marketplace/skills/cch-release
```

**Step 3: 검증**
Run: `ls marketplace/skills/ | wc -l`
Expected: 47 (50 - 3)

**Step 4: 커밋**
```bash
git add -A marketplace/skills/cch-dot marketplace/skills/cch-update marketplace/skills/cch-release
git commit -m "refactor(skills): remove trivial CLI wrapper skills (cch-dot, cch-update, cch-release)"
```

**의존:** 없음

---

### Task 2: cch-sp-brainstorm, cch-sp-write-plan 삭제

**Files:**
- Delete: `marketplace/skills/cch-sp-brainstorm/`
- Delete: `marketplace/skills/cch-sp-write-plan/`

**Step 1: 삭제 전 참조 확인**
이 두 스킬은 서로만 참조하며 함께 삭제되므로 dangling reference 없음.
Run: `grep -r "cch-sp-brainstorm\|cch-sp-write-plan" marketplace/skills/ --include="*.md" -l`
Expected: 자기 자신 + 상대방 파일만 매칭

**Step 2: 디렉터리 삭제**
```bash
rm -rf marketplace/skills/cch-sp-brainstorm
rm -rf marketplace/skills/cch-sp-write-plan
```

**Step 3: 검증**
Run: `ls marketplace/skills/ | wc -l`
Expected: 45 (47 - 2)

**Step 4: 커밋**
```bash
git add -A marketplace/skills/cch-sp-brainstorm marketplace/skills/cch-sp-write-plan
git commit -m "refactor(skills): remove cch-sp-brainstorm/write-plan (duplicated by cch-plan Phase 1/2)"
```

**의존:** Task 1

---

### Task 3: cch-sp-verify 삭제 + 참조 업데이트

**Files:**
- Delete: `marketplace/skills/cch-sp-verify/`
- Modify: `marketplace/skills/cch-sp-debug/SKILL.md`

**Step 1: cch-sp-debug 참조 업데이트**
`cch-sp-debug/SKILL.md` 라인 59:
```
AS-IS: **Pairs with:** `cch-sp-verify` — verify the fix before claiming completion.
TO-BE: **Pairs with:** `cch-verify` — verify the fix before claiming completion.
```

**Step 2: 디렉터리 삭제**
```bash
rm -rf marketplace/skills/cch-sp-verify
```

**Step 3: 검증**
Run: `grep -r "cch-sp-verify" marketplace/skills/ --include="*.md"`
Expected: 매칭 없음

Run: `ls marketplace/skills/ | wc -l`
Expected: 44 (45 - 1)

**Step 4: 커밋**
```bash
git add marketplace/skills/cch-sp-verify marketplace/skills/cch-sp-debug/SKILL.md
git commit -m "refactor(skills): remove cch-sp-verify (replaced by cch-verify), update debug reference"
```

**의존:** Task 2

---

## Phase B: 스킬 통합 (2건)

### Task 4: cch-review를 marketplace에 추가 (SHA 범위 기능 흡수)

**Files:**
- Create: `marketplace/skills/cch-review/SKILL.md` (repo 원본 기반 + SHA 기능 추가)

**Step 1: repo 원본 복사**
```bash
cp -r repo/skills/cch-review marketplace/skills/cch-review
```

**Step 2: SHA 범위 지정 기능 추가**
`cch-review/SKILL.md`의 Step 1에 SHA 범위 옵션 추가:
```
AS-IS:
4. **인자 없음**: `git diff main...HEAD` (현재 브랜치 vs main)

TO-BE:
4. **SHA 범위**: `git diff <base-sha>..<head-sha>` 로 변경사항 추출
5. **인자 없음**: `git diff main...HEAD` (현재 브랜치 vs main)
```

`argument-hint` 업데이트:
```
AS-IS: argument-hint: <리뷰할 브랜치, PR 번호, 또는 커밋 범위>
TO-BE: argument-hint: <리뷰할 브랜치, PR 번호, 커밋 범위, 또는 SHA..SHA>
```

**Step 3: 검증**
Run: `cat marketplace/skills/cch-review/SKILL.md | head -5`
Expected: `name: cch-review` 확인

**Step 4: 커밋**
```bash
git add marketplace/skills/cch-review
git commit -m "feat(skills): add cch-review to marketplace with SHA range support"
```

**의존:** Task 3

---

### Task 5: cch-sp-code-review 삭제 + 참조 업데이트

**Files:**
- Delete: `marketplace/skills/cch-sp-code-review/`
- Modify: `marketplace/skills/cch-sp-receive-review/SKILL.md`

**Step 1: cch-sp-receive-review 참조 업데이트**
`cch-sp-receive-review/SKILL.md` 라인 66:
```
AS-IS: **Pairs with:** `cch-sp-code-review` — the requesting skill dispatches the reviewer that generates the feedback.
TO-BE: **Pairs with:** `cch-review` — the requesting skill dispatches the reviewer that generates the feedback.
```

**Step 2: 디렉터리 삭제**
```bash
rm -rf marketplace/skills/cch-sp-code-review
```

**Step 3: 검증**
Run: `grep -r "cch-sp-code-review" marketplace/skills/ --include="*.md"`
Expected: 매칭 없음

Run: `ls marketplace/skills/ | wc -l`
Expected: 44 (삭제 1 + 추가 1 = 순변화 0)

**Step 4: 커밋**
```bash
git add marketplace/skills/cch-sp-code-review marketplace/skills/cch-sp-receive-review/SKILL.md
git commit -m "refactor(skills): remove cch-sp-code-review (replaced by cch-review), update receive-review reference"
```

**의존:** Task 4

---

### Task 6: cch-verify를 marketplace에 추가

**Files:**
- Create: `marketplace/skills/cch-verify/SKILL.md` (repo 원본 그대로)

**Step 1: repo 원본 복사**
```bash
cp -r repo/skills/cch-verify marketplace/skills/cch-verify
```

**Step 2: 검증**
Run: `cat marketplace/skills/cch-verify/SKILL.md | head -5`
Expected: `name: cch-verify` 확인

Run: `ls marketplace/skills/ | wc -l`
Expected: 45 (44 + 1)

**Step 3: 커밋**
```bash
git add marketplace/skills/cch-verify
git commit -m "feat(skills): add cch-verify to marketplace"
```

**의존:** Task 5

---

## Phase C: Repo ↔ Marketplace 동기화

### Task 7: cch-lsp를 marketplace에 추가

**Files:**
- Create: `marketplace/skills/cch-lsp/SKILL.md` (repo 원본 그대로)

**Step 1: repo 원본 복사**
```bash
cp -r repo/skills/cch-lsp marketplace/skills/cch-lsp
```

**Step 2: 검증**
Run: `cat marketplace/skills/cch-lsp/SKILL.md | head -5`
Expected: `name: cch-lsp` 확인

Run: `ls marketplace/skills/ | wc -l`
Expected: 46 (45 + 1)

**Step 3: 커밋**
```bash
git add marketplace/skills/cch-lsp
git commit -m "feat(skills): add cch-lsp to marketplace (previously repo-only)"
```

**의존:** Task 6

---

### Task 8: dist 동기화 및 최종 검증

**Files:**
- Sync: dist 디렉터리 전체

**Step 1: bin/cch sync 실행**
```bash
bash bin/cch sync
```

**Step 2: 최종 스킬 수 검증**
Run: `ls marketplace/skills/ | wc -l`
Expected: 46

**Step 3: dangling reference 전체 검사**
```bash
# 삭제된 스킬명이 어디에도 남아있지 않은지 확인
grep -r "cch-sp-brainstorm\|cch-sp-write-plan\|cch-sp-verify\|cch-sp-code-review\|cch-dot\b" marketplace/skills/ --include="*.md"
```
Expected: 매칭 없음

**Step 4: 커밋**
```bash
git add -A
git commit -m "chore(skills): sync dist after skill dedup (50 → 46)"
```

**의존:** Task 7

---

## 요약

| Phase | Task | 내용 | 스킬 수 변화 |
|-------|------|------|-------------|
| A | 1 | trivial 래퍼 3개 삭제 | 50 → 47 |
| A | 2 | brainstorm + write-plan 삭제 | 47 → 45 |
| A | 3 | sp-verify 삭제 + debug 참조 수정 | 45 → 44 |
| B | 4 | cch-review marketplace 추가 | 44 → 45 |
| B | 5 | sp-code-review 삭제 + receive-review 참조 수정 | 45 → 44 |
| B | 6 | cch-verify marketplace 추가 | 44 → 45 |
| C | 7 | cch-lsp marketplace 추가 | 45 → 46 |
| C | 8 | dist 동기화 + 최종 검증 | 46 (최종) |

최종 결과: **50 → 46** (삭제 7, 추가 3)
