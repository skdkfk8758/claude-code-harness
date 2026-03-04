---
name: cch-arch-guide
description: 프로젝트 복잡도 인터뷰를 통한 아키텍처 레벨 결정 및 구조 스캐폴딩
user-invocable: true
allowed-tools: Bash, Read, Glob, Write, AskUserQuestion
argument-hint: [skip-interview]
---

# CCH Architecture Guide - 아키텍처 레벨 온보딩

프로젝트 복잡도를 인터뷰하여 적절한 아키텍처 레벨을 결정하고, 디렉토리 구조를 스캐폴딩합니다.

## Levels

| Level | 이름 | 적합한 프로젝트 |
|-------|------|----------------|
| 1 | TDD Only | CRUD, 스크립트, CLI 도구 |
| 2 | Clean Architecture + TDD | 포트/어댑터, 외부 연동 |
| 3 | DDD + TDD | Aggregate, Bounded Context, 이벤트 |

**TDD는 모든 레벨에서 항상 ON입니다.**

## Steps

### Step 1 - Prerequisites

1. Plugin root 찾기: `**/bin/cch` Glob으로 탐색
2. Manifest 로드 확인:
```bash
cat "<plugin-root>/manifests/architecture-levels.json"
```

manifest가 없으면 "architecture-levels.json이 없습니다. CCH를 업데이트하세요." 안내 후 종료.

### Step 2 - 기존 레벨 확인

```bash
bash "<plugin-root>/bin/cch" arch level
```

- 이미 설정되어 있으면 현재 레벨을 표시하고 AskUserQuestion으로 재평가 여부를 질문:
  - "현재 Level N (Name)이 설정되어 있습니다. 재평가하시겠습니까?"
  - 옵션: "예, 재평가" / "아니요, 유지"
- "아니요" 선택 시 "현재 레벨이 유지됩니다." 안내 후 종료

### Step 3 - 바이패스 확인

인자로 `skip-interview`가 전달되었으면:
- "직접 레벨을 설정하려면 `cch arch set <1|2|3>` 을 실행하세요." 안내
- 각 레벨의 간단한 설명 표시 후 종료

### Step 4 - 인터뷰 (3문항)

AskUserQuestion을 사용하여 순차적으로 3개 질문을 합니다.

**Q1: 프로젝트 도메인 복잡도** (가중치 ×3)

질문: "프로젝트의 도메인 복잡도는 어느 수준인가요?"
- A) CRUD/스크립트 수준 — 단순한 데이터 처리, CLI 도구 (0점)
- B) 모듈 + 외부 연동 — API 클라이언트, DB 연동, 서비스 통합 (1점)
- C) 복잡한 도메인 규칙 — 비즈니스 불변조건, 상태 머신, 이벤트 (2점)

**Q2: 핵심 엔티티 수** (가중치 ×2)

질문: "프로젝트의 핵심 엔티티(모델/테이블)는 몇 개인가요?"
- A) 1~4개 (0점)
- B) 5~15개 (1점)
- C) 15개 이상 (2점)

**Q3: 팀/경계 규모** (가중치 ×1)

질문: "프로젝트의 팀 및 모듈 경계 규모는?"
- A) 솔로 개발 / 단일 모듈 (0점)
- B) 소규모 팀 (2~5명) / 2~3 모듈 (1점)
- C) 다수 팀 / 여러 Bounded Context (2점)

### Step 5 - 점수 계산 + 추천

점수 계산: `(Q1 × 3) + (Q2 × 2) + (Q3 × 1)`

**점수 → 레벨 매핑:**
- 0~2점 → Level 1 (TDD Only)
- 3~6점 → Level 2 (Clean Architecture + TDD)
- 7~12점 → Level 3 (DDD + TDD)

결과를 표시합니다:
```
## 인터뷰 결과

점수: N/12
추천 레벨: Level X — <레벨 이름>
설명: <레벨 설명>
```

AskUserQuestion으로 확인:
- "Level X를 적용하시겠습니까?"
- 옵션: "예, 적용" / "다른 레벨 선택"
- "다른 레벨 선택" 시 1/2/3 중 선택하도록 추가 질문

### Step 6 - 적용

결정된 레벨로 설정 및 스캐폴딩:

```bash
bash "<plugin-root>/bin/cch" arch set <N>
bash "<plugin-root>/bin/cch" arch scaffold
```

### Step 7 - 요약

최종 결과를 보고합니다:

```
## 아키텍처 설정 완료

Level: N — <레벨 이름>
TDD: always ON

### 생성된 디렉토리
- <생성된 디렉토리 목록>

### 다음 단계
- `cch arch check` 로 구조 검증
- `cch arch report` 로 현재 상태 확인
- 코드 작성 시 테스트를 먼저 작성하세요 (TDD)
```
