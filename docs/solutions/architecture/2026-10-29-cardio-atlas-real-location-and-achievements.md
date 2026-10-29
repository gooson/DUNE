---
tags: [cardio-atlas, healthkit, watchos, swiftdata, cloudkit, workout-route, location-privacy, achievements, accessibility]
date: 2026-10-29
category: architecture
status: draft
severity: important
related_files:
  - DUNE/Domain/Models/WorkoutLocation.swift
  - DUNE/Data/Persistence/Models/WorkoutLocationRecord.swift
  - DUNE/Data/Persistence/Migration/AppSchemaVersions.swift
  - DUNE/Domain/Models/CardioAtlasProgress.swift
  - DUNEWatch/Managers/WorkoutRouteRecorder.swift
related_solutions:
  - ../healthkit/ios-cardio-live-tracking.md
---

# Solution: Cardio Atlas의 실제 위치와 운동 이력 기반 성취

## Problem

### Symptoms

- 기존 유산소 상세에는 운동 경로와 실내 장소를 일관되게 보관하고 공유할 구조가 없었다. HealthKit 운동만 남거나 실내 운동에 GPS 경로가 없는 경우, 위치를 추정해 그리면 실제 기록과 다른 화면이 된다.
- 로컬 `ExerciseRecord`와 HealthKit `HKWorkout`이 같은 운동을 가리킬 수 있어 Journey 합계와 Passport 달성 횟수가 중복될 수 있다. 세트가 없는 유산소 로컬 기록은 HealthKit 조회 범위 밖에 있으면 목록에서 사라질 수 있었다.
- 경로를 공개하는 공유 이미지에서는 시작·종료 지점과 장소 이름을 별도로 숨길 필요가 있었다. 공유 설정이 비공개 원본을 바꾸거나, 운동 통계까지 함께 줄이면 안 된다.

### Root Cause

운동 본체, 위치 메타데이터, HealthKit 경로, 공유용 공개 범위가 서로 다른 수명과 권한을 갖는데 이를 하나의 추정 경로나 기존 기록 필드로 다루려 하면 스키마 호환성과 데이터 정직성이 함께 흔들린다. 특히 Watch와 iPhone 운동은 앱 출처가 같을 수 있어 출처와 시간 근접성만으로 동일 운동이라고 판단할 수 없다.

## Solution

### Changes Made

| File | Change | Reason |
|---|---|---|
| [`WorkoutLocation.swift`](../../../DUNE/Domain/Models/WorkoutLocation.swift), [`WorkoutLocationRecord.swift`](../../../DUNE/Data/Persistence/Models/WorkoutLocationRecord.swift), [`AppSchemaVersions.swift`](../../../DUNE/Data/Persistence/Migration/AppSchemaVersions.swift) | 검증된 경로·장소 payload를 별도 `WorkoutLocationRecord`에 저장하고 V20에 모델만 추가 | 배포된 V19 모델 필드와 체크섬을 유지하며 CloudKit 호환 메타데이터를 추가 |
| [`WorkoutWriteService.swift`](../../../DUNE/Data/HealthKit/WorkoutWriteService.swift), [`WorkoutRouteQueryService.swift`](../../../DUNE/Data/HealthKit/WorkoutRouteQueryService.swift), [`CardioSessionSummaryView.swift`](../../../DUNE/Presentation/Exercise/CardioSession/CardioSessionSummaryView.swift) | iOS 야외 경로를 로컬/HealthKit에 연결하고, 가져온 HK 경로를 상세에서 조회 | 실제 기록을 사용하며 경로 쓰기 실패가 저장된 운동을 무효화하지 않음 |
| [`WorkoutRouteRecorder.swift`](../../../DUNEWatch/Managers/WorkoutRouteRecorder.swift) | Watch 야외 유산소 GPS 수집과 구간별 HK route 쓰기 | 일시정지·시간 공백을 직선으로 잇지 않고 운동 완료와 route enrichment를 분리 |
| [`CardioAtlasProgress.swift`](../../../DUNE/Domain/Models/CardioAtlasProgress.swift), [`CardioAtlasSection.swift`](../../../DUNE/Presentation/Exercise/CardioAtlas/CardioAtlasSection.swift) | 실제 이력으로 Journey/Passport 재계산, 로컬·HK 별칭 정리 | 편집·삭제 뒤 합계와 달성을 현재 기록에 맞춤 |
| [`WorkoutSummary+Dedup.swift`](../../../DUNE/Presentation/Shared/Extensions/WorkoutSummary+Dedup.swift), [`ExerciseListSection.swift`](../../../DUNE/Presentation/Activity/Components/ExerciseListSection.swift), [`ExerciseViewModel.swift`](../../../DUNE/Presentation/Exercise/ExerciseViewModel.swift) | 정확한 HK ID 링크를 우선하고, 매칭 HK 행이 없는 세트 없는 유산소 로컬 행 유지 | 다른 동시 Watch 운동을 지우지 않으며 가짜 근력 세트 없이 기록 접근성 보존 |
| [`WorkoutLocation+Sharing.swift`](../../../DUNE/Domain/Models/WorkoutLocation+Sharing.swift), [`CardioAtlasShareView.swift`](../../../DUNE/Presentation/Exercise/CardioAtlas/CardioAtlasShareView.swift) | 비공개 원본과 별도 공유 payload 생성, 지도 스냅샷과 이미지 렌더링 | 위치 공개 선택과 양 끝 자르기를 이미지에만 적용 |

### Data and capture contract

`WorkoutLocationPayload`는 좌표·시간·고도·정확도를 검증하고 경로를 최대 4,000점으로 제한한다. 불량점, 긴 시간 간격, 비정상 점프, 일시정지는 새 구간 경계로 남긴다. `WorkoutPlace`는 유효 좌표와 최대 200자 이름을 저장한다. JSON payload는 1 MB 상한을 검사하며, 손상된 바이트는 읽기 실패로 처리하되 복구 가능하도록 원본을 보존한다. 로컬 UUID와 HealthKit workout ID를 독립적으로 연결한다.

`isIndoor`는 운동 종류 메타데이터다. 새 실내 운동은 GPS를 자동 수집하지 않지만, 가져온 실내 운동에 실제 기록된 경로가 있다면 이를 지우지 않는다. 경로가 없을 때는 선택한 장소 또는 위치 미설정 상태를 보여 준다.

iPhone 야외 세션은 수집한 실제 점을 저장하고, 연속 구간마다 별도 `HKWorkoutRoute`를 해당 운동에 연결한다. Watch도 야외 유산소에서만 GPS를 수집하고, 완료된 HK 운동에 연관 route를 구간별로 쓴다. HK 운동 저장 성공 뒤 route 쓰기에 실패해도 운동 성공 상태는 유지한다.

Watch의 프로덕션 HK 콜백 브리지는 `WorkoutRouteCallbackGate`가 취소·늦은 콜백 경합에서 continuation을 한 번만 재개한다. `WorkoutRouteSaveJob`은 외부 writer의 `await`를 지나는 동안 job을 강하게 붙들지 않고 5초 제한 또는 취소 시 소유 데이터를 해제한다. 임의의 협조하지 않는 fake writer가 자기 async frame을 계속 소유할 수는 있으므로, 모든 외부 frame을 강제 종료한다고 해석하지 않는다.

### History, display and privacy contract

Journey는 현재 운동과 같은 활동의 실제 거리 또는 지속 시간 합계를 사용한다. 거리가 측정되지 않은 활동은 시간 목표를 사용한다. Passport는 같은 활동의 단일 운동 거리·시간과 실제 세션 횟수 임계값을 이력에서 다시 계산한다. 층수, 걸음 수, 기기 레벨을 거리나 가상의 거리·거리명으로 바꾸지 않는다. 읽을 수 있는 이력 범위가 제한되면 해당 범위의 기록만 반영한다.

중복 제거는 연결된 HK ID의 정확한 일치를 우선한다. 다른 알려진 ID가 있는 로컬 기록은 같은 시간·운동 유형의 Watch 운동을 근접 매칭으로 소비하지 않는다. ID가 없는 앱 생성 운동에 한해 기존 시간·유형 fallback을 적용한다. HK 요약이 보이지 않는 세트 없는 로컬 유산소 기록은 로컬 행으로 남긴다.

공유 시작 상태는 위치 비공개다. `showPlace == false`이면 공유 payload에서 경로·핀 좌표·장소명을 모두 제거하여 지도 타일도 만들지 않는다. 양 끝 자르기는 구간 사이 공백을 거리로 계산하지 않으며 짧은 경로는 빈 공개 경로가 된다. 원본 payload와 운동 거리·시간 통계는 수정하지 않는다. Atlas, Pace Ribbon, Signature 이미지는 별도 선택지이고, Pace Ribbon은 사용할 수 있는 시각·좌표 구간이 있을 때만 활성화한다. 지도는 `MKMapSnapshotter`로 만들고 `ImageRenderer`는 명시적 크기와 2배 이상 scale을 사용한다. 실패는 재시도 가능한 상태로 표시한다.

### Key Code

```swift
// 기존 모델 필드를 바꾸지 않는 추가 스키마
enum AppSchemaV20: VersionedSchema {
    static let versionIdentifier = Schema.Version(20, 0, 0)
    static var models: [any PersistentModel.Type] {
        AppSchemaV19.models + [WorkoutLocationRecord.self]
    }
}

// 저장된 비공개 위치가 아니라 공유용 사본에서 공개 범위를 계산
let publicLocation = location.shareLocation(
    showPlace: showPlace,
    trimDistanceMeters: trimEnds ? 300 : 0
)
```

## Validation status (2026-10-29, UI verification blocked)

- 핵심 집중 단위 73 tests / 10 suites, 목록·가시성 31 tests / 5 suites, Watch 경로 12 tests 통과. 첫 두 집계에는 겹치는 사례가 있어 합산 고유 테스트 수로 표시하지 않는다.
- Watch 전체 209개 실행에서는 변경하지 않은 음성 피드백 테스트의 영어 기대값과 한국어 결과 사이 21개 assertion issue가 있었다. 광범위 iOS 단위 시도에서도 기존 AI medical safety 0/3 실패가 있었다. 전체 통과로 표시하지 않는다.
- 첫 phone 실행에서 Activity smoke와 HealthKit 상세는 통과했다. 상위 컨테이너 식별자가 자식 식별자를 덮는 문제를 명시적 접근성 컨테이너로 고쳤다. 큰 글씨 재기동을 단일 기동 클래스로 분리했으나 기존 Activity 진입의 AX 질의에서 5분 한도를 넘었다.
- 기본 크기 검사는 시작 전 정체로 종료됐다. 소유권을 확인한 iPhone·Watch만 종료한 뒤 한 번 복구 검증했으나 기기 preflight가 실패했다. iPad·Duo 및 최종 네이티브 캡처는 미완료이며 기존 이미지를 새 증거로 사용하지 않는다.
- 최종 코드 재검토에 미해결 P1/P2는 없지만, UI 게이트 통과와 PR 머지는 완료되지 않았다. [검증 기록](../../reviews/2026-10-29-cardio-atlas/README.md)과 [실제 화면 갱신 상태](../../design/full-redesign-map/review/cardio-atlas-2026-10-29/index.html)를 따른다.
- 로컬 원본 로그는 `.codex-checks/cardio-atlas/`에 보존한다. 실제 기기 GPS·HK route sync·CloudKit 다른 기기 동기화는 미검증이다.

## Native follow-up findings at 18:00

The scheduled retry restored a fresh owned iPhone to a responsive state. Native images exposed a navigation bug that existence-only AX checks had missed: Share/Journey/Passport were pushed underneath the exercise inspector. Atlas now owns enum sheet destinations, each with a local NavigationStack and Done that clears only the Atlas state. Progress values are captured at entry while Journey goal bindings remain live. Tests require hittable destination roots and return to the same detail.

Visual review also caught a map image expanding its preview horizontally because aspect-fill was combined with a fixed250pt height. Aspect-fit at available width preserves the full route. Share tests verify actual style selection and preview/selector bounds. Pace uses distinct existing chart tokens plus the existing localized style caption. At accessibility sizes, full-width vertical Place/Share actions prevent Korean syllables from stacking. The corresponding focused phone cases passed and the new images were independently inspected with no remaining P1/P2 in those deltas.

iPad verification subsequently hit the five-minute allowance during initial app launch and during an Activity interaction; the intervening route/Journey case passed. These results are preserved separately rather than reporting the whole device as passed. Further device verification and the UI gate remain subject to the final review record.

## Prevention

- 스키마 확장은 배포된 모델의 checksum을 먼저 확인하고, 독립 모델의 optional/default 필드로 추가한다. 위치 payload는 입력·저장·읽기 경계에서 같은 정규화를 적용한다.
- 운동 성공과 선택적인 route 저장 성공을 별도로 검증한다. pause·gap·중복 시각·GPS 점프, 취소 전 등록/후 등록/늦은 callback, 5초 제한과 소유권 해제를 재현 가능한 fake provider로 확인한다.
- 이력 합계는 정확한 HK 링크를 먼저 확인한 뒤 좁은 fallback을 사용한다. 다른 ID의 동시 Watch 운동, HK 조회 누락, 세트 없는 유산소를 회귀 사례로 유지한다.
- 공유 검증은 타일·핀·경로·이름을 모두 검사하고, 자르기 전후 비공개 데이터와 운동 통계가 같은지 확인한다. UI fixture의 GPS 표본은 150초 공백 대신 실제적인 약 8초 간격을 사용한다.
- AX 존재만으로 전면 목적지를 검증하지 않는다. native PNG와 hittable 상태를 확인하며 inspector 내부 이동은 presentation ownership을 검토한다.
- 고정 높이 이미지의 intrinsic width가 부모 ScrollView를 확장하지 않게 종횡비를 보존하고 실제 시트 경계를 검사한다.
- native AX 식별자를 section/container에 줄 때는 `.accessibilityElement(children: .contain)`으로 자식 식별자를 보존한다. 큰 글씨 UI 테스트는 앱 중복 실행을 피하고, 목표 화면에 진입하기 전의 기존 루트 오류와 해당 화면 배치 검증을 구분한다.

## Lessons Learned

위치의 실제 기록 여부, 운동 정체성, 공유 공개 범위는 각각 따로 모델링해야 한다. 실내 여부만으로 경로를 삭제하거나 시간 근접성만으로 운동을 합치면 유효한 가져온 경로와 Watch 운동을 잃는다. native UI 테스트는 단위 테스트가 찾지 못한 접근성 컨테이너 식별자 상속 문제를 드러냈으며, 실패 뒤 수정한 코드는 해당 UI 실행 결과가 나올 때까지 검증 완료로 표시하지 않는다.

## Final follow-up scope

Current implementation221cd7ab has focused phone delta2/2 pass. The inline map reserves gestures for the expanded view; directional small drags avoid overshooting a Passport button on short inspector viewports. The place editor uses an always-visible navigation search drawer, verified on portrait iPhone. Its changed unfolded-Duo layout and iPad remain unverified for the documented runtime/readiness reasons. New actual39images are preserved; this document stays draft until the UI pipeline can finish.
