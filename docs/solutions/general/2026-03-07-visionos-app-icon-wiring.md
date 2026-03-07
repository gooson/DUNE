---
tags: [visionos, app-icon, imagestack, xcodegen, asset-catalog, assets-car, xros]
category: general
date: 2026-03-07
severity: important
related_files:
  - DUNE/project.yml
  - DUNE/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json
  - DUNE/Resources/Assets.xcassets/VisionAppIcon.imagestack/Contents.json
related_solutions:
  - general/2026-02-26-watchos-app-icon-validation
---

# Solution: visionOS App Icon 누락 수정

## Problem

### Symptoms

- `DUNEVision` 타겟에서 앱 아이콘이 보이지 않음
- Xcode/project 설정에는 아이콘이 연결된 것처럼 보였지만, 실제 리소스 디렉토리에는 visionOS용 아이콘 자산이 없었음
- `DUNEVision.app/Assets.car` 검사 시 native visionOS icon layer가 포함되지 않았음

### Root Cause

원인은 두 가지였다.

1. `project.yml`의 `DUNEVision` source of truth에 `Resources/Assets.xcassets`가 빠져 있어, xcodegen 재생성 기준으로는 visionOS target이 app icon asset catalog를 안정적으로 포함하지 못했다.
2. iOS용 `AppIcon.appiconset`만으로는 native visionOS 앱 아이콘이 되지 않는다. visionOS는 layered image stack 기반 아이콘이 필요하고, 단순히 `platform: visionos` child를 `appiconset`에 추가하면 `actool`이 `unassigned child`로 무시했다.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/project.yml` | `DUNEVision` target에 `Resources/Assets.xcassets` 추가 | xcodegen source of truth에서 shared asset catalog를 실제 포함 |
| `DUNE/project.yml` | `DUNEVision`의 `ASSETCATALOG_COMPILER_APPICON_NAME`를 `VisionAppIcon`으로 지정 | iOS `AppIcon`과 분리된 visionOS 전용 아이콘 source 사용 |
| `DUNE/Resources/Assets.xcassets/VisionAppIcon.imagestack/*` | 새 visionOS image stack asset 추가 | native visionOS layered icon 제공 |
| `DUNE/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json` | visionOS child 제거, iOS 전용 유지 | 잘못된 `appiconset` 기반 visionOS 슬롯 제거 |

### Key Code

`project.yml`:

```yaml
  DUNEVision:
    sources:
      - path: Resources/Assets.xcassets
        group: DUNEVision/Resources
    settings:
      base:
        ASSETCATALOG_COMPILER_APPICON_NAME: VisionAppIcon
```

visionOS icon asset 구조:

```text
VisionAppIcon.imagestack/
  Front.imagestacklayer/
    Content.imageset/
  Middle.imagestacklayer/
    Content.imageset/
  Back.imagestacklayer/
    Content.imageset/
```

## Prevention

### Checklist Addition

- [ ] native visionOS target은 iOS `AppIcon.appiconset` 재사용만으로 처리하지 않는다
- [ ] `project.yml` 기준으로 visionOS target이 `Assets.xcassets`를 실제 source에 포함하는지 확인한다
- [ ] visionOS app icon은 전용 `.imagestack` asset으로 분리하고 `ASSETCATALOG_COMPILER_APPICON_NAME`를 그 이름으로 지정한다
- [ ] 검증 시 `strings DUNEVision.app/Assets.car | rg 'VisionAppIcon/'` 로 layer가 번들에 들어갔는지 확인한다

## Lessons Learned

- xcodegen 프로젝트에서는 Xcode UI에 보이는 설정보다 `project.yml`이 더 중요하다. source-of-truth에 빠진 asset은 재생성 시 다시 사라진다.
- visionOS native icon은 watchOS/iOS와 달리 layered asset이 필요하다.
- `actool` warning이 없어지고 `Assets.car`에 `VisionAppIcon/Front|Middle|Back/Content`가 들어가야 실제 해결이다.
