# Watch/iOS Parity Rules

## DTO & 데이터 동기화

- Watch DTO 필드 추가 시 양쪽 target 동기화
- WatchConnectivity DTO는 `Domain/Models/WatchConnectivityModels.swift` 단일 소스 유지
- Watch 입력도 iOS 동일 수준 검증
- Watch `isReachable`은 computed property
- WC DTO는 Watch SwiftData ExerciseRecord의 모든 링크 필드를 포함해야 함: WC가 CloudKit보다 먼저 도착하므로, WC 경로로 만든 iPhone ExerciseRecord에 누락된 필드가 있으면 CloudKit dedup이 이를 덮어쓰지 못함. 특히 `healthKitWorkoutID` 같은 외부 시스템 링크 필드는 WC DTO에 반드시 포함하고, iPhone receiver에서 ExerciseRecord 생성 시 설정할 것
- WC/CloudKit 이중 경로 dedup은 2단계: (1) 고유 키(`healthKitWorkoutID`) 매칭 → (2) `exerciseType + date ±120s` 폴백. 고유 키가 있으면 날짜 윈도우 전에 먼저 검사

## WC 메시지 전달 패턴 선택

- "요청" 성격 메시지(`requestBulkSync` 등)에 `transferUserInfo` 사용 금지: 영구 큐 축적으로 중복 처리 발생. `sendMessage` + reachability 재시도 사용
- "데이터" 성격 메시지(운동 완료, 세트 기록)에는 `transferUserInfo` 사용: 보장된 전달 필요
- 설정/라이브러리 동기화에는 `updateApplicationContext` 사용: 최신값 덮어쓰기로 중복 무관

## UI 표시

- bodyweight volume=0에서 "0kg" 표시 금지
- 검색<->브라우징 모드 전환 시 반대편 캐시 초기화
- SVG body diagram 위 DragGesture 금지
- undertrained 리스트는 비즈니스 필터 후 prefix/suffix
- iOS QuickStart popular도 기록 부족 시 library fallback 필수 (Watch personalizedPopular 패턴)

## Watch 운동 세션

- 운동 종료는 액션 즉시 `isSessionEnded` 전환 + finalize timeout watchdog 적용 (HealthKit delegate 지연/누락 방어)
- exerciseLibrary 미수신 상태를 `synced`로 표시 금지: missing context key면 `syncing/notConnected` 유지 + 재요청 경로 확보
- cardio elapsed/pace는 pause 구간을 제외한 active elapsed 기준으로 계산: wall-clock 기반 계산 금지
- 루틴 템플릿은 CloudKit-only 의존 금지: `WorkoutTemplate` primary 유지 + WatchConnectivity fallback DTO/병합(local 우선)
- watchOS nested TabView 금지: horizontal+vertical 중첩은 제스처 충돌/Crown 라우팅 미정의. flat 수평 TabView 사용
- saveCardioRecord에 수집된 모든 metric 전달 확인: `WorkoutManager` 수집 값(steps, floors 등)이 `ExerciseRecord` init에 빠짐없이 전달
- strength 템플릿: `discardWorkout()` + 개별 HKWorkout 생성. HKLiveWorkoutBuilder는 단일 HKWorkout만 생성하므로, strength 세션 종료 시 `discardWorkout()` 후 `WatchWorkoutWriter`로 운동별 개별 HKWorkout 저장. 시간 겹침 방지를 위해 순차 오프셋 적용
- `HKLiveWorkoutDataSource`는 stepCount/flightsClimbed 자동 수집 안 함: `enableCollection(for: HKQuantityType(.stepCount), predicate: nil)` 명시 호출 필수
