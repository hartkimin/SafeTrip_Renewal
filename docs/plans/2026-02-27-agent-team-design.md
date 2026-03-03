# SafeTrip Agent Team Design

**Date:** 2026-02-27
**Status:** Approved

## Overview

Claude Code `.claude/agents/` 디렉토리에 7개 에이전트 파일을 생성하여 SafeTrip 프로젝트용 멀티에이전트 팀을 구성한다.

## Agent Roster

| 파일 | 모델 | 역할 |
|------|------|------|
| `orchestrator.md` | claude-opus-4-6 | 메인 오케스트레이터 — 서브에이전트 디스패치, 순차/병렬 실행 조율 |
| `researcher.md` | claude-sonnet-4-6 | 기술 조사, 요구사항 분석, API 문서 탐색 (Read-only) |
| `flutter-developer.md` | claude-sonnet-4-6 | Flutter/Dart 앱 개발 |
| `backend-developer.md` | claude-sonnet-4-6 | Node.js/TypeScript 백엔드 개발, DB 스키마 관리 |
| `test-engineer.md` | claude-sonnet-4-6 | 테스트 작성 및 실행 |
| `infra-engineer.md` | claude-sonnet-4-6 | Firebase, ngrok, Docker, 배포 스크립트 관리 |
| `security-auditor.md` | claude-sonnet-4-6 | 보안 감사 (Read-only) |

## Domain Ownership (실제 프로젝트 경로)

| 에이전트 | 소유 경로 |
|---------|---------|
| flutter-developer | `safetrip-mobile/lib/`, `safetrip-mobile/pubspec.yaml`, `safetrip-mobile/assets/` |
| backend-developer | `safetrip-server-api/src/`, `safetrip-server-api/package.json`, `safetrip-server-api/scripts/` |
| test-engineer | `safetrip-mobile/test/`, `safetrip-mobile/integration_test/`, `safetrip-server-api/tests/` |
| infra-engineer | `scripts/`, `firebase.json`, `database.rules.json`, `storage.rules`, `.github/workflows/` |
| security-auditor | Read-only (수정 없음) |
| researcher | Read-only (수정 없음) |

## Execution Chains

### Feature Development
```
researcher → backend-developer(API spec) → flutter-developer(UI) → test-engineer → security-auditor
```

### DB Change
```
backend-developer(schema+migration) → backend-developer(API) → flutter-developer(model) → test-engineer
```

### Deployment
```
test-engineer(all tests) → security-auditor(audit) → infra-engineer(build+deploy)
```

## Parallelization Rules

- 같은 파일을 두 에이전트가 동시에 수정하지 않음
- 인터페이스(API 스펙, 모델)는 backend-developer가 먼저 확정
- DB 스키마 변경은 backend-developer만 담당

## File Structure (접근법 A: 간결형)

각 파일 구조:
```yaml
---
name: <에이전트 이름>
description: <이 에이전트를 언제 사용할지 구체적 트리거 설명>
model: claude-opus-4-6 | claude-sonnet-4-6
---

# Role
[역할 설명]

# Domain Ownership
[소유 파일/디렉토리]

# Forbidden
[금지 사항]

# Execution Rules
[순차 실행 체인 내 위치]
```
