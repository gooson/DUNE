# Input Validation

## createValidatedRecord 패턴

사용자 입력을 받는 모든 ViewModel은 다음 패턴을 따름:

```swift
func createValidatedRecord() -> SomeRecord? {
    guard let validated = validateInputs() else { return nil }
    return SomeRecord(...)
}

private func validateInputs() -> ValidatedInput? {
    // 범위 검증, 에러 메시지 설정
}
```

## 필수 검증 항목

- **숫자 입력**: min/max 범위 체크 (예: weight 0-500, bodyFat 0-100)
- **문자열→숫자 변환**: `.trimmingCharacters(in: .whitespaces)` 후 `!trimmed.isEmpty` 먼저 체크. `Int("")`은 nil이므로 optional binding 실패가 "비어있으면 skip" 분기를 우회함
- **문자열 입력**: 길이 제한 (memo: 500자 — `String(input.prefix(500))`)
- **중복 저장 방지**: `isSaving` 플래그로 idempotency 보장. `defer`로 리셋 금지 — 반환값 함수에서는 명시적 리셋
- **에러 표시**: `validationError: String?` 프로퍼티로 UI에 에러 전달
- **정수 곱셈 overflow**: 단위 변환(`mins * 60`) 시 `result / divisor == original` 패턴으로 overflow 검증

## 수학 함수 방어

- `log()` 호출 전: 입력값 > 0 확인 (`.filter { $0.value > 0 }`)
- `sqrt()` 호출 전: 입력값 >= 0 확인
- 나눗셈 전: 분모 != 0 확인
- 계산 결과: `.isNaN`, `.isInfinite` 체크 후 fallback

## HealthKit 값 범위 검증

HealthKit에서 읽은 값도 센서 오류, 수동 입력 오류 가능성이 있으므로 범위 검증 필수:

| 데이터 | 범위 | 근거 |
|--------|------|------|
| Weight | 0-500 kg | 세계 기록 기반 |
| BMI | 0-100 | 의학적 범위 |
| Heart Rate | 20-300 bpm | 생리학적 범위 |
| HRV (SDNN) | 0-500 ms | 센서 범위 |
| Body Fat | 0-100 % | 물리적 범위 |
| Steps | 0-200,000 | 일일 최대 추정 |

**중요**: 동일 데이터의 모든 쿼리 경로에서 동일한 검증 수준을 유지할 것.

## CloudKit 고려사항

잘못된 데이터는 CloudKit을 통해 전 디바이스에 전파되므로 **입력 시점에서 차단**이 필수.
