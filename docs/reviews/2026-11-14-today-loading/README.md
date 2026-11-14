---
tags: [today, dashboard, notification, weather, regression, verification]
date: 2026-11-14
category: solution
status: verified-with-capture-limits
---

# Today 알림 진입 로딩 검증

`review-ship`에서는 이 폴더의 최초 증거를 역사 기록으로 보존하고, `origin/main`에서 분리한 최종 소스와 P2 보완을 별도로 검증한다. 최종 결과는 [리뷰·Ship 기록](review-ship.md)을 기준으로 한다.

## 범위와 기준

- 신고: 오늘의 요약 알림으로 진입한 뒤 Today만 2분 이상 스켈레톤을 유지했고 이후 표시됨.
- 변경: 날씨 작업을 건강 데이터 완료 경계에서 분리. 화면 배치·문구·권한·HealthKit 조회 정책은 변경하지 않음.
- 직접 소비자: `DashboardView`(T03), `DailyDigestNotificationView`(T10). iOS·iPadOS·Duo가 같은 ViewModel을 사용한다. Watch·Widget·visionOS는 이 ViewModel을 사용하지 않는다.
- 성공 기준: 날씨 응답이 없어도 건강 지표·요약이 준비되고, 과거 날씨 응답은 최신 응답을 덮어쓰지 않으며, ViewModel을 불필요하게 보유하지 않음.
- UI 핵심 selector: `DUNEUITests/NotificationResponseRoutingUITests/testNotificationResponseOpensSummaryAndBackReturnsToToday`.
- 실행 예산: 단위 및 단일 UI 실행당 1200초. 한 번에 한 runner, build jobs 2, index store OFF, 병렬 테스트 OFF.
- UI 판정기의 `full` 경고는 소비자 조사로 위 selector에 한정했다. JSON 증거 파일 때문에 Watch 전체 검사가 필요해지는 것은 아니다. 로컬 전체 회귀는 요청·실행하지 않았다.

## 최초 작업 폴더의 단위 검증 · 보완 전 이력

```bash
python3 scripts/lib/command-deadline.py --seconds 1200 -- bash scripts/test-unit.sh \
  --ios-only --only-testing DUNETests/DashboardViewModelTests \
  --log-file .xcodebuild/today-weather-unit-retry.log
```

전용 iPhone 17 `D1E42917-AF53-4D67-A382-CB6B87FC5A1D`, iOS 27.2. `xcodebuild` exit 0, **40 passed / 0 failed / 0 skipped**. 새 회귀 3건의 실행도 [unit-tests.json](unit-tests.json)에서 확인했다.

- `healthDataAndDigestDoNotWaitForWeather`: 날씨 응답 전 건강 지표·강제 요약·로딩 완료, 이후 날씨 반영.
- `obsoleteWeatherDoesNotReplaceCurrentWeather`: 취소에 협조하지 않는 이전 응답의 덮어쓰기 차단.
- `stalledWeatherDoesNotRetainDashboard`: 날씨 대기 중 ViewModel 해제.
- 기존 첫 로딩·권한 대기·취소·최신 요청 우선·실패 시 기존 기록 유지 회귀도 같은 suite에서 통과.

최초 실행은 nonisolated `deinit`에서 MainActor 프로퍼티를 참조해 컴파일 실패했다. `isolated deinit`으로 수정한 뒤 1회 재실행했다. 재실행의 `.xcodebuild` 로그 디렉터리가 실행 중 사라져 표준 runner의 요약 단계는 exit 1이었다. 원인을 추정해 재실행하지 않고, 정상 종료한 원본 xcresult에서 정확한 suite·40개 개별 결과를 추출해 [unit-summary.json](unit-summary.json)과 [unit-tests.json](unit-tests.json)에 보존했다. runner 전체 성공으로 표현하지 않는다.

원본: `.deriveddata/unit-tests/Logs/Test/Test-DUNETests-2026.11.14_22-32-19-+0900.xcresult`.

## 최초 작업 폴더의 UI와 실제 화면 · 보완 전 이력

같은 selector로 알림 요약 진입 → 요약 내용 → Back → Today 로딩 종료·컨디션 카드가 표시되는 것을 확인했다. 전체 회귀가 아니라 아래 선택 실행만 통과했다.

| 실행 | 기기·plan | 결과 | 캡처 |
|------|-----------|------|------|
| `iphone-ui` | 이름 iPhone 17, 커스텀 dual-display runtime · Full plan + 정확한 selector | 1 passed / 0 failed / 0 skipped, exit 0 | Full plan은 VisualAudit 환경을 전달하지 않아 없음 |
| `iphone-capture` | 같은 기기 · DesignCapture plan + 정확한 selector | 1 passed / 0 failed / 0 skipped, exit 0 | screen 1 세로 T03/T10 PNG·AX 2쌍, 비활성 screen 0 검은 PNG는 제외 |
| `ipad-capture` | iPad mini (A20 Pro) `FA097340-7CDF-424F-A55C-42FF5C337B33` · DesignCapture | 1 passed / 0 failed / 0 skipped, exit 0 | T03/T10 PNG·AX 2쌍 |
| `phone-capture` | 일반 iPhone 18 Pro `9D0602F1-9D0B-4AB0-B144-666748CCDC19` · DesignCapture | 1 passed / 0 failed / 0 skipped, exit 0 | T03/T10 PNG·AX 2쌍 |

단위 검증과 첫 UI 실행에 사용한 `iPhone 17` 이름의 기기는 실제로 두 display를 제공하는 커스텀 runtime이었다. 이를 일반 폰이나 목표 Duo 자세의 완료 증거로 바꾸어 부르지 않았다. 일반 폰은 소유권이 등록된 iPhone 18 Pro의 별도 실행으로 확인했다. 앱 소스를 변경하거나 같은 실패를 무조건 재실행한 것이 아니라, 누락 캡처를 위한 plan 변경과 기기별 선택 검증이다.

각 실행은 `DAILVE_UI_TEST_DERIVED_DATA_DIR=.deriveddata/unit-tests DUNE_UI_TEST_WALL_TIMEOUT=1200 bash scripts/test-ui.sh --no-regen --test-plan <plan> --simulator-udid <UDID> --only-testing <위 selector> --log-file .codex-checks/today-loading/<실행>.log`를 사용했다. [실행별 receipt](phone-capture-result.json), [보완 전 소스 SHA-256과 원본 결과 경로](historical-source-and-results.json), [새 실제 화면 6장과 출처](../../design/phone-design-map/actual/today-loading-2026-11-14/index.html)를 보존했다.

새 PNG 6장을 직접 확인했다. T03은 스켈레톤 대신 컨디션 84와 지표가 표시되고, T10은 날짜·컨디션·활동 값이 표시된다. 스크롤 아래에 있는 내용까지 한 viewport에 전부 보인다고 주장하지 않는다. English·Light·기본 글씨·세로의 선택 흐름이며, 다크·최대 글씨·실제 HealthKit·실제 알림 전달 시간은 이번 검증 범위가 아니다.

**미갱신:** T03/T10의 목표 Duo 접힘과 펼침 가로 캡처. 이번 custom runtime의 screen 0이 비활성이고 screen 1은 세로였으며, 이 실행에 목표 각도/활성 display readback과 자세 전환 checkpoint를 포함하지 않았다. PNG 크기만으로 자세를 인증하지 않는다. 재개 시 소유 Duo의 목표 각도·활성 display·viewport readback을 확정한 뒤 같은 selector의 새 PNG를 수집해야 한다. 기존 Duo PNG는 이번 변경의 증거로 재사용하지 않았다.

검증 전에 이미 booted였던 custom 기기는 유지한다. 이번에 boot한 iPad와 일반 iPhone만 runner 종료 후 소유권을 재확인하고 shutdown한다. 새 worktree나 simulator는 만들지 않았다. 원본 xcresult를 포함한 활성 worktree 캐시는 보존한다.

## 검토

- Security: 저장·외부 전송 범위와 민감 데이터 로그를 추가하지 않았다.
- Performance: 날씨를 기다리는 화면 완료 의존을 제거하고, 새 로드마다 이전 작업을 취소한다.
- Architecture: 기존 request ID와 MainActor 상태 적용 경계를 유지한다. ViewModel을 await 너머 강하게 보유하지 않는다.
- Data integrity: HealthKit 보호 조회·권한 대기와 실패별 기존 기록 유지 정책을 유지한다. 과거 날씨 응답은 폐기한다.
- Simplicity: 기존 날씨 fetch를 재사용하고 별도 서비스/timeout 추상화는 추가하지 않았다.
- Agent-native: `.claude/**`와 adapter 변경 없음.
- SwiftUI/UX/UI test 관점: 상태 적용은 MainActor에서 수행하고 기존 weather 캐시 관찰 경로를 사용한다. 로딩 완료와 실제 값 표시를 각각 확인한다.

실기기에서 어떤 요청이 지연됐는지와 실제 알림 수신·HealthKit 데이터 조회 시간은 이번 시뮬레이터 검증으로 확정할 수 없다.
