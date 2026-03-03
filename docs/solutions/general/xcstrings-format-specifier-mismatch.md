---
tags: [localization, xcstrings, swiftui, format-specifier]
date: 2026-03-03
category: solution
status: implemented
---

# xcstrings Format Specifier Mismatch 진단 가이드

## Problem

SwiftUI `Text()` interpolation에서 `Int` 값을 사용하면 xcstrings 키가 `%lld`로 생성되지만, xcstrings에 `%@`(String용)로 등록하면 키 불일치가 발생하여 번역이 적용되지 않는다.

## Root Cause

Swift String interpolation → xcstrings 키 변환 규칙:

| Swift 타입 | Format Specifier | 예시 |
|-----------|-----------------|------|
| `Int` | `%lld` | `Text("Feels \(Int(value))°")` → `"Feels %lld°"` |
| `Double` | `%lf` | `Text("Score: \(score)")` → `"Score: %lf"` |
| `String` | `%@` | `Text("Hello \(name)")` → `"Hello %@"` |

## Solution

xcstrings 키의 format specifier를 코드의 실제 타입과 일치시킨다.

```
// Code:  Text("Feels \(Int(snapshot.feelsLike))°")
// Key:   "Feels %lld°"  ← 올바름
// Key:   "Feels %@°"    ← 불일치 → 번역 무시됨
```

## Prevention

1. 새 interpolated string 추가 시 타입에 맞는 format specifier 확인
2. `Int` → `%lld`, `String` → `%@`, `Double` → `%lf`
3. 번역이 적용되지 않는 증상이 있으면 xcstrings 키의 specifier를 먼저 점검
