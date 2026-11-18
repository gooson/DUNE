---
tags: [swiftui, theme, app-theme, avfoundation, native-navigation, reduce-motion, visual-audit]
category: architecture
date: 2026-11-19
severity: important
status: implemented
related_files:
  - DUNE/Presentation/Shared/Components/ArtistThemeEdition.swift
  - DUNE/Presentation/Shared/Components/ArtistThemeBackground.swift
  - DUNE/Presentation/Shared/Components/WaveShape.swift
  - DUNE/Presentation/Shared/Components/GlassCard.swift
  - DUNEUITests/Visual/ArtistThemeNativeUITests.swift
  - docs/design/phone-design-map/collect-artist-theme-captures.py
related_solutions:
  - general/2026-11-18-forest-canopy-fog-motion.md
---

# 아홉 작가 테마의 네이티브 배경과 카드

## Problem

### Symptoms

Forest와 Ocean의 일부 탭에서 그림이 카드 옆이나 아래 공간을 차지했다. 같은 테마의 일반 상세에서는 기존 물결이나 탭용 장면이 표시돼 탭 제목 뒤의 그림과 이어지지 않았다.

### Root Cause

탭과 상세의 장면이 별도 구현에 있었고, 일부 첫 카드는 테마 조건에 따라 장식에 너비나 높이를 할당했다. 이 구조에서는 같은 원화를 새 상세에 적용할 때 배경과 카드 배치를 함께 다뤄야 했다.

## Solution

### Changes Made

| 파일 | 변경 | 목적 |
|---|---|---|
| `ArtistThemeEdition.swift`, `DUNE/Resources/ArtistEditions/` | `AppTheme.rawValue`로 팔레트 JSON, 정지 JPG와 무음 MP4를 함께 읽는다. | 테마 선택 하나에 대응하는 장면과 표면을 찾는다. |
| `ArtistThemeBackground.swift`, `WaveShape.swift` | 공용 배경이 탭·상세·시트에 맞는 높이와 그라데이션을 사용한다. 화면 노출, 앱 상태, 동작 줄이기와 저전력 모드에 따라 영상 재생을 결정한다. | 시스템 제목을 읽을 수 있게 하면서 장식을 그림 영역에 둔다. |
| `GlassCard.swift`, `ScoreHeroPalette.swift` | 데이터 카드와 어두운 점수판에 테마별 표면과 조명을 적용한다. | 건강 상태색과 데이터 그래프를 각 화면의 표현으로 유지한다. |

### Key Code

`ContentView`가 탭의 `NavigationStack`을 소유한다. 각 상세는 화면의 스크롤 컨테이너 뒤에 `DetailWaveBackground`를 붙인다. 시스템 제목과 데이터 화면이 같은 위치에서 그려지고, 배경의 장식은 터치와 접근성 트리에서 제외된다.

```swift
.background { DetailWaveBackground() }
.englishNavigationTitle("Condition Score")
```

## Prevention

- [ ] 새 상세는 스크롤 컨테이너에 공용 배경을 적용한다. `List`와 `Form`은 `scrollContentBackground(.hidden)`을 컨테이너에 붙이고 제목과 그림을 실제 첫 viewport에서 대조한다.
- [ ] 밝음·어두움에서 헤더, 점수, 차트와 버튼을 확인한다. 같은 상태를 연속 촬영해 그림의 변화와 고정된 값·컨트롤을 확인한다. 화면 이탈과 동작 줄이기는 정지 원화로 확인한다.
- [ ] 앱의 실제 경로에서 PNG와 접근성 트리를 짝지어 수집하고 실행 소스와 기기, Duo 활성 디스플레이를 기록한다. Duo의 뒤로 가기는 오른쪽 조작 영역에 노출될 수 있다. [캡처 수집기](../../design/phone-design-map/collect-artist-theme-captures.py)

## Lessons Learned

제목 뒤에 그림을 그리면 iPhone과 넓은 화면에서 같은 데이터 레이아웃으로 장면을 이어갈 수 있다. 정지 캡처는 레이아웃과 대비를 확인하고, 연속 프레임과 접근성 위치는 움직이는 장식에 의해 정보와 조작 영역이 이동하는지 확인한다.

## 검증 범위

iOS 앱 빌드와 테마·아이콘 단위 테스트 22개가 통과했다. 아홉 테마의 iPhone 화면 198장과 대표 iPad·Duo 화면 66장을 접근성 트리와 함께 보존했다. 파티스리의 Watch 홈·전체 운동·운동 중 지표는 두 UI 테스트에서 확인했다. [기기별 실제 화면](../../design/phone-design-map/actual/artist-themes/index.html)

visionOS 27.2 SDK에서 실제 `AppTheme.swift`와 `VisionThemePalette.swift`를 Swift 6 엄격 동시성으로 함께 컴파일했다. 전체 `DUNEVision` 빌드는 기존 타깃에서 알림 스케줄러 프로토콜과 시간 포맷 확장을 찾지 못해 실패했다. 소스 목록 두 곳을 바로잡은 임시 빌드에서도 HealthKit 관찰자와 운동 마이그레이션의 기존 의존성이 누락돼 전체 빌드와 실행 화면은 검증하지 못했다.
