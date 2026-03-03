---
topic: life-tab-full-localization-recheck
date: 2026-03-04
status: implemented
confidence: high
related_solutions:
  - docs/solutions/architecture/full-localization-xcstrings.md
  - docs/solutions/general/2026-03-04-life-auto-achievement-localization-gap-fix.md
related_brainstorms: []
---

# Implementation Plan: 라이프탭 전 화면 다국어 재점검 (운동명 포함)

## Context

라이프탭(`LifeView`, `HabitFormSheet`, `HabitRowView`, `HabitHistorySheet`)에서 일부 문자열은 ko/ja 번역 키가 누락되어 영어로 노출된다. 특히 자동 업적 카드의 운동명/그룹명은 런타임 `String` 경로로 하드코딩되어 다국어 적용이 불완전하다.

## Requirements

### Functional

- 라이프탭 전 화면에서 사용자 대면 문자열이 ko/ja 로케일에서 번역되어야 한다.
- 자동 업적 카드 내 운동명(예: Arms, Lower Body, Workout 5x/7x)과 그룹명이 번역되어야 한다.
- 기존 비즈니스 로직(습관 계산/업적 계산/리마인더 스케줄)은 변경 없이 유지되어야 한다.

### Non-functional

- 탭/네비게이션 타이틀 영어 고정 규칙(#190) 유지.
- 변경 범위를 라이프탭 문자열/카탈로그 보강에 한정.
- `Localizable.xcstrings` JSON 유효성 유지.

## Approach

- `LifeView`의 런타임 하드코딩 문자열을 `String(localized:)` 기반으로 전환한다.
- `DUNE/Resources/Localizable.xcstrings`에 라이프탭 누락 키를 추가하고, 기존 누락 번역(null)을 ko/ja로 채운다.
- 로직 변경이 없으므로 기존 테스트 스위트 회귀 실행으로 안정성을 확인한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `xcstrings`만 보강 | 코드 수정 최소화 | 런타임 `String` 경로는 계속 영어 고정 가능 | Rejected |
| 코드에서 `Text("...")`만 유지 | 구현 단순 | 키 누락 감지/보강이 어려움 | Rejected |
| 코드 + 카탈로그 동시 정리 | 화면 누락과 런타임 누락을 함께 해결 | 파일 2개 이상 수정 필요 | Selected |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Life/LifeView.swift` | Modify | 자동 업적 그룹명/운동명 런타임 문자열을 localization 경로로 전환 |
| `DUNE/Resources/Localizable.xcstrings` | Modify | 라이프탭 누락 키 추가 + ko/ja null 번역 채움 |
| `docs/solutions/general/` | Add | 이번 점검 결과를 재사용 가능한 해결 문서로 기록 |

## Implementation Steps

### Step 1: 라이프탭 코드 문자열 경로 보강

- **Files**: `LifeView.swift`
- **Changes**:
  - `shortMetricTitle` 반환값을 `String(localized:)`로 전환
  - 업적 그룹명(`Routine Consistency`, `Strength Split`, `Running Distance`)을 localized 문자열로 생성
- **Verification**: 빌드 경고/오류 없이 컴파일

### Step 2: String Catalog 누락 보강

- **Files**: `DUNE/Resources/Localizable.xcstrings`
- **Changes**:
  - 기존 누락 번역 키 채움: `My Habits`, `Recurring`, `Due`, `Next due %@`, `Best streak %@w`, 예시 문구
  - 신규 키 추가: 라이프탭 전 화면(히스토리/사이클 상태/리마인더 문구/업적 단축명/그룹명)
- **Verification**: `jq empty DUNE/Resources/Localizable.xcstrings`

### Step 3: 품질 확인

- **Files**: none
- **Changes**: 회귀 테스트 실행
- **Verification**:
  - `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNETests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing DUNETests/LifeViewModelTests -only-testing DUNETests/LifeAutoAchievementServiceTests -quiet`

## Edge Cases

| Case | Handling |
|------|----------|
| 문자열 보간 key 포맷 차이(`%@` vs `%lld`) | 코드에서 사용하는 실제 포맷 키를 기준으로 카탈로그 키를 맞춤 |
| 사용자 입력 habitName은 번역 대상 아님 | 템플릿 문장만 번역하고 habitName은 그대로 삽입 |
| 탭/타이틀 영어 고정 정책 충돌 | `englishNavigationTitle` 경로는 유지 |

## Testing Strategy

- Unit tests: Life 관련 기존 테스트(업적/뷰모델) 회귀 실행
- Static validation: `jq empty`로 카탈로그 JSON 검증
- Manual verification: ko/ja 로케일에서 Life 탭 진입 후 폼/리스트/히스토리/자동업적 텍스트 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| xcstrings 수동 편집 오타 | Medium | High | 최소 범위 편집 + `jq empty` 검증 |
| 보간 포맷 키 불일치 | Medium | Medium | 코드 문자열과 동일한 키 패턴으로 등록 |
| 번역 톤 불일치 | Low | Low | 기존 Life 용어(습관/주간/완료) 톤 재사용 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 범위가 명확하고 재현된 누락 키가 확인되었으며, 수정 대상이 UI 문자열 경로로 한정되어 있다.
