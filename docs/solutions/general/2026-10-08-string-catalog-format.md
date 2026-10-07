---
tags: [localization, xcstrings, xcode, formatting]
date: 2026-10-08
category: general
status: implemented
---

# String Catalog 포맷을 Xcode 출력과 일치시키기

## Problem

`Localizable.xcstrings`에 새 문자열을 수동 생성할 때 키 순서와 JSON 공백 규칙이 Xcode 출력과 다르면, 빌드 이후 포맷만 바뀐 큰 diff가 생긴다. `3a2af57d`는 Shared 카탈로그를 Xcode 형식으로 정리한 사례다.

## Solution

해당 커밋의 파일은 Foundation `JSONSerialization`의 `.prettyPrinted`, `.sortedKeys`, `.withoutEscapingSlashes` 옵션으로 직렬화한 결과와 바이트 단위로 같다. 마지막 개행도 없다. `scripts/format-xcstrings.swift`는 두 카탈로그를 같은 옵션으로 정리하고 `--check`에서 차이를 오류로 보고한다. 직렬화 전에 중복 JSON 키를 거부해 번역 데이터 손실을 방지한다.

```bash
swift scripts/format-xcstrings.swift
swift scripts/format-xcstrings.swift --check
```

새 키를 추가한 뒤 포맷하고, 빌드 후 `--check`를 다시 실행한다. Pre-commit hook은 staged 카탈로그의 Git index 내용을 검사한다. Xcode의 문자열 추출이 새 키나 `extractionState`를 바꾸는 경우에는 그 의미 변경을 별도로 검토해야 한다.

## Prevention

새 번역을 등록할 때 두 카탈로그에 같은 포맷 도구를 적용하고, 빌드 후 `--check`로 포맷 차이가 없는지 확인한다.
