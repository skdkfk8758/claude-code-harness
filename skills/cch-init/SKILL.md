---
name: cch-init
description: "프로젝트 분석 및 CCH 마이그레이션 — 스캔→문서→스캐폴딩 통합 파이프라인"
user-invocable: true
allowed-tools: [Agent, Read, Write, Bash, Glob, Grep, AskUserQuestion, Skill]
argument-hint: "onboard 또는 migrate"
---

# CCH Init — 프로젝트 온보딩 & 마이그레이션 파이프라인

신규 프로젝트를 CCH 생태계에 통합하는 진입점.
스캔 → 문서화 → 스캐폴딩의 3단계 파이프라인을 오케스트레이션한다.

## 사용법

```
/cch-init onboard    # 문서만 생성 (scan → docs)
/cch-init migrate    # 문서 + CCH 스캐폴딩 (scan → docs → scaffold)
/cch-init            # 모드를 대화형으로 선택
```

---

## Step 0: Pre-check

### 재실행 감지

`.claude/cch/init/` 디렉터리가 존재하면 이전 실행 결과가 있다.

```bash
test -d .claude/cch/init && echo "exists"
```

존재 시 AskUserQuestion으로 사용자에게 선택을 요청한다:

```
question: "이전 분석 결과가 있습니다. 어떻게 진행할까요?"
options:
  - "이어서 진행 (이전 결과 활용)"
  - "처음부터 다시 시작 (이전 결과 삭제)"
  - "취소"
```

- "이어서 진행": `.claude/cch/init/progress` 파일을 읽어 중단된 단계부터 재개
- "처음부터": `rm -rf .claude/cch/init` 후 전체 초기화
- "취소": 즉시 종료

### Git repo 확인

```bash
test -d .git && echo "git" || echo "no-git"
```

`.git`이 없으면 경고를 출력하되 계속 진행한다:

```
[경고] Git 저장소가 감지되지 않았습니다. CCH는 Git 기반 워크플로우를 권장합니다.
계속 진행하겠습니다.
```

### 상태 디렉터리 초기화

```bash
mkdir -p .claude/cch/init
```

---

## Step 1: 모드 선택

ARGUMENTS에 `onboard` 또는 `migrate`가 포함되어 있으면 해당 모드를 사용한다.

인자가 없거나 이어서 진행하는 경우 `.claude/cch/init/mode` 파일을 확인한다:

```bash
cat .claude/cch/init/mode 2>/dev/null
```

파일이 없으면 AskUserQuestion으로 사용자에게 선택을 요청한다:

```
question: "어떤 모드로 진행할까요?"
options:
  - "onboard — 프로젝트 문서만 생성 (Architecture, PRD, Roadmap, TODO)"
  - "migrate — 문서 생성 + CCH 디렉터리 구조 스캐폴딩"
```

선택된 모드를 저장한다:

```bash
echo "<mode>" > .claude/cch/init/mode
echo "scan" > .claude/cch/init/progress
```

---

## Step 2: Scan (cch-init-scan)

`.claude/cch/init/progress` 값이 `scan`이면 이 단계를 실행한다.
`docs`, `scaffold`, `done` 이면 건너뛴다.

Agent 도구로 cch-init-scan 스킬을 실행한다:

```
Agent(subagent_type="general-purpose")
프롬프트: "skills/cch-init-scan/SKILL.md 의 지침을 따라 프로젝트를 스캔하라.
  결과를 .claude/cch/init/scan-result.json 에 저장하라.
  완료 후 저장된 파일 경로를 반환하라."
```

완료 후 진행 상태를 업데이트한다:

```bash
echo "docs" > .claude/cch/init/progress
```

---

## Step 3: Docs (cch-init-docs)

`.claude/cch/init/progress` 값이 `docs`이면 이 단계를 실행한다.
`scaffold`, `done` 이면 건너뛴다.

Agent 도구로 cch-init-docs 스킬을 실행한다:

```
Agent(subagent_type="general-purpose")
프롬프트: "skills/cch-init-docs/SKILL.md 의 지침을 따라 프로젝트 문서를 생성하라.
  .claude/cch/init/scan-result.json 을 입력으로 사용하라.
  다음 파일들을 생성하라:
  - docs/Architecture.md
  - docs/PRD.md
  - docs/Roadmap.md
  완료 후 생성된 파일 목록을 반환하라."
```

완료 후 진행 상태를 업데이트한다:

```bash
# onboard 모드면 done으로, migrate 모드면 scaffold로
echo "<next-progress>" > .claude/cch/init/progress
```

- `onboard` 모드: `echo "done" > .claude/cch/init/progress`
- `migrate` 모드: `echo "scaffold" > .claude/cch/init/progress`

---

## Step 4: Scaffold (migrate 모드 전용, cch-init-scaffold)

`onboard` 모드이면 이 단계를 건너뛴다.

`.claude/cch/init/progress` 값이 `scaffold`이면 이 단계를 실행한다.
`done` 이면 건너뛴다.

Agent 도구로 cch-init-scaffold 스킬을 실행한다:

```
Agent(subagent_type="general-purpose")
프롬프트: "skills/cch-init-scaffold/SKILL.md 의 지침을 따라 CCH 디렉터리 구조를 스캐폴딩하라.
  .claude/cch/init/scan-result.json 을 입력으로 사용하라.
  다음을 생성하라:
  - CCH 디렉터리 구조 (.claude/, bin/, skills/ 등 필요한 항목)
  - manifests/ 디렉터리 및 기본 매니페스트
  - profiles/ 디렉터리 및 기본 프로파일
  완료 후 생성된 디렉터리/파일 목록을 반환하라."
```

완료 후 진행 상태를 업데이트한다:

```bash
echo "done" > .claude/cch/init/progress
```

---

## Step 5: 최종 보고

`.claude/cch/init/scan-result.json`을 읽어 프로젝트 요약을 구성한다.

사용자에게 다음을 보고한다:

### 보고 형식

```
## CCH Init 완료

### 프로젝트 요약
- 이름: <project-name>
- 기술 스택: <tech-stack>
- 규모: <scale (파일 수, 라인 수 등)>
- 특이사항: <notable findings>

### 생성된 파일

#### 문서
- docs/Architecture.md
- docs/PRD.md
- docs/Roadmap.md

#### CCH 구조 (migrate 모드만)
- <scaffolded directories and files>

### 다음 권장 단계
```

**onboard 모드 권장 단계:**

```
1. 생성된 문서를 검토하고 필요에 따라 수정하세요:
   - docs/Architecture.md — 시스템 구조 확인
   - docs/PRD.md — 제품 요구사항 확인
   - docs/Roadmap.md — 개발 로드맵 확인
2. CCH 마이그레이션이 필요하다면 /cch-init migrate 를 실행하세요
```

**migrate 모드 권장 단계:**

```
1. bin/cch setup 으로 CCH를 초기화하세요
2. 생성된 문서를 검토하고 필요에 따라 수정하세요
3. manifests/ 및 profiles/ 를 프로젝트에 맞게 조정하세요
4. /cch-status 로 CCH 상태를 확인하세요
```

---

## 에러 처리

| 단계 | 실패 | 대응 |
|------|------|------|
| Pre-check | `.claude/cch/init/` 생성 실패 | 권한 오류 안내 후 중단 |
| Scan | cch-init-scan 실패 | 에러 메시지 출력, 재시도 여부 AskUserQuestion |
| Docs | cch-init-docs 실패 | 에러 메시지 출력, 부분 생성된 파일 안내 |
| Scaffold | cch-init-scaffold 실패 | 에러 메시지 출력, 수동 조치 안내 |

Scan 또는 Docs 실패 시 AskUserQuestion:

```
question: "<단계> 단계에서 오류가 발생했습니다. 어떻게 처리할까요?"
options:
  - "재시도"
  - "이 단계 건너뛰기"
  - "취소"
```
