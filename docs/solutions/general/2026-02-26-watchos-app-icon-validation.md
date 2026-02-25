---
tags: [watchos, app-icon, cfbundleiconname, info-plist, xcodegen, validation, asset-catalog, idiom, contents-json]
category: general
date: 2026-02-26
severity: important
related_files:
  - DUNE/project.yml
  - DUNEWatch/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json
  - scripts/build-ios.sh
related_solutions:
  - general/2026-02-26-app-icon-launch-screen
---

# Solution: watchOS App Icon Validation 실패 수정

## Problem

### Symptoms

Xcode Archive → Distribute 시 두 가지 validation 에러:

1. `Missing Icons. No icons found for watch application 'DUNE.app/Watch/DUNEWatch.app'`
2. `Missing Info.plist value. A value for the Info.plist key 'CFBundleIconName' is missing`

Clean Build Folder 후 재시도해도 동일한 에러 반복.

### Root Cause

**두 가지 원인이 동시에 존재:**

1. **Contents.json 레거시 포맷 (핵심 원인)**: `"idiom": "watch"` + `"scale": "2x"` 조합은 레거시 watchOS 아이콘 포맷. 이 포맷은 38mm/40mm/44mm 등 **여러 사이즈의 아이콘을 요구**하므로, 1024x1024 하나만 있으면 "Missing Icons" 발생. 현대 watchOS(10+)는 `"idiom": "universal"` + scale 없음 포맷으로 단일 1024x1024 아이콘 사용.

2. **CFBundleIconName Info.plist 키 누락 (부차 원인)**: `GENERATE_INFOPLIST_FILE: true` 사용 시 `ASSETCATALOG_COMPILER_APPICON_NAME` 빌드 설정만으로는 `CFBundleIconName` Info.plist 키가 자동 생성되지 않음. `INFOPLIST_KEY_CFBundleIconName`을 명시해야 함.

**오진 과정**: 처음에 Info.plist 키 누락만 수정했으나, Contents.json 포맷이 근본 원인이었기 때문에 클린 빌드 후에도 동일 에러 반복.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNEWatch/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json` | `"idiom": "watch"` → `"universal"`, `"scale": "2x"` 제거 | 레거시 다중 사이즈 요구 → 현대 단일 아이콘 포맷 |
| `DUNE/project.yml` | `INFOPLIST_KEY_CFBundleIconName: AppIcon` 추가 | watchOS validation이 요구하는 Info.plist 키 |
| `scripts/build-ios.sh` | xcodegen 후 objectVersion/compatibilityVersion sed 후처리 추가 | Correction #121 스크립트 반영 |

### Key Code

**Contents.json (수정 후)**:
```json
{
  "images" : [
    {
      "filename" : "AppIcon.png",
      "idiom" : "universal",
      "platform" : "watchOS",
      "size" : "1024x1024"
    }
  ]
}
```

**project.yml (DUNEWatch 설정 추가)**:
```yaml
ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon    # asset catalog 컴파일러
INFOPLIST_KEY_CFBundleIconName: AppIcon          # Info.plist 키 생성
```

## Prevention

### Checklist Addition

- [ ] watchOS AppIcon.appiconset의 Contents.json은 `"idiom": "universal"` + scale 없음 포맷 사용
- [ ] `"idiom": "watch"` + `"scale": "2x"`는 레거시 — 다중 사이즈 요구하므로 사용 금지
- [ ] watchOS 타겟에 `GENERATE_INFOPLIST_FILE: true` 사용 시 `INFOPLIST_KEY_CFBundleIconName` 명시

### Diagnostic Steps

validation 에러 발생 시:
1. **빌드 설정 확인보다 asset catalog Contents.json 먼저 확인** — idiom/scale 포맷이 올바른지
2. Archive 산출물 내 Info.plist 직접 확인: `plutil -p path/to/DUNEWatch.app/Info.plist | grep Icon`
3. 클린 빌드로 캐시 문제 배제한 후에도 동일하면 빌드 설정이 아닌 리소스 문제

## Lessons Learned

- **빌드 성공 ≠ validation 성공**: asset catalog 컴파일은 레거시 Contents.json에서도 경고 없이 성공하지만, validation은 엄격하게 아이콘 완성도를 검사
- **증상이 동일해도 원인이 다를 수 있음**: "Missing Icons"와 "Missing CFBundleIconName"이 동시에 발생하면 Info.plist 설정만 의심하기 쉽지만, asset catalog 포맷 자체가 근본 원인일 수 있음
- **watchOS는 iOS보다 validation이 엄격**: iOS에서는 관대하게 처리되는 설정이 watchOS에서는 에러
- **오진 후 "클린해봐"는 시간 낭비**: 빌드 캐시 의심보다 리소스 파일 자체를 먼저 검증하는 것이 효율적
