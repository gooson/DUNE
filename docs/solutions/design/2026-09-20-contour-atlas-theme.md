---
tags: [swiftui, theme, contour, accessibility, preview, watchos]
category: solution
date: 2026-09-20
status: draft
related_files:
  - DUNE/Presentation/Shared/Components/ContourBackground.swift
  - DUNE/Presentation/Settings/Components/ThemePickerSection.swift
  - DUNE/Presentation/Shared/Components/WavePreset.swift
related_solutions: [2026-03-04-adding-new-theme]
---

# Contour Atlas 테마와 정적 카드 미리보기

> `codex/contour-atlas-theme` 구현 기록. 아직 main에 머지되지 않은 초안이다.

## Problem

실제 선택 가능한 6개 테마는 곡선 배경과 반투명 카드라는 표현을 공유한다. 색상 점 3개만 보여주는 선택 화면에서는 재질과 배경 차이를 판단하기 어렵다. 과거 기획/해결 문서에는 현재 enum에 없는 테마도 있어 문서의 테마 개수를 구현 근거로 삼을 수 없다.

## Solution

- `AppTheme.contourAtlas`와 `Contour` prefix, light/dark 26개 색상 자산을 추가했다.
- `ContourLines`는 비정형 닫힌 등고선을 unit-space 좌표로 한 번 계산한다. `path(in:)`에서는 좌표 변환만 수행한다.
- `ContourBackground`를 Tab/Detail/Sheet와 Watch에서 공유한다. Watch는 선 개수를 줄이며 모든 Contour 배경은 정적이다.
- Hero/Standard/Inline/Section 카드에 불투명 석회색/먹색 표면을 적용한다. 상태/지표 색의 구분을 유지하고 라임은 작은 강조에 사용한다.
- 설정에서는 실제 `TabWaveBackground`, `StandardCard`, `ProgressRingView`를 재사용한다. 예시 숫자는 접근성 트리에서 제외하며 선택 이름은 Dynamic Type을 유지한다.
- 시스템 `accessibilityReduceMotion`은 읽기 전용이다. `waveAnimationEnabled`와 결합한 `waveReducedMotion`으로 미리보기의 반복 애니메이션 시작을 차단한다. 기본값은 true라 기존 화면의 모션 정책은 유지된다.
- 영어/한국어/일본어 이름과 예시 레이블을 추가했다.
- 실제 dark 캡처에서 Today 보조 텍스트가 흐릿해지는 것을 확인하고, Contour에서만 대비를 검증한 `sandColor`로 표시한다. 기존 테마의 보조 텍스트 스타일은 유지한다.
- 테마별 버튼을 독립 Form 행으로 만들고, 상위 식별자는 섹션 헤더로 옮겨 개별 버튼의 접근성 식별자가 유지되게 한다.
- 샘플 데이터 seeder가 설정을 초기화하므로, debug 테스트 경로에서 시딩 이후 명시적으로 요청한 테마를 복원한다.

## Prevention

- 테마 목록의 source of truth는 `AppTheme.allCases`이다.
- 새 테마는 enum뿐 아니라 Tab/Detail/Sheet, 공유 카드, 링, Watch 연결을 확인한다.
- 미리보기마다 영구 애니메이션을 실행하지 않는다. 시스템 접근성 환경값을 덮어쓰지 않는다.
- 색상 자산 로딩과 light/dark 대비는 단위 테스트로 검증하고 실제 선택/재실행은 UI 테스트로 검증한다.
- 배경은 hit testing 및 VoiceOver 탐색에서 제외한다.
- lazy Form에서 화면 밖으로 나간 행을 `isSelected`로 조회하면 snapshot을 얻을 수 없다. 선택은 해당 행이 보이는 시점에 확인하고 지속성은 앱 재실행으로 검증한다.

## Lessons Learned

새로움은 색상 수보다 재질과 형태의 차이에서 얻을 수 있다. 고정 등고선과 불투명 카드의 조합은 데이터 가독성을 유지하면서 기존 물결/유리 표현과 구별된다.

## Validation

- iOS + embedded Watch 시뮬레이터 빌드 통과.
- 26개 자산 JSON 및 두 String Catalog의 en/ko/ja 테마 이름 확인.
- 텍스트용 Accent/Bronze/Sand의 배경/카드 대비: 최저 4.76:1.
- `AppThemeTests`: 9개 통과. 실제 UIColor 자산 로딩과 light/dark 대비 검사 포함.
- iPhone 17 / iOS 27: UI 2개 통과. 라이트·다크, 설정 선택, Desert→Contour 전환 및 재실행 지속성 확인.
- iPad Pro 13-inch (M5) / iOS 27: UI 1개 통과. 라이트·다크 및 설정 미리보기 확인.
- iPhone/iPad의 Today 및 설정 캡처를 직접 확인했다. Contour의 작은 Today 문구 대비 개선 후 재검증했다.
- 첫 실행 Morning Briefing이 화면을 가리지 않도록 테스트 실행 인자에서 해당 안내를 끈다.
- SwiftUI/UX/UI testing/quality gate 관점을 인라인 검토했다: 기존 테마 기본 동작 유지, 정적 배경의 캐시/접근성 제외, 개별 선택 행/선택 trait, 번역, 저장 호환성 확인.
- 제한: watchOS 런타임 부재로 Watch 화면은 미검증. iOS 26 실행, 최대 Dynamic Type 및 가로 모드는 이번 검증에 포함하지 않았다.
