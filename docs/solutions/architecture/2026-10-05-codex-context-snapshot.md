---
tags: [codex, token-efficiency, review, context, scripts, ui-testing, skills, pipeline]
date: 2026-10-05
category: solution
status: implemented
severity: minor
related_files: [scripts/codex-context.py, scripts/tests/test_codex_context.py, scripts/test-ui.sh, scripts/test-watch-ui.sh, scripts/lib/test-log-summary.py, scripts/lib/verify-ui-test-log.py, scripts/plan-ui-tests.py, .codex/skill-compat.md, .codex/token-efficiency.md]
---

# 토큰 낭비 분석과 반복 작업 스크립트화

구현 완료 범위는 리뷰 컨텍스트 수집 스크립트와 Codex adapter 연결이다. 아래 UI 테스트와 스킬 파이프라인 개선 항목은 코드·지침 조사에 기반한 후속 제안이며 아직 구현하지 않았다.

## Problem

설정과 실행 스크립트를 조사한 결과, 테스트 요약(`test-log-summary.py`), 성공 검증 재사용(`codex-check.py`), UI 범위 선택(`plan-ui-tests.py`)은 이미 구현되어 있었다. 이를 새로 구현하는 대신 아직 수동으로 반복하는 리뷰 입력 수집을 추출했다.

| 낭비 가능 지점 | 근거 | 처리 |
|---|---|---|
| 큰 지침·메모리 일괄 로딩 | 변경 전 체크아웃 Markdown 69개, 360,548 bytes; run skill 28,010 bytes, reviewer memory 여러 개가 13–18KB | inventory로 본문 없이 크기 확인, 필수 문서는 유지하고 선택 문서는 필요한 구간 검색 |
| reviewer/phase마다 Git diff 재수집 | adapter가 공유 수집을 요구하지만 전용 수집기가 없음 | snapshot 한 번 생성 후 경로 공유 |
| 단계 전환 후 오래된 diff 재사용 | uncommitted/index/untracked 상태가 HEAD만으로 구별되지 않음 | 기존 fingerprint와 patch hash로 최신성 검사 |
| 검증·로그 전체 재실행/재로딩 | 기존 요약·receipt 도구가 이미 있음 | 기존 도구 유지; 자동 통과/재시도 도구 추가하지 않음 |

실제 세션별 토큰 로그는 분석하지 않았으므로 지점별 소비량과 절감률은 unknown이다. 파일 크기는 자동 주입량과 같지 않다.

### UI 테스트 추가 분석

테스트 프로세스가 오래 실행되는 것 자체와 모델의 토큰 소비는 구분한다. 토큰 낭비 가능성이 큰 부분은 실행 중 반복 상태 조회, 실패 로그 재탐색, 같은 실패의 재분석, 단계별 결과 재해석이다. 실제 세션에서 발생한 빈도는 측정하지 않았으며 다음은 실행기와 규칙에서 확인한 구조적 개선 기회다.

| 지점 | 확인한 현재 동작 | 후속 개선 제안 |
|---|---|---|
| 로그 출력 | iOS/watch 실행기는 로컬 기본 streaming이 꺼져 있고 파일 로그와 요약을 제공한다. CI 또는 명시적 옵션은 streaming을 켤 수 있다 | 기존 기본값 유지. 전체 로그를 다시 읽기보다 실패한 구간만 확인 |
| 대기 중 반복 조회 | adapter에 polling 간격·중복 실행 제한이 있으나 모델의 실행 절차에 의존한다 | 실행·대기·완료 결과 수집을 묶어 동일 실행의 상태를 반복 해석하는 호출 축소 |
| 최초 실패 원인 누락 | `test-log-summary.py`는 마지막 오류 12개를 보관하고 각 줄을 300자로 제한한다 | 최초 오류와 실패 테스트별 중복 제거 요약, 원문 줄 번호를 함께 제공 |
| 전체 테스트로 범위 확대 | `plan-ui-tests.py`는 미매핑 변경과 일반 tooling 변경을 iOS/watch full로 보수적으로 판정한다 | 앱 영향 없는 도구 경로를 근거와 계약 테스트가 있는 경우에만 분류. 미확인 영향은 full 유지 |
| 같은 실패 재시도 | 최대 1회 조건부 재시도 규칙은 문서에 있고 실행기가 이력을 강제하지 않는다 | 실행 식별자·실패 원인·원인에 대응한 변화·재시도 횟수를 파일로 보존. 단순 재실행이나 phase 전환으로 초기화하지 않음 |
| 결과 판정 반복 | iOS는 `verify-ui-test-log.py`로 선택 테스트 실행 여부를 검사한다. watch 실행기는 요약 후 xcodebuild 종료 코드를 반환한다 | 공통 결과 JSON으로 실제 실행·skip·실패 수와 필수 suite 누락 여부를 제공하고 watch 검증도 보강 |

### UI 테스트 개선 우선순위 — 미구현

1. **실패 요약과 공통 결과 JSON**: 성공 시 상태·실행 수·로그 경로만, 실패 시 최초 원인·실패 테스트·필요한 로그 구간만 반환한다. 실행 수 unknown/0, 필수 suite 누락, 환경 실패를 통과로 처리하지 않는다.
2. **실행·대기·재시도 이력 통합**: 동일 실행을 중복 시작하지 않고 완료 결과를 한 번 수집한다. timeout/중단 상태를 보존하고 근거 없는 재시도는 차단한다. 사람의 원인 판단이 필요한 부분까지 문자열 일치로 확정하지 않는다.
3. **변경 범위 판정 정밀화**: 앱 영향 없는 도구 변경에 대한 분류를 추가하되 관련 UI 테스트·공통 smoke·릴리스 전체 회귀 의무를 유지한다. 범위 축소는 영향 분석과 대체 검증 근거가 있을 때만 적용한다.

기존 `codex-check.py`의 성공 증거 재사용 기능은 계속 사용한다. UI 결과를 재사용할 때는 소스뿐 아니라 simulator/runtime, locale, seed, app 데이터 등 실행 환경이 동일한지도 확인해야 한다. 위 제안은 테스트 생략이나 자동 통과를 위한 기능이 아니다.

### run 및 하위 스킬 추가 분석

조사 대상은 source of truth인 `/Users/shanks/work/Health/.claude/skills/`의 `run`, `plan`, `work`, `review`, `ship`과 `.codex/skill-compat.md`, `.codex/token-efficiency.md`다. 스킬을 분석한 것이며 전체 파이프라인을 실행한 것은 아니다. 아래 중복은 원문 절차에서 발생 가능한 경로이며 실제 실행마다 모두 중복된다고 단정하지 않는다.

| 지점 | 원문 근거 | Codex의 현재 완화 / 남은 개선 |
|---|---|---|
| 품질 에이전트 재호출 | `work` Phase 3.2와 `run` Phase 2.3, 3.5가 같은 전문가 검증을 요구 | 동일 검증 재사용 규칙은 있음. 담당 관점·대상 상태·결과를 연결해 중복 호출 여부를 기계적으로 확인할 필요 |
| UI 테스트 재실행 | `work` Phase 3.1과 `run` Phase 2.5에서 UI 검증 요구 | 변경 범위 게이트와 성공 증거 재사용이 이미 적용됨. 각 phase에서 증거를 조회하는 연결은 실행자가 수행 |
| 수정 후 전체 재리뷰 | `run` Phase 4에서 수정 후 Review 재진입 요구 | adapter가 변경분과 영향받는 관점만 재검토하도록 제한. 이전 findings와 이후 diff의 연결을 구조화할 필요 |
| 계획·관련 문서 재로딩 | `run` Phase 2.1이 방금 작성한 계획과 참고 solution을 재확인하고 `work`도 계획 확인 요구 | 스킬 자체는 phase 진입 시 한 번 읽는 규칙이 있음. 계획·참조 문서까지 읽기 이력을 관리하는 도구는 없음 |
| 원문과 adapter 해석 반복 | `run`이 하위 스킬 절차를 재서술하고 Codex 예외가 별도 문서에 존재 | 필수 절차를 보존하면서 phase별 실행 조건·담당·증거를 한 번 정리하는 실행 명세가 필요 |
| 상태·진행 보고 중복 | `run` phase marker/Proof Ledger와 하위 스킬 step marker, 최종 보고가 중첩 | adapter는 Proof Ledger를 완료 메시지·최종 요약에 집계. 추가 축약은 필수 보고를 보존하는 명시적 adapter 설계 필요 |
| 기계적 사전 확인 반복 | 여러 단계에서 Git 상태·변경 파일·산출물·finding 상태를 다시 확인 | snapshot 수집은 구현됨. 나머지 확인은 상태가 바뀌는 경계에서 검사하고 결과만 요약하는 스크립트 후보 |

필수 리뷰 관점 자체를 없애는 것이 목적은 아니다. 같은 대상·관점·환경을 새 근거 없이 다시 실행하는 비용을 먼저 줄인다. 서로 다른 전문 관점이나 Ship 직전 통합 검증은 이름이 비슷하다는 이유로 합치지 않는다.

### 스킬 개선 설계와 우선순위 — 미구현

1. **실행 상태 파일과 증거 검사기**: phase 이름과 독립된 검증 식별자로 완료 결과를 저장한다. 뒤 phase는 재실행 전에 증거의 범위와 최신성을 검사한다. 기존 `codex-check.py` receipt와 `codex-context.py` snapshot을 참조하고 fingerprint 구현을 복제하지 않는다.
2. **리뷰·품질 실행 담당 통합**: `/run` 안에서는 parent가 관점별 담당과 완료 결과를 관리한다. Work에서 수행한 관점은 Phase 3.5에서 유효성을 확인하고, 변경이 생기면 영향받는 관점만 추가 검토한다. standalone `/work`의 필수 검증은 유지한다.
3. **공통 결과와 보고 생성**: UI 결과 JSON, 리뷰 findings, 검증 receipt를 상태 파일에서 연결한다. 시작·완료·실패의 필수 안내와 최종 요약을 같은 기록에서 생성하여 결과를 반복 집계하는 비용을 줄인다.
4. **문서 읽기 이력과 실행 명세**: 읽은 문서 경로·내용 hash를 기록해 변경 여부를 확인한다. hash가 같아도 내용이 현재 컨텍스트에 없거나 필수 원문 확인이 필요한 경우 다시 읽는다. 생성된 실행 명세에는 원문 위치·적용된 adapter 예외를 남기고 source 변경 시 무효화한다.

실행 상태 파일의 최소 정보는 다음과 같다. 경로와 스키마는 구현 시 확정한다.

| 정보 | 목적 |
|---|---|
| schema version, 작업 ID, worktree, 실제 base, HEAD, 내용 fingerprint | 다른 작업이나 오래된 상태와 구분 |
| phase, 검증 ID, 담당, 범위·리뷰 관점, 실행 환경 context | 같은 이름이지만 다른 검증을 재사용하지 않도록 구분 |
| pending/running/passed/failed/blocked/skipped 상태, 증거 경로·hash, skip 사유 | 실행 중·실패·정당한 면제를 구분하고 완료 증거 연결 |
| findings와 미해결 항목, 이전 검토 이후 변경 범위 | 필요한 재리뷰 대상을 판단할 근거 제공 |
| 실패 원인, 원인에 대응한 변화, 재시도 횟수, 재개 조건 | phase/turn이 바뀌어도 재시도 한도 유지 |

검사기는 상태 파일의 `passed` 표기만으로 게이트를 통과시키면 안 된다. 실제 증거가 없거나 변경·환경의 동일성을 확인할 수 없으면 재사용 불가로 반환한다. 자동 테스트 receipt가 전문가 리뷰를 증명하지 않으며, 문서 hash가 원문 이해를 증명하지도 않는다. 중복 실행 방지를 위한 lock, 원자적 상태 저장, 중단 후 복구도 구현 범위에 포함한다.

수용 검증은 작은 fixture로 수행한다: 동일 증거는 재사용되고, 소스·환경·범위 변경 또는 증거 누락/훼손은 거부되어야 한다. 실행 중 중복 시작, 중단을 성공으로 오인, phase 전환으로 재시도 횟수 초기화가 없어야 한다. 검증만을 위해 전체 앱 파이프라인을 추가 실행하지 않는다.

전체 개선 순서는 **UI 실패 요약·결과 JSON → 실행 상태·증거 검사기 → 중복 품질 호출·대기·재시도 통합 → 범위 판정 및 문서 로딩 정밀화**로 제안한다. `.claude/**` 원본은 보존하고 Codex 전용 실행 변경은 `.codex/**`와 스크립트에 반영한다. 현재 문서 갱신만으로 이 개선들이 적용된 것은 아니다.

## Solution

```sh
python3 scripts/codex-context.py inventory
python3 scripts/codex-context.py snapshot --base main
python3 scripts/codex-context.py check /tmp/codex-context-EXAMPLE
python3 -B -m unittest discover -s scripts/tests -p test_codex_context.py
```

snapshot은 시스템 임시 디렉터리에 `manifest.json`, `branch.patch`, `staged.patch`, `unstaged.patch`를 저장한다. stdout에는 경로·개수·크기만 반환한다. 실제 PR base의 merge-base부터 수집하며 rename은 삭제/추가 양쪽 경로로 보존한다. staged 변경을 worktree에서 되돌린 경우도 누락하지 않는다. 공백/개행 경로는 NUL 기반으로 읽는다. Git 오류는 실패로 반환한다.

untracked 파일은 경로만 제공한다. binary 본문과 untracked 내용은 별도 확인해야 한다. snapshot check는 파일 상태와 patch 무결성만 확인하며 리뷰나 테스트 성공을 인증하지 않는다. 기존 `codex-check.py` fingerprint를 재사용하므로 ignored 파일·외부 의존성은 보장 범위 밖이다.

기존 Git hooksPath가 공용 저장소 hooks를 가리키므로 이 작업에서 공용 hook 설치·변경은 하지 않았다. `.claude/**`도 유지했다. Codex adapter에 실행 절차를 연결했으며 자동 tool hook으로 등록한 것은 아니다.

## Prevention

- 여러 reviewer에 대화 전체 대신 snapshot 경로, 담당 범위, role/rule 경로를 전달한다.
- 재사용 전 check하고 작업 중 파일이 바뀌면 새 snapshot을 만든다.
- 출력량을 줄이기 위해 필수 검증이나 관련 호출부 확인을 생략하지 않는다.
- 앱 변경이 없는 이 도구 작업에는 Python 계약 테스트와 parity 검증을 사용한다.
- UI 테스트는 대기 시간과 모델 호출·로그 입력량을 별도로 측정한다. 개선 효과를 측정하려고 전체 UI 파이프라인을 추가 실행하지 않는다.

## Lessons Learned

이미 스크립트화된 검증을 중복 구현하기보다 반복되는 입력 수집부터 자동화한다. 공유 입력의 최신성 검사는 출력 절약만큼 중요하다. 실제 토큰 절감은 동일 범위 작업의 사용량 기록으로 별도 측정해야 한다.
