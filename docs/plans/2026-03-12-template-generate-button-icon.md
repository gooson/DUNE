---
topic: template-generate-button-icon
date: 2026-03-12
status: draft
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-03-03-theme-prefix-resolver-shared-extension.md
  - docs/solutions/architecture/2026-03-07-activity-section-consolidation.md
related_brainstorms: []
---

# Implementation Plan: Template Generate Button Icon

## Context

`TemplateFormView`의 AI 템플릿 생성 버튼이 일부 테마에서 텍스트만 보이고 leading icon이 사라진다. 현재 구현은 `Label("Generate Template", systemImage: "wand.and.stars")`에 기본 `borderedProminent` 스타일을 적용하고 있어, 상위 환경의 tint 및 label rendering 변화에 따라 아이콘 노출이 불안정하다.

## Requirements

### Functional

- `AI Workout Generator` 섹션의 `Generate Template` 버튼 앞에 아이콘이 항상 보인다.
- 현재 동작(`generateTemplateFromPrompt()`, disabled state, accessibility identifier)은 유지한다.
- 모든 앱 테마에서 버튼 tint와 아이콘 대비가 깨지지 않는다.

### Non-functional

- 변경 범위는 템플릿 생성 버튼 UI에 한정한다.
- 기존 테마 토큰과 화면 패턴을 재사용한다.
- localization key와 접근성 식별자는 유지한다.

## Approach

버튼 label을 기본 `Label`에서 명시적인 `HStack + Image + Text` 구성으로 바꾼다. 이 방식은 `LabelStyle`이나 시스템의 label collapsing에 덜 의존하므로 아이콘이 빠지는 회귀를 막기 쉽다. 동시에 `@Environment(\\.appTheme)`를 사용해 버튼 tint를 현재 테마 accent로 명시하고, icon/text 간 spacing과 symbol scale을 고정한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `Label` 유지 + `.labelStyle(.titleAndIcon)` 추가 | diff가 가장 작음 | 상위 환경/시스템 스타일 영향에 여전히 의존 | 기각 |
| 버튼 앞에 별도 장식 아이콘 추가 | 구현 단순 | 접근성/레이아웃이 중복되고 버튼 label 의미가 분산됨 | 기각 |
| `HStack + Image + Text`로 label 명시 | 아이콘/텍스트 렌더링을 직접 제어 가능, 테마 tint와 함께 안정적 | `Label` 대비 코드가 약간 길어짐 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Exercise/Components/CreateTemplateView.swift` | UI update | 테마 환경을 사용하고 템플릿 생성 버튼 label을 명시적 icon+text 구조로 변경 |

## Implementation Steps

### Step 1: Stabilize themed button label

- **Files**: `DUNE/Presentation/Exercise/Components/CreateTemplateView.swift`
- **Changes**:
  - `@Environment(\\.appTheme)` 추가
  - `Generate Template` 버튼 label을 `HStack` 기반으로 변경
  - 버튼 tint를 `theme.accentColor`로 명시
  - icon/text spacing, font, symbol rendering을 고정
- **Verification**: 코드 diff에서 버튼 label과 tint가 현재 theme를 사용하도록 바뀌었는지 확인

### Step 2: Verify no behavior regressions

- **Files**: `DUNE/Presentation/Exercise/Components/CreateTemplateView.swift`
- **Changes**:
  - `disabled`, `accessibilityIdentifier`, async action 유지 확인
  - 기존 안내 문구와 form 구조 비변경 확인
- **Verification**: build 성공, 생성 버튼의 식별자와 액션 wiring 유지 확인

## Edge Cases

| Case | Handling |
|------|----------|
| 밝은 accent를 쓰는 테마에서 foreground 대비가 약한 경우 | `borderedProminent` + theme tint 조합을 유지해 시스템 대비 계산을 활용 |
| 상위 environment에서 `LabelStyle`이 바뀌는 경우 | `Label` 대신 `HStack`을 써 영향 제거 |
| 버튼 disabled 상태 | 기존 `canGenerateTemplate` 조건을 유지해 상태 변화 영향 없음 |

## Testing Strategy

- Unit tests: 없음. SwiftUI button label 렌더링 변경으로 로직 변화가 없다.
- Integration tests: `scripts/build-ios.sh`로 컴파일 검증.
- Manual verification:
  - 템플릿 생성 시트에서 `Generate Template` 버튼 leading icon이 보이는지 확인
  - 최소 red/shanks, sakura, forest, arctic 계열 테마에서 버튼 tint와 icon 대비 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 수동 구성 label이 기존 버튼 typography와 미세하게 달라질 수 있음 | Low | Low | 기존 borderedProminent 스타일과 semibold font만 적용해 차이를 최소화 |
| theme environment 미주입 화면에서 tint가 예상과 다를 수 있음 | Low | Low | 앱 전역에서 `appTheme`를 이미 주입하므로 기존 패턴과 동일 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 문제 범위가 단일 SwiftUI 버튼 label에 국한되어 있고, 테마 토큰과 액션 wiring은 기존 구조를 그대로 재사용하면 된다.
