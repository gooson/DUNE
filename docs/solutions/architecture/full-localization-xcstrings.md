---
tags: [localization, xcstrings, string-catalogs, i18n, korean, japanese]
date: 2026-03-01
category: solution
status: implemented
---

# Full App Localization with Xcode String Catalogs

## Problem

앱 전체에 하드코딩된 한국어 UI 텍스트와 영어 텍스트가 혼재. 다국어 지원(EN/KO/JA)을 위한 체계적인 localization 인프라 부재.

## Solution

### 전략: English-text-as-key + String Catalogs (.xcstrings)

1. **영어 텍스트를 key로 사용** — 별도 key 관리 불필요, 코드 가독성 유지
2. **Xcode String Catalogs** — JSON 기반 .xcstrings 파일로 모든 번역을 단일 소스에서 관리
3. **SwiftUI 자동 localization 활용** — `Text("literal")`은 자동으로 LocalizedStringKey 처리
4. **String(localized:) for programmatic strings** — enum displayName, validation errors 등

### 구현 패턴

#### 1. SwiftUI View (자동 처리, 코드 변경 불필요)
```swift
Text("Start")  // SwiftUI가 자동으로 xcstrings 조회
Button("Cancel") { ... }  // 동일
```

#### 2. Enum displayName (String(localized:) 필수)
```swift
var displayName: String {
    switch self {
    case .strength: String(localized: "Strength")
    case .hiit: String(localized: "HIIT")  // 약어도 래핑 필수
    }
}
```

#### 3. Validation errors (String(localized:) 필수)
```swift
validationError = String(localized: "Weight must be between 0 and 500")
```

#### 4. String interpolation
```swift
// Swift interpolation → xcstrings에서 %lld/%@ 자동 변환
title: String(localized: "\(count) exercises focusing on \(muscles)")
// xcstrings key: "%lld exercises focusing on %@"
```

#### 5. 하위 문자열 번역 (pre-resolve 패턴)
```swift
// BAD: milestoneText가 번역되지 않음
let milestoneText = "1 Week"
String(localized: "\(milestoneText) workout streak!")

// GOOD: 하위 문자열도 개별 번역
let milestoneText = String(localized: "1 Week")
String(localized: "\(milestoneText) workout streak!")
```

### 파일 구조

```
DUNE/Resources/Localizable.xcstrings      # iOS (505+ entries)
DUNEWatch/Resources/Localizable.xcstrings  # watchOS (38 entries)
.claude/rules/localization.md              # 개발 규칙
```

### 변환 범위

| 영역 | 파일 수 | 문자열 수 |
|------|---------|----------|
| Enum displayName extensions | 15 | ~200 |
| Korean UI text → English keys | 22 | 118 |
| CoachingEngine messages | 1 | 65+ |
| Validation errors | 10 | 38 |
| watchOS UI | 1 | 38 |

## Prevention

- `.claude/rules/localization.md` 규칙 파일이 모든 세션에 자동 로드
- 새 문자열 추가 시 반드시 xcstrings에 3개 언어 번역 포함
- 리뷰 체크포인트: `String` 프로퍼티에 사용자 대면 텍스트 시 `String(localized:)` 확인
- 약어도 `String(localized:)` 래핑 필수 (번역자 검토 기회 보장)

## Key Learnings

1. `String(localized:)`는 Foundation API — Domain 레이어에서 사용 가능 (레이어 경계 위반 아님)
2. Swift interpolation은 xcstrings에서 자동으로 `%lld`/`%@` format specifier로 변환
3. 하위 문자열이 번역 대상이면 반드시 개별 `String(localized:)` 래핑 후 상위 문자열에 interpolation
4. 데이터 레벨 필터 키워드 (예: 운동 검색 필터)는 localization 대상이 아님
5. 대규모 변환 시 Presentation → Domain → Watch 순서로 레이어별 진행이 효과적
