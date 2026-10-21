---
tags: [watchos, healthkit, heart-rate-zone, paging, cardio, distance, haptic]
category: general
date: 2026-10-21
status: implemented
severity: important
related_files: [DUNEWatch/Views/SessionPagingView.swift, DUNEWatch/Managers/WorkoutManager.swift, DUNEWatch/ContentView.swift, DUNEWatch/Views/Cardio/CardioHRZonePage.swift]
related_solutions: [docs/solutions/general/2026-10-12-watch-workout-screen-system.md]
---

# Solution: Watch 유산소 존 페이지 유지와 1km 통과 알림

## Problem

### Symptoms

- 유산소 운동 중 가로 스와이프로 심박 존에 머물러도 손목을 내렸다 올리면 메인 지표로 돌아갔다.
- 첫 HealthKit 존에서 `존 0`이 표시되고 존 막대의 강조 위치도 맞지 않았다.
- 달리기 등 거리 중심 운동에서 1km 통과 시 별도 피드백이 없었다.

### Root Cause

`CardioSessionPagingView`가 `isLuminanceReduced` 전환 때마다 선택된 탭을 `.mainMetrics`로 변경했다. `HKWorkoutZone.index`는 0 기반인데 `displayedZoneIndex`는 원시 값을 그대로 표시했고, `HRZoneBar`는 1 기반 번호를 그렸다. 거리 표본은 UI 지표와 페이스 계산에만 사용됐다.

## Solution

### Changes Made

| File | Change | Reason |
|---|---|---|
| `DUNEWatch/Views/SessionPagingView.swift` | 저휘도 탭 강제 변경을 제거하고 페이징 화면과 같은 계층에 6초 거리 통과 배너를 표시 | 사용자가 선택한 페이지를 유지하고 시각 피드백 제공 |
| `DUNEWatch/Managers/WorkoutManager.swift` | HealthKit 원시 존 인덱스를 설정 배열의 1 기반 표시 순서로 변환; 거리 경계 통과를 세션별로 한 번 감지 | `존 0`과 막대 위치 불일치 및 중복 알림 방지 |
| `DUNEWatchTests/CardioDistanceMilestoneTests.swift` | 1km 경계·중복·거리 후퇴·비정상 표본 검사 | 센서 표본 흔들림과 큰 값 갱신의 결정적 동작 보장 |
| `DUNEWatchUITests/Smoke/WatchLiveHeartRateZonesUITests.swift` | 0 기반 첫 존과 거리 배너 fixture 검사 | 실제 Watch 화면의 텍스트·페이지·배너 확인 |
| `DUNEWatch/ContentView.swift` | DEBUG 시뮬레이터 전용 달리기 세션 진입 인수 추가 | 홈 화면 진입 불안정성과 무관하게 운동 화면을 검증 |

거리 기반 유산소 활동에서 누적 거리가 정수 km를 처음 넘으면 최신 km를 저장하고 Watch 진동을 한 번 실행한다. 같은 km의 반복 표본이나 센서 값 후퇴에서는 반복하지 않는다. 새 세션은 0부터 시작하고 복구 세션은 복구된 거리의 정수 km를 이미 지난 경계로 간주한다. 일시정지 중 들어온 거리 표본은 알림 없이 경계만 소비한다.

시뮬레이터 UI 검증은 `--ui-watch-direct-running`으로 운동 화면에 진입하고, `--ui-watch-kilometer-milestone`에서 심박 존 페이지로 스와이프할 때 990m에서 1010m 표본을 입력한다. 시간 지연 fixture는 앱 시작 시간 변동으로 배너가 테스트 전에 사라질 수 있어 사용하지 않는다. 첫 존의 실제 화면은 작업트리 전용 Watch에서 캡처해 C03에 등록했다. 배너는 최신 빌드의 전용 Watch 테스트 녹화에서 확인했고, 16초 프레임을 C13 실제 화면으로 등록했다. 배너를 `TabView`의 overlay에서 상위 `ZStack`의 형제 뷰로 옮긴 뒤에도 XCTest 접근성 식별자 조회는 실패했다. 접근성 노출 여부와 실기기 진동은 별도로 확인해야 한다.

### Verification

- Watch 단위 테스트 12개가 전용 Watch에서 통과했다. 0 기반 존을 `존 1`로 표시한 C03 UI 테스트도 통과했다.
- C13은 최신 빌드의 실제 Watch 녹화 프레임에서 `1 km 통과` 배너를 시각적으로 확인했다. 해당 UI 테스트의 접근성 식별자 검사는 실패했다.
- 거리 변화와 C13 캡처를 검사하도록 수정한 최종 UI 테스트는 Xcode가 전용 Watch를 대상 목록에서 찾지 못해 실행되지 않았다. 최종 자동 UI 테스트는 미검증 상태다.

## Prevention

- HealthKit의 0 기반 인덱스를 화면 라벨·막대 위치에 연결할 때 표시 순서를 따로 계산한다.
- watchOS 저휘도 전환은 선택된 운동 페이지를 바꾸는 트리거로 사용하지 않는다.
- 누적 센서 값에서 경계 알림을 만들 때 세션별 마지막 경계, 복구 시드, 일시정지 표본을 함께 처리한다.
- 실제 AOD 유지와 진동·심박 수집 상호작용은 실기기에서 확인한다. 시뮬레이터 캡처는 이를 증명하지 않는다.

## Lessons Learned

운동 중 화면 상태와 HealthKit 데이터 인덱스는 별도의 계약이다. 화면 선택은 저휘도 변화에 종속시키지 않고, 건강 데이터의 원시 인덱스는 사용자에게 표시하기 전에 정규화해야 한다.
