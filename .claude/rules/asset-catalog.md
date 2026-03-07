# Asset Catalog & Xcode Project Rules

## xcodegen 후처리

- xcodegen 후 objectVersion/compatibilityVersion 후처리 (build-pipeline.md 참조)
- watchOS: `INFOPLIST_KEY_CFBundleIconName` 명시 + platform 소문자

## visionOS

- native visionOS app icon은 전용 `.imagestack` asset 필요: iOS `AppIcon.appiconset`의 `visionos` child 추가로 해결되지 않음
- `project.yml`에 `Resources/Assets.xcassets` 포함 + `ASSETCATALOG_COMPILER_APPICON_NAME`를 visionOS 전용 stack asset(`VisionAppIcon`)으로 지정

## PBXGroup

- XcodeGen shared 파일을 target-specific group으로 다시 매달지 말 것: 같은 실파일이 여러 PBXGroup에 걸리면 `file reference is a member of multiple groups` 경고. 별도 path(필요 시 symlink)로 참조

## Asset Catalog 구조

- Asset catalog 폴더에 `"provides-namespace": true`
- AI 생성 아이콘 투명 배경 확인 / 제네릭 장비는 SF Symbol
- Equipment.other -> nil ("없음" vs "미인식" 구분)
- Icon switch dispatch는 View init에서 pre-resolve
- validation 에러는 asset catalog "Unassigned" 먼저 확인
