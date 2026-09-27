---
tags: [ui-test, selective-testing, codex, retry-budget, token-efficiency, ci]
category: testing
date: 2026-09-27
severity: important
related_files:
  - scripts/plan-ui-tests.py
  - scripts/test-ui.sh
  - scripts/lib/verify-ui-test-log.py
  - .github/workflows/test-ui.yml
  - .codex/skill-compat.md
  - .codex/token-efficiency.md
related_solutions:
  - docs/solutions/testing/2026-03-04-pr-fast-gate-and-nightly-regression-split.md
---

# 변경 범위별 UI 검증과 근거 있는 재시도

## Problem

Codex `/run`의 전체 UI 실행 요구가 문서·도구 변경에도 적용돼 변경과 관계없는 검증 비용이 발생했다.
실행기의 `--smoke`와 `--only-testing`도 함께 지정하면 smoke가 빠져 요청한 합집합을 검증하지 못했다.
도구 개선 과정에서 기존 UI 실패 복구까지 범위를 확장하고 환경 장애를 반복 확인한 것은 잘못된 판단이었다.

## Solution

| 변경 | 검증 |
|------|------|
| 문서 | UI 생략 |
| 단위 테스트만 | 관련 단위 테스트 |
| UI 판정/선택/로그 도구 | Python 계약 테스트·dry-run·구문·diff 검토 |
| 매핑된 앱 기능 | 관련 UI suite와 smoke 합집합 |
| 공유 코드·미매핑 변경 | 영향 플랫폼 full |

`python3 scripts/plan-ui-tests.py --base main`은 merge-base부터 현재 tracked/untracked 변경을 확인하고 이유와 argv를 출력한다.
rename은 이전/새 경로 모두 포함한다. 출력은 권고이며 테스트 실행이나 커버리지 인증이 아니다.
호출부·새 동작·실행 환경의 영향은 리뷰로 확인하고 범위를 상향한다.

`scripts/test-ui.sh --dry-run --smoke --only-testing DUNEUITests/LifeRegressionTests`로 실행 없이 선택을 확인한다.
명시적 선택은 smoke와 합쳐지고, 선택을 가리는 기본 skip만 제거된다. 사용자의 명시적 skip은 유지된다.
실제 실행 시 로그 검증기는 양수 실행 수, 성공 case 및 선택 suite/method의 증거를 요구한다.
클래스별 하나 이상의 성공 증거를 검사하며 모든 메서드의 완전 실행을 인증하는 도구는 아니다.

PR CI도 도구 전용 변경이면 계약 검사만 실행한다. workflow 면제는 기존 iOS/watch 실행 job 본문과
전역 env/defaults가 merge-base와 동일한 경우로 제한한다. 실행 명령·환경이 바뀌면 UI 검증을 유지한다.
기존 PR smoke와 nightly 전체 회귀의 실행 내용은 유지한다.

Codex 정책은 `.codex/skill-compat.md` 및 `AGENTS.md`에 반영한다. `.claude/**`는 변경하지 않는다.

## Prevention

- 같은 원인은 원인에 대응한 변화가 확인된 경우에만 최대 1회 재시도한다. phase/turn/명령 표기 변경으로 횟수를 초기화하지 않는다.
- 실패 지점, 원인, 새 증거, 재시도 횟수, 다음 조치만 기록한다. 시간 경과나 일시적 부하 하락은 복구 증거가 아니다.
- 같은 장애가 반복되면 해당 실행 경로를 멈추고 독립 작업을 계속한다. 필요한 미검증 범위는 그대로 보고한다.
- 실행 중인 작업을 복제하지 않고, 변화 없는 polling·전체 로그 재독·agent 재호출을 하지 않는다.
- 기존 무관한 UI 실패를 고치느라 도구 작업의 범위를 넓히지 않는다. 검증 후에는 변경된 부분과 관련 관점만 다시 확인한다.

## Validation

- Python 계약 테스트 40개 통과: Git dirty/untracked/rename/base, feature/full/skip 분류, workflow 실행 변경, shell argv 합집합, dry-run 부작용/시뮬레이터 잠금 비의존, 0개/누락/실패 증거 검증.
- shell 구문, Codex/Claude parity, diff whitespace 통과.
- workflow YAML 파싱 및 실제 scope step 로컬 실행: 도구 전용 변경에서 `ios=false`, `watch=false` 확인.
- 최종 앱·프로젝트·UI 테스트 net diff 없음. 이번 작업의 UI 게이트는 skipped이며 앞선 실패/중단을 통과 증거로 사용하지 않는다.
- 6관점 리뷰와 최종 품질/PR 통합 리뷰 완료. CI 범위 관련 P2 2건은 수정 후 해당 관점 재검토 완료.

## Lessons Learned

검증 비용을 줄이는 작업은 검증 범위를 먼저 확정해야 한다. 전체 UI의 성공을 도구 개선의 완료 조건으로 삼으면 원래 문제를 반복한다.
재시도는 실패한 의존성에 대한 새 증거가 있을 때만 가치가 있다. 토큰·시간 절감률은 측정하지 않았으므로 수치로 주장하지 않는다.
