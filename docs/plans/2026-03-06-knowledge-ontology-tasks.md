# Knowledge Ontology Layer -- Tasks

## Summary
- **Total**: 8 tasks in 3 batches
- **Target file**: `skills/workflow/SKILL.md` (449줄, 마크다운 프롬프트)
- **Additional file**: `.gitignore` (Task 1)
- **Agent/YAML 변경**: 없음
- **삽입 위치 기준**: 라인 번호가 아닌 **섹션 헤딩 기반**으로 위치 지정 (이전 Task의 삽입으로 라인이 밀리므로)

## Known Limitations
- agent-chain에서 첫 에이전트에만 context injection (reviewer는 간접 전달)
- 이 한계는 의도적 설계 (백로그: 옵션 C에서 해결 예정)
- YAML step 정의에 `input` 필드가 없는 step도 있음 → P1 매칭은 "이전 step의 output" 또는 "현재 step의 input"이 있을 때만 적용

---

--- Batch 1 (Tasks 1-3) → checkpoint ---

### Task 1: .gitignore에 knowledge-graph.json 추가
- **Estimate**: 2분
- **Files**: `.gitignore`
- **Changes**:
  - `.claude/workflow-state.json` 라인 다음에 `.claude/knowledge-graph.json` 추가
- **TDD Steps**:
  1. RED: `.gitignore`를 읽고 `knowledge-graph.json`이 없음을 확인
  2. GREEN: `.claude/workflow-state.json` 다음 줄에 `.claude/knowledge-graph.json` 추가
  3. REFACTOR: 불필요
- **Verify**: `grep "knowledge-graph" .gitignore` → `.claude/knowledge-graph.json` 출력
- **Dependencies**: none

### Task 2: Knowledge Graph Management 섹션 헤더 + 스키마 정의 추가
- **Estimate**: 5분
- **Files**: `skills/workflow/SKILL.md`
- **Changes**:
  - **삽입 위치**: `## Error Handling` 헤딩 직전 (빈 줄 포함)
  - 삽입할 내용:

```
## Knowledge Graph Management

이 섹션은 워크플로우 step 완료 시 산출물에서 도메인 지식을 추출하고,
에이전트 dispatch 시 관련 지식을 자동 주입하는 기능을 정의한다.
knowledge-graph.json이 없으면 이 섹션의 모든 로직을 건너뛴다 (하위 호환).

### Schema

`.claude/knowledge-graph.json` 구조 (빈 그래프 초기화 시):

    {
      "version": "1.0",
      "lastUpdated": "ISO-8601",
      "projectId": "프로젝트명 (디렉터리명 또는 package.json name)",
      "concepts": [],
      "decisions": [],
      "artifacts": [],
      "changelog": []
    }

Node types, concept types, relation types, artifact types는
디자인 문서(`docs/plans/2026-03-06-knowledge-ontology-design.md`)의
Knowledge Graph Schema 섹션을 참조.
```

- **TDD Steps**:
  1. RED: SKILL.md에서 `## Knowledge Graph Management` 검색 → 없음 확인
  2. GREEN: `## Error Handling` 직전에 위 내용 삽입
  3. REFACTOR: 기존 섹션 순서와 어울리는지 확인 (Agent Dispatch Red Flags 다음)
- **Verify**: `grep -n "Knowledge Graph Management" skills/workflow/SKILL.md` → 라인 번호 출력
- **Dependencies**: none

### Task 3: Indexing 서브섹션 추가
- **Estimate**: 5분
- **Files**: `skills/workflow/SKILL.md`
- **Changes**:
  - **삽입 위치**: `### Schema` 서브섹션의 마지막 줄 ("Knowledge Graph Schema 섹션을 참조.") 다음
  - 삽입할 내용:

```
### Indexing (step 완료 후)

각 step 완료 후 output 파일이 존재하면:

1. `.claude/knowledge-graph.json` 읽기 (없으면 빈 그래프 초기화)
2. output 마크다운을 읽고, 아래 추출 지시에 따라 concepts/decisions/changelog 추출
3. 기존 concept과 name 매칭 — 있으면 병합(files, relations 합집합), 없으면 신규 생성
4. artifact 노드 추가 (derivedFrom은 이전 step의 artifact id)
5. knowledge-graph.json 저장
6. 인덱싱 실패 시 (파일 I/O 에러 등) 경고만 출력하고 워크플로우는 계속 진행:

    [workflow] Knowledge indexing failed: {error}. Continuing without indexing.

#### Step type별 Indexing 적용

| Step Type | Indexing 시점 |
|-----------|--------------|
| `type: skill` (Gate) | 사용자 승인 후, output 파일이 존재하면 인덱싱 |
| `type: agent` | 에이전트 완료 후 output 인덱싱 |
| `type: agent-chain` | 체인 전체 완료 후 최종 output 인덱싱 |
| `type: parallel` | 모든 sub-step 완료 후 각각의 output 개별 인덱싱 |
| `type: conditional` | 실행된 branch의 output 인덱싱 |

#### 추출 지시

step output 마크다운을 읽은 후, 다음을 추출:

1. **concepts** — 도메인 엔티티, 서비스, 패턴, 모듈, 인프라
   - name, type, description (1줄), files (언급된 파일 경로), relations
2. **decisions** — 설계/구현 결정과 근거
   - content, rationale, 관련 concepts
3. **changelog** — 이 step에서 변경/영향받은 개념과 파일
   - conceptsAffected, filesChanged, summary (1줄)

추출 규칙:
- 기존 concept은 name으로 매칭하여 병합 (files, relations 합집합)
- 새 concept만 신규 생성
- 불확실한 추출은 하지 않음 — 명시적으로 언급된 것만 추출

산출물 유형별 추출 초점:

| 산출물 유형 | 주요 추출 대상 | 파싱 힌트 |
|------------|--------------|----------|
| design.md | concepts, decisions | "## Architecture", "## Components", "## Decision Summary" |
| plan.md | concepts 보강 (파일 매핑) | "## Architecture Impact", "## Task Overview" |
| context.md | decisions | "## Key Decisions", "## Technical Context" |
| tasks.md | concept-file 매핑 | 각 Task의 "Files" 목록 |
| review.md | changelog, 이슈 기록 | "## Blocking Issues", "## Verification Drift" |
```

- **TDD Steps**:
  1. RED: SKILL.md에서 `### Indexing` 검색 → 없음 확인
  2. GREEN: Schema 서브섹션 다음에 위 내용 삽입
  3. REFACTOR: 추출 지시가 디자인 문서의 Extraction Rules와 일치하는지 확인
- **Verify**: `grep -cE "Indexing|Step type별|추출 지시|산출물 유형별" skills/workflow/SKILL.md` → 4 이상 출력
- **Dependencies**: Task 2

--- Batch 2 (Tasks 4-6) → checkpoint ---

### Task 4: Context Injection 서브섹션 추가
- **Estimate**: 5분
- **Files**: `skills/workflow/SKILL.md`
- **Changes**:
  - **삽입 위치**: `### Indexing` 서브섹션 전체(산출물 유형별 추출 초점 테이블 포함)의 마지막 줄 다음
  - 삽입할 내용:

```
### Context Injection (agent dispatch 시)

에이전트 dispatch prompt 구성 시, knowledge-graph.json이 존재하면:

1. knowledge-graph.json 읽기
2. 3단계 관련성 매칭으로 concepts 필터:
   - **P1 (Artifact)**: 현재 step의 input 파일 경로 또는 이전 step의 output 파일 경로 →
     artifacts 배열에서 path 매칭 → 해당 artifact의 concepts.
     YAML에 input 필드가 없는 step은 이전 step의 output만 사용.
   - **P2 (Workflow 내부)**: 현재 workflow의 이전 step에서 생성된 decisions, concepts
     (workflow-state.json의 decisions 필드와 교차 참조)
   - **P3 (Git diff)**: `git diff --name-only main..HEAD`의 변경 파일과
     concept.files의 교집합 (implementation, review step에서 주로 활용)
3. 관련 concepts의 최근 decisions (최대 5개) 수집
4. 관련 concepts의 changelog (최대 3개) 수집
5. 50줄 이내로 포맷하여 dispatch prompt에 추가 (초과 시 P1 > P2 > P3 순 절삭):

    ## Project Knowledge Context (auto-injected)

    ### Domain Concepts Related to This Task
    - {concept.name}: {concept.description}, {concept.files 요약}

    ### Relevant Past Decisions
    - [{decision.date}] "{decision.content}" ({decision.workflow})

    ### Change History for Affected Concepts
    - {concept.name}: {modifiedCount}회 수정 (최근: {lastModified})

6. 관련 concept이 없으면 이 섹션을 생략 (빈 컨텍스트 주입 안 함)

knowledge-graph.json이 없으면 context injection을 건너뛴다 (하위 호환).

#### Step type별 Context Injection 적용

| Step Type | Context Injection |
|-----------|------------------|
| `type: skill` (Gate) | 미적용 — 사용자가 직접 스킬 호출하므로 오케스트레이터 개입 불가 |
| `type: agent` | 적용 — dispatch prompt에 knowledge context 추가 |
| `type: agent-chain` | 첫 번째 에이전트 dispatch에만 주입 (후속 에이전트는 이전 output이 컨텍스트) |
| `type: parallel` | 각 sub-step dispatch에 독립적으로 주입 |
| `type: conditional` | 선택된 branch의 에이전트 dispatch에 주입 |
```

- **TDD Steps**:
  1. RED: SKILL.md에서 `### Context Injection` 검색 → 없음 확인
  2. GREEN: Indexing 서브섹션 다음에 위 내용 삽입
  3. REFACTOR: P1 매칭이 input 필드 없는 step도 커버하는지 확인
- **Verify**: `grep -cE "Context Injection|P1.*Artifact|P2.*Workflow|P3.*Git diff" skills/workflow/SKILL.md` → 4 출력
- **Dependencies**: Task 3

### Task 5: `type: agent` 섹션에 knowledge context dispatch 항목 추가
- **Estimate**: 3분
- **Files**: `skills/workflow/SKILL.md`
- **Changes**:
  - **삽입 위치**: `` ### `type: agent` (Executor — automatic) `` 섹션 내부,
    "Build the dispatch prompt:" 목록의 마지막 항목 (`- If step has `cross-cutting` list, read each skill's SKILL.md and append the core rules`) 다음 줄
  - 추가할 줄:
    ```
       - Append knowledge context (see Knowledge Graph Management > Context Injection)
    ```
- **TDD Steps**:
  1. RED: `type: agent` 섹션의 dispatch prompt 목록에 "knowledge context" 언급이 없음 확인
  2. GREEN: cross-cutting 항목 다음 줄에 위 내용 추가
  3. REFACTOR: 불필요
- **Verify**: `grep "Append knowledge context" skills/workflow/SKILL.md` → 해당 줄 출력
- **Dependencies**: Task 4

### Task 6: `type: agent-chain`, `type: parallel`, `type: conditional` 섹션에 knowledge context 항목 추가
- **Estimate**: 5분
- **Files**: `skills/workflow/SKILL.md`
- **Changes**:
  - **`` ### `type: agent-chain` (Chained Executors — automatic) ``** 섹션:
    "2. First agent: dispatch with full context" 다음 줄에 추가:
    ```
       - Include knowledge context in first agent dispatch only (see Knowledge Graph Management > Context Injection)
    ```
  - **`` ### `type: parallel` (Parallel Executors — automatic) ``** 섹션:
    "1. Dispatch all sub-steps simultaneously via Agent tool" 다음 줄에 추가:
    ```
       - Include knowledge context in each sub-step dispatch independently (see Knowledge Graph Management > Context Injection)
    ```
  - **`` ### `type: conditional` (Conditional Branch — automatic) ``** 섹션:
    "2. Dispatch `then` or `else` branch accordingly" 다음 줄에 추가:
    ```
       - Include knowledge context in the dispatched branch (see Knowledge Graph Management > Context Injection)
    ```
- **TDD Steps**:
  1. RED: 각 섹션에서 "knowledge context" 언급이 없음 확인
  2. GREEN: 각 섹션의 지정된 항목 다음 줄에 추가
  3. REFACTOR: 3개 섹션의 표현이 일관적인지 확인
- **Verify**: `grep -c "knowledge context" skills/workflow/SKILL.md` → 최소 4 출력 (Task 5의 1개 + 이 Task의 3개)
- **Dependencies**: Task 5

--- Batch 3 (Tasks 7-8) → checkpoint ---

**실행 순서: Task 8 먼저, 그 다음 Task 7** (둘 다 기존 섹션의 인접 영역을 수정하므로, 앞 라인을 수정하는 Task 8을 먼저 실행해야 Task 7의 위치가 안정적)

### Task 8: Auto-Extraction Rules에서 Knowledge Indexing 참조 추가
- **Estimate**: 2분
- **Files**: `skills/workflow/SKILL.md`
- **Changes**:
  - **삽입 위치 1**: `### Auto-Extraction Rules` 내부, "After each Auto step completes:" 목록의
    마지막 항목 ("4. Write to state file immediately") 다음 줄에 추가:
    ```
    5. Perform knowledge indexing (see Knowledge Graph Management > Indexing)
    ```
  - **삽입 위치 2**: 같은 섹션의 "After each Gate step:" 목록의
    마지막 항목 ("2. If user added comments beyond...") 다음 줄에 추가:
    ```
    3. Perform knowledge indexing if output file exists (see Knowledge Graph Management > Indexing)
    ```
- **TDD Steps**:
  1. RED: Auto-Extraction Rules에 "knowledge indexing" 참조가 없음 확인
  2. GREEN: 각 목록 끝에 위 항목 추가
  3. REFACTOR: 불필요
- **Verify**: `grep -c "knowledge indexing" skills/workflow/SKILL.md` → 2 출력
- **Dependencies**: Task 3

### Task 7: Resume with Context Recovery 섹션에 knowledge 요약 추가
- **Estimate**: 3분
- **Files**: `skills/workflow/SKILL.md`
- **Changes**:
  - **삽입 위치**: `### Resume with Context Recovery` 내부, 단계 목록의 마지막 항목
    ("4. Inject the `summary` and `decisions` from all completed steps into the next agent's dispatch prompt") 다음 줄에 추가:
    ```
    5. If `.claude/knowledge-graph.json` exists, append knowledge summary to the resume display:
       ```
       Knowledge: 주요 개념 {N}개 ({concept names}), 관련 결정 {M}건
       ```
       knowledge-graph.json이 없으면 이 줄을 생략.
    ```
- **TDD Steps**:
  1. RED: Resume 섹션에 knowledge 관련 단계가 없음 확인
  2. GREEN: 4번째 단계 다음에 위 내용 추가
  3. REFACTOR: resume 출력 예시의 포맷이 기존 스타일과 일관적인지 확인
- **Verify**: `grep "Knowledge:" skills/workflow/SKILL.md` → 해당 줄 출력
- **Dependencies**: Task 8 (같은 Batch에서 Task 8 이후 실행)

---

## Verification Checklist (전체 완료 후)

1. `grep "knowledge-graph" .gitignore` → 출력 확인
2. `grep -cE "Knowledge Graph Management|### Indexing|### Context Injection" skills/workflow/SKILL.md` → 3 출력
3. `grep -c "knowledge context" skills/workflow/SKILL.md` → 4+ 출력
4. `grep "Knowledge:" skills/workflow/SKILL.md` → resume 줄 출력
5. `grep -c "knowledge indexing" skills/workflow/SKILL.md` → 2 출력
6. SKILL.md 전체 줄 수 확인: `wc -l skills/workflow/SKILL.md` → 약 530-560줄 (80-110줄 증가)
7. `## Error Handling` 섹션이 `## Knowledge Graph Management` 다음에 위치하는지 확인
8. `## Knowledge Graph Management` 섹션이 `## Agent Dispatch Red Flags` 다음에 위치하는지 확인
