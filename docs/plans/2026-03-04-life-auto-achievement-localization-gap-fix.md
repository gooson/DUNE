---
topic: life-auto-achievement-localization-gap-fix
date: 2026-03-04
status: implemented
confidence: high
related_solutions:
  - docs/solutions/general/localization-gap-audit.md
  - docs/solutions/general/2026-03-01-localization-leak-pattern-fixes.md
related_brainstorms: []
---

# Implementation Plan: Life 자동 업적 다국어 누락 개선

## Context

`Life` 탭의 Auto Workout Achievements 섹션에서 영어 문구가 그대로 노출된다. 원인은 (1) `LifeAutoAchievementService`의 하드코딩 영어 `String`과 (2) `Localizable.xcstrings` 내 빈 키(`{}`) 상태다.

## Requirements

### Functional

- Auto achievement 섹션 헤더/설명/빈 상태 문구가 ko/ja 로케일에서 번역되어 표시되어야 한다.
- 자동 업적 카드 타이틀(Workout 5x/week 등)과 단위(`workouts`)가 ko/ja 번역을 사용해야 한다.
- 기존 계산 로직(주간 집계, streak, dedup, 거리 계산)은 동작이 변하지 않아야 한다.

### Non-functional

- 기존 localization 규칙(`.claude/rules/localization.md`) 준수.
- 변경 범위를 Life 자동 업적 문자열 누락에 한정.
- JSON 카탈로그 유효성 유지.

## Approach

- `LifeAutoAchievementService.Rule.title` 및 `Rule.unit`을 `String(localized:)` 기반으로 전환한다.
- `DUNE/Resources/Localizable.xcstrings`에서 빈 키를 채우고, 신규 키(업적 타이틀/단위)를 en/ko/ja 구조로 추가한다.
- 회귀 방지를 위해 기존 `LifeAutoAchievementServiceTests`에 문자열 관련 검증을 추가한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 코드만 `String(localized:)`로 변경 | 코드 수정 최소화 | xcstrings 키 누락 시 번역 불가 지속 | Rejected |
| xcstrings만 수정 | 코드 변경 없음 | 하드코딩 `String` 경로는 여전히 locale 미적용 가능 | Rejected |
| 코드 + xcstrings 동시 수정 | 누락 원인 직접 해결, 재발 방지 | 파일 3개 동시 수정 필요 | Selected |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Domain/UseCases/LifeAutoAchievementService.swift` | Modify | 업적 타이틀/단위를 `String(localized:)`로 전환 |
| `DUNE/Resources/Localizable.xcstrings` | Modify | 빈 키 채움 + 신규 키 ko/ja 번역 추가 |
| `DUNETests/LifeAutoAchievementServiceTests.swift` | Modify | 문자열 localization 회귀 검증 추가 |

## Implementation Steps

### Step 1: Service 문자열 경로 정리

- **Files**: `LifeAutoAchievementService.swift`
- **Changes**: `Rule.title`, `Rule.unit`의 영어 하드코딩 제거 → `String(localized:)` 적용
- **Verification**: 기존 테스트가 타이틀/단위 변경으로 실패하지 않는지 확인

### Step 2: String Catalog 누락 보강

- **Files**: `Localizable.xcstrings`
- **Changes**:
  - 기존 빈 키 채움: `Auto Workout Achievements`, `HealthKit-based weekly goals (Mon-Sun)`, `No HealthKit-linked workouts yet`
  - 신규 키 추가: `Workout 5x / week`, `Workout 7x / week`, `Strength 3x / week`, `Chest 3x / week`, `Back 3x / week`, `Lower Body 3x / week`, `Shoulders 3x / week`, `Arms 3x / week`, `Running 15km / week`, `workouts`
- **Verification**: `jq empty DUNE/Resources/Localizable.xcstrings`

### Step 3: 테스트 및 품질 확인

- **Files**: `LifeAutoAchievementServiceTests.swift`
- **Changes**: 업적 타이틀/단위 기본값(개발 언어 en) 검증 추가
- **Verification**: `xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNETests -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing DUNETests/LifeAutoAchievementServiceTests -quiet`

## Edge Cases

| Case | Handling |
|------|----------|
| 문자열 키와 코드 불일치 | 코드 문자열을 키와 1:1로 맞춤, 오타 방지 |
| `%`/포맷 specifier 누락 | 이번 변경은 정적 문구 위주, 포맷 키 추가 없음 |
| 단위 spacing 이슈 | 기존 UI 포맷 유지 (`2/5 workouts`, `0 / 15 km`) |

## Testing Strategy

- Unit tests: `LifeAutoAchievementServiceTests` 실행 + localization label assertion 추가
- Integration tests: 생략 (UI 문자열 경로 변경, 도메인 로직 불변)
- Manual verification: ko locale에서 Life 탭 자동 업적 카드 문구 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| xcstrings 수동 편집 실수 | Medium | High | 최소 범위 패치 + `jq empty` 검증 |
| 번역 톤 불일치 | Low | Medium | 기존 앱 용어(운동/주/회)와 일치시킴 |
| 문자열 정책 충돌(타이틀 영어 고정) | Low | Low | 네비게이션 타이틀(`Life`)은 변경하지 않음 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 영향 범위가 작고 기존 테스트가 존재하며, 누락 원인이 코드+카탈로그 두 군데로 명확하다.
