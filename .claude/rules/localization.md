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

## Localization Leak Detection

코드 변경 시 아래 패턴을 **반드시** 점검하여 미번역 문자열이 누출되지 않도록 한다.

### Leak Pattern 1: Helper 함수 `String` 파라미터

View helper 함수가 `String`을 받아 `Text(string)`에 전달하면 `Text.init(_ content: some StringProtocol)` → 자동 번역 미적용.

```swift
// LEAK: Text(title)가 localize하지 않음
private func sectionHeader(title: String) -> some View {
    Text(title)
}

// FIX: LocalizedStringKey 사용
private func sectionHeader(title: LocalizedStringKey) -> some View {
    Text(title)
}
```

### Leak Pattern 2: Sendable struct의 String 프로퍼티

`Sendable` struct는 `LocalizedStringKey` 저장 불가 (Swift 6 non-Sendable). `String(localized:)` 필수.

```swift
// LEAK: 영어 하드코딩
struct MyStat: Sendable {
    let title: String  // "Volume" — 번역 안됨
}

// FIX: String(localized:) 팩토리
static func volume() -> MyStat {
    MyStat(title: String(localized: "Volume"))
}
```

### Leak Pattern 3: ViewModel/Model String 할당

ViewModel에서 `String` 프로퍼티에 사용자 대면 텍스트를 할당할 때 `String(localized:)` 누락.

```swift
// LEAK
errorMessage = "Unable to load data."

// FIX
errorMessage = String(localized: "Unable to load data.")
```

### Leak Pattern 4: Enum rawValue UI 직접 사용

enum rawValue를 `Text()` 또는 Picker에 직접 렌더링하면 번역 불가.

```swift
// LEAK: rawValue가 그대로 표시됨
Text(period.rawValue)
Picker { Text(period.rawValue).tag(period) }

// FIX: displayName computed property 경유
Text(period.displayName)
```

### Leak Pattern 5: 상수 레이블 body 내 반복 생성

`String(localized:)` 상수를 body에서 매번 생성하면 불필요한 per-render allocation.

```swift
// SUBOPTIMAL: body마다 5회 호출
scoreLabel: String(localized: "READINESS"),

// FIX: private enum으로 호이스트
private enum Labels {
    static let scoreLabel = String(localized: "READINESS")
}
```

### 번역 면제 대상

다음은 번역하지 않아도 되는 문자열:
- **네비게이션 타이틀** (각 탭/화면의 `.navigationTitle`)
- **운동 이름** (Bench Press, Squat 등 — 국제 표준 영어)
- **로그/디버그 메시지** (AppLogger, print 등)
- **SF Symbol 이름** (systemName 파라미터)
- **ID/Key 문자열** (identifier, UserDefaults key 등)
- **단위 기호** (kg, bpm, ms 등 — 숫자 포매터가 locale 처리)

## 금지 패턴

- `localizedDisplayName`, `bilingualDisplayName` 별도 프로퍼티 금지 → `displayName`이 locale 처리
- `String(format:)` 사용 금지 → `String(localized:)` + interpolation
- `.strings` / `.stringsdict` 파일 생성 금지 → `.xcstrings` 단일 소스
- 코드 내 번역 분기 (`if locale == "ko"`) 금지 → xcstrings가 자동 처리
- 운동 이름(Bench Press 등)은 번역하지 않음 → 국제 표준 영어 유지
- enum rawValue를 `Text()`에 직접 전달 금지 → `displayName` computed property 경유
- xcstrings 키에 smart quote(U+2019 등) 사용 금지 → 코드와 동일한 ASCII 문자 사용

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

## 검증 명령

```bash
# 번역 커버리지 확인 (미번역 항목은 XLIFF에 untranslated로 표시)
xcodebuild -exportLocalizations -project DUNE/DUNE.xcodeproj \
  -localizationPath /tmp/loc-export -exportLanguage ko -exportLanguage ja
```

## 테이블 정책

단일 `Localizable` 테이블을 유지한다. 필요 시 타겟별로 분리하되 `table:` 파라미터를 명시한다.
기본값(`Localizable`)에서 벗어나는 경우 이 문서에 반드시 기록한다.

약어(HIIT 등)도 `String(localized:)` 래핑 필수 — 모든 locale에서 동일해도 xcstrings 등록으로 번역자 검토 기회를 보장한다.

## 리뷰 체크포인트

### 필수 (P1 — 누락 시 번역 불가)

- [ ] 새 UI 문자열 추가 시 xcstrings에 3개 언어(en/ko/ja) 모두 포함되었는가
- [ ] `String` 프로퍼티에 사용자 대면 텍스트 할당 시 `String(localized:)`가 사용되었는가
- [ ] 새 enum displayName이 `String(localized:)` 패턴을 따르는가
- [ ] View helper 함수가 `Text()`에 전달할 레이블을 `String`이 아닌 `LocalizedStringKey`로 받는가
- [ ] enum rawValue를 UI에 직접 표시하지 않고 `displayName` computed property를 경유하는가
- [ ] `Sendable` struct의 사용자 대면 `String` 필드가 `String(localized:)` 팩토리로 생성되는가

### 권장 (P2 — 품질/성능)

- [ ] 상수 레이블이 body에서 매번 `String(localized:)`로 생성되지 않고 static let으로 호이스트되었는가
- [ ] watchOS 공유 문자열이 Watch xcstrings에도 반영되었는가
- [ ] Dynamic Type에서 긴 번역이 레이아웃을 깨뜨리지 않는가
- [ ] 보간 문자열의 xcstrings 키 형식(%@, %lld 등)이 정확한가

### Orphan 방지 (P1 — Xcode 경고 발생)

- [ ] 코드에서 문자열 삭제/변경 시 xcstrings에서 해당 키도 동시 삭제/변경
- [ ] xcstrings 키 문자열과 코드 문자열이 정확히 일치 (smart quote, en-dash 등 유니코드 주의)
- [ ] Watch 전용 문자열은 Watch xcstrings에만 등록 (iOS xcstrings에 중복 등록 금지)
- [ ] 새 `Text()` 또는 `String(localized:)` 추가 시 xcstrings에 en/ko/ja 3개 언어 동시 등록
