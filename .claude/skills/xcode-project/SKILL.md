---
name: xcode-project
description: "Xcode 프로젝트 관리. xcodegen으로 프로젝트 생성/재생성, 빌드, 테스트 실행."
---

# Xcode Project Management

xcodegen 기반 Xcode 프로젝트를 관리합니다.

## Project Structure

### 디스크 구조

```
Health/                    # repo root
├── DUNE/
│   ├── project.yml        # xcodegen spec (source of truth)
│   ├── DUNE.xcodeproj/    # Generated
│   ├── App/               # @main, ContentView, AppLogger
│   ├── Data/              # HealthKit services, SwiftData models
│   ├── Domain/            # Models, UseCases
│   ├── Presentation/      # Views, ViewModels
│   └── Resources/         # Info.plist, Entitlements, Assets.xcassets
├── DUNETests/             # Unit tests (Swift Testing)
├── DUNEUITests/           # UI tests (XCTest)
└── DUNEWatch/             # watchOS app
```

### Xcode 프로젝트 네비게이터 그룹 구조

```
DUNE (project)
├── DUNE/                 ← iOS 앱 소스 (group: DUNE)
│   ├── App/
│   ├── Data/
│   ├── Domain/
│   ├── Presentation/
│   └── Resources/
├── DUNEWatch/            ← Watch 전용 소스 (path: ../DUNEWatch)
├── Shared/               ← iOS & Watch 공유 모델 (group: Shared/*)
│   ├── Models/           ← Data/Persistence/Models
│   ├── Migration/        ← Data/Persistence/Migration
│   └── Domain/           ← Domain/Models 중 공유 enum
├── DUNETests/            ← path: ../DUNETests
├── DUNEUITests/          ← path: ../DUNEUITests
├── Frameworks
└── Products
```

### xcodegen group 규칙

| 타겟 | source path | group | 결과 |
|------|-------------|-------|------|
| DUNE | `App`, `Data`, `Domain`, `Presentation`, `Resources` | `DUNE` | DUNE/ 그룹 하위에 배치 |
| DUNEWatch | `../DUNEWatch` (excludes Resources) | (없음) | DUNEWatch/ 그룹 |
| DUNEWatch | `../DUNEWatch/Resources` | (없음) | Resources 그룹 |
| DUNEWatch | `Data/Persistence/Models` 등 공유 모델 | `Shared/Models` 등 | Shared/ 그룹 하위 |
| DUNETests | `../DUNETests` | (없음) | DUNETests/ 그룹 |
| DUNEUITests | `../DUNEUITests` | (없음) | DUNEUITests/ 그룹 |

**금지 패턴:**
- `group`과 `path`가 동일한 값 → xcodegen 무한루프
- Watch 공유 모델을 `DUNEWatch/Shared/` 하위에 배치 → `Shared/`(루트 레벨)에 배치

## Targets

| Target | Type | Framework | Bundle ID |
|--------|------|-----------|-----------|
| DUNE | app | SwiftUI | com.raftel.dailve |
| DUNEWatch | app (watchOS) | SwiftUI | com.raftel.dailve.watchkitapp |
| DUNETests | unit-test | Swift Testing | com.raftel.dailve.tests |
| DUNEUITests | ui-testing | XCTest | com.raftel.dailve.uitests |

## Commands

### 프로젝트 재생성 + 빌드
```bash
scripts/build-ios.sh
```

> `xcodegen generate`를 직접 실행하지 않는다 — 후처리(objectVersion, xcscheme 패치)가 누락됨.

### 유닛 테스트
```bash
xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNETests \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.2' \
  -only-testing DUNETests
```

### UI 테스트
```bash
xcodebuild test -project DUNE/DUNE.xcodeproj -scheme DUNEUITests \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.2' \
  -only-testing DUNEUITests
```

## Adding New Files

1. 적절한 디렉토리에 Swift 파일 생성
2. `project.yml`의 `sources` 경로에 포함되는 디렉토리이면 자동 포함
3. 새 디렉토리 추가 시 `project.yml`에 path 추가 후 `scripts/build-ios.sh` 실행

## Adding New Test Files

1. `DUNETests/` 에 `{TargetName}Tests.swift` 생성
2. `import Foundation`, `import Testing`, `@testable import DUNE` 필수
3. `@Suite`, `@Test` 매크로 사용 (Swift Testing)
4. ViewModel 테스트는 `@MainActor` 어노테이션 필요

## Adding Shared Models (Watch 공유)

새 Domain/Models 파일을 Watch에서도 사용해야 할 때:
1. `project.yml`의 DUNEWatch sources에 추가
2. `group: Shared/Domain` 지정
3. `scripts/build-ios.sh` 실행

```yaml
- path: Domain/Models/NewModel.swift
  group: Shared/Domain
```

## Dependencies

- **xcodegen**: `brew install xcodegen` (프로젝트 생성에 필요)
- **HealthKit**: SDK framework (프로비저닝 필요)
- **SwiftData**: Built-in (iOS 17+)

## Notes

- `DUNE.xcodeproj/`는 생성물이므로 `.gitignore`에 추가 권장
- `project.yml`이 source of truth
- 시뮬레이터에서 HealthKit entitlement 경고는 정상 (실기기에서만 동작)
- 빌드 타겟: iOS 26.0+, watchOS 26.0+, Swift 6, strict concurrency
