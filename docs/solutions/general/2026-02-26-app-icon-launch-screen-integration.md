---
tags: [app-icon, launch-screen, xcassets, xcodegen, project-format, UILaunchScreen]
date: 2026-02-26
category: general
status: implemented
---

# App Icon + Launch Screen + AccentColor 통합

## Problem

DUNE 앱에 브랜딩 에셋(아이콘, 런치스크린, 액센트컬러)이 없어 기본 빈 아이콘과 흰 런치스크린이 표시됨.

통합 과정에서 발생한 구체적 문제들:

1. **런치스크린 로고 크기**: `UILaunchScreen` Info.plist 방식은 이미지 크기를 직접 제어할 수 없음. 1024px 원본 → 너무 큼, 150pt(@1x/@2x/@3x) → iPad에서 너무 작음
2. **LaunchScreen.storyboard 실패**: 수동 작성한 XML을 Xcode 26.2가 파싱 불가 (`com.apple.InterfaceBuilder error -1`)
3. **xcodegen 프로젝트 포맷**: xcodegen이 Xcode 16.3 포맷(objectVersion 90)을 지원하지 않아 후처리 필요

## Solution

### 런치스크린: Info.plist + Universal 이미지

LaunchScreen.storyboard 대신 `UILaunchScreen` plist 방식 채택. 이미지는 scale factor 없는 universal 단일 파일(500x500px)로 설정.

```xml
<!-- Info.plist -->
<key>UILaunchScreen</key>
<dict>
    <key>UIColorName</key>
    <string>LaunchBackground</string>
    <key>UIImageName</key>
    <string>LaunchLogo</string>
</dict>
```

```json
// LaunchLogo.imageset/Contents.json — scale 미지정 = universal
{
  "images" : [{ "filename" : "LaunchLogo.png", "idiom" : "universal" }],
  "properties" : { "template-rendering-intent" : "original" }
}
```

### 앱 아이콘: iOS + watchOS 동일 이미지

1024x1024 단일 PNG를 iOS(`platform: ios`)와 watchOS(`platform: watchOS, scale: 2x`)에 공유.

### AccentColor: Colors/ 하위 통합

xcassets 내 모든 색상을 `Colors/` 그룹에 일관 배치. light/dark 동일 값이면 universal만 유지.

### xcodegen 후처리

xcodegen이 objectVersion 90을 지원하지 않으므로 생성 후 sed로 교체:

```bash
xcodegen generate
sed -i '' 's/objectVersion = [0-9]*;/objectVersion = 90;/' DUNE.xcodeproj/project.pbxproj
sed -i '' 's/compatibilityVersion = "Xcode [^"]*"/compatibilityVersion = "Xcode 16.3"/' DUNE.xcodeproj/project.pbxproj
```

**주의**: `project.yml`의 `xcodeVersion: "26.2"`는 IDE 버전이고, pbxproj의 `compatibilityVersion: "Xcode 16.3"`은 프로젝트 파일 포맷. 서로 다른 개념.

## Prevention

1. **런치스크린 변경 후 시뮬레이터 테스트**: 앱 삭제 → 재설치 필수 (iOS가 런치스크린을 캐싱)
2. **LaunchScreen.storyboard 수동 작성 금지**: Xcode Interface Builder로만 생성하거나 Info.plist 방식 사용
3. **xcodegen 실행 시 항상 후처리 포함**: `scripts/` 에 스크립트화 권장
4. **xcassets 색상은 Colors/ 하위에 배치**: root에 colorset 생성 금지
5. **light/dark 동일 색상은 universal만**: 불필요한 dark variant 중복 금지

## Lessons Learned

- `UILaunchScreen`의 `UIImageName`은 이미지의 pt 크기 그대로 표시됨. Auto Layout 제어 불가하므로 타겟 디바이스 범위에서 적절한 단일 크기 선택 필요
- xcodegen `xcodeVersion`과 pbxproj `compatibilityVersion`/`objectVersion`는 별개 개념
- watchOS AppIcon은 iOS와 동일 이미지를 사용해도 watchOS가 자동으로 원형 마스크 적용
