# Excalidraw Diagram Skill - 사용 가이드 & Best Practices

## 개요

자연어로 요청하면 Claude Code가 Excalidraw 다이어그램을 자동 생성하는 스킬.
아키텍처, 워크플로우, 프로토콜, 데이터 흐름 등을 시각적으로 표현할 수 있다.

**설치 경로**: `.claude/skills/excalidraw-diagram/`

---

## 빠른 시작

### 1. 기본 사용법

Claude Code에서 자연어로 요청:

```
"CCH의 훅 데이터 흐름을 Excalidraw 다이어그램으로 만들어줘"
"activity-tracker → summary-writer → cch-hud 의 session_id 흐름을 시각화해줘"
"현재 프로젝트 아키텍처를 다이어그램으로 그려줘"
```

### 2. 생성 결과물

- `.excalidraw` JSON 파일 (Excalidraw에서 열기/편집 가능)
- `.png` 렌더링 이미지 (검증용 자동 생성)

### 3. 렌더링 명령

```bash
cd .claude/skills/excalidraw-diagram/references
uv run python render_excalidraw.py <path-to-file.excalidraw>
```

---

## Best Practices

### 요청 시 포함할 정보

| 구분 | 좋은 요청 | 나쁜 요청 |
|------|-----------|-----------|
| **구체성** | "UserPromptSubmit → activity-tracker → last_question 파일 기록 흐름" | "훅 흐름 그려줘" |
| **깊이 지정** | "실제 JSON 페이로드와 파일 경로를 포함한 기술 다이어그램" | "다이어그램 만들어" |
| **용도 명시** | "README에 넣을 아키텍처 개요도" | "그림 하나 그려" |

### 다이어그램 유형별 가이드

#### 1. 아키텍처 다이어그램 (Comprehensive)

시스템 컴포넌트 간 관계를 표현. 실제 파일 경로, API 엔드포인트, 데이터 포맷을 포함.

```
"CCH 프로젝트의 전체 아키텍처를 다이어그램으로 만들어줘.
 hooks/, scripts/, skills/ 간 관계와 데이터 흐름을 실제 파일명으로 표시."
```

**적합한 패턴**: Fan-out (훅 분배), Assembly Line (데이터 변환), 섹션 경계 (컴포넌트 분리)

#### 2. 워크플로우/시퀀스 다이어그램 (Comprehensive)

단계별 처리 흐름. 타임라인 패턴과 실제 이벤트명 사용.

```
"사용자 프롬프트부터 statusline 표시까지의 전체 워크플로우를 그려줘.
 각 단계에서 어떤 파일이 생성/읽기되는지 포함."
```

**적합한 패턴**: Timeline (순서), Convergence (병합), Gap/Break (단계 구분)

#### 3. 개념 다이어그램 (Simple)

추상적 관계나 멘탈 모델 표현. 라벨 중심, 구체적 데이터 불필요.

```
"CCH의 모드 전환 개념 (plan → code → tool → swarm)을 시각화해줘"
```

**적합한 패턴**: Spiral/Cycle (순환), Side-by-Side (비교), Cloud (추상 상태)

#### 4. 의사결정 플로우 (Simple/Comprehensive)

조건 분기와 결정 포인트 표현.

```
"훅 이벤트 라우팅 로직을 의사결정 다이어그램으로 만들어줘.
 UserPromptSubmit, PreToolUse, Stop 각각의 분기를 포함."
```

**적합한 패턴**: Diamond (결정), Fan-out (분기), Assembly Line (처리)

---

## 커스터마이징

### 브랜드 컬러 변경

`references/color-palette.md` 파일 하나만 수정하면 전체 스타일 적용:

```markdown
| Semantic Purpose | Fill | Stroke |
|------------------|------|--------|
| Primary/Neutral  | `#3b82f6` | `#1e3a5f` |  ← 이 값들을 브랜드 컬러로 변경
```

### 주요 시맨틱 컬러 역할

| 용도 | 기본 Fill | 설명 |
|------|-----------|------|
| Primary | `#3b82f6` (파랑) | 일반 컴포넌트 |
| Start/Trigger | `#fed7aa` (주황) | 시작점, 트리거 |
| End/Success | `#a7f3d0` (초록) | 완료, 성공 |
| Decision | `#fef3c7` (노랑) | 조건 분기 |
| AI/LLM | `#ddd6fe` (보라) | AI 관련 요소 |
| Error | `#fecaca` (빨강) | 에러, 실패 |

---

## 품질 체크리스트

다이어그램 생성 후 자동으로 검증 루프가 실행된다. 수동 확인이 필요할 때 참고:

### 필수 확인 항목

- [ ] **구조 반영**: 시각적 구조가 개념적 구조를 반영하는가?
- [ ] **텍스트 가독성**: 모든 텍스트가 잘리지 않고 읽을 수 있는가?
- [ ] **화살표 정확성**: 화살표가 올바른 요소를 연결하는가?
- [ ] **간격 균일성**: 요소 간 간격이 일관적인가?
- [ ] **시각적 계층**: 중요한 요소가 더 크고 눈에 띄는가?

### 기술 다이어그램 추가 확인

- [ ] **실제 데이터**: 실제 이벤트명, 파일 경로, JSON 포맷이 포함되어 있는가?
- [ ] **코드 스니펫**: 관련 코드 예시가 포함되어 있는가?
- [ ] **멀티 줌**: 요약 흐름 + 섹션 경계 + 세부사항 3단계가 있는가?

---

## 출력 파일 관리

### 권장 저장 경로

```
docs/diagrams/              ← 프로젝트 문서용 다이어그램
  architecture.excalidraw
  architecture.png
  hook-flow.excalidraw
  hook-flow.png
```

### Excalidraw 파일 편집

생성된 `.excalidraw` 파일은 [excalidraw.com](https://excalidraw.com)에서 열어 수동 편집 가능.

---

## 트러블슈팅

| 문제 | 해결 |
|------|------|
| `uv: command not found` | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| Playwright 렌더링 실패 | `cd references && uv run playwright install chromium` |
| 다이어그램이 너무 큼 | 섹션별 빌드 요청: "먼저 인프라 섹션만 그려줘" |
| 텍스트 깨짐/겹침 | 렌더 후 자동 수정 루프가 처리. 반복 안 되면 수동으로 좌표 조정 |
| 색상 변경 안 됨 | `references/color-palette.md` 수정 후 다시 생성 |

---

## 활용 시나리오 예시

### PRD/설계 문서에 포함

```
"PRD의 시스템 아키텍처 섹션에 넣을 다이어그램을 만들어줘.
 docs/PRD.md의 아키텍처 설명을 기반으로."
```

### ADR (Architecture Decision Record) 시각화

```
"session_id 통일 결정의 before/after를 비교하는 다이어그램을 만들어줘.
 process.ppid 방식 vs session_id 방식의 데이터 흐름 차이를 보여줘."
```

### README 아키텍처 개요

```
"README에 넣을 프로젝트 구조 개요 다이어그램을 만들어줘.
 심플하게 주요 디렉토리와 역할만."
```

### 디버깅/분석 시각화

```
"현재 버그의 데이터 흐름을 다이어그램으로 그려줘.
 어디서 데이터가 끊기는지 빨간색으로 표시."
```
