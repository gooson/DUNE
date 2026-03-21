# Performance & Caching Patterns

## Formatter/Color 캐싱
- `NSObject` 기반 formatter → `private enum Cache { static let formatter = ... }`
- `String(format:)`은 value operation → static 캐싱 불필요
- `Color(hue:saturation:brightness:)` → static 배열 캐싱
- `static let` > `static func` for body-called gradients

## Computed Property 캐싱
- 정렬/필터 포함 → `private(set) var` + `didSet { invalidateCache() }`
- merge 로직 포함 → `@State` + `onChange(of: count)` 무효화
- sheet에 전달하는 computed → `@State`로 캐싱
- ViewModel computed UseCase 호출 → stored property (`loadData`에서 1회)

## body 내 금지 패턴
- Calendar 연산 → ViewModel `loadData`에서 사전 계산
- Service 호출 → `@State` + `.task(id:)` 캐싱
- `UserDefaults.standard.integer(forKey:)` → stored property + setter
- ScrollView paging body에서 UserDefaults 접근 금지
- `Shape.path(in:)` 내 문자열 파싱/JSON/정규식 금지 → init-time 수행

## Collection 최적화
- ForEach O(N) lookup → `[UUID: Record]` Dictionary 캐시
- `personalizedPopular(limit:)` → 실제 필요 수량 전달
- Icon switch dispatch → View init에서 `Resolved` enum pre-resolve

## Scene Phase / Lifecycle 콜백
- `.active` scene phase에서 비용 높은 작업(HealthKit 쿼리 등) → `lastRefreshDate` throttle (30분 등 도메인 적합 간격)
- `NSPersistentStoreRemoteChange` 기반 refresh에서 throttle bypass 금지 → SwiftData write가 CloudKit sync를 트리거하여 feedback loop 발생. 전용 짧은 throttle(5초 등) 사용

## Task Concurrency
- Cancel-before-spawn: `reloadTask?.cancel()` 후 새 Task 할당
- `guard !Task.isCancelled` 후 state 업데이트
- parallel fetch → partial failure 보고 ("N of M sources")
- TaskGroup catch → 에러 식별 로그: `"[Module] {key} fetch failed: \(error)"`
- `defer` 사용: Void async → 필수, returning func → 금지 (명시적 리셋)
- Swift 6 `@MainActor` 클래스에서 `withThrowingTaskGroup` 내 `@MainActor addTask` 금지 → continuation 내부 Task timeout 패턴 사용

## AVCaptureSession Buffer Pool
- `CMSampleBuffer`/`CVPixelBuffer`를 비동기 Task/closure에 캡처 금지
- 2D detection (synchronous): pool buffer 직접 사용 가능 — `captureOutput` 반환 시 pool에 즉시 반환
- 3D detection (async): `CIContext.createCGImage`로 CGImage 변환 후 전달 — CGImage만 풀 의존성 제로
- CVPixelBuffer 딥카피는 불충분 — Vision 내부 ML 파이프라인이 여전히 풀을 경유할 수 있음
- Vision `mlImage buffer` 에러는 메모리 부족이 아닌 **풀 고갈** 시그널
- 카메라 관련 변경은 반드시 실기기 테스트 (시뮬레이터 재현 불가)

## JSON/Data
- 번들 JSON 파싱 → `static let shared` 싱글턴
- aggregate 합산 → `isFinite` guard + 물리적 상한
