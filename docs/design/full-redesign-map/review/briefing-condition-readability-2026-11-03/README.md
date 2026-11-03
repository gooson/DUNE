---
tags: [morning-briefing, condition-detail, native-capture, dynamic-type]
date: 2026-11-03
category: review
status: reviewed
---

# T09 정보 강조 · T04 카드 높이 검증

사용자가 아침 브리핑 **1번 정보 강조**를 선택하고 컨디션 카드 높이도 수정하도록 요청했다. 앱 코드·실제 PNG·시안은 구분한다. [새 실제 화면](index.html)과 [출처·파일 해시](evidence.json)를 보존한다.

## 결과

| 범위 | 결과 |
|---|---|
| 초기 `BriefingTemplateEngineTests` |33개/1 suite PASS |
| Review/Resolve 후 최종 `BriefingTemplateEngineTests` |35개/1 suite PASS |
| iPhone 한국어 브리핑 | 정보 수치·스크롤·실제 Done PASS |
| iPhone 어두움 최대 접근성 브리핑 | 제목·수치·본문 노출·실제 Done PASS |
| iPhone 이전 RHR 카드 일반 글씨 | 최초 제목 시작선2.667pt 차이 FAIL, 아이콘 최소 정사각형 보정 후 PASS |
| iPhone 이전 RHR 카드 최대 글씨 | 보정 전/후 모두 PASS; 최종 보정 후 결과를 사용 |
| iPhone 최종 캡처 플랜 | 관련1개 PASS, 새 T04 PNG 확보 |
| iPad mini 관련 두 selector |2/2 PASS, T04·T09 새 PNG 확보 |
| 문자열 카탈로그 | 포맷·manual 상태 PASS |
| 테마맵 | build 및 --check PASS |
| SwiftUI·Apple UX 읽기 전용 검토 | 구체적 P1/P2/P3 finding 없음, 새 PNG 별도 확인 |

실행한 selector는 `DUNEUITests/TodaySettingsRegressionTests/testMorningBriefingInformationHighlightsInKorean`, `DUNEUITests/TodaySettingsRegressionTests/testMorningBriefingAtDarkMaximumAccessibilitySize`, `DUNEUITests/ConditionDetailRedesignTests/testPriorRHRDateKeepsContributionCardsAndRowsAligned`, `DUNEUITests/ConditionDetailRedesignTests/testPriorRHRDateStacksContributionCardsAtMaximumText`다. iPad는 그중 기본 글씨 두 개만 실행했다. 전체 회귀 통과를 뜻하지 않는다.

## 실행·소스

소스 기준 revision은 `df53412c41340861722d422c8da6f4fa0d8e77fd`에 이번 dirty 변경을 더한 상태다. source 해시는 evidence.json에 기록했다. 브리핑 두 검사의 이후 제품 변경은 별도 파일인 ConditionDetailHeader의 아이콘 프레임뿐이어서 해당 근거를 재사용했다. unit도 엔진과 관련 테스트가 동일해 재사용했다.

- unit: `.xcodebuild/briefing-info-unit.log`,33 PASS.
- 최초4개 UI: `.xcodebuild/briefing-condition-info-ui.log`,3 PASS/1 FAIL/exit65. 결과 `Test-DUNEUITests-2026.11.03_10-13-41-+0900.xcresult`.
- 아이콘 수정 후 관련2개: `.xcodebuild/condition-alignment-retry-ui.log`,2 PASS/exit0. 동일 실패 재시도1회 소진. 실패 조건을 완화하지 않았다.
- 최종 T04 캡처: `.xcodebuild/condition-final-native-capture.log`,1 PASS/exit0. 일반 Full 플랜에는 VisualAudit 환경 설정이 없어 별도 DesignCapture 플랜에서 새 PNG를 보존했다. 결과 `Test-DUNEUITests-2026.11.03_10-28-07-+0900.xcresult`.
- iPad: `.xcodebuild/briefing-condition-ipad-native.log`,2 PASS/exit0. 결과 `Test-DUNEUITests-2026.11.03_10-31-17-+0900.xcresult`.

기기는 소유권 등록된 iPhone `5E9B3E4F-136B-4D22-8113-CCB18744729B`와 iPad `AB35434E-7026-4601-A301-F2F284B063FE`다. 정상 종료 뒤 이번 작업이 부팅한 두 기기만 shutdown했다. 다른 작업의 기기·공용 service는 조작하지 않았다.

브리핑은 한국어·DUNE 어두움, 컨디션은 영어·DUNE 밝음·100점/이전 RHR fixture다. 사용자 첨부의58점·Ocean 화면과 같은 입력 비교가 아니다. iPhone1206×2622, iPad1512×2316 원본을 직접 확인했다. 최대 글씨의 스크롤 밖 내용은 콘텐츠 clipping과 구분했다.

초기 시안 요청 때 중단한 앱 빌드는 테스트 미실행/exit130이며 제품 실패가 아니다. 이번 변경에 필수가 아닌 formatter 구현의 Python 회귀 실행도 중단하여 통과 근거로 사용하지 않는다. 실제 카탈로그 `--check --check-manual`은 별도로 통과했다.

## 미갱신 범위

Duo 접힘·펼침의 **T04·T09** 새 PNG는 미완료다. 검토된 `/tmp/life-hinge-20261029/skills/hinge/scripts/hinge`가 없고 현재 Xcode27.2의 `devicectl device`에는 기존 motion 조회 경로가 없다. `device simulate`도 biometrics/location/statusBar만 제공한다. `cua.getApp('com.apple.dt.Devices')`는 server -10005 timeoutReached로 실패했다. Mac 잠금이라고 단정하거나 잠금 해제를 요청하지 않았다. 기존 두 자세의 PNG를 이번 수정 증거로 사용하지 않았다. 검토된 자세 제어·실제 readback 경로 또는 Device Hub AX 연결이 복구되면 소유 Duo에서 해당 두 화면만 재수집한다.

일본어 실행·iPad 최대 글씨·다른 테마 전체·Duo 자세·Watch/visionOS의 런타임 검증으로 확대하지 않는다. Watch·visionOS는 두 화면의 직접 소비자가 아니다.

## Review/Ship 보완

리뷰에서1ms 미만 HRV의 방향 보존과 이력 없는 평균 생략을 보완했다. 주간 진행률은 Sections로 옮겼고 미사용 주간 문장과 번역 키3개를 제거했다. 최종 엔진35개가 통과했으며 추가된 사례는±0.5/±0.0001ms와 이력 없음이다. 한국어 브리핑1개 최종 재검증도 PASS했고 해당 일반 글씨3장·Phone T09 행·Today 보드를 최신 원본으로 갱신했다. 기존 컨디션 카드 소스·입력·배치의 성공 근거는 그대로 재사용한다. 새로운 숫자 문자열과 이력 없는 평균 상태가 예전 캡처에서 검증된 것으로 주장하지 않는다.
