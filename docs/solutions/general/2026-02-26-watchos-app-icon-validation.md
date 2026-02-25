---
tags: [watchos, app-icon, cfbundleiconname, info-plist, xcodegen, validation, asset-catalog, idiom, contents-json, platform-case]
category: general
date: 2026-02-26
severity: important
related_files:
  - DUNE/project.yml
  - DUNEWatch/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json
  - DUNEWatch/Resources/Info.plist
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

**세 가지 원인이 동시에 존재:**

1. **Contents.json `platform` 대소문자 (핵심 원인)**: `"platform": "watchOS"` (대문자 OS)는 Xcode가 인식하지 못함. **`"platform": "watchos"` (소문자)가 올바른 값**. iOS도 `"ios"` (소문자) 사용. 잘못된 platform 값은 Xcode에서 "Unassigned" 표시 → asset catalog 컴파일 시 아이콘 미포함 → Archive에 `Assets.car` 자체가 없음.

2. **Contents.json 레거시 idiom**: 초기에는 `"idiom": "watch"` + `"scale": "2x"` (레거시 포맷)이었음. 이것을 `"idiom": "universal"` + scale 제거로 수정해야 했으나, platform 대소문자가 더 근본적인 문제.

3. **CFBundleIconName Info.plist 키 누락**: `GENERATE_INFOPLIST_FILE: true`만으로는 `CFBundleIconName`이 자동 생성되지 않음. 명시적 `Info.plist` 파일로 해결.

### 오진 순서

1차: `INFOPLIST_KEY_CFBundleIconName` 빌드 설정 추가 → 효과 없음
2차: Contents.json idiom을 `"universal"`로 변경 → 효과 없음
3차: 명시적 Info.plist 파일 생성 + INFOPLIST_FILE 설정 → 효과 없음
4차: Archive 산출물 직접 검사 → `Assets.car` 자체가 없음 발견
5차: Xcode에서 "Unassigned" 확인 → `"watchOS"` → `"watchos"` 대소문자 수정 → **해결**

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNEWatch/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json` | `"idiom": "watch"` → `"universal"`, `"scale": "2x"` 제거, `"platform": "watchOS"` → `"watchos"` | 현대 단일 아이콘 포맷 + platform 소문자 |
| `DUNEWatch/Resources/Info.plist` | 새 파일 생성 (`CFBundleIconName = AppIcon`) | Info.plist 키 명시적 포함 |
| `DUNE/project.yml` | `INFOPLIST_FILE`, `INFOPLIST_KEY_CFBundleIconName` 추가 | Watch 타겟 설정 |
| `scripts/build-ios.sh` | xcodegen 후 objectVersion/compatibilityVersion 후처리 | Correction #121 스크립트 반영 |

### Key Code

**Contents.json (최종)**:
```json
{
  "images" : [
    {
      "filename" : "AppIcon.png",
      "idiom" : "universal",
      "platform" : "watchos",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

**platform 값 규칙**: 항상 소문자. `"ios"`, `"watchos"`, `"macos"`.

**DUNEWatch/Resources/Info.plist**:
```xml
<dict>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
</dict>
```

## Prevention

### Checklist Addition

- [ ] Asset catalog Contents.json의 `platform` 값은 항상 **소문자**: `"ios"`, `"watchos"`, `"macos"`
- [ ] watchOS AppIcon은 `"idiom": "universal"` + `"platform": "watchos"` + `"size": "1024x1024"` (scale 없음)
- [ ] Xcode에서 아이콘이 "Unassigned"로 표시되면 Contents.json 포맷 문제
- [ ] watchOS 타겟에 명시적 Info.plist 파일 생성하여 `CFBundleIconName` 포함

### Diagnostic Steps

validation 에러 발생 시:
1. **Xcode에서 asset catalog 열어 "Unassigned" 여부 확인** — 이것이 가장 빠른 진단
2. Archive 산출물에 `Assets.car` 존재 여부: `find .xcarchive -name "Assets.car"`
3. Archive 산출물 Info.plist 직접 확인: `plutil -p DUNEWatch.app/Info.plist | grep Icon`
4. Contents.json의 platform 대소문자, idiom, scale 확인

## Lessons Learned

- **platform 문자열은 대소문자 구분**: `"watchOS"` ≠ `"watchos"`. iOS는 `"ios"` 소문자. 공식 문서에 명확히 나오지 않아 함정
- **빌드 성공 ≠ validation 성공**: asset catalog 컴파일러는 잘못된 platform에서도 빌드를 성공시키지만, 아이콘을 `Assets.car`에 포함하지 않음. Archive validation에서만 발견됨
- **"Unassigned" 경고가 핵심 단서**: Xcode asset catalog 에디터의 "Unassigned" 표시는 Contents.json 포맷 오류의 가장 직접적인 증거
- **빌드 설정/Info.plist 수정보다 리소스 파일 자체를 먼저 검증**: 동일 에러가 반복되면 빌드 설정이 아닌 리소스 파일의 포맷 문제 의심
- **Archive 산출물 직접 검사가 확실한 진단법**: `find .xcarchive -name "Assets.car"`로 아이콘이 실제 번들에 있는지 확인
