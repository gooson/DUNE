---
tags: [localization, life, auto-achievement, xcstrings, string-localized]
date: 2026-03-04
category: solution
status: implemented
---

# Life 자동 업적 다국어 누락 수정

## Problem

Life 탭의 `Auto Workout Achievements` 섹션에서 ko/ja 로케일에서도 영어 문구가 그대로 노출됐다.

### Symptoms

- 섹션 헤더/설명/빈 상태 문구가 영어로 표시됨
- 자동 업적 카드 제목(`Workout 5x / week` 등)이 영어 고정
- 진행 텍스트가 `2/5 workouts` 형태로 영어 노출

### Root Cause

- `LifeAutoAchievementService`가 사용자 대면 문자열을 bare `String`으로 하드코딩
- `DUNE/Resources/Localizable.xcstrings`에 관련 키가 빈 객체(`{}`)이거나 누락됨

## Solution

도메인 서비스 문자열을 localization 경로로 전환하고, 누락된 String Catalog 번역을 보강했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Domain/UseCases/LifeAutoAchievementService.swift` | `Rule.title`, `Rule.unit`을 `String(localized:)`로 전환, workouts 진행 텍스트를 localized format 키 사용 | 도메인 `String` 누락 패턴 제거 |
| `DUNE/Resources/Localizable.xcstrings` | 빈 키(3개) 채움 + 업적 제목/단위/포맷 키 추가(ko/ja) | 실제 런타임 번역 데이터 보강 |
| `DUNETests/LifeAutoAchievementServiceTests.swift` | 타이틀/단위/progressText localization assertion 추가(로케일 독립) | 회귀 방지 |

### Key Code

```swift
var title: String {
    switch self {
    case .weeklyWorkout5: String(localized: "Workout 5x / week")
    // ...
    }
}

var progressText: String {
    if unit == String(localized: "workouts") {
        return String(localized: "\(Int(currentValue))/\(Int(targetValue)) workouts")
    }
    // ...
}
```

## Prevention

- `Sendable`/Domain 모델의 사용자 대면 `String`은 항상 `String(localized:)`로 생성
- localization 이슈 수정 시 코드 경로와 `.xcstrings` 키를 항상 동시에 점검
- 포맷 문자열은 `%lld/%lld ...` 키를 카탈로그에 명시적으로 등록해 로케일별 공백/어순 차이를 제어

### Checklist Addition

- [ ] Domain/UseCase에서 새 사용자 대면 문자열 추가 시 `String(localized:)` 적용 여부 확인
- [ ] `.xcstrings`에서 키가 `{}`(빈 객체)로 남아 있지 않은지 확인
- [ ] 숫자+단위 문자열은 format 키 기반으로 번역되는지 확인

## Lessons Learned

- UI의 `Text("...")`만 점검해서는 누락을 놓칠 수 있고, 도메인에서 만들어지는 `String` 경로를 함께 점검해야 한다.
- `workouts`처럼 단순 단위 치환만으로는 로케일별 공백 규칙을 맞추기 어려워 format 키가 더 안전하다.
