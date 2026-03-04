# Branch Workflow Design

- 작성일: 2026-03-03
- work-id: w-branch-workflow
- 상태: 설계 완료, 구현 예정

## 배경

현재 CCH는 단일 `master` 브랜치에서 직접 커밋하는 방식으로 운영 중이다.
cch-pr 스킬은 feature 브랜치 워크플로우를 기대하지만 실제로는 사용 불가 상태이며,
Work-Item과 브랜치 간 연결도 없다.

### 현재 문제점

| 문제 | 상세 |
|------|------|
| PR 스킬 비활성 | `git log main..HEAD` 기대하나 feature 브랜치 없음 |
| main/master 불일치 | PR 스킬은 `main` 기대, 실제는 `master` |
| 작업 격리 부재 | 리팩토링/실험 시 안전하게 되돌릴 방법 없음 |
| Work-Item 연결 없음 | 커밋 트레일러만 존재, 브랜치 레벨 매핑 없음 |

## 요구사항 (인터뷰 결과)

| 항목 | 결정 |
|------|------|
| 개발자 수 | Solo (AI 에이전트 협업) |
| 도입 동기 | Work-Item 격리 + PR 활성화 + 실험 안전망 |
| 브랜치 생성 | plan-bridge에서 자동 (ExitPlanMode 시) |
| 네이밍 규칙 | `type/WI-ID-slug` (예: `feat/WI-042-branch-workflow`) |
| Merge 전략 | Squash merge |
| 브랜치 정리 | merge 후 자동 삭제 (local + remote) |
| Base 브랜치 | master → main 통일 |
| 통합 범위 | 전체 파이프라인 자동화 |
| main 직접 커밋 | 허용 (Solo 개발이므로 제한 불필요) |

## 접근 방식: B안 - bin/cch branch 서브커맨드

`bin/lib/work.sh`와 동일한 패턴으로 `bin/lib/branch.sh`를 추가한다.
plan-bridge와 cch-pr 스킬이 이를 호출하는 구조.

선택 이유:
1. `bin/cch work`와 동일한 패턴 (학습 비용 0)
2. hook(plan-bridge.mjs)과 스킬(cch-pr) 모두에서 호출 가능
3. 브랜치 로직이 한 곳에 집중 (유지보수 용이)
4. Shell 기반이라 CI/CD 확장에도 유리

기각된 대안:
- A안 (Hook 확장): plan-bridge.mjs와 cch-pr이 비대해짐, 로직 분산
- C안 (전용 스킬): 자동화에 부적합 (스킬은 사용자 호출 기반), hook에서 호출 불가

## 설계

### 1. bin/lib/branch.sh

```
cmd_branch()           # 라우터
branch_create()        # 브랜치 생성
branch_list()          # 활성 브랜치 목록
branch_current()       # 현재 브랜치 정보 + work-item 매핑
branch_cleanup()       # 병합 완료된 stale 브랜치 일괄 정리
branch_base()          # 설정된 base 브랜치 이름 반환
```

**branch_create 흐름:**
```
branch_create <type> <work-id> <slug>
  1. main 브랜치 최신화 (git fetch origin main)
  2. git checkout -b <type>/<work-id>-<slug> main
  3. 상태 기록 (.claude/cch/branches/<branch-slug>.yaml)
  4. 출력: "[cch] Branch created: feat/WI-042-branch-workflow (from main)"
```

**상태 파일 (`branches/<slug>.yaml`):**
```yaml
branch: feat/WI-042-branch-workflow
type: feat
work_id: WI-042
slug: branch-workflow
base: main
created_at: 2026-03-03T10:00:00Z
status: active
```

**branch_base:**
- `read_state "config_base_branch"` 값 반환 (G1: 파일-per-키 패턴, `.claude/cch/config` YAML 아님)
- 미설정 시 기본값 `main`
- G14: 3단 fallback 체인 (config값 → `master` → `origin/main` → 에러)

### 2. plan-bridge.mjs 통합

현재 Step 7의 `runCchBatch`에 브랜치 생성 추가:

```javascript
// Before (현재)
runCchBatch([
  `work create "${parsed.work_id}" "${parsed.goal}"`,
  `work transition "${parsed.work_id}" doing`,
  "mode code",
]);

// After (변경)
runCchBatch([
  `work create "${parsed.work_id}" "${parsed.goal}"`,
  `branch create "${branchType}" "${parsed.work_id}" "${slug}"`,
  `work transition "${parsed.work_id}" doing`,
  "mode code",
]);
```

**브랜치 타입 추론:**
- plan 문서 파일명에서 추론:
  - `*-design.md` / `*-impl.md` → `feat`
  - `*-fix.md` / `*-bugfix.md` → `fix`
  - `*-refactor.md` → `refactor`
  - 기본값 → `feat`

**bridge-output 확장:**
- additionalContext에 브랜치 정보 포함: `[CCH-BRANCH] Created feat/WI-042-branch-workflow from main`

### 3. cch-pr 스킬 확장 (Step 5: Merge & Cleanup)

기존 4단계 + 신규 Step 5:

```
Step 1 - 수집 (기존, 변경 없음)
Step 2 - Work-Item 감지 (강화: branch 상태 파일도 참조)
Step 3 - PR 내용 생성 (기존, 변경 없음)
Step 4 - PR 생성 + Push (기존, 변경 없음)
Step 5 - Merge & Cleanup (NEW, 사용자 확인 후)
  ├─ gh pr merge --squash --delete-branch
  ├─ git checkout main && git pull origin main
  ├─ git branch -d <feature-branch> (local 정리)
  ├─ bin/cch work transition <WI-ID> done
  └─ .claude/cch/branches/<branch>.yaml 정리
```

**base branch 동적 참조:**
- cch-pr 내 모든 `main` 하드코딩을 `bin/cch branch base` 호출로 대체

### 4. master → main 마이그레이션

브랜치 전략의 전제 조건:

```
1. git branch -m master main
2. git push -u origin main
3. GitHub default branch를 main으로 변경
4. git push origin --delete master
5. .claude/cch/config에 base_branch: main 설정
```

## 전체 파이프라인 흐름도

```
[ 설계 단계 ]
  plan mode → 설계 문서 작성 → ExitPlanMode
                                    │
[ plan-bridge 자동화 ]              ▼
  plan-bridge.mjs (PostToolUse:ExitPlanMode)
    ├─ plan 문서 파싱
    ├─ execution-plan.json 저장
    ├─ cch work create WI-042 "..."
    ├─ cch branch create feat WI-042 slug  ← NEW
    │    └─ git checkout -b feat/WI-042-slug main
    ├─ cch work transition WI-042 doing
    └─ cch mode code
                                    │
[ 개발 단계 ]                       ▼
  code mode에서 구현 작업
    ├─ 코드 작성/수정
    └─ /cch-commit → 커밋들 생성 (feature 브랜치에서)
                                    │
[ PR & Merge 단계 ]                 ▼
  /cch-pr
    ├─ Step 1-4: PR 생성
    │    └─ gh pr create (feat/WI-042-slug → main)
    └─ Step 5: Merge & Cleanup
         ├─ 사용자 확인
         ├─ gh pr merge --squash --delete-branch
         ├─ git checkout main && git pull
         ├─ local 브랜치 삭제
         ├─ cch work transition WI-042 done
         └─ 상태 파일 정리
```

## 안전장치

| 규칙 | 방식 |
|------|------|
| force push 금지 | 기존 규칙 유지 |
| merge 전 사용자 확인 | Step 5는 사용자 승인 후 실행 |
| graceful degradation | 브랜치 없이도 기존 동작 유지 |
| main 직접 커밋 허용 | Solo 개발이므로 제한 없음 |
| Feature 브랜치 최초 push | `/cch-pr` Step 4에서만 발생 (G6: 생성 시 로컬 전용) |

## 변경 대상 파일

| 파일 | 변경 유형 | 설명 |
|------|-----------|------|
| `bin/lib/branch.sh` | 신규 | 브랜치 관리 모듈 (G1-G5, G7, G10, G14) |
| `bin/cch` | 수정 | branch.sh 로드 + cmd_branch 라우팅 + status 브랜치 표시 (G11) |
| `scripts/plan-bridge.mjs` | 수정 | inferBranchType (G8), runCchBatch 개선 (G9), branch 필드 (G13) |
| `scripts/lib/bridge-output.mjs` | 수정 | warnings 파라미터 (G9) |
| `skills/cch-pr/SKILL.md` | 수정 | Step 5 추가, push 시점 문서화 (G6) |
| `skills/cch-commit/SKILL.md` | 수정 | Step 1/7 브랜치 정보 (G12) |
| `skills/cch-status/SKILL.md` | 수정 | 브랜치+WI 표시 (G11) |
| `tests/test_branch.sh` | 신규 | G3, G7, G14 등 19개 테스트 케이스 |
| `tests/integration/plan-bridge-e2e.test.mjs` | 수정 | branch 필드 검증 (G13) |

## 수용 기준

1. `bin/cch branch create feat WI-042 slug` → 브랜치 생성 + 상태 파일 기록
2. `bin/cch branch list` → 활성 브랜치 + work-item 매핑 출력
3. `bin/cch branch base` → 설정된 base 브랜치 반환
4. ExitPlanMode → plan-bridge → 자동 브랜치 생성 확인
5. `/cch-pr` Step 5 → squash merge + 브랜치 정리 + work-item done
6. master → main 마이그레이션 완료
7. 브랜치 없이도 기존 워크플로우 정상 동작 (graceful degradation)
