# Today 어두운 카드 대비 실제 화면

Sakura·Contour·Water Lilies 밝음 모드 · iPhone 18 Pro Max / iPad Pro 13-inch (M5) · 2026-10-19

[실제 화면 갤러리](index.html) · [캡처 출처](capture-index.json)

어두운 Today 카드에 밝은 모드용 짙은 강조색을 사용하던 상태를 고쳤다. 링 호·상태 제목·추세선에는 어두운 카드용 밝은 색을 적용하고, 밝은 주변 화면의 버튼 색은 유지했다. Contour와 Water Lilies의 근거 수치도 어두운 카드에서 읽히는 상태색으로 조정했다. 링 크기와 카드의 정보 순서는 바꾸지 않았다.

| 테마 | iPhone | iPad | 상태 제목 색/표면 대비(전 → 후) |
|---|---|---|---|
| Sakura | [T03](iphone/sakura/T03.png) | [T03](ipad/sakura/T03.png) | 4.19:1 → 5.58:1 |
| Contour | [T03](iphone/contour/T03.png) | [T03](ipad/contour/T03.png) | 2.05:1 → 10.03:1 |
| Water Lilies | [T03](iphone/water-lilies/T03.png) | [T03](ipad/water-lilies/T03.png) | 2.02:1 → 6.29:1 |

색 대비는 `DesertHorizonConditionHeroView`의 불투명 카드 배경과 sRGB 강조색을 WCAG 상대 휘도 공식으로 계산한 값이다. iPhone 세 테마의 밝음·어두움 4탭 UI 테스트는 각각 통과했다. iPad 3장은 같은 새 빌드를 시뮬레이터에 설치하고 테스트 데이터로 실행한 뒤 LCD를 직접 촬영했다. 이전 화면은 [6개 테마 iPhone 갤러리](../six-theme-hero-rings-2026-10-19/README.md), [Water Lilies iPhone 갤러리](../water-lilies-hero-rings-2026-10-19/README.md), [7개 테마 iPad 갤러리](../seven-theme-ipad-hero-rings-2026-10-19/README.md)에 보존한다.
