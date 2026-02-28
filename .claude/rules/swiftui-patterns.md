# SwiftUI Layout & Animation Patterns

## Chart UI
- Selection info → `.overlay(alignment: .top)` + `.ultraThinMaterial` (VStack 삽입 금지)
- Period 전환 → `.id(period)` + `.transition(.opacity)` (Spring 금지)
- 데이터 종속 UI → 항상 placeholder 렌더 + `.frame(minHeight:)`
- Swift Charts → `.clipped()` 필수; Chart closure 내 allocation 금지
- gradient/color → `private enum Gradients { static let }` 로 호이스트

## Navigation & Routing
- `.navigationDestination(for:)` → 조건 블록 밖 (body 최상위)
- Push 자식 sheet → 독립 `@State` (부모 VM bind 금지)
- sizeClass View 분기 → `@State`로 초기값 캡처 (iPad multitasking 안정)
- iPad HStack → 섹션을 computed property로 추출

## State Management
- `.onChange(of: array)` 대신 `.onChange(of: array.count)` (O(1))
- `.task(id:)` key → content-aware `Hasher` (count 기반 String 금지)
- 관련 `@State` → tuple return 후 동시 할당 (중간 상태 노출 방지)
- `onAppear` + `onChange` 동일 로직 → `.task(id:)` 통합
- sheet 이중 트리거 → `pendingSheet` @State + `onChange` 한 프레임 지연

## List & Collection
- `modelContext.delete()` → `withAnimation {}` 래핑 필수 (CollectionView crash)
- `.swipeActions` 삭제 확인 → `Button { }.tint(.red)` (role: .destructive 금지)
- `modelContext.save()` 명시적 호출 지양 → auto-save 위임
- 분류 switch에 `default:` 금지 → exhaustive case 나열

## @Query
- `fetchLimit` → `Query(FetchDescriptor)` init 사용 (`@Query` 매크로는 fetchLimit 직접 파라미터 미지원)

## ScrollView
- LazyVGrid + @Query 동일 View 금지 → child 격리 또는 eager grid
- `.scrollBounceBehavior(.basedOnSize)` 동적 content에 적용
- eager grid ForEach → stable identity 필수 (`id: \.self` 금지)
- List/Form + 커스텀 배경 → `.scrollContentBackground(.hidden)`

## Wave Background System
- 새 View → Tab(`TabWaveBackground`), Detail(`DetailWaveBackground`), Sheet(`SheetWaveBackground`)
- 색상 오버라이드 → `.environment(\.waveColor, color)` (init 파라미터 금지)
- WavePreset에 소비자 없는 case 추가 금지

## iOS 26 Specifics
- TabBar tint → `.tint(DS.Color.warmGlow)` modifier (UITabBar.appearance 금지)
- `.sidebarAdaptable` → UIKit appearance proxy 무시됨
