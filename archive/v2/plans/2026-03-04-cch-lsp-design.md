# CCH LSP Installer Skill Design

**Date**: 2026-03-04
**Status**: Approved
**Approach**: 순수 SKILL.md (B안)

## Overview

프로젝트 파일을 자동 스캔하여 필요한 LSP 서버를 감지하고, 사용자 인터뷰를 통해 확인 후 설치하는 CCH 스킬.

## Requirements

- **대상**: 새 프로젝트 온보딩 + 기존 프로젝트 수동 호출 모두 지원
- **범위**: LSP 서버 실제 설치 (`npm`, `pip`, `go install` 등)
- **UX**: 자동 감지 → 사용자 확인 → 설치
- **언어**: 주요 ~15개 언어
- **재시작**: 자동 `restart_language_server` 호출

## Skill Metadata

```yaml
name: cch-lsp
description: "프로젝트 LSP 감지/설치 — 파일 스캔 → 인터뷰 → LSP 서버 설치 → Serena 설정"
user-invocable: true
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion, mcp__serena__*]
argument-hint: "[scan|add <language>|status|remove <language>]"
```

## Subcommands

| Command | Description |
|---------|-------------|
| `/cch-lsp` | 전체 플로우 (스캔 → 인터뷰 → 설치) |
| `/cch-lsp scan` | 감지만 (설치 안 함) |
| `/cch-lsp add <language>` | 특정 언어 직접 추가 |
| `/cch-lsp status` | 현재 설치된 LSP 목록 |
| `/cch-lsp remove <language>` | 특정 언어 제거 |

## Language Mapping Table

| Language | Serena ID | File Patterns | Install Command |
|----------|-----------|---------------|-----------------|
| TypeScript/JS | `typescript` | `*.ts, *.tsx, *.js, *.jsx` | `npm i -g typescript-language-server typescript` |
| Python | `python` | `*.py` | `pip install python-lsp-server` |
| Python (Jedi) | `python_jedi` | `*.py` | `pip install jedi-language-server` |
| Go | `go` | `*.go` | `go install golang.org/x/tools/gopls@latest` |
| Rust | `rust` | `*.rs` | `rustup component add rust-analyzer` |
| Java | `java` | `*.java` | 안내만 (eclipse.jdt.ls) |
| Bash | `bash` | `*.sh, *.bash` | `npm i -g bash-language-server` |
| Ruby | `ruby` | `*.rb` | `gem install solargraph` |
| PHP | `php` | `*.php` | `npm i -g intelephense` |
| C/C++ | `cpp` | `*.c, *.cpp, *.h, *.hpp` | `brew install llvm` / `apt install clangd` |
| Kotlin | `kotlin` | `*.kt, *.kts` | 안내만 (kotlin-language-server) |
| Swift | `swift` | `*.swift` | Xcode sourcekit-lsp 내장 |
| Dart | `dart` | `*.dart` | Dart SDK 내장 |
| Lua | `lua` | `*.lua` | `brew install lua-language-server` |
| YAML | `yaml` | `*.yml, *.yaml` | `npm i -g yaml-language-server` |
| TOML | `toml` | `*.toml` | `cargo install taplo-cli` |

## Core Flow

```
/cch-lsp 실행:

1. [SCAN] 프로젝트 파일 확장자 스캔
   - Glob으로 각 언어 패턴 검색
   - 매치 수 집계 → 감지된 언어 목록 생성

2. [STATUS] 현재 .serena/project.yml 읽기
   - 이미 설정된 languages 확인
   - 감지됐지만 미설치인 언어 식별

3. [INTERVIEW] 사용자에게 결과 제시
   - "다음 언어가 감지되었습니다: [목록]"
   - AskUserQuestion으로 설치할 언어 multi-select
   - 대안이 있는 언어는 선택지 제시 (e.g. Python LSP 종류)

4. [INSTALL] 선택된 언어별 LSP 서버 설치
   - Bash로 설치 커맨드 실행
   - 설치 성공/실패 추적
   - 실패 시 에러 메시지 + 수동 설치 가이드

5. [CONFIG] .serena/project.yml 업데이트
   - languages 배열에 새 언어 추가
   - Edit 도구로 정확한 위치에 삽입

6. [RESTART] Serena LSP 재시작
   - restart_language_server 호출

7. [VERIFY] 설치 확인
   - which/command -v로 바이너리 존재 확인
   - 최종 상태 요약 출력
```

## Subcommand Flows

### `scan`
Step 1만 실행 → 감지된 언어 목록 출력

### `add <language>`
Step 4-7 실행 (해당 언어만)

### `status`
Step 2 실행 → 현재 설정 + 바이너리 존재 여부 출력

### `remove <language>`
languages 배열에서 제거 → project.yml 업데이트 → LSP 재시작

## Error Handling

- 패키지 매니저 없음: 설치 방법 안내 (brew/apt/npm 등)
- 권한 부족: sudo 필요 여부 안내
- 네트워크 오류: 재시도 안내
- 이미 설치됨: 스킵하고 config만 업데이트

## Integration

- `cch-init` 파이프라인에서 호출 가능 (온보딩 시)
- 독립 실행 가능 (`/cch-lsp`)
