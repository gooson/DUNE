---
tags: [swiftui, desert-horizon, widgetkit, activitykit, accessibility, native-capture, duo]
category: general
status: implemented
date: 2026-10-24
severity: important
related_files:
  - DUNE/Presentation/Shared/Components/DesertWaveBackground.swift
  - DUNE/Domain/UseCases/ExerciseMixService.swift
  - DUNE/Presentation/Dashboard/NotificationHubView.swift
  - DUNE/Presentation/Dashboard/DashboardView.swift
  - DUNEWidget/Views/SmallWidgetView.swift
related_solutions: []
---

# Solution: DESERT HORIZON 시안을 실제 정보와 시스템 호스트에 구현하기

## Problem

시안을 그대로 간결하게 옮기면 실제 앱의 추천·근육 지도·개인 기록·보고서 데이터가 사라질 수 있다. DUNE 카드의 material은 진한 사구 배경을 비쳐 대비가 약해지고, 시스템 Widget의 작은 영역에서는 링과 footer가 겹쳤다. 앱 안에서 보기 좋은 위젯 시안만으로 WidgetKit·ActivityKit 호스트의 배치를 검증할 수도 없었다.

### Symptoms

- 상단 배경 끝이 드러나거나 사구 곡선이 큰 원처럼 보임.
- 요약 카드에서 그래프·세부 정보·기록 경로가 누락됨.
- 부모 AX identifier가 자식 차트·비교율 식별자를 덮음.
- Duo에서 별도의 toolbar action 두 개가 멀리 떨어지고 시스템 glass가 본문을 가림.
- SpringBoard gallery는 앱 내부 custom ID와 다른 native widget host를 노출함.

### Root Cause

시안의 표현과 제품의 정보 계약을 구분하지 않으면 단순화를 기능 삭제로 구현하게 된다. 시스템 host가 SwiftUI content를 자체 toolbar·widget 구조로 변환하기 때문에 앱의 버튼 ID·스크린샷만으로 최종 geometry를 추측할 수 없다. UI 테스트의 고정 언어·배열 index·큰 swipe 역시 실제 표시가 정상이어도 false failure를 만들 수 있다.

## Solution

| File/area | Change | Reason |
|---|---|---|
| DesertPalette·named colors | 밝음/어두움 카드·글자·테두리 자산과 Desert 전용 surface | 다른 테마를 건드리지 않고 대비 확보 |
| DesertWaveBackground | 원래 frequency/skew 유지, 185pt crest를 420pt fill로 비례 변환하고 fade mask와 전체 gradient | 원래 곡선과 페이지 연속성 유지 |
| 기존 4탭 component | 지도·추천·보고서·개인 기록·그래프를 재사용하고 중복 기록 CTA만 상단으로 이동 | 정보·행동 보존 |
| ExerciseMixService | 동일 28일 summary에서 count/weekly/muscle/cardio/frequency 생성 | 루트·상세 분모 불일치 방지 |
| ActivityViewModel | 하나의 28일 HealthKit query를 training load와 공유, 날짜 필터 후 completed sets 접근 | 중복 I/O·전체 이력 정렬 회피 |
| NotificationHubView·WhatsNewStore | typed destination, 건강/News 필터, 합산 unread/read-all, queue 밖 change notification | 기존 경로·동시성 유지 |
| DashboardView | 두 action을 하나의 bounded HStack toolbar item으로 묶음 | 접힘·iPhone·iPad 상단 가림 해소 확인, 펼침 최종 배치는 미검증 |
| Widget·Live Activity | intrinsic VStack/Spacer footer, appearance-aware ink/accent, privacySensitive와 기존 timer 유지 | 실제 시스템 크기·상태와 호환 |

### Key contracts

- 기간·미래 날짜를 먼저 거른 다음 explicit link와 app-only 이름/시간 fallback으로 중복을 제거한다. 외부 HealthKit 운동은 근접 시간만으로 없애지 않는다.
- 완료 세트는 중복 없는 primary muscle에 균등 배분한다. 부위 정보가 없는 세트는 별도 집계하고 유효한 duration/distance만 합산한다.
- accessibilityElement(children: .contain)을 통해 카드의 자식 chart/rate identifier를 보존한다. AX text-size에서는 좁은 요약 행을 세로로 전환한다.
- Widget gallery placeholder와 Home timeline, device appearance와 ActivityKit host appearance, 방향 시안과 실제 앱 PNG를 별도 출처로 기록한다.

## Prevention

- UI 테스트 통과 후에도 최소 합본의 실제 native PNG에서 가림·잘림을 확인한다. Duo는 active display, 공식 orientation readback, 실제 AX viewport와 native PNG를 함께 검증한다.
- native control의 AX child frame과 enclosing system hit target을 구분한다. 임의 y150 제한 대신 실제 rail/viewport와 compact-group 조건을 검사한다.
- 시스템 gallery에는 stable semantic firstMatch를 쓰고 transient bound-index query를 사용하지 않는다. 홈 배치가 확인되지 않았으면 다른 gallery PNG를 그 증거로 재사용하지 않는다.
- 스크롤은 실제 navigation/tab/scroll frame으로 유효 viewport를 구하고 겹친 거리만큼 작은 방향 drag를 한다.
- 최초 XCTest setup부터 원하는 seeded scenario를 적용한다. 본문에서 재실행하기 전에 super setup이 실패할 수 있다.
- 실패한 전체 번들과 통과한 개별 method를 구분한다. 원인과 대응한 변경이 있을 때만 한 번 재검증하고, 무관한 full suite로 확대하지 않는다.

### Rule proposal

`.claude/**`는 수정하지 않았다. 시스템 host의 실제 geometry·출처 확인은 기존 디자인맵 절차에 따라 수행하며 새 전역 규칙 승격은 제안만 남긴다.

## Lessons Learned

시안의 간결함은 실제 데이터 양을 줄이는 근거가 아니다. 기존 정보 구조와 계산 경로를 보존한 뒤 표면·간격·정보 위계만 바꾸면 최종 구현을 검증하기 쉽다. 앱·Widget·Live Activity는 같은 색 토큰을 공유해도 서로 다른 시스템 레이아웃 계약을 가지므로 각각 실제 host의 대표 상태에서 확인해야 한다.

## Verification and deferred state

최종 제품 소스 c239a50d에서 iOS·Widget·Watch 통합 빌드와 관련7suite의58개 단위 테스트가 통과했다. 이후 앱 소스는 동일하며 선택한 iPhone·iPad·Duo 접힘, Widget gallery3family, Rest/Watch Notification Center UI를 확인했다. 전체 UI 회귀·Home 실제 점수 timeline·Island·실제 페어링/잠금 개인정보 상태는 미검증이다.

Duo 펼침 Today는 물리 landscapeLeft와 별개로 표시 컨트롤러가 rot0, 실제 AX669×951로 남아 가로 검증이 실패했다. XCUIDevice와 공식 physical orientation 명령도 이 상태를 해결하지 못했다. 세부 원인은 미확정이며 앱 코드 문제로 단정하지 않는다. 사용자가 “일단 넘어가”로 이 검증을 보류했으므로 후속 진행을 허용하되, 실패 로그와 캡처 없음은 유지한다. 잠금 해제 후 실제 display/AX/native PNG가 모두 가로임을 확인한 뒤 focused selector만 재개한다.
