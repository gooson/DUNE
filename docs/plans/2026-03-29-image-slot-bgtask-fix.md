---
tags: [image-slot, bgtask, cloudkit, scroll-anchor, gpu]
date: 2026-03-29
category: plan
status: approved
---

# Plan: Fix Image Slot 1320x0 & BGTask Scheduling Errors

## Problem

세 가지 런타임 에러가 콘솔에 출력됨:

1. **`Failed to create 1320x0 image slot`**: GPU가 height=0 텍스처 할당 시도 → 실패
2. **`updateTaskRequest failed ... BGSystemTaskSchedulerErrorDomain Code=3`**: CoreData CloudKit 백그라운드 export 태스크 스케줄링 실패
3. **`[AppRefreshCoordinator] Refresh triggered by cloudKitRemoteChange`**: 정보성 로그 (에러 아님)

## Root Cause Analysis

### Error 1: Image Slot 1320x0

4개 탭 루트 View에서 `Color.clear.frame(height: 0).id(ScrollAnchor.top)` 패턴을 scroll-to-top 앵커로 사용.
`Color.clear`는 투명이지만, SwiftUI는 proposed width(= 디바이스 전체 너비 1320px@3x)에 height 0인 레이어를 할당 시도.
GPU가 0-dimension 텍스처 생성에 실패하여 IOSurface 에러 발생.

**영향 파일:**
- `DUNE/Presentation/Dashboard/DashboardView.swift` (line ~81-83)
- `DUNE/Presentation/Activity/ActivityView.swift` (line ~174-176)
- `DUNE/Presentation/Wellness/WellnessView.swift` (line ~41-43)
- `DUNE/Presentation/Life/LifeView.swift` (line ~49-51)

### Error 2: BGTask Code=3

`Info.plist`에 `processing` background mode와 CoreData CloudKit task identifier가 누락.
SwiftData의 CloudKit integration은 내부적으로 `BGProcessingTaskRequest`를 스케줄링하지만,
`UIBackgroundModes`에 `processing`이 없고 `BGTaskSchedulerPermittedIdentifiers`가 없으면 Code=3(unavailable) 반환.

**영향 파일:**
- `DUNE/Resources/Info.plist`

## Implementation Steps

### Step 1: Fix scroll anchor (4 files)

`Color.clear.frame(height: 0)` → `Color.clear.frame(width: 0, height: 0)` 변경.
width를 0으로 설정하면 GPU가 0x0 텍스처를 할당할 필요 없이 최적화로 스킵.

**변경 파일:**
- DashboardView.swift
- ActivityView.swift
- WellnessView.swift
- LifeView.swift

**패턴:**
```swift
// Before
Color.clear
    .frame(height: 0)
    .id(ScrollAnchor.top)

// After
Color.clear
    .frame(width: 0, height: 0)
    .id(ScrollAnchor.top)
```

### Step 2: Fix BGTask scheduling (Info.plist)

Info.plist에 두 가지 추가:

1. `UIBackgroundModes`에 `processing` 추가 (기존 `remote-notification` 유지)
2. `BGTaskSchedulerPermittedIdentifiers` 키 추가:
   - `com.apple.coredata.cloudkit.activity.export`
   - `com.apple.coredata.cloudkit.activity.import`

이 identifier들은 CoreData CloudKit이 내부적으로 사용하는 표준 prefix.

## Test Strategy

- 빌드 성공 확인 (`scripts/build-ios.sh`)
- 기존 유닛 테스트 통과 확인
- 시뮬레이터에서 앱 실행 후 콘솔 로그에 `1320x0` 에러 사라지는지 확인
- CloudKit sync가 정상 동작하는지 (기존 동작 유지)

## Risks & Edge Cases

- **scroll-to-top 동작**: `frame(width: 0, height: 0)`도 `ScrollViewReader.scrollTo` 앵커로 정상 작동 (SwiftUI는 view identity로 스크롤, 크기 무관)
- **BGTask on simulator**: `processing` mode 추가 후에도 시뮬레이터에서는 BGTask가 실행되지 않을 수 있음. 하지만 에러 로그는 줄어들 것으로 예상
- **배터리 영향**: `processing` mode 추가 시 시스템이 백그라운드에서 앱을 깨울 수 있음. CoreData CloudKit export는 가벼운 작업이므로 영향 미미
