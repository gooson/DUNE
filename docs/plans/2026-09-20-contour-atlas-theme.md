---
tags: [theme, contour, accessibility, settings]
date: 2026-09-20
category: plan
status: implemented
confidence: high
related_solutions: [2026-03-04-adding-new-theme]
---

# Implementation Plan: Contour Atlas

## Context

기존 6개 테마는 자연 모티프, 곡선 배경, 반투명 카드가 반복된다. 설정의 색상 점만으로는 실제 화면 차이를 비교하기 어렵다. 사용자가 Contour Atlas 제안과 구현 진행을 승인했다.

## Requirements

- 일곱 번째 테마 `contourAtlas`: 석회색/먹색 표면, 얇은 지형 등고선, 라임 포인트.
- Tab/Detail/Sheet 배경과 Hero/Standard/Inline/Section 카드에 적용.
- 기존 저장값과 테마 색상 의미를 유지하고 iOS/watchOS en/ko/ja 이름 제공.
- 실제 공유 카드와 배경을 사용한 설정 미리보기, 선택 상태 접근성, Dynamic Type 대응.
- 등고선은 정적 벡터로 구성하고 좌표를 캐싱. 미리보기 모션 비활성화.

## Approach

Prefix 색상 resolver와 기존 exhaustive switch를 재사용한다. 새 테마에만 불투명 카드 표면을 적용한다. 건강 지표/상태 색은 구분 가능한 의미 색을 유지한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 물결 색상만 교체 | 작은 변경 | 기존과 유사 | 제외 |
| 실시간 지형 애니메이션 | 강한 효과 | 데이터 집중/전력 비용 | 추후 검토 |
| 캐시된 등고선 + 불투명 표면 | 차별성/가독성/낮은 비용 | 정적 표현 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| DUNE/Domain/Models/AppTheme.swift | 수정 | 저장 enum |
| DUNE/Presentation/Shared/Extensions/AppTheme+View.swift | 수정 | prefix, 이름 |
| Shared/Resources/Colors.xcassets/Contour*.colorset | 추가 | light/dark 토큰 |
| DUNE/Presentation/Shared/Components/ContourBackground.swift | 추가 | 공유 벡터 배경 |
| DUNE/Presentation/Shared/Components/{WaveShape,GlassCard,SectionGroup,ProgressRingView}.swift | 수정 | 테마 연결 |
| DUNEWatch/Views/WatchWaveBackground.swift, DUNE/project.yml | 수정 | Watch 공유 배경 |
| DUNE/Presentation/Shared/Components/WavePreset.swift 및 기존 배경 | 수정 | 시스템 접근성을 유지하는 미리보기 모션 게이트 |
| DUNE/Presentation/Settings/Components/ThemePickerSection.swift | 수정 | 카드 미리보기 |
| DUNE/Presentation/Settings/SettingsView.swift | 수정 | 테마별 Form 행과 섹션 접근성 분리 |
| DUNE/Presentation/Dashboard/Components/{ConditionHeroView,BaselineTrendBadge,YesterdayRecapCard}.swift | 수정 | Contour 보조 텍스트 대비 |
| DUNE/App/DUNEApp.swift | 수정 | 테스트 데이터 시딩 후 지정 테마 복원 |
| Shared/Resources/Localizable.xcstrings, DUNEWatch/Resources/Localizable.xcstrings | 수정 | 번역 |
| DUNETests/AppThemeTests.swift, DUNEUITests/Visual/ContourThemeTests.swift | 수정/추가 | 저장/자산/선택/UI 검증 |

## Implementation Steps

1. 테마 enum, 팔레트, 배경, 카드, 링, Watch 연결. Verification: 빌드, 자산 존재/색 대비/저장값 테스트.
2. 설정 미리보기와 번역, 접근성 식별자/선택 상태. Verification: 선택/재실행/기존 테마 복귀 UI 테스트.
3. iPhone/iPad light/dark 화면 캡처, 정적 품질 검토. 결과와 제한 기록.

## Edge Cases

| Case | Handling |
|------|----------|
| 알 수 없는 저장값/기존 alias | 기존 resolver 유지 |
| 큰 글자 | 미리보기는 장식, 선택 이름 세로 확장 |
| Reduce Motion/저전력 | Contour는 상시 정적, 미리보기 전체 정적 |
| Watch | 같은 캐시된 등고선, 낮은 밀도 |
| 빈 데이터 | 미리보기 표본임을 명시, 실제 건강 데이터 미사용 |

## Testing Strategy

- AppThemeTests: Codable, rawValue, prefix, 모든 Contour 색상 light/dark 로딩과 텍스트용 accent 대비.
- UI: 선택/지속성/기존 테마 전환, Today light/dark 및 설정 캡처, iPad 동일 흐름.
- scripts/build-ios.sh, 필요한 범위의 xcodebuild test, 정적 diff 검사.

## Risks

- 테마 분기 누락: exhaustive switch와 타겟 빌드로 확인.
- 배경/숫자 경쟁: 불투명 카드로 격리, 실제 화면 시각 확인.
- 시뮬레이터: 설치된 iOS 27 사용, watchOS 런타임 부재 시 빌드까지만 확인.

## References

- [Apple Motion](https://developer.apple.com/design/human-interface-guidelines/motion): 불필요한 모션 절제 및 접근성 설정 존중.

## Confidence Assessment

High: 기존 prefix 구조를 유지하며 새 테마에 변경을 한정한다.

## Execution Results

- iOS + embedded Watch 빌드 통과.
- iPhone 17 / iOS 27: 라이트·다크/설정 캡처, 테마 전환/재실행 지속성 2개 UI 테스트 통과.
- iPad Pro 13-inch (M5) / iOS 27: 라이트·다크/설정 1개 UI 테스트 통과.
- AppThemeTests 9개 통과: 저장 호환성, 자산 존재, 대비 검증 포함.
- 캡처 확인 후 Today 보조 텍스트 대비 보강.
- Watch 실화면, iOS 26 런타임, 최대 Dynamic Type/가로 모드 검증은 미실시.
- 기능 브랜치에 구현/검증 커밋 보존. GitHub PR을 통해 main에 반영한다.
