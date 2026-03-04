# Claude Framework 설계 문서 (v1.7, Plugin MVP)

- 작성일: 2026-03-03
- 상태: Draft v1.7
- 목표: "클로드코드 플러그인으로 실제 설치/사용 가능한 설계"로 정렬

## 1) 설계 목표

기존 인터뷰 결정사항은 유지하되, 제품 형태를 명확히 `Claude Code plugin`으로 고정한다.

1. 사용자 진입점은 `/plugin install` 이후 slash command 사용
2. 내부 오케스트레이션 엔진은 `cch`로 유지
3. Baseline 운영선 + DOT 실험선의 dual-track 유지

## 2) 인터뷰 핵심 결정사항 (유효)

1. 속도+품질 균형 목표 유지
2. 공개 레포 + 팀 재사용 유지
3. 모드는 `plan/code/tool/swarm` 유지
4. `gptaku_plugins` 미가용 시 Graceful Fallback 유지
5. DOT는 2주 PoC, 기본 OFF, `code` 모드만 적용
6. DOT 채택은 엄격 KPI + 독립 킬스위치로 판정

## 3) 플러그인 계약 (Command Contract)

플러그인 설치 후 노출되는 사용자 명령은 다음으로 고정한다.

1. `/cch-setup`: 초기 환경 점검/설정
2. `/cch-mode <plan|code|tool|swarm>`: 모드 전환
3. `/cch-status`: 상태(`Healthy/Degraded/Blocked`) 조회
4. `/cch-update`: 업데이트/검증 실행
5. `/cch-dot on|off`: DOT 실험 플래그 토글 (`code` 모드 한정)

호환 alias:

- `/omc-setup` -> `/cch-setup` 위임 (기존 UX 호환)

## 4) 플러그인 설치/실행 라이프사이클

1. 설치
- `/plugin marketplace add <repo-url>`
- `/plugin install claude-code-harness`

2. 초기화
- `/cch-setup` 실행
- 필수 도구/경로/권한 검사

3. 실행
- `/cch-mode <mode>`로 capability 활성화
- 필요 시 `/cch-dot on`으로 DOT 실험선 진입

4. 운영
- `/cch-status`로 현재 건강 상태 및 fallback 확인
- `/cch-update`로 pin 검증 및 영향 요약 생성

## 5) 패키징 전략 (Plugin 적합성 보완)

P1 리스크 대응을 위해 배포 단위를 분리한다.

1. 개발 저장소(`dev source`)
- submodule 허용
- 실험/통합 작업 수행

2. 플러그인 릴리즈 아티팩트(`plugin release bundle`)
- submodule 의존 제거
- 고정된 lock/manifest와 실행 스크립트를 번들링
- 설치 시 git recursive clone이 없어도 동작

원칙:

- "개발 의존성"과 "사용자 설치 의존성"을 분리한다.

## 6) 런타임/파일 전략

1. 기본 정책: 심링크 강제 금지
- 가능한 경우 복사/미러 방식 우선
- 심링크는 성능 최적화 옵션으로만 사용

2. 상태 파일:
- `.claude/cch/` 하위에 mode, lock, health 저장

3. 실행 경로:
- slash command -> plugin handler -> `cch` engine -> `.resolved/`

## 7) 운영 모델 (Dual Track)

### 7.1 Baseline Track

- 코어: `superpowers`, `omc`, `ruflo`, `gptaku_plugins`
- 모드: `plan`, `code`, `tool`, `swarm`
- `ruflo`는 `swarm`에서 우선 연결

### 7.2 DOT Experiment Track

- 기본 OFF
- `code` 모드 only
- 규칙 소스 DOT only
- fetch 실패 시 로컬 lock/cache로 계속 실행

## 8) DOT PoC 게이트

1. 기간: 2주
2. KPI:
- 토큰 20%+ 절감
- 모드 전환 추가 지연 < 1초
- 프롬프트 충돌 주 1건 이하
3. 킬스위치(독립):
- 지연 실패 반복
- 품질 회귀 2회 이상
- 팀 독립 재현 실패
4. 통과 전 기본 상태:
- DOT 기본 OFF 유지

## 9) Superpowers 1차 이관 범위

DOT로 선별 이관:

1. `brainstorming`
2. `tdd`
3. `systematic-debugging`

## 10) 출시 전 필수 체크 (Plugin Ready Gate)

1. slash command 5종 동작 검증
2. `/omc-setup` alias 호환 검증
3. submodule 없이 clean install 성공
4. macOS/WSL 모두에서 `cch-setup -> cch-mode` 성공
5. `cch-status`에서 fallback 원인 가시화

## 11) 작업 기록 관리 모델 (Git vs Local)

기록은 "증적 문서"와 "실행 상태"를 분리한다.

1. PLAN (Git 관리)
- 경로: `docs/plans/YYYY-MM-DD-<work-id>-plan.md`
- 내용: 목표, 범위, 리스크, 승인 상태
- 생성 시점: `/cch-mode plan`

2. TODO (기본 로컬 상태)
- 경로: `.claude/cch/work-items/<work-id>/todo.yaml`
- 상태 전이: `todo -> doing -> blocked -> done`
- 갱신 시점: `/cch-mode code|tool|swarm` 실행 중

3. 실행 로그 (로컬 디버깅)
- 경로: `.claude/cch/runs/<date>/<work-id>.jsonl`
- 내용: 실행 명령, fallback, 오류 원인, 소요시간

4. 상태 조회
- `/cch-status`에서 PLAN + TODO + Health 통합 조회

5. Git 정책
- commit: `docs/plans/*`, 최종 결과 요약 문서
- ignore: `.claude/cch/runs/*`, `.claude/cch/work-items/*` (팀 합의 시 예외)

6. DOT PoC 메트릭
- 경로: `.claude/cch/metrics/dot-poc.jsonl`
- 항목: 토큰/지연/충돌 KPI, 킬스위치 트리거 여부

## 12) 테스트 전략 (Layered)

1. 플러그인 계약 테스트
- 대상: `/cch-setup`, `/cch-mode`, `/cch-status`, `/cch-update`, `/cch-dot`, `/omc-setup`
- 검증: 명령 존재, 인자 파싱, slash->engine 매핑

2. 에이전트 단위 테스트
- 대상: `plan/code/tool/swarm`
- 방식: 픽스처 입력 + 기대 결과(JSON/체크리스트)

3. 스킬 단위 테스트
- 대상: `brainstorming`, `tdd`, `systematic-debugging` 등
- 검증: 필수 절차 준수, 부작용 없음

4. 워크플로우 E2E 테스트
- 시나리오: `/cch-setup -> /cch-mode plan -> /cch-mode code -> /cch-status -> /cch-update`
- 검증: PLAN 생성, TODO 전이, fallback 표시, 최종 상태 일관성

5. 장애/회귀 테스트
- 대상: `gptaku/ruflo/DOT` 미가용 상황
- 검증: `Healthy/Degraded/Blocked` 판정 정확성, graceful fallback 동작

6. DOT 게이트 테스트
- `code` 모드 한정, 2주 KPI 측정
- 킬스위치 충족 시 즉시 중단/옵션화
