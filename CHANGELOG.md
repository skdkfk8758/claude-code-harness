# Changelog

## [0.5.0] - 2026-03-09

### 새 기능
- **workflow**: 스킬 스텝 auto-dispatch 및 3단계 gate 레벨(approval/checkpoint/auto) 도입
- **workflow**: 완료 후속 제안 체계 및 next-suggestions YAML 필드 추가
- **workflow**: feature-dev에 tech-research 조건부 스텝, metric-design 선택 스텝 추가
- **workflow**: 프로젝트 로컬 리소스 해석 확장 기능 추가
- **workflow**: 워크플로우 히스토리 추적 기능 추가
- **brainstorming**: ICE 스코어링, 4관점 스트레스 테스트, Tigers Pre-Mortem 프레임워크 도입
- **writing-plans**: 태스크별 복잡도/리스크 지표(🟢🟡🔴) 및 위험 태스크 배치 격리
- **hud**: 세션 경과 시간, 워크플로우 5칸 진행 바(█░), 컨텍스트 모드(percent/tokens/both) 추가
- **agents**: web-research-specialist 버전 감지 및 context7/llms.txt 문서 fallback 체인 추가
- **skill-manager**: discover 핸들러(skills.sh/GitHub 검색), 유령 참조 탐지, 중복 감지, 구조 무결성 검사 추가
- **skills**: experiment-analysis(A/B 테스트 분석), metric-design(성공 지표 정의) 스킬 추가
- **plan-cleanup**: 플랜 문서 아카이브 스킬 추가

### 문서
- 6개 스킬에 Domain Context 섹션 추가 (방법론 근거 및 참고 문헌)
- CLAUDE.md에 사용자 대면 용어 규칙 및 Auto-Fix 규칙 추가
- README를 feature-dev 9단계 워크플로우에 맞춰 업데이트

### 버그 수정
- **hud**: rate limit API 에러(429) 시 캐시 TTL 무시 버그 수정 (v0.4.4)

## [0.4.4] - 2026-03-06

### 버그 수정
- **hud**: rate limit API 에러(429) 시 캐시 TTL 무시되어 매 요청마다 재호출되는 버그 수정

## [0.4.3] - 2026-03-06

### 리팩토링
- **workflow**: 워크플로우 목록을 하드코딩에서 YAML 동적 스캔 방식으로 변경

## [0.4.2] - 2026-03-06

### 새 기능
- **agent**: spec-reviewer 독립 검증 모드(Mode B) 추가 — 기획서 대비 구현 충족도 검증

## [0.4.1] - 2026-03-06

### 새 기능
- **skill**: commit, pr 스킬 추가
- **release**: 릴리즈 스킬 한글화 및 플러그인 버전 동기화 추가

## [0.4.0] - 2026-03-06

### 새 기능
- **workflow**: 자동 브랜치 생성 기능 추가
- **skill**: meta-cognitive 기법 도입 (stack-skills 기반)
- **workflow**: planning-only, quick-fix, skill-creation 워크플로우 추가

### 문서
- **docs**: CLAUDE.md 프로젝트 규칙 추가 및 README v3 업데이트

### 리팩토링
- **agents**: 기존 에이전트 및 스킬 v3 정렬 리파인

## [0.3.0] - 2026-03-05

### 새 기능
- Workflow orchestration 시스템 도입
- Skill gates 및 agent dispatch 메커니즘
