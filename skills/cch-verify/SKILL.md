---
name: cch-verify
description: Verify implementation before claiming completion. Runs tests, checks output, validates against spec. Absorbs debug and TDD workflows.
user-invocable: true
allowed-tools: Bash, Read, Glob, Grep, Agent, AskUserQuestion
argument-hint: <검증할 대상 설명 또는 테스트 명령>
---

# CCH Verify - 구현 검증

작업 완료를 선언하기 전에 실행하는 검증 스킬.
테스트 실행, 출력 확인, 스펙 대비 검증을 수행합니다.

> **원칙: 증거 먼저, 주장은 나중에.** 검증 명령의 출력을 직접 확인한 뒤에만 성공을 선언합니다.

## Steps

### Step 1 - 대상 파악

ARGUMENTS를 분석하여 검증 대상을 결정합니다:

1. **테스트 명령이 주어진 경우**: 해당 명령을 Step 2에서 실행
2. **파일/기능 설명이 주어진 경우**: 관련 테스트 파일을 탐색
3. **인자 없음**: 최근 변경 파일 기반으로 관련 테스트 탐색

탐색 순서:
- `git diff --name-only HEAD~1..HEAD` (최근 커밋)
- `git diff --name-only` (미커밋 변경)
- 변경된 소스 파일에 대응하는 테스트 파일 찾기:
  - `test_<name>.*`, `<name>.test.*`, `<name>.spec.*`, `__tests__/<name>.*`

### Step 2 - 테스트 실행

관련 테스트를 실행합니다:

```bash
# 프로젝트 테스트 러너 자동 감지 순서:
# 1. package.json scripts.test → npm test
# 2. Makefile test target → make test
# 3. pytest.ini / setup.cfg → pytest
# 4. tests/*.sh → bash tests/<file>.sh
# 5. 직접 명령 실행
```

**결과 판정:**
- 종료 코드 0 + 예상 출력 → PASS
- 종료 코드 != 0 → FAIL (Step 3으로)
- 타임아웃 → FAIL (Step 3으로)

### Step 3 - 실패 분석 (FAIL 시에만)

테스트 실패 시 systematic debugging을 수행합니다:

1. **에러 메시지 분석**: 스택 트레이스, assertion 실패, 로그 확인
2. **가설 수립**: 최대 3개 가설 (가장 가능성 높은 순)
3. **가설 검증**: 각 가설을 코드 읽기/실행으로 검증
4. **근본 원인 보고**: 확인된 원인과 수정 방향 제시

> 가설 없이 코드를 수정하지 않습니다. 원인을 확인한 뒤에만 수정합니다.

### Step 4 - 결과 보고

```
## 검증 결과

| 항목 | 결과 | 상세 |
|------|------|------|
| 테스트 | PASS/FAIL | N개 중 M개 통과 |
| 대응 테스트 커버리지 | N/M | 테스트 없는 소스 파일 목록 |

결론: <VERIFIED / FAILED / NEEDS_ATTENTION>
```

- **VERIFIED**: 모든 테스트 통과, 검증 완료
- **FAILED**: 테스트 실패, 근본 원인 분석 포함
- **NEEDS_ATTENTION**: 테스트 없음 또는 수동 확인 필요
