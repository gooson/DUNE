---
name: xcode-project
description: "Xcode 프로젝트 관리. xcodegen으로 프로젝트 생성/재생성, 빌드, 테스트 실행."
---

# Xcode Project Management

xcodegen 기반 Xcode 프로젝트를 관리합니다.

## Project Structure

```
DUNE/
├── project.yml          # xcodegen spec
├── DUNE.xcodeproj/      # Generated (gitignored)
├── App/                 # @main, ContentView, AppLogger
├── Data/                # HealthKit services, SwiftData models
├── Domain/              # Models, UseCases
├── Presentation/        # Views, ViewModels
└── Resources/           # Info.plist, Entitlements, Assets.xcassets

DUNETests/               # Unit tests (Swift Testing)
DUNEUITests/             # UI tests (XCTest)
```

## Targets

| Target | Type | Framework | Bundle ID |
|--------|------|-----------|-----------|
| DUNE | app | SwiftUI | com.raftel.dailve |
| DUNETests | unit-test | Swift Testing | com.raftel.dailve.tests |
| DUNEUITests | ui-testing | XCTest | com.raftel.dailve.uitests |

## Commands

### 프로젝트 재생성
```bash
cd DUNE && xcodegen generate
```

`project.yml` 수정 후 반드시 실행해야 합니다.

### 빌드
```bash
scripts/build-ios.sh
```

> 주의: `generic/platform=iOS` 대신 **iOS Simulator destination**을 고정 사용합니다.
> 프로젝트 생성이 필요하면 스크립트가 `xcodegen generate --spec DUNE/project.yml`를 자동 실행합니다.

### 유닛 테스트
```bash
xcodebuild test -project DUNE.xcodeproj -scheme DUNETests \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' \
  -only-testing DUNETests -quiet
```

### UI 테스트
```bash
xcodebuild test -project DUNE.xcodeproj -scheme DUNEUITests \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' \
  -only-testing DUNEUITests -quiet
```

## Adding New Files

1. 적절한 디렉토리에 Swift 파일 생성
2. `project.yml`의 `sources` 경로에 포함되는 디렉토리이면 자동 포함
3. 새 디렉토리 추가 시 `project.yml`에 path 추가 후 `xcodegen generate` 실행

## Adding New Test Files

1. `DUNETests/` 에 `{TargetName}Tests.swift` 생성
2. `import Foundation`, `import Testing`, `@testable import DUNE` 필수
3. `@Suite`, `@Test` 매크로 사용 (Swift Testing)
4. ViewModel 테스트는 `@MainActor` 어노테이션 필요

## Dependencies

- **xcodegen**: `brew install xcodegen` (프로젝트 생성에 필요)
- **HealthKit**: SDK framework (프로비저닝 필요)
- **SwiftData**: Built-in (iOS 17+)

## Notes

- `DUNE.xcodeproj/`는 생성물이므로 `.gitignore`에 추가 권장
- `project.yml`이 source of truth
- 시뮬레이터에서 HealthKit entitlement 경고는 정상 (실기기에서만 동작)
- 빌드 타겟: iOS 26.0+, Swift 6, strict concurrency
