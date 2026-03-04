---
name: cch-lsp
description: "Project LSP detection/installation — file scan, interview, LSP server install, Serena config"
user-invocable: true
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
argument-hint: [scan|add <language>|status|remove <language>]
---

# CCH LSP — 프로젝트 LSP 감지 및 설치

프로젝트 파일을 스캔하여 필요한 언어 서버를 자동 감지하고, 사용자 확인 후 설치합니다.

## 서브커맨드 라우팅

인자를 파싱하여 해당 섹션으로 이동합니다:
- 인자 없음 → **Full Flow** 실행
- `scan` → **Step 1 (SCAN)** 만 실행 후 종료
- `add <language>` → **Add Flow** 실행
- `status` → **Status Flow** 실행
- `remove <language>` → **Remove Flow** 실행

---

## Full Flow

### Step 1 — SCAN: 프로젝트 파일 확장자 스캔

Glob 도구로 다음 패턴을 **병렬** 검색합니다:

| Serena ID | 패턴 |
|-----------|------|
| `typescript` | `**/*.ts`, `**/*.tsx`, `**/*.js`, `**/*.jsx` |
| `python` | `**/*.py` |
| `go` | `**/*.go` |
| `rust` | `**/*.rs` |
| `java` | `**/*.java` |
| `bash` | `**/*.sh`, `**/*.bash` |
| `ruby` | `**/*.rb` |
| `php` | `**/*.php` |
| `cpp` | `**/*.c`, `**/*.cpp`, `**/*.h`, `**/*.hpp` |
| `kotlin` | `**/*.kt`, `**/*.kts` |
| `swift` | `**/*.swift` |
| `dart` | `**/*.dart` |
| `lua` | `**/*.lua` |
| `yaml` | `**/*.yml`, `**/*.yaml` |
| `toml` | `**/*.toml` |

결과에서 `node_modules/`, `.git/`, `vendor/`, `dist/`, `build/` 경로를 포함하는 파일은 필터링합니다. Glob 결과를 받은 후 이 경로를 포함하는 항목을 제외하고 카운트합니다.

각 언어별 매치 파일 수를 집계합니다. 매치가 1개 이상인 언어만 "감지된 언어"로 분류합니다.

`scan` 서브커맨드인 경우 결과를 테이블로 출력하고 종료:
```
## LSP 스캔 결과

| 언어 | 감지 파일 수 | 현재 설치 |
|------|-------------|-----------|
| typescript | 42 | [MISSING] |
| bash | 15 | [OK] |
| python | 3 | [MISSING] |
```

### Step 2 — STATUS: 현재 설정 확인

`.serena/project.yml` 파일이 존재하는지 확인합니다. 파일이 없으면 기본 템플릿으로 생성합니다:
```yaml
project_name: ""
languages: []
encoding: "utf-8"
```

`.serena/project.yml` 파일을 Read 도구로 읽어 `languages:` 배열에서 이미 설정된 언어를 추출합니다.

감지된 언어 목록에서 이미 설정된 언어를 분리합니다:
- **신규 필요**: 감지됐지만 미설정
- **이미 설정됨**: 감지됐고 이미 설정됨

### Step 3 — INTERVIEW: 사용자 확인

신규 필요 언어가 없으면 "모든 감지된 언어가 이미 설정되어 있습니다" 출력 후 종료합니다.

신규 필요 언어가 있으면 AskUserQuestion으로 설치할 언어를 multi-select합니다:

```
질문: "다음 언어의 LSP 서버를 설치하시겠습니까?"
multiSelect: true
옵션: 감지된 신규 언어 각각 (파일 수 포함)
  예: "TypeScript (42 files)" → typescript
      "Python (3 files)" → python
```

대안이 있는 언어(Python)를 선택한 경우 추가 질문:
```
질문: "Python LSP 서버를 선택해주세요"
옵션:
  - "python-lsp-server (pylsp) — 플러그인 확장 가능" → python
  - "jedi-language-server — 가벼움" → python_jedi
```

### Step 4 — INSTALL: LSP 서버 설치

선택된 각 언어에 대해 Bash로 설치 커맨드를 실행합니다.

플랫폼별 분기가 필요한 언어(cpp, lua)는 먼저 `uname -s`를 실행하여 OS를 감지합니다 (Darwin = macOS, Linux = Linux).

**설치 커맨드 매핑:**

| Serena ID | 설치 커맨드 | 확인 커맨드 |
|-----------|------------|-------------|
| `typescript` | `npm i -g typescript-language-server typescript` | `command -v typescript-language-server` |
| `python` | `pip install python-lsp-server` | `command -v pylsp` |
| `python_jedi` | `pip install jedi-language-server` | `command -v jedi-language-server` |
| `go` | `go install golang.org/x/tools/gopls@latest` | `command -v gopls` |
| `rust` | `rustup component add rust-analyzer` | `command -v rust-analyzer` |
| `java` | 설치 안내만 출력 | — |
| `bash` | `npm i -g bash-language-server` | `command -v bash-language-server` |
| `ruby` | `gem install solargraph` | `command -v solargraph` |
| `php` | `npm i -g intelephense` | `command -v intelephense` |
| `cpp` | macOS: `brew install llvm`; Linux: `sudo apt install clangd` | `command -v clangd` |
| `kotlin` | 설치 안내만 출력 | — |
| `swift` | Xcode 내장 — 안내만 | — |
| `dart` | Dart SDK 내장 — 안내만 | — |
| `lua` | macOS: `brew install lua-language-server`; Linux: 안내 | `command -v lua-language-server` |
| `yaml` | `npm i -g yaml-language-server` | `command -v yaml-language-server` |
| `toml` | `cargo install taplo-cli` | `command -v taplo` |

**설치 전 사전 검사:**
- npm 기반: `command -v npm` 확인, 없으면 "npm이 필요합니다" 안내
- pip 기반: `command -v pip` 또는 `command -v pip3` 확인
- go 기반: `command -v go` 확인
- 기타: 해당 패키지 매니저 존재 확인

**실패 처리:**
- 설치 실패 시 에러 메시지를 캡처하여 출력
- 실패한 언어는 건너뛰고 나머지 계속 진행
- 최종 결과에 실패 목록 포함

### Step 5 — CONFIG: .serena/project.yml 업데이트

`.serena/project.yml` 파일이 존재하는지 확인합니다. 파일이 없으면 기본 템플릿으로 생성합니다:
```yaml
project_name: ""
languages: []
encoding: "utf-8"
```

성공적으로 설치된 언어만 `.serena/project.yml`의 `languages:` 배열에 추가합니다.

Edit 도구를 사용하여 기존 languages 배열에 새 항목을 추가합니다.

예시 — 기존:
```yaml
languages:
- bash
```

typescript와 python 추가 후:
```yaml
languages:
- bash
- typescript
- python
```

**주의:** 이미 존재하는 언어는 중복 추가하지 않습니다.

### Step 6 — RESTART: Serena LSP 재시작

project.yml이 변경되었으므로 다음을 안내합니다:

"Serena LSP 서버가 재시작되어야 합니다. Claude Code 세션을 재시작해주세요."

(참고: `restart_language_server` MCP 도구는 개별 파일 변경 후 사용. project.yml의 languages 변경은 세션 재시작이 필요할 수 있음)

### Step 7 — VERIFY: 설치 확인 및 보고

Bash로 각 설치된 언어의 확인 커맨드를 실행하여 바이너리 존재를 검증합니다.

최종 결과를 테이블로 출력:
```
## LSP 설치 완료

| 언어 | Serena ID | 서버 | 상태 |
|------|-----------|------|------|
| TypeScript | typescript | typescript-language-server | [OK] 설치됨 |
| Python | python | pylsp | [OK] 설치됨 |
| Go | go | gopls | [MISSING] 설치 실패 |

project.yml 업데이트: [OK]
세션 재시작 필요: [WARN] 새 언어가 추가되었으므로 세션을 재시작해주세요.
```

---

## Add Flow (`/cch-lsp add <language>`)

1. `<language>`가 유효한 Serena ID인지 검증 (위 매핑 테이블 참조)
2. 이미 project.yml에 있는지 확인 → 있으면 "이미 설정되어 있습니다" 출력 후 종료
3. Step 4 (INSTALL) 실행 — 해당 언어만
4. Step 5 (CONFIG) 실행
5. Step 6 (RESTART) 실행
6. Step 7 (VERIFY) 실행 — 해당 언어만

---

## Status Flow (`/cch-lsp status`)

1. `.serena/project.yml` 파일이 없으면 'Serena project.yml이 없습니다 — 설정된 언어 없음'을 출력하고 종료합니다.
2. `.serena/project.yml` 읽기 → 설정된 languages 추출
3. 각 언어의 LSP 서버 바이너리 존재 확인 (`command -v`)
4. 테이블 출력:
```
## 현재 LSP 상태

| Serena ID | 서버 바이너리 | 설치 상태 |
|-----------|--------------|-----------|
| bash | bash-language-server | [OK] |
```

---

## Remove Flow (`/cch-lsp remove <language>`)

1. `<language>`가 project.yml에 있는지 확인 → 없으면 "설정되지 않은 언어입니다" 출력 후 종료
2. 마지막 언어인지 확인 → 마지막이면 "최소 1개 언어가 필요합니다" 경고 후 종료
3. AskUserQuestion으로 확인: "bash LSP를 제거하시겠습니까? (project.yml에서만 제거, 서버 바이너리는 유지)"
4. Edit 도구로 project.yml에서 해당 언어 제거
5. 제거 후 project.yml을 다시 읽어 해당 언어가 실제로 제거되었는지 검증합니다
6. 결과 테이블 출력:
```
## LSP 제거 완료

| 항목 | 값 |
|------|-----|
| 제거된 언어 | <language> |
| project.yml 반영 | [OK] |
```
7. 세션 재시작 안내: "Serena LSP 서버가 재시작되어야 합니다. Claude Code 세션을 재시작해주세요."
