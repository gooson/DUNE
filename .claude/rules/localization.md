# Localization Rules

## String Catalog (.xcstrings)

프로젝트는 Xcode String Catalogs를 사용한다.

| 타겟 | 파일 위치 |
|------|----------|
| iOS (DUNE) | `DUNE/Resources/Localizable.xcstrings` |
| watchOS (DUNEWatch) | `DUNEWatch/Resources/Localizable.xcstrings` |

## 지원 언어

| 코드 | 언어 | 역할 |
|------|------|------|
| en | English | Development Language (base) |
| ko | Korean | 번역 |
| ja | Japanese | 번역 |

## 키 전략: 영어 텍스트 = 키

영어 텍스트 자체를 키로 사용한다. 별도의 구조화된 키를 만들지 않는다.

```swift
// GOOD: 영어 텍스트가 곧 키
Text("Done")           // xcstrings에서 "Done" → ko:"완료", ja:"完了"
Text("Rest Time")      // xcstrings에서 "Rest Time" → ko:"휴식 시간", ja:"休憩時間"

// BAD: 구조화된 키 사용 금지
Text("common.button.done")
Text("exercise.restTime")
```

## SwiftUI 문자열 패턴

### Text, Label, Button (자동 LocalizedStringKey)

```swift
// SwiftUI가 자동으로 LocalizedStringKey 처리 → 코드 변경 불필요
Text("Done")
Label("Rest Time", systemImage: "timer")
Button("Cancel") { dismiss() }
.navigationTitle("Today")
```

SwiftUI의 Text, Label, Button, Section, navigationTitle 등은 문자열을 자동으로 `LocalizedStringKey`로 처리한다. `.xcstrings` 파일에 해당 키와 번역이 있으면 자동 적용.

### Programmatic String (non-SwiftUI 컨텍스트)

```swift
// GOOD: String(localized:) 사용
let message = String(localized: "Could not load workout data")
viewModel.validationError = String(localized: "Future dates are not allowed")

// BAD: 하드코딩 String
let message = "Could not load workout data"
```

`String` 타입 프로퍼티에 할당하는 사용자 대면 문자열은 반드시 `String(localized:)`로 감싼다.

### Interpolation

```swift
// GOOD: String(localized:) + 보간
validationError = String(localized: "Weight must be between 0 and \(maxWeight) kg")
// xcstrings 키: "Weight must be between 0 and %lld kg"
// ko: "체중은 0~%lldkg 사이여야 합니다"
// ja: "体重は0〜%lldkgの範囲で入力してください"
```

번역에서 인자 순서를 변경해야 하면 positional specifier 사용: `%1$lld`, `%2$@` 등.

### Enum displayName

```swift
// GOOD: switch + String(localized:)
var displayName: String {
    switch self {
    case .chest: String(localized: "Chest")
    case .back: String(localized: "Back")
    }
}

// BAD: localizedDisplayName 별도 프로퍼티
var localizedDisplayName: String {
    switch self {
    case .chest: "가슴"
    }
}
```

`displayName` 하나로 통합. locale에 따라 자동 반환.

## 금지 패턴

- `localizedDisplayName`, `bilingualDisplayName` 별도 프로퍼티 금지 → `displayName`이 locale 처리
- `String(format:)` 사용 금지 → `String(localized:)` + interpolation
- `.strings` / `.stringsdict` 파일 생성 금지 → `.xcstrings` 단일 소스
- 코드 내 번역 분기 (`if locale == "ko"`) 금지 → xcstrings가 자동 처리
- 운동 이름(Bench Press 등)은 번역하지 않음 → 국제 표준 영어 유지

## 새 문자열 추가 프로세스

1. 코드에 영어 텍스트로 `Text("English text")` 또는 `String(localized: "English text")` 작성
2. `Localizable.xcstrings`에 해당 키의 ko/ja 번역 추가
3. watchOS에도 해당되면 Watch xcstrings에도 추가

## 번역 품질 규칙

- 운동 용어는 해당 언어권 피트니스 커뮤니티 표준 용어 사용
- UI 버튼/레이블은 간결하게 (일본어는 특히 길어지므로 주의)
- 존칭: 한국어 해요체, 일본어 です/ます体
- 단위: locale에 따른 자동 변환은 `.formatted()` 위임 (xcstrings 범위 아님)

## Pluralization

```swift
// xcstrings에서 plural rule 사용 (필요시)
// en: "%lld days" (plural variations 지원)
// ko: "%lld일" (단수=복수 동일)
// ja: "%lld日" (단수=복수 동일)
```

## 리뷰 체크포인트

- 새 UI 문자열 추가 시 xcstrings에 3개 언어 모두 포함되었는가
- `String` 프로퍼티에 사용자 대면 텍스트 할당 시 `String(localized:)`가 사용되었는가
- 새 enum displayName이 `String(localized:)` 패턴을 따르는가
- watchOS 공유 문자열이 Watch xcstrings에도 반영되었는가
- Dynamic Type에서 긴 번역이 레이아웃을 깨뜨리지 않는가
