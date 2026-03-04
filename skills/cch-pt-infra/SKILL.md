---
name: cch-pt-infra
description: PinchTab 서버 생명주기 및 인스턴스/프로필 관리
user-invocable: true
allowed-tools: Bash, Read, Write
---

# PinchTab Infrastructure Manager

PinchTab 서버의 설치, 시작, 상태 확인, 인스턴스/프로필 관리, 정리를 담당한다.

## 사전 조건

- Node.js/npm이 설치되어 있어야 한다
- Chrome 또는 Chromium이 시스템에 설치되어 있어야 한다

## 헬퍼 스크립트

모든 PinchTab 조작은 `bin/cch-pt` 래퍼를 통해 수행한다.

## 명령별 동작

### setup / ensure — 설치 및 서버 보장

```bash
# headless 모드 (기본)
bash bin/cch-pt ensure true

# headed 모드 (눈에 보이는 Chrome)
bash bin/cch-pt ensure false
```

1. `pinchtab` 설치 여부 확인, 미설치 시 `npm install -g pinchtab`
2. 서버 동작 여부 확인 (`/health`), 미실행 시 백그라운드로 시작
3. 최대 10초 대기 후 health check로 정상 확인
4. 실패 시 포트 충돌 가능성 안내

### status — 상태 확인

```bash
# health check
bash bin/cch-pt health

# 탭 목록
bash bin/cch-pt tabs
```

사용자에게 다음을 보고한다:
- 서버 실행 여부 및 포트
- 활성 탭 수 및 URL
- bridge 모드 상태

### tabs — 탭 관리

```bash
# 새 탭 생성
bash bin/cch-pt new-tab "https://example.com"

# 탭 닫기
bash bin/cch-pt close-tab "tab-id"

# 탭 목록
bash bin/cch-pt tabs
```

### cleanup — 전체 정리

```bash
bash bin/cch-pt cleanup
```

모든 인스턴스 중지 후 서버 프로세스 종료.

## 오케스트레이터 연동

`cch-pinchtab` 오케스트레이터에서 호출될 때의 출력 형식:

```json
{
  "status": "ready",
  "port": 9867,
  "tabId": "111CCA8D459265A0C5C83FF0AE4B4C78",
  "mode": "headless"
}
```

이 결과를 세션 디렉토리의 `infra-result.json`에 저장한다.

## 에러 처리

| 상황 | 대응 |
|------|------|
| pinchtab 미설치 | npm install -g pinchtab 자동 실행 |
| 서버 시작 실패 | 포트 충돌 확인 (`lsof -i :9867`), 대체 포트 안내 |
| health check 실패 | 3회 재시도 (2초 간격), 실패 시 로그 확인 안내 |
| Chrome 미설치 | 설치 가이드 안내 (brew install --cask chromium) |
