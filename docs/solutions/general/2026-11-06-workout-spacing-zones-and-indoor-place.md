---
tags: [live-activity, swiftui, watchos, heart-rate-zone, indoor-cardio, healthkit, location]
category: general
date: 2026-11-06
status: implemented
severity: important
related_files:
  - DUNEWidget/WatchWorkoutLiveActivity.swift
  - DUNEWatch/Views/Cardio/CardioDistanceMetricsPage.swift
  - DUNEWatch/Managers/WorkoutRouteRecorder.swift
  - DUNEWatch/Managers/WorkoutManager.swift
  - DUNE/Data/HealthKit/WorkoutRouteQueryService.swift
  - DUNE/Domain/Models/WorkoutLocation.swift
---

# 운동 Live Activity 여백·Watch 현재 존·실내 장소 핀

## Problem

### Symptoms

- 거리 우선 Live Activity에서 제목과 마지막 지표가 시스템 카드의 위아래에 가까웠다.
- Watch 러닝 거리·시간 화면은 현재 심박 존을 보려면 다른 페이지로 이동해야 했다.
- Watch 실내 유산소는 실외 경로 기록 대상에서 제외되어 운동 장소도 자동으로 남지 않았다.

### Root Cause

Live Activity는 62pt 심벌과 별도 경과 시간 행이 높이를 차지했다. 단순 패딩 증가는 시스템 컨테이너 높이 안에서 콘텐츠를 다시 압축할 수 있었다. 실내 운동의 경우 경로와 장소 수집 정책을 구분하지 않았다.

## Solution

| 파일 | 변경 |
|---|---|
| `DUNEWidget/WatchWorkoutLiveActivity.swift` | 기본 카드 수직 패딩 20pt, 내부 간격 8pt, 심벌 40×44pt. 선택 지표가 시간이 아니면 경과 시간을 헤더 오른쪽에 둔다. small·Island 배치는 유지한다. |
| `DUNEWatch/Views/Cardio/CardioDistanceMetricsPage.swift` | 사용자가 승인한 V2: 큰 km·시간·평균 페이스 유지, 하단 심박·현재 존·가변 구간 막대. 기존 `displayedZoneIndex/Count`를 사용한다. 미수신은 `Zone --`와 비활성 막대다. |
| `DUNEWatch/Managers/WorkoutRouteRecorder.swift` | 실내 유산소는 coarse 단발 위치 요청으로 최대 30초·최신 15초 이내·오차 100m 이내의 첫 위치 한 점을 수집한 뒤 중지한다. 경로를 만들지 않는다. 기존 실외 경로의 20m 미만 기준은 유지한다. |
| `DUNEWatch/Managers/WorkoutManager.swift` | 실내 장소를 저장 직전 HealthKit workout metadata에 추가한다. 오류를 분리해 운동 저장을 계속한다. 세션 종료·실패·초기화마다 임시 장소를 정리한다. |
| `WorkoutLocation.swift`·`WorkoutRouteQueryService.swift` | `com.dune.workout.place` 저장 계약과 크기·좌표 검증, iPhone에서 운동별 장소와 경로를 읽는다. |
| `CardioAtlasSection/MapView/ShareView` | 자동 장소 핀과 `Workout location` 이름 fallback을 표시한다. 사용자 저장·장소 제거가 자동 위치보다 우선하며 기존 공유 위치 제외 기본값은 유지한다. |

실내 GPS 좌표에서 시설명을 추측하지 않는다. 과거에 위치가 기록되지 않은 운동의 장소를 생성하지 않는다. Watch 위치 권한 설명과 번역도 실제 용도에 맞춰 갱신했다.

### 시스템 타이머의 유한한 폭

헤더의 시스템 `.timer`에 가로 `fixedSize`를 적용하자 SwiftUI의 `GeometryReaderLayout.placeSubviews` 측정에서 위젯이 종료됐다. 유한한 scaled 64pt 폭과 축소 하한을 지정해 해결했다. 실패 로그를 보존하고 수정 후 거리 화면만 재시도했으며 최종 시간·거리 화면도 다시 통과했다.

## Prevention

- 패딩 값만 검사하지 않고 시스템 `activity-content-view`의 실제 경계와 제목·마지막 지표 프레임 차이를 확인한다. `ListCell`에는 별도 시스템 허용 안내가 들어갈 수 있다.
- 시스템 타이머에 무제한 가로 크기 측정을 요청하지 않는다.
- 실내 장소 핀과 실외 경로를 같은 GPS 수집 정책으로 처리하지 않는다. 실내에서 GPS 흔들림을 이동 경로·운동 거리로 저장하지 않는다.
- 위치 미수신·권한 거부·일시 정지·시간 초과·늦은 callback을 독립적으로 검증한다.
- 존 번호를 5개로 고정하거나 HealthKit index 0을 ‘존 0’으로 노출하지 않는다.

## Lessons Learned

UI의 여백은 콘텐츠 높이 예산과 함께 설계해야 한다. 실내 운동도 지도에 표시할 수 있지만 실제 위치 한 점과 이동 경로를 구분해야 한다. 시안 승인, 네이티브 렌더링, 실기기 센서·기기 간 전파 검증은 별도 증거다.

## 검증

단위 21건(iPhone 6·Watch 15), iPhone UI 4건, 40mm Watch UI 3건, 카탈로그 계약 11건이 통과했다. 실제 카드 여백은 위 20pt·아래 20.1–20.3pt다. [검증 기록](../../reviews/2026-11-06-workout-surfaces.md)과 [새 실제 캡처 8장](../../design/phone-design-map/actual/workout-surfaces-2026-11-06/index.html)을 따른다. 실기기 실내 GPS 수신·Watch/HealthKit/iPhone 동기화는 미검증이며 fixture 지도 캡처를 그 증거로 사용하지 않는다.

## 예약 review-ship의 Resolve 보강

2026-11-06 리뷰에서 선택적 경로 조회가 실패해도 유효한 장소를 보존하도록 수정했다. 취소와 장소 없는 실패는 계속 전달한다. 실내 수집은 coarse 단발 요청으로 바꾸고 명시적 일시 정지 후 재개에서만 새 요청을 허용하며 최초 30초 deadline을 유지한다. HealthKit 장소 metadata는 endCollection 전에 최대 1초만 기다려 workout 저장의 앞단을 무기한 막지 않는다. 미사용 route-only protocol/wrapper도 제거했다. 새 회귀 검증 결과는 review-ship 보고서에 별도 기록한다.
