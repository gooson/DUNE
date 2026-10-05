---
tags: [codex, pipeline, token-efficiency, ui-testing]
date: 2026-10-05
category: plan
status: approved
---

# 토큰 효율적인 검증 파이프라인

## 목표

UI 실패 원인과 검증 결과를 기계적으로 요약하고 phase 간 증거 재사용, 중복 실행 차단, 조건부 재시도 이력, 문서 읽기 이력을 제공한다. 사용자가 `/run` 구현·검증·머지까지 승인했다. `.claude/**`와 앱 동작은 유지한다.

## Affected Files

| 파일 | 변경 |
|---|---|
| scripts/lib/test-log-summary.py, verify-ui-test-log.py | 최초 오류·중복 제거·공통 JSON·watch selector 지원 |
| scripts/test-ui.sh, test-watch-ui.sh | 결과 JSON과 fail-closed 검증 연결; 실행 argv/기기 설정 유지 |
| scripts/codex-pipeline.py, scripts/tests/test_codex_pipeline.py | lock/원자적 상태/증거 검사/재시도/문서 읽기 이력 |
| scripts/plan-ui-tests.py, scripts/tests/test_plan_ui_tests.py | 명시적인 비앱 tooling 경로 분류 |
| scripts/codex-context.py, scripts/tests/test_codex_context.py | 앞선 변경 포함, 리뷰 입력 공유 |
| .codex/skill-compat.md, .codex/token-efficiency.md | 실행 상태 도구를 phase와 연결 |
| docs/solutions/architecture/2026-10-05-codex-context-snapshot.md | 최종 구현과 사용법 반영 |

## Implementation Steps

1. UI 로그 요약의 최초 오류 보존·bounded dedup·JSON 결과와 iOS/watch 실행 검증 통합.
2. 기존 fingerprint/receipt를 재사용하는 pipeline CLI 작성. 실행은 명시적으로 요청한 명령만 수행, 동시 실행 거부, 실패·중단 보존, 재시도는 변화 근거가 있는 1회만 허용.
3. 외부 리뷰 결과의 hash/관점/context를 기록·확인하고 통과 결과를 위조하지 않는다. phase/문서 상태를 구조화하고 compact report 제공.
4. tooling 경로 분류 및 adapter 연결. 공용 hook 설치 없이 저장소 스크립트로 제공.
5. 계약 테스트·구문·dry-run 검증, 6관점 리뷰와 필요한 수정, 문서 갱신, PR 생성·머지.

## Test Strategy

- 격리 Git fixture: 내용/환경/범위 변경, 로그 훼손/누락, 실패·timeout, 동시 실행, 조건 없는 재시도, phase 전환 후 횟수 보존.
- UI fixture: 최초 오류 유지, 반복 로그 제한, unknown/0/skipped/실패/selector 누락, watch 결과, JSON 파일 생성.
- planner: 정확한 도구 경로만 면제, 미매핑 및 실행 환경 변경은 보수적 판단 유지.
- `python3 -B -m unittest discover -s scripts/tests`, shell 구문, iOS dry-run, parity, diff check.
- 앱 소스/프로젝트/UI test body/seed/기기 실행 조건이 바뀌지 않으므로 adapter에 따라 앱 빌드·UI 실행 면제. 변경 시 영향 범위를 재평가.

## Risks / Edge Cases

- 테스트 exit 0만으로 UI 커버리지를 통과시키지 않는다. 리뷰 기록은 사람/agent 검토의 결과이며 자동 인증으로 취급하지 않는다.
- ignored 파일·외부 환경은 fingerprint 외부이므로 context와 실행자 확인이 필요하다.
- 로컬 state는 worktree별 ignored 저장소에 두고 원자적으로 저장한다. symlink·중복 실행·중단 복구를 검증한다.
- 테스트 선택/실행 명령은 유지한다. 코드 재시도와 환경 실패를 구분하고 같은 실패를 무한 재시도하지 않는다.
- 현재 대화에서 만든 선행 변경은 포함하고 다른 작업 변경은 커밋하지 않는다.
