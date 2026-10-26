---
tags: [card-navigation, disclosure, design-map]
date: 2026-10-27
category: review
status: reviewed
---

# 카드 헤더 Review / Resolve · 2026-10-27

## Review

대상은 `codex/hrv-rhr-grouping`, 실제 PR base는 `origin/main` (`2e078ba0`), 앱 기준 HEAD는 `f92af99a`다. 시작 시 변경은 오늘의 요약 대안 문서 4개와 레이아웃 인덱스뿐이었다. 모두 이 요청의 범위다. 커밋된 앱·테스트·문서와 해당 미추적 시안을 함께 검토했다. 텍스트 diff 4,539줄과 새 대안 HTML이 있어 review 스킬의 2,000줄 이상 예외에 따라 주 에이전트가 폴더별로 직접 검토했다. 생성 HTML은 편집 원본과의 포함 일치도 확인했다.

| 관점 | 결과 |
|---|---|
| Security | 새로운 네트워크·인증·저장 동작 없음. 시안 예시와 앱 mock 캡처를 사용자 건강 기록과 구분. 새 취약점 발견 없음 |
| Performance | 고정 크기의 헤더 레이블과 40pt 링. 쿼리·정렬·동시성 변경 없음. 섹션 헤더의 한정된 AnyView 경계에 신규 성능 문제 근거 없음 |
| Architecture | 목적지 소유권은 기존 루트에 유지. 정보/입력 버튼은 링크 밖 형제. 기존 hero UI 계약 테스트 누락 P2 1건 |
| Data integrity | 계산·영속성 변경 없음. 부채의 finite/비음수 검증을 통과한 값만 링에 사용하며 원래 시간 표시 보존 |
| Simplicity | 여러 실제 소비자의 동일 헤더를 공유. 시안은 앱 적용과 분리. 추가 문제 발견 없음 |
| Localization | 새 앱 키 없이 기존 localized Text/Label/접근성 hint 재사용. 숫자·사용자 데이터는 기존 포맷 유지. xcstrings 포맷 검사 통과 |
| Agent-native | 이 작업의 agent·prompt 변경이 없어 제외 |

P1 0건 / P2 1건 / P3 0건. 결과 JSON은 `/tmp/review-findings-codex-hrv-rhr-grouping.json`에 저장했다.

## Resolve

`arch-001` **Resolved**: `HeroRhythmUITests.testActivityComponentsRecordedHistoryAndDetail`가 의도적으로 삭제된 `activity-hero-details` footer를 기다렸다. footer 부재를 검증하고 기존 `activityHeroReadiness` 헤더로 동일 목적지를 열도록 수정했다. 해당 selector는 33.426초 통과했다. 앱 코드는 이 Resolve에서 변경하지 않았다. 기존 P1/P2는 최종 delta에서 다시 확인했으며 Open은 0건이다.

## 실제 검증

전용 기기 `02CE1F65-F721-44A3-9BBF-523AE138F678`의 재부팅 후 설치·직접 실행 복구 근거로, 앞선 `Running tests...` 정체에 대해 한 번 재개했다. 동일 AX 자식 오류를 반복하거나 전체 회귀로 범위를 넓히지 않았다.

```sh
DUNE_UI_TEST_WALL_TIMEOUT=600 DUNE_VISUAL_AUDIT_STATIC=1 \
DAILVE_UI_TEST_DERIVED_DATA_DIR=.deriveddata/build-ios \
bash scripts/test-ui.sh --no-regen \
  --simulator-udid 02CE1F65-F721-44A3-9BBF-523AE138F678 \
  --only-testing DUNEUITests/CardNavigationHeaderUITests \
  --only-testing DUNEUITests/ActivityExerciseRegressionTests/testTrainingVolumeSummaryAtMaximumAccessibilityTextSize \
  --only-testing DUNEUITests/HeroRhythmUITests/testActivityComponentsRecordedHistoryAndDetail \
  --log-file .xcodebuild/review-ship-card-headers-ui.log
```

6개 실행·6개 통과·0실패, 172.805초, 정상 종료 0이다. 앱과 UITest target 빌드도 완료했다. SDK 경고는 남았으나 성공 결과가 있어 이를 이전 정체의 확정 원인으로 주장하지 않는다. Swift 구문 검사, xcstrings 포맷, 시안 JS 구문, 원본/생성 HTML 일치, 캡처 해시, `git diff --check`도 확인했다. 시안의 헤더·본문 펼침/접기와 상세 이동·뒤로가기를 브라우저에서 직접 확인했다.

[새 실제 iPhone 화면과 출처](../design/full-redesign-map/review/card-headers-review-ship-2026-10-27/index.html)를 보존했다. 전체 회귀는 요청되지 않아 실행하지 않았다. Watch는 변경 컴포넌트를 사용하지 않는다. 전체 UI 판정기의 공통 파일 fallback은 소비자 확인 후 iOS 관련 6개로 한정했다. 실행하지 않은 full 게이트를 통과로 보고하지 않는다.

오늘의 요약·스트레스 점수 강조는 대안 제시 범위이며 앱에는 적용하지 않았다. [요약 대안](../design/layout-map/digest-disclosure-proposal.md)에서 제안과 현재 앱을 구분한다.


## 최종 PR 통합 검토

기존 Review와 Resolve 이후 변경은 회귀 테스트 1곳, 제안 문서, 새 실제 캡처·출처·포털 링크다. 앱·HealthKit·SwiftData 소스의 추가 변경은 없다. 대상 diff의 강제 unwrap/cast·배열 접근·목적지 소유권·추가 비동기 작업을 재확인했고 신규 크래시/데이터 위험은 발견하지 않았다. 최초 P2는 통과한 selector와 수정된 diff에서 Resolved, Open P1/P2 0건이다. 시안은 앱 반영으로 표시하지 않는다.


추가 실제 화면은 전용 iPad 4장과 Duo 외부 LCD/내부 LCD-1 각 4장을 수집·육안 확인했다. [기기·패널·각도/회전 제한](../design/full-redesign-map/review/card-headers-review-ship-2026-10-27/README.md)을 명시했다. 새 PNG를 모든 하단 상태·모든 기기 테스트의 통과로 확대하지 않는다. 앱 소스가 그대로여서 이미 통과한 6개 UI를 반복하지 않았다.
