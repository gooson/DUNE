---
tags: [personal-records, share, image-renderer, sparkline, navigation]
date: 2026-03-30
category: plan
status: approved
---

# Plan: PR Shareable Card + Sparkline Tap Interaction

## Summary

두 가지 p3 TODO를 함께 구현합니다:
1. **#154 PR Shareable Card**: PR 달성 시 Instagram Stories용 이미지 자동 생성 (ImageRenderer 기반)
2. **#156 Sparkline Tap Interaction**: PR 섹션 카드 내 스파크라인 탭 시 해당 Kind로 상세 진입

## Affected Files

| File | Change Type | Description |
|------|------------|-------------|
| `DUNE/Presentation/Activity/PersonalRecords/Components/PRShareCard.swift` | **New** | PR 공유용 카드 뷰 (dark bg, 운동 종류/PR 값/날짜/델타 표시) |
| `DUNE/Presentation/Activity/PersonalRecords/Components/PRShareService.swift` | **New** | ImageRenderer 기반 PR 공유 이미지 렌더링 서비스 |
| `DUNE/Presentation/Activity/PersonalRecords/PersonalRecordsDetailView.swift` | **Modify** | 현재 Best 카드에 공유 버튼 추가 |
| `DUNE/Presentation/Activity/Components/PersonalRecordsSection.swift` | **Modify** | 스파크라인 영역에 탭 제스처 추가, onSparklineTap 콜백 |
| `DUNE/Presentation/Activity/ActivityView.swift` | **Modify** | 스파크라인 탭 핸들러 → PersonalRecordsDetailView로 kind 전달 |
| `DUNE/Presentation/Activity/ActivityDetailDestination.swift` | **Modify** | personalRecords에 preselectedKind 파라미터 추가 |
| `Shared/Resources/Localizable.xcstrings` | **Modify** | 새 UI 문자열 en/ko/ja 추가 |
| `DUNETests/PRShareServiceTests.swift` | **New** | ImageRenderer 렌더 결과 검증 |

## Implementation Steps

### Step 1: PR Share Card View (`PRShareCard.swift`)

기존 `WorkoutShareCard.swift` 패턴을 참고하되, PR 데이터 전용으로 구성.

**레이아웃:**
```
+-------------------------------------+
| [trophy.fill] Personal Record       |
|                                     |
| Bench Press                         |
| Est. 1RM                            |
|                                     |
|   142.5 kg          +5.2 kg        |
|   Mar 28, 2026                      |
|                                     |
| [DUNE branding]                     |
+-------------------------------------+
```

**구현 핵심:**
- Dark gradient background (기존 `ShareCardPalette` 재사용)
- Kind-specific tint accent
- 운동 이름 + kind 표시
- 큰 값 + 단위 + 델타
- 날짜
- DUNE 브랜딩
- 폭 360pt (기존 share card와 동일)

**데이터 모델:**
```swift
struct PRShareData: Sendable {
    let exerciseName: String
    let kindDisplayName: String
    let kindIconName: String
    let value: String
    let unitLabel: String?
    let delta: String?
    let date: Date
    let kindTintColor: Color // Note: Color is not Sendable, but ok for Presentation layer
}
```

### Step 2: PR Share Service (`PRShareService.swift`)

기존 `WorkoutShareService` 패턴 그대로:
- `measuredRenderSize()` → `sizeThatFits`로 높이 계산
- `renderShareImage()` → `ImageRenderer` + `proposedSize` 고정 (correction #209)
- scale 3.0 retina

### Step 3: Detail View에 공유 버튼 추가

`PersonalRecordsDetailView.swift`의 `currentBestCard` 우측 상단에 share 버튼:
- `Button` + `square.and.arrow.up` 아이콘
- 탭 시 `PRShareService.renderShareImage()` 호출
- 결과를 `@State private var shareImage: ShareableImage?`에 저장
- `.sheet(item: $shareImage)` → `ShareImageSheet` 재사용

### Step 4: Sparkline Tap Interaction

**PersonalRecordsSection.swift:**
- `onSparklineTap: ((ActivityPersonalRecord.Kind) -> Void)?` 콜백 추가
- 스파크라인 영역에 `.onTapGesture` + `.contentShape(Rectangle())`
- `accessibilityHidden(true)` 제거하고 접근성 레이블 추가
- 탭 시 콜백으로 해당 record의 kind 전달

**ActivityDetailDestination.swift:**
- `personalRecords` → `personalRecords(preselectedKind: ActivityPersonalRecord.Kind?)` 변경

**ActivityView.swift:**
- `PersonalRecordsSection`의 `onSparklineTap` 핸들러에서 `.personalRecords(preselectedKind: kind)` 네비게이션

**PersonalRecordsDetailView.swift:**
- `var preselectedKind: ActivityPersonalRecord.Kind?` 파라미터 추가
- `.task(id:)`에서 preselectedKind가 있으면 `viewModel.selectedKind = preselectedKind`

### Step 5: Localization

새 문자열:
- "Share PR" (공유 버튼 접근성 레이블) → en/ko/ja
- "Personal Record" (공유 카드 헤더) → en/ko/ja
- sparkline 접근성 레이블: "View {kind} details" → en/ko/ja

### Step 6: Unit Tests

`DUNETests/PRShareServiceTests.swift`:
- `renderShareImage`가 non-nil UIImage를 반환하는지
- 렌더된 이미지의 width/height > 0 확인
- 빈 데이터에서 안전하게 동작하는지

## Test Strategy

- **Unit Test**: PRShareService 렌더 결과 검증
- **Manual**: 시뮬레이터에서 PR detail → share 버튼 → 이미지 미리보기 → ShareLink 동작
- **Manual**: Activity tab → PR card sparkline 탭 → Detail view에서 해당 Kind 선택 상태 확인

## Risks & Edge Cases

1. **ImageRenderer offscreen 높이 0**: correction #209 적용 (sizeThatFits + explicit frame + proposedSize)
2. **No PR data**: 공유 버튼은 currentBest가 있을 때만 표시
3. **Single sparkline point**: sparkline이 2 미만이면 탭 영역이 없음 → 카드 전체 탭은 기존 NavigationLink 유지
4. **ActivityDetailDestination Hashable**: Kind를 associated value로 추가해도 Hashable은 자동 합성됨 (Kind: Hashable)
5. **kind 매칭 실패**: preselectedKind가 availableKinds에 없으면 무시 (기존 first fallback 동작)
