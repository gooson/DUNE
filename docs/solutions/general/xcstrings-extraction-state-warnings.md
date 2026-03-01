---
tags: [localization, xcstrings, xcode, warnings, extractionState]
date: 2026-03-01
category: solution
status: implemented
---

# xcstrings Yellow Warning (extractionState Missing)

## Problem

Xcode String Catalog 에디터에서 모든 항목에 노란색 경고 삼각형이 표시된다.
번역이 모두 완료되었고 state도 "translated"인데 경고가 사라지지 않는다.

## Root Cause

xcstrings 항목에 `extractionState` 필드가 없으면 Xcode가 소스 코드 추출 과정에서
해당 키를 확인할 수 없어 경고를 표시한다. 특히 수동으로 추가된 항목(스크립트 등으로 일괄 추가)에서 발생한다.

## Solution

모든 수동 추가 항목에 `"extractionState": "manual"` 설정:

```python
import json

with open('DUNE/Resources/Localizable.xcstrings', 'r') as f:
    data = json.load(f)

for key, val in data['strings'].items():
    if 'extractionState' not in val:
        val['extractionState'] = 'manual'

with open('DUNE/Resources/Localizable.xcstrings', 'w') as f:
    json.dump(data, f, ensure_ascii=False, indent=2)
```

## Additional Patterns

### 번역하지 않을 키 (탭 타이틀, 국제 단위)

```json
{
  "extractionState": "manual",
  "shouldTranslate": false,
  "localizations": {}
}
```

사용처: 탭 타이틀 (Today, Activity, Wellness, Life), 국제 단위 약어 (min, kcal)

### String(localized:) + interpolation 키 매칭

`String(localized: "All \(total) muscle groups ready")` → xcstrings 키는 `"All %lld muscle groups ready"`
Swift 컴파일러가 interpolation을 format specifier로 변환한 형태가 키가 된다.

## Prevention

- xcstrings에 항목 추가 시 항상 `extractionState: "manual"` 포함
- 국제 단위 약어(min, kcal, kg 등)는 `shouldTranslate: false` 설정
- interpolated String(localized:)의 xcstrings 키는 `%lld`, `%@` 형태로 등록
