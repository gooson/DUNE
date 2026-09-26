---
tags: [codex, tokens, model-routing, test-logs, verification-reuse]
date: 2026-09-26
category: architecture
status: implemented
severity: important
related_files:
  - .codex/agent-map.md
  - .codex/skill-compat.md
  - .codex/token-efficiency.md
  - scripts/codex-check.py
  - scripts/lib/test-log-summary.py
related_solutions:
  - docs/solutions/architecture/2026-03-21-codex-claude-agent-adapter.md
---

# Codex 모델 분담과 검증 중복 제거

## Problem

agent-map에 경량 모델을 적어도 inline 실행은 Astra parent를 그대로 사용했다. Work/Run의 중첩된 테스트·품질 절차와 반복적인 로그 읽기도 비용을 늘릴 수 있었다. `.claude` 원본은 변경하지 않는 계약이므로 Codex의 실행 차이를 adapter에 명시해야 했다.

## Solution

| 변경 | 동작 |
|------|------|
| 모델 배정 | 일반 작업 Sol medium, 단순 테스트/조사 Luna medium, 복잡한 판단 Astra high. 실행 시 모델과 추론 인자를 명시 |
| 최소 컨텍스트 | `fork_turns="none"` + 역할 지침의 정확한 경로, 목표/파일/규칙/완료 조건. 단순 명령 실행은 셸로 처리 |
| 스킬 읽기 | phase 진입 시 필요한 source skill만 읽고, 동일 내용을 반복 로드/서술하지 않음. 필수 규칙은 보존 |
| 테스트 출력 | 세 실행기가 공통 요약 helper 사용. 종료 상태, 마지막 보고 테스트 수, 최대 12개 오류, 전체 로그 경로 출력 |
| 검증 증거 | 명시적 run/check. 코드·명령·환경 context와 성공 로그의 hash가 일치해야 재사용 |
| 품질 게이트 | smoke/full 및 device 범위 구분. Resolve의 필수 전체 재리뷰 유지 |

`scripts/codex-check.py`는 실패/중단된 재실행이 이전 성공을 무효화하도록 먼저 상태를 기록한다. 실행 전후 내용이 바뀌면 성공 증거로 인정하지 않는다. 이름별 lock으로 실행 중인 결과를 재사용하지 않으며, 로그 삭제/변조도 거부한다.

기본 fingerprint는 HEAD/index를 포함한다. Git 이력에 의존하지 않는 검증에는 `--content-only`를 명시적으로 선택할 수 있어, 내용이 같은 commit 뒤의 불필요한 재실행을 줄인다. ignored 입력과 외부 환경은 자동 추적하지 않으므로 context와 실제 환경 확인이 필요하다.

## Verification

- 로그 요약 fixture 6개와 검증 증거 integration test 12개, 총 18개 통과. 독립 검토에서 발견한 context/게이트/증거 일치 문제를 수정 후 재확인했다.
- 로그 fixture: 실패 종료 코드와 성공 문구 혼재, 긴 오류 출력, 공백 경로, XCTest/Swift Testing 혼합, 수를 알 수 없는 출력.
- 임시 Git repo: 성공/실패/중단, 파일·index·명령·context 변경, 로그 소실/변경, 실행 중 변경, commit 뒤 content-only 재사용.
- shell syntax와 `scripts/check-codex-claude-parity.py` 검사.
- 앱 Swift 코드는 변경하지 않았다. 이번 검증은 helper/실행기 계약을 대상으로 하며 실제 Xcode 앱·UI suite 실행 결과를 대신하지 않는다.

## Prevention

- 모델명이 문서에 있다는 이유만으로 모델이 전환됐다고 보고하지 않는다. 현재 parent/앱 전역 모델은 그대로이며 실제 delegate 인자를 확인한다.
- 재사용 전에 gate 범위와 환경을 확인한다. flaky 결과, 입력 불명확, skip/0 tests는 전체 검증 통과 근거로 삼지 않는다.
- 관련 운영 절차는 `.codex/token-efficiency.md`에서만 관리한다. `.claude` source를 복제하거나 변경하지 않는다.

## Lessons Learned

스크립트 출력량과 모델 토큰, 계정 사용 한도는 서로 다른 지표다. 실제 절감률은 아직 측정하지 않았다. 단순 테스트 추가/UI 실패 수정/일반 구현의 다음 실제 작업에서 모델·추론·제공된 토큰 지표·재시도·재사용·품질 결과를 기록하고 기존 동급 작업과 비교한다. 토큰 지표가 없으면 unknown으로 남기며 측정만을 위한 중복 실행은 하지 않는다.
