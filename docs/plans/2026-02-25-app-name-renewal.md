---
topic: app-name-renewal
date: 2026-02-25
status: draft
confidence: high
related_solutions: []
related_brainstorms: [2026-02-25-app-name-renewal]
---

# Implementation Plan: App Name Renewal (Dailve → DUNE)

## Context

brainstorm 결과 앱 이름이 "Dailve" → "DUNE"으로 확정됨. Bundle identifier(`com.raftel.dailve`)는 유지하면서 사용자에게 노출되는 모든 텍스트를 변경해야 함.

## Requirements

### Functional

- 홈 화면 앱 이름: "DUNE" 표시
- Watch 앱 이름: "DUNE" 표시
- HealthKit 권한 요청 문구: "DUNE needs access..." 표시
- 앱 내 UI에서 "Dailve" 대신 "DUNE" 표시

### Non-functional

- Bundle ID `com.raftel.dailve` 절대 변경 금지
- iCloud container `iCloud.com.raftel.dailve` 변경 금지
- UserDefaults key (`com.raftel.dailve.*`, `com.dailve.*`) 변경 금지
- 기존 사용자 데이터 영향 없음
- 디렉토리명(`Dailve/`, `DailveWatch/` 등)은 유지 (인프라 변경 최소화)

## Approach

**Display Name Only 전략**: `CFBundleDisplayName`을 "DUNE"으로 설정하여 홈 화면 표시명만 변경. `PRODUCT_NAME`은 "Dailve" 유지. 사용자에게 보이는 텍스트만 수정.

디렉토리명, target명, scheme명, struct명 등 내부 인프라는 모두 유지. 이유:
1. 디렉토리 리네이밍은 150+ 파일의 import path에 영향
2. target/scheme 변경은 CI, 스크립트, 빌드 설정 전체에 영향
3. Bundle ID가 동일하므로 내부명과 외부명이 다른 것은 표준 관행

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Display Name만 변경 | 최소 변경, 안전 | 내부 코드에 "Dailve" 잔존 | **채택** |
| 전체 리네이밍 (디렉토리+target+struct) | 완전한 이름 통일 | 150+ 파일 수정, 높은 리스크, CI 파손 가능 | 거절 (미래 TODO) |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `Dailve/project.yml` | Modify | CFBundleDisplayName 추가 + HealthKit 권한 문구 변경 |
| `Dailve/Presentation/Exercise/Components/WorkoutShareCard.swift` | Modify | `Text("Dailve")` → `Text("DUNE")` |
| `Dailve/Presentation/Shared/DesignSystem.swift` | Modify | 주석에서 "Dailve" → "DUNE" |
| `DailveWatch/Views/QuickStartPickerView.swift` | Modify | "Open the Dailve app" → "Open the DUNE app" |
| `DailveWatch/Views/RoutineListView.swift` | Modify | `.navigationTitle("Dailve")` → `.navigationTitle("DUNE")` |

## Implementation Steps

### Step 1: project.yml — Display Name + 권한 문구

- **Files**: `Dailve/project.yml`
- **Changes**:
  1. iOS target settings에 `INFOPLIST_KEY_CFBundleDisplayName: DUNE` 추가
  2. Watch target settings에 `INFOPLIST_KEY_CFBundleDisplayName: DUNE` 추가
  3. iOS `NSHealthShareUsageDescription`: "Dailve" → "DUNE"
  4. iOS `NSHealthUpdateUsageDescription`: "Dailve" → "DUNE"
  5. Watch `NSHealthShareUsageDescription`: "Dailve" → "DUNE"
  6. Watch `NSHealthUpdateUsageDescription`: "Dailve" → "DUNE"
- **Verification**: `xcodegen generate` 후 Info.plist에 CFBundleDisplayName = "DUNE" 확인

### Step 2: 사용자 노출 UI 텍스트 변경

- **Files**:
  - `Dailve/Presentation/Exercise/Components/WorkoutShareCard.swift`
  - `DailveWatch/Views/QuickStartPickerView.swift`
  - `DailveWatch/Views/RoutineListView.swift`
- **Changes**:
  - `Text("Dailve")` → `Text("DUNE")`
  - `"Open the Dailve app\non your iPhone to sync"` → `"Open the DUNE app\non your iPhone to sync"`
  - `.navigationTitle("Dailve")` → `.navigationTitle("DUNE")`
- **Verification**: 각 화면에서 "DUNE" 표시 확인

### Step 3: 코드 주석 업데이트

- **Files**: `Dailve/Presentation/Shared/DesignSystem.swift`
- **Changes**: 주석에서 "Dailve Design System" → "DUNE Design System"
- **Verification**: 빌드 성공

### Step 4: 빌드 검증

- **Command**: `scripts/build-ios.sh`
- **Verification**: 빌드 성공, 에러/경고 없음

## 변경하지 않는 항목 (명시)

| 항목 | 이유 |
|------|------|
| `com.raftel.dailve` (bundle ID) | 사용자 명시적 지시 |
| `iCloud.com.raftel.dailve` (CloudKit) | bundle ID 연동 |
| `com.raftel.dailve.*` UserDefaults keys | 기존 데이터 호환 |
| `com.dailve.*` UserDefaults keys | 기존 데이터 호환 |
| Logger subsystem `com.raftel.dailve` | bundle ID 관행 |
| 디렉토리명 (`Dailve/`, `DailveWatch/`) | 인프라 안정성 |
| Target/Scheme명 | CI/빌드 스크립트 호환 |
| Swift struct명 (`DailveApp`, `DailveWatchApp`) | 내부 코드, 사용자 미노출 |
| `.entitlements` 파일 | CloudKit 동기화 |

## Edge Cases

| Case | Handling |
|------|----------|
| 기존 사용자 업데이트 시 홈 화면 이름 | iOS가 CFBundleDisplayName 변경 시 자동 반영 |
| Watch 앱 이름 동기화 | Watch target에도 동일하게 CFBundleDisplayName 설정 |
| Spotlight 검색 | CFBundleDisplayName이 Spotlight 인덱싱에 사용됨 |

## Testing Strategy

- Unit tests: 변경 없음 (UI 텍스트만 수정)
- Integration tests: 변경 없음
- Manual verification:
  - 시뮬레이터에서 홈 화면 앱 이름 "DUNE" 확인
  - WorkoutShareCard에 "DUNE" 워터마크 확인
  - Watch 앱 RoutineListView 제목 "DUNE" 확인
  - HealthKit 권한 요청 문구에 "DUNE" 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| CFBundleDisplayName이 App Store에 영향 | 낮음 | 낮음 | App Store 표시명은 App Store Connect에서 별도 설정 |
| xcodegen 재생성 시 누락 | 낮음 | 중 | project.yml에 명시적 설정으로 안전 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 변경 범위가 5개 파일, 텍스트 치환만 수행. Bundle ID/데이터 영향 없음. 실패 시 revert 용이.
