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

## Task Concurrency
- Cancel-before-spawn: `reloadTask?.cancel()` 후 새 Task 할당
- `guard !Task.isCancelled` 후 state 업데이트
- parallel fetch → partial failure 보고 ("N of M sources")
- TaskGroup catch → 에러 식별 로그: `"[Module] {key} fetch failed: \(error)"`
- `defer` 사용: Void async → 필수, returning func → 금지 (명시적 리셋)
- Swift 6 `@MainActor` 클래스에서 `withThrowingTaskGroup` 내 `@MainActor addTask` 금지 → continuation 내부 Task timeout 패턴 사용

## JSON/Data
- 번들 JSON 파싱 → `static let shared` 싱글턴
- aggregate 합산 → `isFinite` guard + 물리적 상한
