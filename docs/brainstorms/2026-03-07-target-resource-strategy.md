---
tags: [resources, xcassets, xcstrings, multi-target, shared, equipment, localization]
date: 2026-03-07
category: brainstorm
status: implemented
---

# Brainstorm: 타겟별 리소스 관리 전략

## Problem Statement

5개 타겟(DUNE, DUNEWatch, DUNEWidget, DUNEVision, DUNEVisionWidgets)의 리소스가 일부는 Shared, 일부는 타겟별로 분산되어 있고, 통합 원칙 없이 ad-hoc으로 관리되고 있다.

주요 문제:
1. **iOS xcstrings ≡ Shared xcstrings**: 22,471줄 완전 중복 (diff 결과 동일)
2. **Equipment icons 중복**: 25개가 iOS/Watch 양쪽에 별도 해상도로 존재
3. **DUNEVisionWidgets**: Colors.xcassets, Localizable.xcstrings 미참조 (system colors만 사용 중)
4. 새 타겟 추가 시 어떤 리소스를 어디서 참조해야 하는지 가이드라인 부재

## 현재 상태 (As-Is)

### 리소스 매트릭스

| 리소스 | DUNE (iOS) | DUNEWatch | DUNEWidget | DUNEVision | DUNEVisionWidgets |
|--------|:----------:|:---------:|:----------:|:----------:|:-----------------:|
| **Colors.xcassets** (232+ 색상) | Shared ✅ | Shared ✅ | Shared ✅ | Shared ✅ | **없음** ⚠️ |
| **Localizable.xcstrings** | 자체 (22K줄) ⚠️ | 자체 (1.4K줄) ✅ | Shared (22K줄) ✅ | Shared (22K줄) ✅ | **없음** ⚠️ |
| **Equipment icons** | 자체 25개 512px ⚠️ | 자체 31개 128px ⚠️ | - | - | - |
| **AppIcon** | 자체 ✅ | 자체 ✅ | - | VisionAppIcon ✅ | - |
| **whatsnew images** | 자체 11개 ✅ | - | - | - | - |
| **exercises.json** | 자체 ✅ | WC sync ✅ | - | - | - |
| **WidgetScoreData.swift** | Shared ✅ | - | Shared ✅ | - | - |

### 디렉토리 구조

```
Shared/Resources/
├── Colors.xcassets/        (232+ universal color sets)
└── Localizable.xcstrings   (22,471줄 — DUNE/Resources/와 동일)

DUNE/Resources/
├── Assets.xcassets/
│   ├── AppIcon.appiconset/     (1024px 단일 소스)
│   ├── Colors/                 (14 iOS-only 색상: Activity*, ShareCard*, Launch*)
│   ├── Equipment/              (25 아이콘, 512×512px, 총 708KB)
│   ├── whatsnew-*.imageset/    (11 feature showcase images)
│   ├── LaunchLogo.imageset/
│   └── ShanksPirateFlagMark.imageset/
├── Localizable.xcstrings       (22,471줄 ← Shared와 동일)
├── Info.plist
└── DUNE.entitlements

DUNEWatch/Resources/
├── Assets.xcassets/
│   ├── AppIcon.appiconset/     (watchOS 전용)
│   └── Equipment/              (31 아이콘, 128×128px, 총 276KB)
├── Localizable.xcstrings       (1,405줄 — Watch 전용 축소판)
├── Info.plist
└── DUNEWatch.entitlements

DUNEWidget/Resources/           (Info.plist + entitlements만)
DUNEVision/Resources/           (Info.plist + entitlements만)
DUNEVisionWidgets/Resources/    (Info.plist만)
```

### project.yml 리소스 참조

```yaml
# DUNE: 자체 Resources + Shared Colors
- path: Resources
- path: ../Shared/Resources/Colors.xcassets

# DUNEWatch: 자체 경로 + Shared Colors
- path: ../DUNEWatch
- path: ../Shared/Resources/Colors.xcassets

# DUNEWidget: Shared xcstrings + Shared Colors
- path: ../Shared/Resources/Localizable.xcstrings
- path: ../Shared/Resources/Colors.xcassets

# DUNEVision: Shared xcstrings + Shared Colors
- path: ../Shared/Resources/Localizable.xcstrings
- path: ../Shared/Resources/Colors.xcassets

# DUNEVisionWidgets: 없음 (system colors만 사용)
```

## 발견된 이슈 상세

### 1. iOS xcstrings 완전 중복

`DUNE/Resources/Localizable.xcstrings`와 `Shared/Resources/Localizable.xcstrings`가 **byte-for-byte 동일**.
현재 iOS는 자체 파일을, Widget/Vision은 Shared를 참조하고 있어 양쪽에 동시 수정이 필요한 상황.

**위험**: 한쪽만 수정하면 iOS ↔ Widget/Vision 번역 불일치 발생.

### 2. Equipment icons — 해상도 분리 필요

| 항목 | iOS | Watch |
|------|-----|-------|
| 공유 아이콘 수 | 25 | 25 (+ 6 exclusive) |
| 해상도 | 512×512px | 128×128px |
| 파일 크기 (총) | 708KB | 276KB |
| 파일명 패턴 | `barbell.png` | `equipment.barbell.png` |
| Contents.json | universal, template | universal, template |

→ 해상도·파일명이 다르므로 단순 폴더 공유 불가.
→ 선택지: (A) 현행 유지 (B) Shared에 고해상도 단일 소스 + Asset Catalog scale slots

### 3. DUNEVisionWidgets 리소스 공백

현재 system colors(`.secondary`, `.green`, `.indigo`, `.orange`)만 사용.
DS 테마 적용 시 Colors.xcassets + xcstrings 참조 필요.

### 4. Watch-only Equipment 6개

`ab-roller`, `battle-rope`, `bench`, `foam-roller`, `landmine`, `preacher-curl`이 Watch에만 존재.
iOS에서도 사용할 수 있어야 일관성 확보.

## 제안: 리소스 관리 원칙 (To-Be)

### 원칙 1: Single Source of Truth

| 리소스 유형 | 소스 위치 | 비고 |
|------------|----------|------|
| 테마 색상 | `Shared/Resources/Colors.xcassets` | 모든 타겟 참조 |
| 타겟별 색상 | `{Target}/Resources/Assets.xcassets/Colors/` | iOS Activity 색상 등 |
| 번역 문자열 | `Shared/Resources/Localizable.xcstrings` | iOS 포함 통합 |
| Watch 전용 문자열 | `DUNEWatch/Resources/Localizable.xcstrings` | Watch-only UI 축소판 |
| Equipment icons | 현행 유지 (해상도별 분리) | 해상도 차이로 통합 어려움 |
| App Icon | 타겟별 | 플랫폼 요구사항 상이 |
| Feature images | `DUNE/Resources/Assets.xcassets/` | iOS-only (whatsnew 등) |
| exercises.json | `DUNE/Data/Resources/` | Watch는 WC sync |

### 원칙 2: 새 타겟 추가 시 체크리스트

1. `Shared/Resources/Colors.xcassets` 참조 추가
2. `Shared/Resources/Localizable.xcstrings` 참조 추가 (사용자 대면 문자열이 있는 경우)
3. 타겟별 AppIcon 생성 (플랫폼 요구사항 확인)
4. entitlements 분리 (플랫폼별 capability 상이)

### 원칙 3: 리소스 중복 금지 기준

- **동일 파일**: 즉시 Shared로 추출 (현재 xcstrings 해당)
- **동일 컨텐츠, 다른 포맷**: 타겟별 유지 + 원본 소스 명시 (Equipment icons 해당)
- **완전 독립**: 타겟 내 보관 (AppIcon, whatsnew images 해당)

## Scope

### MVP (즉시 수행)

- [ ] **iOS xcstrings 중복 제거**: `DUNE/Resources/Localizable.xcstrings` 삭제 → `Shared/Resources/Localizable.xcstrings` 참조로 교체
- [ ] **DUNEVisionWidgets**: Colors.xcassets 참조 추가 (DS 통합 준비)
- [ ] **localization.md** 규칙 업데이트: 단일 소스 반영
- [ ] **리소스 관리 원칙** 문서를 `.claude/rules/` 에 추가

### Nice-to-have (Future)

- [ ] Equipment icons: Watch-only 6개를 iOS에도 추가 (512px 버전 제작)
- [ ] Equipment icons: `Shared/Resources/Equipment/` 구조 검토 (SVG 단일 소스 + 빌드 타임 리사이즈)
- [ ] DUNEVisionWidgets: xcstrings 참조 추가 (DS 테마 적용 시)
- [ ] Watch xcstrings 키를 Shared xcstrings subset으로 검증하는 lint 스크립트

## Open Questions

1. Equipment SVG 단일 소스 → 빌드 타임 리사이즈가 실용적인가? (Xcode asset catalog이 이를 지원하는지)
2. Watch-only 6개 아이콘이 iOS에서도 필요한지? (UI에서 해당 장비가 표시되는지)
3. DUNEVisionWidgets가 DS 테마를 적용할 시점은? (MVP or post-launch?)

## Next Steps

- [ ] `/plan` 으로 MVP 항목 구현 계획 생성
