---
topic: iPad UI 수정, 날짜/시간 편집 기능, UI Test 전문가 스킬 도입
date: 2026-02-16
status: implemented
confidence: high
related_solutions: []
related_brainstorms: []
---

# Implementation Plan: iPad UI 수정 + 날짜 편집 모드 + UI Test 전문가 도입

## Context

현재 앱에 3가지 문제/개선 사항이 있음:

1. **iPad 사이드바 및 버튼 미작동**: iPad의 `NavigationSplitView`에서 각 섹션 뷰가 자체 `NavigationStack`을 가지고 있어 중첩 네비게이션 문제 발생. toolbar 버튼(+)과 sheet가 정상 동작하지 않을 수 있음
2. **날짜/시간 자동 입력 → 편집 모드 필요**: 현재 Exercise, BodyComposition 입력 시 `Date()`로 현재 시간이 고정됨. 과거 기록을 입력하거나 날짜를 수정할 수 있어야 함
3. **UI Test 전문가 스킬 부재**: 체계적인 UI 테스트 인프라와 전문가 에이전트가 없어 iPad/iPhone 양쪽의 UI 동작을 자동 검증할 수 없음

## Requirements

### Functional

- **F1**: iPad에서 사이드바 선택 시 detail 영역의 toolbar 버튼(+), sheet, contextMenu가 정상 동작
- **F2**: iPad에서 EmptyStateView의 action 버튼이 정상 동작
- **F3**: Exercise/BodyComposition 추가 시 DatePicker로 날짜/시간 선택 가능
- **F4**: 기본값은 현재 날짜/시간, 사용자가 변경 가능
- **F5**: BodyComposition 편집 시에도 날짜 수정 가능
- **F6**: UI Test 전문가 스킬(`.claude/skills/ui-testing/`)로 테스트 시나리오 자동 생성
- **F7**: UI Test 전문가 에이전트(`.claude/agents/ui-test-expert.md`)로 리뷰 시 UI 테스트 관점 포함

### Non-functional

- 기존 iPhone 레이아웃에 영향 없음
- CloudKit 동기화 시 날짜 유효성 보장 (미래 날짜 방지)
- UI Test는 시뮬레이터에서 HealthKit 없이 실행 가능해야 함

## Approach

### 1. iPad 네비게이션 수정

**문제 분석**: 현재 `ContentView`의 iPad 레이아웃에서 `NavigationSplitView` > detail에 각 뷰(`DashboardView`, `ExerciseView` 등)가 배치되는데, 이 뷰들 각각이 `NavigationStack`을 가지고 있음. `NavigationSplitView` 자체가 navigation container이므로 중첩 `NavigationStack`이 toolbar/sheet 동작을 방해할 수 있음.

**해결**: iPad에서는 detail 뷰의 `NavigationStack`을 제거하고 `NavigationSplitView`의 네비게이션 컨텍스트를 사용. `ViewModifier`로 플랫폼별 네비게이션 래핑을 처리.

### 2. 날짜/시간 편집 기능

**접근**: ViewModel에 `selectedDate: Date` 프로퍼티 추가, Form 내에 `DatePicker` 추가. 기본값 `Date()`, 미래 날짜 제한(`...Date()`).

### 3. UI Test 전문가 인프라

**접근**:
- `.claude/skills/ui-testing/SKILL.md` 스킬 생성
- `.claude/agents/ui-test-expert.md` 에이전트 생성
- `DailveUITests/` 에 실제 UI 테스트 추가

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| NavigationStack 중첩 유지 + workaround | 변경 최소 | 근본 해결 아님, iOS 버전별 동작 차이 | **X** |
| AdaptiveNavigationModifier로 분기 | 각 뷰가 독립적으로 동작, 한 곳에서 관리 | 새 modifier 추가 필요 | **O** 채택 |
| 날짜를 별도 sheet로 | 입력 흐름 분리 | 과도한 UX 단계 | **X** |
| 날짜를 Form 내 DatePicker로 | 자연스러운 UX, 최소 변경 | 없음 | **O** 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `Dailve/App/ContentView.swift` | **Modify** | iPad detail에서 NavigationStack 제거, navigationTitle 처리 |
| `Dailve/Presentation/Exercise/ExerciseView.swift` | **Modify** | AdaptiveNavigation 적용, AddSheet에 DatePicker 추가 |
| `Dailve/Presentation/BodyComposition/BodyCompositionView.swift` | **Modify** | AdaptiveNavigation 적용, FormSheet에 DatePicker 추가 |
| `Dailve/Presentation/Dashboard/DashboardView.swift` | **Modify** | AdaptiveNavigation 적용 |
| `Dailve/Presentation/Sleep/SleepView.swift` | **Modify** | AdaptiveNavigation 적용 |
| `Dailve/Presentation/Exercise/ExerciseViewModel.swift` | **Modify** | `selectedDate` 프로퍼티 추가, `createValidatedRecord()`에 날짜 전달 |
| `Dailve/Presentation/BodyComposition/BodyCompositionViewModel.swift` | **Modify** | `selectedDate` 프로퍼티 추가, `createValidatedRecord()`/`applyUpdate()`에 날짜 전달 |
| `Dailve/Presentation/Shared/AdaptiveNavigationModifier.swift` | **Create** | sizeClass 기반 NavigationStack 조건부 래핑 |
| `DailveUITests/DailveUITests.swift` | **Modify** | iPad/iPhone 네비게이션 테스트, 입력 폼 테스트 추가 |
| `DailveUITests/ExerciseUITests.swift` | **Create** | Exercise 추가/편집 UI 흐름 테스트 |
| `DailveUITests/BodyCompositionUITests.swift` | **Create** | BodyComposition 추가/편집 UI 흐름 테스트 |
| `DailveUITests/Helpers/UITestHelpers.swift` | **Create** | 공통 UI 테스트 헬퍼 (launch, navigation) |
| `.claude/skills/ui-testing/SKILL.md` | **Create** | UI Test 전문가 스킬 정의 |
| `.claude/agents/ui-test-expert.md` | **Create** | UI Test 전문가 에이전트 정의 |
| `DailveTests/ExerciseViewModelTests.swift` | **Modify** | selectedDate 관련 유닛 테스트 추가 |
| `DailveTests/BodyCompositionViewModelTests.swift` | **Modify** | selectedDate 관련 유닛 테스트 추가 |

## Implementation Steps

### Step 1: AdaptiveNavigation ViewModifier 생성

- **Files**: `Dailve/Presentation/Shared/AdaptiveNavigationModifier.swift`
- **Changes**:
  ```swift
  struct AdaptiveNavigation: ViewModifier {
      @Environment(\.horizontalSizeClass) private var sizeClass
      let title: String

      func body(content: Content) -> some View {
          if sizeClass == .regular {
              // iPad: NavigationSplitView가 이미 navigation container
              content.navigationTitle(title)
          } else {
              // iPhone: NavigationStack 필요
              NavigationStack { content.navigationTitle(title) }
          }
      }
  }
  ```
- **Verification**: Preview에서 iPhone/iPad 모두 정상 렌더링 확인

### Step 2: 각 섹션 뷰에 AdaptiveNavigation 적용

- **Files**: `DashboardView.swift`, `ExerciseView.swift`, `SleepView.swift`, `BodyCompositionView.swift`
- **Changes**:
  - 기존 `NavigationStack { ... .navigationTitle("X") }` → `.adaptiveNavigation(title: "X")`
  - toolbar, sheet, task 등은 그대로 유지
- **Verification**: iPad 시뮬레이터에서 사이드바 선택 → detail 영역에 title + toolbar 버튼 표시 확인

### Step 3: iPad ContentView detail 영역 정리

- **Files**: `Dailve/App/ContentView.swift`
- **Changes**: iPad detail 내 각 뷰가 이제 NavigationStack을 자체 관리하므로 변경 없음 (Step 2에서 처리)
- **Verification**: iPad에서 사이드바 → Exercise → + 버튼 → sheet 정상 표시

### Step 4: ExerciseViewModel에 날짜 선택 기능 추가

- **Files**: `ExerciseViewModel.swift`
- **Changes**:
  - `var selectedDate: Date = Date()` 프로퍼티 추가
  - `createValidatedRecord()`에서 `Date()` → `selectedDate` 사용
  - `resetForm()`에서 `selectedDate = Date()` 초기화
  - 날짜 검증: `selectedDate <= Date()` (미래 날짜 방지)
- **Verification**: 유닛 테스트 - 미래 날짜 거부, 과거 날짜 허용

### Step 5: BodyCompositionViewModel에 날짜 선택 기능 추가

- **Files**: `BodyCompositionViewModel.swift`
- **Changes**:
  - `var selectedDate: Date = Date()` 프로퍼티 추가
  - `createValidatedRecord()`에서 `Date()` → `selectedDate` 사용
  - `applyUpdate(to:)`에서 `record.date = selectedDate` 추가
  - `startEditing()`에서 `selectedDate = record.date` 설정
  - `resetForm()`에서 `selectedDate = Date()` 초기화
- **Verification**: 유닛 테스트 - 미래 날짜 거부, 편집 시 날짜 복원

### Step 6: AddExerciseSheet에 DatePicker 추가

- **Files**: `ExerciseView.swift` (AddExerciseSheet)
- **Changes**:
  - Form 내 첫 번째 Section에 `DatePicker("Date & Time", selection: $viewModel.selectedDate, in: ...Date())` 추가
  - `.datePickerStyle(.compact)` 사용
- **Verification**: 시뮬레이터에서 DatePicker 동작 확인

### Step 7: BodyCompositionFormSheet에 DatePicker 추가

- **Files**: `BodyCompositionView.swift` (BodyCompositionFormSheet)
- **Changes**:
  - Form 상단에 `DatePicker("Date & Time", selection: $viewModel.selectedDate, in: ...Date())` 추가
- **Verification**: 추가/편집 모두에서 DatePicker 동작 확인

### Step 8: UI Test 전문가 스킬 생성

- **Files**: `.claude/skills/ui-testing/SKILL.md`
- **Changes**:
  - UI Test 작성 패턴, 접근성 식별자 규칙, iPad/iPhone 분기 테스트 가이드
  - Page Object 패턴 정의
  - 테스트 시나리오 생성 템플릿
- **Verification**: 스킬 문서 완성도 확인

### Step 9: UI Test 전문가 에이전트 생성

- **Files**: `.claude/agents/ui-test-expert.md`
- **Changes**:
  - 에이전트 역할: UI 동작 검증, 접근성 감사, iPad/iPhone 호환성 테스트
  - /review 시 UI Test 관점 추가
  - 기존 리뷰 에이전트 목록과 연동 방법
- **Verification**: 에이전트 정의 완성도 확인

### Step 10: UI 테스트 인프라 및 헬퍼 구축

- **Files**: `DailveUITests/Helpers/UITestHelpers.swift`
- **Changes**:
  - `XCUIApplication` 확장: launch helper, wait helper
  - 접근성 식별자 상수 (`.accessibilityIdentifier` 매칭)
  - iPad/iPhone 판별 유틸리티
- **Verification**: 빌드 성공 확인

### Step 11: 뷰에 접근성 식별자 추가

- **Files**: `ExerciseView.swift`, `BodyCompositionView.swift`, `DashboardView.swift`, `SleepView.swift`, `ContentView.swift`
- **Changes**:
  - toolbar 버튼에 `.accessibilityIdentifier("exercise-add-button")` 등 추가
  - Form 필드, 저장/취소 버튼에 식별자 추가
  - iPad 사이드바 항목에 식별자 추가
- **Verification**: UI 테스트에서 요소 찾기 성공

### Step 12: 핵심 UI 테스트 작성

- **Files**: `DailveUITests/DailveUITests.swift`, `ExerciseUITests.swift`, `BodyCompositionUITests.swift`
- **Changes**:
  - **Navigation 테스트**: iPad 사이드바 탭 → detail 전환
  - **Exercise 입력 테스트**: + 버튼 → sheet → 필드 입력 → DatePicker → 저장
  - **BodyComposition 입력 테스트**: + 버튼 → sheet → 필드 입력 → DatePicker → 저장
  - **버튼 상태 테스트**: 빈 폼에서 Save disabled, 입력 후 enabled
- **Verification**: `xcodebuild test` 실행

### Step 13: ViewModel 유닛 테스트 보강

- **Files**: `DailveTests/ExerciseViewModelTests.swift`, `DailveTests/BodyCompositionViewModelTests.swift`
- **Changes**:
  - 날짜 선택 관련 테스트 추가 (기본값, 미래 날짜 거부, 과거 날짜 허용)
  - 폼 리셋 시 날짜 초기화 테스트
- **Verification**: `xcodebuild test -only-testing DailveTests`

## Edge Cases

| Case | Handling |
|------|----------|
| 미래 날짜 선택 시도 | DatePicker `in: ...Date()` 범위 제한 + ViewModel에서 이중 검증 |
| 매우 오래된 날짜 입력 | 합리적 하한 설정 (예: 2020-01-01) |
| iPad에서 sheet 위에 사이드바 전환 | sheet dismiss 후 전환되도록 자연스럽게 처리 (SwiftUI 기본 동작) |
| 편집 시 날짜만 변경 | `applyUpdate`에서 날짜도 업데이트 |
| DatePicker가 키보드와 겹치는 경우 | Form 내 배치로 자동 스크롤 처리 |
| iPad Split View에서 toolbar 겹침 | AdaptiveNavigation이 중첩 NavigationStack 방지 |

## Testing Strategy

- **Unit tests**: ViewModel의 selectedDate 검증, 미래 날짜 거부, 폼 리셋
- **UI tests (iPhone)**: 탭 네비게이션, + 버튼, sheet 표시, DatePicker 조작, 저장 흐름
- **UI tests (iPad)**: 사이드바 선택, detail toolbar, sheet 표시, DatePicker 조작
- **Manual verification**: 실제 디바이스에서 iPad multitasking 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| AdaptiveNavigation이 일부 뷰에서 예상과 다르게 동작 | 낮음 | 중간 | sizeClass 기반 분기 테스트, Preview 확인 |
| NavigationSplitView + sheet 조합 iOS 26 동작 차이 | 낮음 | 중간 | iPad 시뮬레이터에서 집중 테스트 |
| DatePicker 접근성 식별자가 XCTest에서 불안정 | 중간 | 낮음 | date picker는 existence 테스트만, 값 검증은 ViewModel 유닛 테스트 |
| project.yml에 새 파일 추가 필요 | 낮음 | 낮음 | XcodeGen으로 자동 처리 (glob 기반) |

## Confidence Assessment

- **Overall**: High
- **Reasoning**:
  - iPad NavigationSplitView 중첩 문제는 잘 알려진 패턴이고 해결 방법이 명확
  - DatePicker 추가는 기존 Form 구조에 자연스럽게 통합 가능
  - UI Test 인프라는 XCTest 기반으로 이미 scaffold가 있음
  - 기존 코드 구조가 깔끔해서 변경 범위가 명확
