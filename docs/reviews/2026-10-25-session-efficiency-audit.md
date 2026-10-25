---
tags: [codex, claude, session-audit, tokens, ui-testing, screen-lock]
category: review
date: 2026-10-25
status: completed-for-requested-scope
confidence: medium
related_plan: ../plans/2026-10-25-session-efficiency-and-locked-ui.md
---

# 최근 3주 세션 사용량·중단 감사

## 결론

Health의 관측 입력+출력은 **4,093,496,824 토큰**이며 입력의 **98.28%가 캐시 읽기**였다. 새 입력은 70,125,554, 출력은 9,897,350이다. 상위 10개 세션이 Health 총량의 **53.20%**를 차지한다. 긴 디자인·캡처·UI 검증 작업에서 모델 호출과 대기 조회가 누적된 사례가 확인됐다. 캐시 포함 총량을 과금액·계정 한도 소모나 불필요한 작업량으로 해석하면 안 된다.

중단 후보를 원문으로 확인하면 UI 실행기·기기 발견/기동 문제가 가장 자주 보고됐고, 저장소 실행권 점유와 Mac 화면 잠금이 별도로 등장한다. Mac 잠금만을 모든 UI 실패의 원인으로 판단하거나 전체 작업을 멈추는 방식은 수정해야 한다. 이번 작업은 Codex 실행 규칙과 진단·집계 도구를 수정했다. 후속 별도 기기 실험에서 **Mac 잠금 상태의 iPhone·Watch XCTest와 새 캡처를 확인**했다. 잠금 해제 비교군은 별도 검증 항목이다.

## 범위와 집계 방법

- 기간: **2026-10-04 17:55 이상 ~ 2026-10-25 17:55 미만, KST**, 정확히 21일. 이번 감사 자체는 제외했다.
- 로컬 Codex 활성·보관·`.jsonl.zst` 압축 기록과 Claude projects **2,904개 파일**을 전수 스캔했다. 기간 내 고유 session ID는 **867개**(Codex 589, Claude 278)다. 자식 실행이 포함되므로 사용자 대화 867개라는 뜻은 아니다.
- 사용량이 확인된 session ID는 **797개**, usage가 없는 ID는 **70개**다. 읽기 오류·손상 JSON은 0개다. 시간 없는 이벤트 131,904개는 제외했고, 그중 usage 이벤트는 0개였다. 원격에만 있거나 이미 삭제된 기록까지 포함하지 않는다.
- Codex response별 usage 기록 34,167건, Claude message별 usage 28,768건을 반영했다. response/message ID 중복과 Claude 반복 content block을 제거했다. legacy 누적값은 해당 turn의 modern usage가 없을 때만 사용하며 이번 기간 실제 반영은 0건이다.
- 모델·프로젝트·역할은 **usage 시점**의 값으로 귀속했다. 세션 마지막 cwd로 전체 비용을 귀속하면 프로젝트를 이동한 장기 세션의 비용이 잘못 섞인다.
- 전체 파일은 프로그램으로 검토하고, Health의 상위 비용 세션과 미완료 후보는 원문을 확인했다. 모든 본문을 모델에 일괄 로드하지 않았다. 개별 요청에 tool별 token attribution이 없으므로 대기·지침·코드 작성 각각의 정확한 토큰 점유율은 산출하지 않았다.
- 원문·세션 식별자·근거 행 위치는 로컬 ignored 경로 `.codex-checks/session-audit/`에 보관했다. 공유 보고서에는 필요한 집계와 주제 요약만 기록한다.

## 실제 사용량

단위는 토큰이며 비용 가중치를 적용하지 않았다. 캐시 읽기/쓰기는 입력의 부분집합이고 reasoning은 출력의 부분집합이다.

| 범위 | 입력 | 캐시 읽기 | 캐시 쓰기 | 출력 | 입력+출력 |
|---|---:|---:|---:|---:|---:|
| 전체 Codex | 4,373,741,824 | 4,298,747,264 | 0 | 10,560,923 | 4,384,302,747 |
| 전체 Claude | 8,645,616,782 | 8,447,422,670 | 198,111,794 | 16,707,786 | 8,662,324,568 |
| 전체 합계 | 13,019,358,606 | 12,746,169,934 | 198,111,794 | 27,268,709 | 13,046,627,315 |
| Health 귀속분 | 4,083,599,474 | 4,013,473,920 | 0 | 9,897,350 | 4,093,496,824 |

Health 귀속 usage가 있는 ID는 526개다. 새 입력+출력은 **80,022,904 토큰**이다. 출력 중 reasoning 3,934,959는 다시 더하지 않는다. Claude의 새 입력에는 cache write도 포함해야 한다. `uncached` 필드만 비교하면 Claude의 새 입력을 크게 과소평가한다. API usage의 구성은 [OpenAI 관측성 문서](https://developers.openai.com/api/docs/guides/agents-api/observability)와 [Anthropic 캐싱 문서](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)를 참조했다. 이 정의를 Codex 구독 요금 산식으로 확대하지 않는다.

### 비용 집중 구간

다음 주제는 실제 세션의 내용 요약이며 세션 제목을 바꾼 것이 아니다. 숫자는 해당 세션 중 Health에 귀속된 사용량이다.

| 주제 요약 | 입력+출력 | 새 입력+출력 |
|---|---:|---:|
| Watch 재작업 확인·폰 실제 디자인맵 재생성 | 484,071,287 | 4,377,207 |
| 디자인 개편 진행 상황 확인·후속 실행 | 308,966,190 | 3,087,534 |
| iOS 27/WWDC 조사·적용 작업 | 234,135,973 | 3,665,061 |
| Duo 기능 조사·최적화·검증 | 232,146,626 | 5,430,594 |
| 신규 테마·레이아웃 작업 | 193,435,519 | 1,601,791 |

상위 세션에서 확인한 실행 패턴:

1. 최대 세션은 모델 usage 기록 3,313건이다. 동일 process session에 같은 인자의 `write_stdin` 대기 호출이 **42회**, 동일 50초 sleep 호출이 **43회** 등장한다. 두 번째 세션에도 동일 현재 시각 조회 25회가 있었다. 기다림 자체가 필요한 경우도 있으므로 모두 낭비로 세지는 않는다. 하지만 시각 조회·sleep·로그 확인을 개별 모델 호출로 이어 붙이는 방식은 줄일 수 있다.
2. 지침 읽기·Git 상태 조회·UI 실행·캡처가 장기 대화 안에서 반복된다. 문자열 분류는 한 호출에 여러 항목이 겹치므로 횟수를 그대로 작업 수나 낭비 비율로 사용하지 않았다. 기존 snapshot/검증 증거 재사용 규칙을 유지하고 대기 규칙을 구체화했다.
3. 큰 도구 출력에는 수 MB의 이미지 payload가 포함됐다. 직렬화 bytes를 텍스트 토큰으로 바꿔 “로그 출력이 가장 큰 낭비”라고 결론 내리지 않았다.
4. 전체 Codex에서는 이미 Sol 계열 사용량이 크다. 고급 모델 사용을 줄이는 것만으로 핵심 병목을 해결한다는 근거는 없다. 기존 역할별 모델 배정은 유지했다.

## 어디서 멈췄는가

명시적 이벤트는 전체 Codex `turn_aborted` **15건**, Claude 사용자 interruption **26건**이다. 사용자 개입이므로 자동으로 시스템 장애로 분류하지 않는다. Codex task start 2,960 / complete 2,944의 차이도 기간 경계·진행 중 실행 때문에 실패 수가 아니다. Codex compaction 139 / Claude compact boundary 15는 정상 컨텍스트 관리 이벤트다.

Health root의 종료 보고 중 실패·미완료 표현을 포함한 **99개 후보**를 읽고, 실제 미완료 조건을 명시한 보고를 아래와 같이 분류했다. 카테고리는 겹치며 같은 세션의 후속 보고를 포함한다. **독립 장애 횟수나 입증된 근본 원인 수가 아니라, 확인된 미완료 보고의 하한**이다. 모든 프로젝트의 중단 원인을 같은 깊이로 수작업 분류한 것은 아니다.

| 미완료 보고 분류 | 보고 수 | 고유 세션 수 |
|---|---:|---:|
| XCTest/Simulator 실행·기동·대상 발견 | 20 | 13 |
| 앱/UI assertion 실패 | 7 | 6 |
| 저장소 simulator 실행 잠금 점유 | 5 | 4 |
| Mac 잠금으로 설명한 미완료 | 5 | 3 |
| 브라우저 접근/로컬 페이지 검증 제약 | 5 | 3 |
| Ship 인증·충돌·승인 제약 | 4 | 4 |
| 기존 테스트 컴파일 실패 | 3 | 2 |

대표 근거:

- 10월 5일 Duo 작업은 Mac 잠금으로 전체 진행을 멈췄다가, 후속 응답에서 코드·빌드·로그 작업은 가능하다고 정정했다. 이후 실제 UI assertion 실패도 별도로 있었다. 잠금과 앱 실패를 한 원인으로 합칠 수 없다.
- 10월 24일 디자인 작업은 물리 방향과 AX/native PNG viewport 불일치가 남은 상태에서 잠금 해제를 재개 조건으로 제시했다. setter 성공만으로 회전을 검증할 수 없으며, 미완료 UI 때문에 독립 리뷰까지 전부 멈출 필요는 없다.
- 10월 25일 Reading 작업은 iPhone 검증 후 iPad/Duo가 다른 실행자의 저장소 lock 때문에 시작하지 못했다. 같은 날 Running/Watch 작업도 실행권 점유가 캡처를 막았다. 이는 Mac 화면 잠금과 별개다.
- AppIntents 작업에서는 계정 한도가 아니라 XCTest의 testcase 시작 전 정체로 보고된 구간이 있었다. 오래 걸린다는 이유로 토큰 한도 장애라고 판단하지 않는다.

## 화면 잠금과 최신 공식 정보

Apple DTS의 [2026년 8월 답변](https://developer.apple.com/forums/thread/840965)은 잠긴 Mac 세션에서 **macOS 앱 XCUITest**를 실행할 수 없다고 설명한다. 이를 iOS/watch Simulator 전체의 불가능 판정으로 확대할 근거는 없다. Apple의 [Simulator 자동화 안내](https://developer.apple.com/library/archive/documentation/DeveloperTools/Conceptual/testing_with_xcode/chapters/08-automation.html)는 로그인된 Aqua 세션을 요구하지만 2017년 보관 문서여서 최신 잠금 동작 전체를 보장하지 않는다.

[XCTest interruption monitor](https://developer.apple.com/documentation/xctest/handling-ui-interruptions)는 예상하지 못한 modal 처리용이며 호스트 잠금을 해제하는 기능이 아니다. `caffeinate`, 디스플레이 수면 방지, Mac 화면 잠금, Simulator guest 잠금도 서로 구분해야 한다.

확인 기준은 [2026-10-15 공개 Xcode 27.1](https://developer.apple.com/news/releases/?id=10152026a)이며 로컬도 27A9275다. [27.1 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes)는 초기 Simulator 기동 지연, Duo StandBy 미지원, 대부분의 Duo app extension 실행·디버깅 미지원을 명시한다. 이런 제한을 앱 재빌드나 같은 테스트 반복으로 해결하려 하지 않는다. SDK 업그레이드는 이번 작업에서 수행하지 않았다.

초기 로컬 진단은 `caller_launch_manager=Aqua`, `console_user_session=yes`, `host_locked=yes`를 반환했지만 저장소 실행 잠금 때문에 캡처를 시작하지 못했다. 이후 사용자가 별도 기기 검증을 요청해 실행 범위를 격리했고, 아래 후속 실험에서 XCTest·캡처 성공 증거를 확보했다. 다른 runner를 중단하거나 Mac 잠금을 해제하지 않았다.

## 반영한 개선과 후속 계획

| 우선순위 | 변경 | 상태·완료 기준 |
|---|---|---|
| P0 | response/message 단위 집계, 압축 archive, 기간 경계·중복·모델 변경 처리 | 구현, 합성 계약 테스트 11개 통과 |
| P0 | iOS/Watch runner가 `<log>.host.json` 기록 | 구현, 진단 테스트 5개와 기존 runner 계약 5개 통과 |
| P0 | 저장소 lock / host session / Simulator / assertion / result-finalize 구분 | `.codex/ui-execution.md`에 반영. 진단은 통과 증거가 아님 |
| P0 | 짧은 yield·시각 조회·sleep·tail 반복 제한 | adapter에 반영. 기존 session 대기와 timeout 사용 |
| P0 | UI 환경 대기 중 독립 리뷰·로그 분석·문서 진행 | adapter에 반영. 필수 UI 게이트와 Ship 제한은 유지 |
| P1 | 잠금/해제 상태에서 iOS·Watch XCTest 및 capture 비교 | **잠금 상태 검증 완료**. iPhone·Watch 각 1개 통과, 새 PNG 6장 확보. 잠금 해제 비교군은 사용자 인증 후 별도 확인 |
| P1 | 여러 worktree의 실행권 대기 경험 개선 | 명시적 `worktree` lock scope 구현·검증. 같은 worktree의 중복 실행은 차단. owner/queue 통지는 별도 계획이며 무제한 polling 금지 |
| P2 | 동급 작업의 전후 효과 측정 | 계획. 호출 수·새 입력·출력·무변화 조회·재시도·미검증 잔여 범위를 비교. 실제 절감률은 아직 없음 |

실행 정책은 `.claude/**`를 수정하지 않고 Codex adapter에만 반영했다. UI 장애 가이드는 실패할 때만 읽게 분리했다. 이는 [2026년 9월 OpenAI 스킬 지침](https://developers.openai.com/blog/rethinking-skills-and-prompts-for-gpt-6-astra)의 간결한 지시·필요시 상세 참조 방향과 맞는다. 효과는 [스킬 평가 안내](https://developers.openai.com/blog/eval-skills)처럼 관측 가능한 실행 결과로 평가하며 지침 길이나 캐시율만으로 성공을 선언하지 않는다.

## 검증과 재현

- 합성 집계 테스트 11개, 호스트 진단 테스트 5개, 기존 runner 계약 5개: **21개 통과**.
- iOS/Watch shell 구문, Codex/Claude parity, diff 공백 검사 통과.
- 전수 집계에서 세션 합계와 전체 합계, usage 시점의 Health 귀속 합계가 일치함을 확인했다.
- 앱 소스/화면은 수정하지 않았다. 전체 앱 UI 회귀·새 디자인맵 캡처를 이번 도구 변경 검증으로 추가하지 않았다.
- 환경의 실제 잠금/해제 A/B와 개선 후 실사용 절감률은 남아 있다.

```sh
python3 -B scripts/audit-agent-sessions.py \
  --start 2026-10-04T08:55:00+00:00 \
  --end 2026-10-25T08:55:00+00:00 \
  --output .codex-checks/session-audit/usage.json
python3 -B -m unittest discover -s scripts/tests -p test_audit_agent_sessions.py
python3 -B -m unittest discover -s scripts/tests -p test_ui_host_state.py
bash -n scripts/test-ui.sh scripts/test-watch-ui.sh
python3 -B scripts/check-codex-claude-parity.py
```

로컬 상세 자료: `usage.json`(수치), `inspect-all.json`(호출 패턴 후보), `terminals-all.json`(종료 후보), `classified-blockers.json`(수작업 분류·원문 위치), `current-host.json`(이번 호스트 진단). 모두 `.codex-checks/session-audit/` 아래에 있으며 원문은 커밋하지 않는다.


## 후속 실험: 별도 시뮬레이터에서 잠금 상태 검증

사용자의 별도 기기 검증 요청에 따라 `DUNE_SIM_TEST_LOCK_SCOPE=worktree`를 해당 명령에만 적용했다. 기본 repository 직렬화는 유지하고 두 모드 모두 현재 worktree 잠금을 획득한다. 구버전 runner는 이 추가 잠금이 없으므로 실제 프로세스의 작업 경로·UDID가 다른 worktree임을 확인했다. 전용 UDID·DerivedData·로그·`--no-regen`을 사용했고 앱·테스트 소스 1,190개 hash 비교에서 변화가 없었다.

| 실행 | 기기 / selector | 결과 |
|---|---|---|
| 기존 iPhone clone | iPhone 18 Pro / `DashboardSmokeTests/testNavigateToSettings` | 시작 화면에 머물러 primary navigation 없음, 1 실패. 실제 앱 PNG는 생성됨 |
| Watch 첫 시도 | 새 clone 준비 | registry → deadline에서 inherited lock FD 손실로 `Bad file descriptor`, XCTest 시작 전 실패 |
| Watch 원인 수정 후 1회 | Watch SE 3 / `WatchWorkoutFlowSmokeTests/testCaptureEmptyLibraryDesignMap` | **1/1 passed, exit 0**, testcase 12.325초, PNG 2장 |
| 빈 iPhone 전용 기기 | iPhone 18 Pro / `DashboardSmokeTests/testNavigateToSettings` | **1/1 passed, exit 0**, testcase 19.447초, PNG 4장 + AX hierarchy |

두 성공 실행의 시작·종료 sidecar 모두 `host_locked=yes`, `caller_launch_manager=Aqua`였다. 성공한 iPhone 설정 화면과 Watch 빈 운동 목록 PNG를 직접 열어 확인했다. XCTest는 실제 앱 시작·AX 조회·탭·화면 전환을 수행했다. 기존 iPhone의 시작 정체는 빈 기기에서 재현되지 않았지만, 저장 상태·기동 조건 중 어느 것이 근본 원인인지는 분리 입증하지 않았다.

실험 중 확인한 실행기 버그도 수정했다:

- `simulator-test-lock.py`: 명시적 linked-worktree scope와 동일 worktree 직렬화. 기본 repository scope 유지.
- `command-deadline.py`: repository/worktree 두 잠금 FD를 하위 프로세스로 전달.
- `worktree-simulator-registry.py`: nested simctl deadline에도 유효한 잠금 FD를 전달. 잘못된/닫힌 FD는 거부.
- 같은 원인의 Watch 재시도는 FD 전달 수정 및 실제 `list devices` 성공을 확인한 뒤 1회만 수행했다.

추가 검증: 잠금 계약 11개, deadline 계약 9개, simulator registry 전체 20개, 기존 runner 통합 2개가 통과했다. 이와 별도로 실제 iPhone·Watch XCTest가 각 1개 통과했다. Python unittest discovery는 하이픈 파일명을 수집하지 못하므로 registry 전체 검사는 `python3 -B scripts/tests/test-simulator-worktree.py`로 실행해 20개 실행을 확인했다.

증거는 `.codex-checks/session-audit/isolated/`의 `ios-locked-fresh.log(.result.json/.host.json)`, `watch-locked-fixed.log(.result.json/.host.json)`, 각 `*-end.host.json`, `*-attachments/manifest.json`에 보존했다. 두 플랫폼의 targeted 통과를 전체 UI·Duo 자세 검증으로 확대하지 않는다. 잠금 해제 A/B와 실사용 토큰 절감률은 별도 항목이다.


## 최종 범위 확정

2026-10-25 사용자가 “지금은 잠금 상태 결과로 마무리”를 선택했다. iPhone·Watch의 잠금 상태 targeted XCTest 각 1개 통과와 새 PNG 6장, 실행기 수정 검증을 이번 완료 범위로 확정한다. 잠금 해제 A/B는 사용자 선택으로 보류하며 추가 실행하지 않는다. 향후 실사용 토큰 절감률은 아직 측정하지 않았고 이번 결과에 포함하지 않는다.


## 출하 전 리뷰 보강

[6관점 코드 리뷰](2026-10-25-session-audit-review.md)에서 legacy counter reset 중복 제거, 기간 밖 usage 메모리 보관, 무관한 Claude 파일 재독해, 상세 JSON 권한, 캡처 잠금 문구를 보강했다. 합성 감사 테스트는 14개가 통과했다. 실제 고정 기간 재집계의 토큰·그룹·중단·도구 집계는 위 보고 수치와 일치했다. 이전 ID 집합은 보관 이력에 따라 커지므로 메모리 사용이 완전히 일정하다고 주장하지 않는다.
