# CCH v2 Archive

- 아카이브 날짜: 2026-03-05
- 아카이브 이유: CCH v3 리뉴얼 (외부 의존성 제거, 영속성 레이어 재설계)
- 복원 방법: `git checkout v2-archive` 또는 개별 파일 `git checkout v2-archive -- <path>`

## 내용물

### plans/ (20 files)
v2 시절 생성된 모든 설계/구현 플랜 문서. 2026-03-04 날짜의 모든 플랜.

### beads/ (11 files)
Beads(bd CLI) 이슈 트래킹 데이터.
- `issues.jsonl`: 100개 이슈 (98 closed, 2 open)
- `metadata.json`: DB 설정

### config-snapshots/ (4 files)
삭제 전 설정 파일 스냅샷:
- `global-settings.json`: `~/.claude/settings.json`
- `project-settings.json`: `.claude/settings.local.json`
- `installed-plugins.json`: 설치된 플러그인 목록
- `known-marketplaces.json`: 등록된 마켓플레이스 목록

## v2에서 사용했던 외부 의존성

| 이름 | 유형 | 버전 | 삭제 이유 |
|------|------|------|----------|
| superpowers | 플러그인 | 4.3.1 | 핵심 가치 내재화 완료, 나머지는 상식 |
| kkirikkiri | 플러그인 | 0.8.0 | Agent Teams 실험적 기능 의존, 독립적 |
| oh-my-claudecode | 플러그인 | - | Serena MCP가 동일 기능 커버 |
| beads (bd CLI) | 외부 도구 | 0.44.0 | 네이티브 4층 영속성으로 대체 |

## 참고할 패턴 (v3에서 재사용 가능)

| 출처 | 패턴 | 설명 |
|------|------|------|
| superpowers | Iron Law + Rationalization Table | 에이전트 자기합리화 방지 3단 구조 |
| superpowers | Two-stage review | spec compliance -> code quality 순서 강제 |
| superpowers | 3-failure threshold | 3회 fix 실패 시 아키텍처 문제로 판단 |
| kkirikkiri | Shared Memory 외부화 | TEAM_PLAN/PROGRESS/FINDINGS 파일 패턴 |
| kkirikkiri | DEAD_ENDS 로깅 | 실패 접근법 기록으로 반복 방지 |
| kkirikkiri | Quality Validation Loop | 3단계 에스컬레이션 전략 |
