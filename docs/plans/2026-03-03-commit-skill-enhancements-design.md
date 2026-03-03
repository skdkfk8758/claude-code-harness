# Design: cch-commit 스킬 확장 — Simplify + README 자동화

**날짜:** 2026-03-03
**상태:** 승인됨

## 배경

현재 `cch-commit` 스킬은 5단계(수집→분석→확인→실행→보고)로 동작한다.
두 가지 기능을 추가한다:

1. **커밋 후 자동 /simplify**: 커밋된 코드 파일에 code-simplifier 에이전트를 실행하여 코드 정리
2. **커밋 후 README 재생성**: 프로젝트 구조를 스캔하여 README.md를 최신 상태로 갱신

## 설계 결정

### 타이밍: Commit 후 (Post-Commit)

**선택 이유:**
- 안전성: 원본 변경사항이 먼저 커밋되어 rollback 가능
- 실패 격리: simplify/README 실패 시에도 원본 커밋 보존
- 자연스러운 흐름: "작업 저장 → 정리 → 문서화"

**기각된 대안:**
- Pre-Commit: simplify가 사용자 확인 없이 코드를 변경할 위험. 커밋 전 대기 시간 증가
- 별도 단계: 자동화 이점 감소, 워크플로우 분산

## 확장된 플로우 (7단계)

```
Step 1: 수집      (기존 유지)
Step 2: 분석      (기존 유지)
Step 3: 확인      (기존 유지)
Step 4: 실행      (기존 유지) — 원본 커밋 생성
Step 5: Simplify  (신규) — 커밋된 코드 파일 정리
Step 6: README    (신규) — 프로젝트 스캔 후 README.md 재생성
Step 7: 보고      (기존 확장) — simplify/README 결과 포함
```

## Step 5: Simplify 상세

### 동작

1. Step 4에서 커밋된 파일 목록을 `git diff --name-only HEAD~N..HEAD`로 추출 (N = Step 4 커밋 수)
2. 코드 파일만 필터링 (`.md`, `.json`, `.yaml` 등 비코드 파일 제외)
3. 코드 파일이 있을 경우에만 `code-simplifier` 에이전트를 서브에이전트로 호출
4. 에이전트에게 변경된 파일 목록과 "이 파일들만 simplify하라"는 지시 전달
5. simplify 결과로 변경이 발생하면:
   - `git add <changed-files>`
   - `git commit -m "refactor: simplify recently committed code"`
6. 변경이 없으면 "Simplify: 변경 없음" 기록 후 Step 6으로

### 스킵 조건

- 커밋된 파일이 모두 비코드 파일 (docs, config 등)인 경우
- 커밋이 `docs:` 또는 `chore:` 타입만인 경우

### 실패 처리

- simplify 에이전트 오류 시: 경고 메시지 출력하고 Step 6으로 계속 진행
- simplify가 LSP 에러를 도입한 경우: `git checkout -- .`으로 변경 취소, 경고 출력

## Step 6: README 재생성 상세

### 동작

1. 프로젝트 구조 스캔:
   - `ls skills/` → 스킬 목록 수집
   - `ls scripts/` → 스크립트 목록 수집
   - `ls bin/` → CLI 도구 수집
   - `ls docs/` → 문서 목록 수집
   - `ls tests/` → 테스트 목록 수집
   - `cat docs/PRD.md` → 프로젝트 설명 추출 (첫 섹션)
2. 각 스킬의 `SKILL.md`에서 name + description 추출
3. README 템플릿에 수집된 정보를 채워 README.md 생성
4. 기존 README.md와 비교하여 변경이 있는 경우에만:
   - `git add README.md`
   - `git commit -m "docs: update README"`

### README 템플릿

```markdown
# Claude Code Harness (CCH)
> {PRD에서 추출한 1줄 설명}

## 개요
{PRD 기반 2-3줄 설명}

## 스킬 목록
| 스킬 | 설명 |
|------|------|
{skills/*/SKILL.md의 name + description 자동 추출}

## 스크립트
| 스크립트 | 용도 |
|---------|------|
{scripts/ 파일별 첫 번째 주석 라인 추출}

## 설치 및 설정
{docs/guide/ 참조 링크}

## 문서
{docs/ 내 파일 링크 목록}

## 테스트
{tests/ 파일 목록 및 실행 방법}
```

### 스킵 조건

- README.md 내용이 이전과 동일하면 커밋하지 않음

### 실패 처리

- 스캔 오류 시: 경고 출력하고 Step 7으로 진행 (README 미갱신)

## Step 7: 보고 (확장)

기존 커밋 결과 테이블에 simplify/README 커밋을 포함하고, 후처리 결과 섹션을 추가한다:

```
## 커밋 완료

| # | 해시 | 타입 | 설명 | 파일수 |
|---|------|------|------|--------|
| 1 | abc1234 | feat | ... | 2 |
| 2 | def5678 | fix  | ... | 1 |
| 3 | ghi9012 | refactor | simplify recently committed code | 3 |
| 4 | jkl3456 | docs | update README | 1 |

총 N개 커밋 생성

## 후처리 결과
- Simplify: 3개 파일 정리됨 (또는 "변경 없음" / "스킵됨")
- README: 갱신됨 (또는 "변경 없음" / "오류로 스킵됨")
```

## 안전 규칙

기존 안전 규칙에 추가:

- **Step 5~6은 Step 4 완료 후에만 실행**: 원본 커밋 보존 보장
- **Step 5~6 각각 독립적으로 실패 허용**: 하나가 실패해도 나머지는 계속 진행
- **불필요한 커밋 생성 금지**: 변경이 없으면 커밋하지 않음
- **simplify는 코드 파일에만 적용**: docs/config 전용 커밋은 simplify 스킵
