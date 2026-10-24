---
tags: [design, layout, widget, live-activity, ios, watchos]
date: 2026-10-24
category: plan
status: implemented-pending-validation
---

# DESERT HORIZON 위젯·휴식 라이브 액티비티 배치

[크기·상태별 추가 시안](../theme-map/themes/dune-widget-live-activity.html) · [4탭 시안](../theme-map/themes/dune-final-four-tab.html) · [실제 화면맵](../phone-design-map/actual/index.html)

이 문서는 `DUNEWidget/`와 `Shared/`에 반영한 **정보·표면 배치 계약**이다. HTML은 코드에 있는 콘텐츠를 재구성한 디자인 시안이며 실제 위젯·라이브 액티비티 캡처가 아니다. WidgetKit 크기별 화면과 휴식 라이브 액티비티의 시스템 호스트 캡처는 [증거 목록](../live-activity-captures/README.md)을 포함해 아직 대기 중이다.

## 화면 ID와 정보 순서

| ID | 위치·크기 | 현재 구현의 정보 | DESERT HORIZON 배치 |
|---|---|---|---|
| LA01 | iPhone 잠금 화면 | Rest Timer → 운동명 → Set 번호·남은 시간 | 휴식 타이머 → 운동명 → 세트 번호·남은 시간. 남은 시간을 가장 강하게, 이름은 한 줄에서 자른다. |
| LA02 | Dynamic Island compact | 타이머 기호 + 남은 시간 | 기호와 단색 호박색 시간. 섬의 시스템 검은 표면을 유지한다. |
| LA03 | Dynamic Island minimal | 타이머 기호 | 기호 하나만 표시한다. 여러 활동이 있을 때도 숫자를 억지로 넣지 않는다. |
| LA04 | Dynamic Island expanded | Rest Timer + 남은 시간 + 운동명 | 제목·남은 시간을 양쪽에, 운동명을 아래에 둔다. 세트 번호는 현재 구현에 없으므로 추가하지 않는다. |
| LA05 | Watch Smart Stack small | 운동명 → 세트 번호 → 타이머 기호·남은 시간 | 세 정보의 순서를 유지하고 손목에서 읽을 수 있도록 남은 시간을 크게 둔다. |
| WG01 | DUNE Today small | 컨디션·준비도·웰니스 작은 링, 가장 낮은 점수 상태, 갱신 시각 | 세 링의 크기와 열 폭을 같게 하고 맨 아래 상태·시각을 한 줄에 둔다. |
| WG02 | DUNE Today medium | 세 점수의 세로 타일 | 각 타일에 지표 이름·링·상태를 유지한다. |
| WG03 | DUNE Today large | 세 점수의 가로 행, 가장 낮은 점수 상태, 갱신 시각 | 링·이름·상태·짧은 설명을 행마다 두고 하단 요약을 분리한다. |
| WG04 | DUNE Score small·medium·large·세로 | 선택한 컨디션/준비도/웰니스 점수, 상태, 크기에 따라 설명 | 작은 크기에서는 제목·링·상태, 중간 이상에서는 설명을 추가한다. 세로 크기는 큰 링을 중앙에 둔다. |

## 상태·표현 계약

- 값이 없는 점수는 `--`와 DUNE 열기 안내를 사용한다. 세 점수가 모두 없으면 현재 구현의 브랜드·심장 기록지·안내를 크기에 맞게 보여 준다. 일부 값만 없으면 다른 점수는 남긴다.
- 세 점수의 의미색은 현재 `WidgetDS`의 상태색을 따른다. 테마 호박색은 배경의 옅은 빛과 링 바탕에만 사용해 건강 상태의 의미를 덮지 않는다.
- 잠금 화면의 운동명은 주변 사람에게 보일 수 있다. 현재 잠금 화면·Dynamic Island·Watch small의 운동명에는 `privacySensitive()`를 적용했다. 실제 시스템 잠금 상태와 개인정보 표시 방식은 호스트 캡처에서 확인한다. 시안에는 현재 속성인 운동명·세트 번호·남은 시간만 둔다.
- 휴식 카운트다운은 종료 시간이 갱신되면 새 종료 시간을 표시한다. 시안의 01:30과 00:08은 정지된 상태 예시다. 완료 후 화면을 임의로 유지하지 않는다.
- 홈 화면 위젯 표면은 시스템 컨테이너를 기준으로 한다. Live Activity의 compact·minimal·expanded는 시스템 검은 표면을 그대로 사용한다. DUNE의 색은 정보 계층을 보조하는 정도로 적용한다.
- WG01 Small의 세 링·지표 이름은 카드 위쪽, 가장 낮은 점수 요약·갱신 시각은 카드 아래쪽에 배치한다. 하단 행은 카드 내용 높이를 기준으로 흐르며 링 위에 겹치거나 절대 위치에 매달리지 않는다. 다른 위젯 크기도 제목·링·설명·하단 정보가 각각의 영역 안에서 줄바꿈되도록 둔다.
- 밝음·어두움, 작은 폭, 큰 글씨, 점수 일부 누락·전체 누락을 확인한다. 한 줄에 들어가지 않는 문장은 자연스럽게 줄바꿈하고 링 수치가 잘리지 않게 한다.
- 위젯의 표시 크기는 기기·시스템 구성에 따라 달라지므로 HTML의 프레임은 정보 구조용이다. 실제 플랫폼 크기·안전 영역과 글씨 대비는 해당 런타임 캡처에서 판정한다.

## 현재 구현 대조에서 확인한 일

1. `WorkoutRestLiveActivity.swift`의 다섯 프레젠테이션에는 타이머·운동명·세트 번호만 있다. 운동 일시정지·건너뛰기 버튼은 현재 제공되지 않는다.
2. 구현 전 잠금 화면은 검정 80% 표면, Dynamic Island는 흰 기호·텍스트였다. 현재 DESERT HORIZON은 밝음·어두움에 대응하는 `WidgetWarmSurface`와 `WidgetWarmAccent`를 사용한다. 잠금 화면 시스템 행동은 표면과 대비되는 `DesertHorizonInk`를 사용하고, Dynamic Island의 시스템 검은 표면은 유지한다. 다른 테마의 잠금 화면은 기존 검정 표면을 유지한다.
3. `WidgetDS`는 앱에서 선택한 테마의 액센트를 읽고, 점수 자체의 의미색은 유지한다. DESERT HORIZON 위젯은 따뜻한 컨테이너·타일·테두리를 적용했다. `WellnessDashboardEntry`의 전체·일부·전체 누락 `#Preview`는 개발용 상태 fixture이며 시스템 호스트 캡처 증거가 아니다.
4. `SmallWidgetView`의 가장 낮은 점수 요약과 `LargeWidgetView`의 갱신 시각, `SingleMetricWidget`의 네 크기 및 전체 누락 상태를 각각 포함한다.
5. 코드 반영은 완료했으나 실제 캡처·접근성 합격은 아직 기록하지 않는다. 다음 실제 검증에는 잠금 화면, iPhone 세로·가로 Dynamic Island, Watch Smart Stack, 위젯별 크기·밝음·어두움·누락 상태가 필요하다. 시스템 호스트에 진입하지 못한 상태는 미캡처로 남긴다.

## Apple 디자인 원칙 검토

| 원칙 | 판정 | 이번 배치에서의 근거 |
|---|---|---|
| 목적 | 적합 | 휴식에는 남은 시간, 점수 위젯에는 수치와 상태를 가장 먼저 읽는다. |
| 주도권 | 적합 | 위젯은 앱 진입의 요약이며 미구현 조작을 암시하지 않는다. |
| 책임 | 확인 필요 | 운동명은 잠금 화면에 노출될 수 있어 실제 개인정보 설정과 함께 판단해야 한다. |
| 친숙함 | 적합 | 시스템 프레젠테이션과 위젯 크기별 기본 정보 구조를 유지한다. |
| 유연함 | 확인 필요 | 실제 기기 큰 글씨·제한된 Dynamic Island 폭의 캡처가 아직 없다. |
| 단순함 | 적합 | compact·minimal에는 타이머 핵심 정보만 둔다. |
| 완성도 | 확인 필요 | 테마색과 상태색의 대비 및 여백은 실제 런타임에서 확인해야 한다. |
| 즐거움 | 적합 | 호박색과 부드러운 표면은 운동·건강 정보를 가리지 않는다. |

[Apple Live Activities](https://developer.apple.com/design/human-interface-guidelines/live-activities)와 [Apple Widgets](https://developer.apple.com/design/human-interface-guidelines/widgets)의 짧고 한눈에 읽히는 정보, 시스템 위치별 적응, 적절한 여백, 민감 정보 노출 기준을 적용한다.

## 최신 Watch 운동 Live Activity

main의 WLA01 통합 후 [Watch 운동 계약](watch-workout-live-activity.md)에도 같은 표면·대비 기준을 반영했다. 운동명·심박·칼로리·거리는 privacySensitive로 표시하며 진행·일시 정지·stale·경과 시간과 미러링 동작은 기존 코드를 보존한다. 새 시스템 캡처의 출처·미검증 상태는 [실제 WLA01 맵](../phone-design-map/actual/live-activity/index.html)에서 구분한다.
