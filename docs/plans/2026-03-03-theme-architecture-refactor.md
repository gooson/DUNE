---
tags: [theme, architecture, refactor, watchos, automation, design-system]
date: 2026-03-03
category: plan
status: implemented
---

# 테마 코드 구조 리팩토링 (신규 테마 추가 자동화)

## Problem

신규 테마 추가 시 iOS와 Watch 각각의 `AppTheme` 확장에 반복 `switch`를 수동으로 추가해야 해서 누락 위험이 높다.  
또한 테마 토큰 매핑 규칙이 한 곳에 모여 있지 않아 빠르고 안정적인 확장이 어렵다.

## Research 요약

- iOS 테마 매핑: `DUNE/Presentation/Shared/Extensions/AppTheme+View.swift`에 다수 `switch self`
- Watch 테마 매핑: `DUNEWatch/Views/Extensions/AppTheme+WatchView.swift`에 유사 코드 중복
- Shared 색상 자산은 이미 `Shared/Resources/Colors.xcassets`로 통합되어 있어 네이밍 규칙 기반 접근이 가능
- 과거 해결책:
- `docs/solutions/design/2026-03-01-multi-theme-architecture.md`
- `docs/solutions/architecture/2026-03-02-shared-colors-xcassets.md`

## Solution 방향

1. `AppTheme`에 테마 prefix 규칙을 추가해 asset 이름 생성 규칙을 단일화한다.
2. 테마 색상 접근을 generic resolver로 통합해 반복 `switch`를 제거한다.
3. iOS의 `AppTheme+View.swift`를 Watch target에도 포함해 양 플랫폼 동시 반영을 강제한다.
4. Watch 쪽 중복 확장은 환경키만 유지하고 나머지 매핑은 공유 확장을 사용한다.
5. 규칙 회귀 방지를 위해 `AppTheme` 네이밍 규칙 테스트를 추가한다.

## Affected Files

| 파일 | 변경 유형 | 설명 |
|------|-----------|------|
| `DUNE/Domain/Models/AppTheme.swift` | Edit | 테마 prefix/asset 네이밍 규칙 추가 |
| `DUNE/Presentation/Shared/Extensions/AppTheme+View.swift` | Edit | `switch` 기반 매핑을 공용 resolver 기반으로 교체 |
| `DUNEWatch/Views/Extensions/AppTheme+WatchView.swift` | Edit | 중복 매핑 제거, Watch 환경키만 유지 |
| `DUNE/project.yml` | Edit | Watch target에 공용 `AppTheme+View.swift` 포함 |
| `DUNETests/AppThemeTests.swift` | Edit | 테마 네이밍 규칙 검증 테스트 추가 |

## Implementation Steps

### Step 1: AppTheme 네이밍 규칙 단일화

- **Files**: `DUNE/Domain/Models/AppTheme.swift`
- **Changes**:
- 테마 prefix(`Ocean`, `Forest`, `Sakura`)와 default(Desert) 판별 속성 추가
- `themedAssetName(default:variantSuffix:)` 유틸 추가
- **Verification**:
- 컴파일 성공
- 각 테마별 asset 이름이 기대값과 일치

### Step 2: iOS/Watch 공용 색상 resolver 도입

- **Files**: `DUNE/Presentation/Shared/Extensions/AppTheme+View.swift`
- **Changes**:
- 반복 `switch` 제거
- 공용 resolver 호출로 색상/토큰 매핑 단일화
- Watch 미사용 타입(`OutdoorFitnessLevel`) 영역은 플랫폼 조건부 컴파일 처리
- **Verification**:
- iOS, watchOS 양쪽에서 extension 중복/심볼 충돌 없음
- 기존 UI 코드 변경 없이 동일 프로퍼티 접근 가능

### Step 3: Watch 중복 코드 제거 + 공유 파일 타깃 연결

- **Files**: `DUNEWatch/Views/Extensions/AppTheme+WatchView.swift`, `DUNE/project.yml`
- **Changes**:
- Watch 파일은 `EnvironmentKey`만 유지
- Watch target sources에 `Presentation/Shared/Extensions/AppTheme+View.swift` 추가
- **Verification**:
- project 생성 후 watch target에서 `theme.accentColor` 등 기존 호출 정상 컴파일

### Step 4: 테스트 강화

- **Files**: `DUNETests/AppThemeTests.swift`
- **Changes**:
- 테마 prefix 및 asset name 생성 규칙 테스트 추가
- **Verification**:
- DUNETests 통과

### Step 5: 품질 검증

- **Files**: (N/A)
- **Changes**:
- xcodegen 재생성
- iOS + watchOS 빌드/테스트 실행
- **Verification**:
- 빌드/테스트 통과

## Edge Cases

| 케이스 | 대응 |
|------|------|
| 새 테마 추가 시 prefix만 추가되고 자산 누락 | 네이밍 규칙 테스트 + 빌드에서 색상 미존재 즉시 노출 |
| Watch에서 iOS 전용 타입 참조 컴파일 오류 | `#if os(iOS)`로 분리 |
| 저장된 오래된 rawValue | 기존 rawValue 유지로 하위호환 보장 |

## Risks

| 리스크 | 가능성 | 영향도 | 완화 |
|------|--------|--------|------|
| 네이밍 규칙과 실제 asset 이름 불일치 | 중간 | 높음 | 테스트 추가 + 빌드 검증 |
| project.yml 변경 후 xcodeproj 미동기화 | 중간 | 중간 | `scripts/lib/regen-project.sh` 실행 |
| Watch target source 누락으로 런타임 불일치 | 낮음 | 중간 | 공용 extension 파일을 watch target에 명시 추가 |

## Test Strategy

1. Unit test: `DUNETests/AppThemeTests.swift`
2. Build/test: `xcodebuild test` (DUNETests, DUNEWatchTests)
3. 수동 확인:
- iOS Settings에서 테마 변경 시 탭 tint/배경이 정상 전환되는지 확인
- Watch에서 동기화된 테마 색상(카드/메트릭)이 정상 적용되는지 확인
