---
tags: [watchos, app-icon, asset-catalog, app-store-connect]
category: general
date: 2026-11-19
severity: important
related_files:
  - DUNEWatch/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
  - scripts/generate-app-icon-assets.swift
  - scripts/tests/test_watch_primary_icon.py
  - .github/workflows/build-ios.yml
related_solutions: [2026-02-26-watchos-app-icon-validation, 2026-11-16-themed-app-icon-and-launch-branding]
---

# App Store Connect에서 Watch에만 이전 아이콘이 표시될 때

빌드의 ‘포함된 자산’에서 iPhone은 코럴·샌드 인터리브, Apple Watch는 예전 능선 로고로 표시됐다. 두 타깃은 각각 `AppIcon`을 선언한다. 생성기가 iOS 카탈로그만 갱신하면서 Watch 카탈로그에는 유효한 예전 이미지가 남아 빌드도 성공했다.

## 수정과 회귀 검사

Watch 아이콘을 기본 82/P04 PNG로 교체했다. 이후 `swift scripts/generate-app-icon-assets.swift`를 저장소 루트에서 실행하면 생성된 iOS 기본 PNG가 Watch 디렉터리에도 기록된다. 각 카탈로그는 자체 플랫폼 선언을 유지한다. `--output-dir`는 미리보기 출력만 생성한다.

빌드 워크플로에서 `python3 -B -m unittest scripts.tests.test_watch_primary_icon`으로 각 플랫폼의 1024px 항목이 가리키는 파일을 읽어 비교한다.

## 배포 빌드 확인

1. iOS 앱 번들에서 `Watch/DUNEWatch.app/Info.plist`의 `CFBundleIconName`이 `AppIcon`인지 확인한다.
2. 상위 앱과 내장 Watch 앱의 각 `Assets.car`에 `xcrun assetutil --info`를 실행한다. 이름이 `AppIcon`인 1024px `Icon Image`의 렌디션 해시를 비교하면 실제 패키징된 그림이 같은지 확인할 수 있다.
3. 새 빌드가 App Store Connect에서 처리된 후 ‘포함된 자산’에서 원형 Apple Watch 아이콘을 확인한다.
