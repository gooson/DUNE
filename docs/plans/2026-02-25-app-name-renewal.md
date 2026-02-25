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

brainstorm 결과 앱 이름이 "Dailve" → "DUNE"으로 확정됨. Bundle identifier(`com.raftel.dailve`)는 유지하면서, 디렉토리명·타겟명·사용자 노출 텍스트를 모두 DUNE으로 변경.

## Requirements

### Functional

- 홈 화면 앱 이름: "DUNE" 표시
- Watch 앱 이름: "DUNE" 표시
- HealthKit 권한 요청 문구: "DUNE needs access..." 표시
- 앱 내 UI에서 "Dailve" 대신 "DUNE" 표시
- 디렉토리명: `Dailve/` → `DUNE/`, `DailveWatch/` → `DUNEWatch/` 등
- Xcode project/target/scheme명: DUNE 기반으로 변경
- PRODUCT_NAME: "DUNE" (iOS), "DUNEWatch" (watchOS)

### Non-functional (변경 금지)

- Bundle ID `com.raftel.dailve` 절대 변경 금지
- iCloud container `iCloud.com.raftel.dailve` 변경 금지
- UserDefaults key (`com.raftel.dailve.*`, `com.dailve.*`) 변경 금지
- Logger subsystem `com.raftel.dailve` 변경 금지 (bundle ID 관행)
- Entitlements 파일 내용 변경 금지 (파일명만 변경)

## Approach

**Full Rename 전략**: 디렉토리, 타겟, 스킴, PRODUCT_NAME, UI 텍스트를 모두 DUNE으로 변경. Bundle ID와 persistent storage key만 유지.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Display Name만 변경 | 최소 변경, 안전 | 내부 코드에 "Dailve" 잔존 | 거절 |
| Full Rename (bundle ID 제외) | 완전한 이름 통일 | 변경 범위 넓음 | **채택** |

## Affected Files

### A. 디렉토리 리네이밍 (git mv)

| From | To |
|------|----|
| `Dailve/` | `DUNE/` |
| `DailveWatch/` | `DUNEWatch/` |
| `DailveTests/` | `DUNETests/` |
| `DailveUITests/` | `DUNEUITests/` |

### B. 파일 리네이밍 (git mv)

| From | To |
|------|----|
| `DUNE/Resources/Dailve.entitlements` | `DUNE/Resources/DUNE.entitlements` |
| `DUNEWatch/DailveWatch.entitlements` | `DUNEWatch/DUNEWatch.entitlements` |
| `DUNE/App/DailveApp.swift` | `DUNE/App/DUNEApp.swift` |
| `DUNEWatch/DailveWatchApp.swift` | `DUNEWatch/DUNEWatchApp.swift` |

### C. 내용 수정

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/project.yml` | Major | 프로젝트명, 타겟명, 스킴명, 경로, PRODUCT_NAME, HealthKit 문구 |
| `DUNE/App/DUNEApp.swift` | Modify | `struct DailveApp` → `struct DUNEApp` |
| `DUNEWatch/DUNEWatchApp.swift` | Modify | `struct DailveWatchApp` → `struct DUNEWatchApp` |
| `DUNE/Presentation/Exercise/Components/WorkoutShareCard.swift` | Modify | `Text("Dailve")` → `Text("DUNE")` |
| `DUNE/Presentation/Shared/DesignSystem.swift` | Modify | 주석 "Dailve" → "DUNE" |
| `DUNEWatch/Views/QuickStartPickerView.swift` | Modify | "Dailve app" → "DUNE app" |
| `DUNEWatch/Views/RoutineListView.swift` | Modify | `.navigationTitle("Dailve")` → `.navigationTitle("DUNE")` |
| `DUNE/Data/WatchConnectivity/WatchSessionManager.swift` | Modify | 주석에서 DailveWatch 참조 업데이트 |
| `scripts/build-ios.sh` | Modify | 경로/스킴 업데이트 |
| `scripts/hooks/pre-commit.sh` | Modify | 디렉토리명 패턴 업데이트 |

### D. .claude/ 인프라 (경로 참조 업데이트)

| File | Description |
|------|-------------|
| `.claude/rules/testing-required.md` | `DailveTests/` → `DUNETests/`, 빌드 명령 |
| `.claude/rules/navigation-ownership.md` | `Dailve/App/ContentView.swift` 경로 |
| `.claude/skills/xcode-project/SKILL.md` | 디렉토리 구조, 빌드 명령 |
| `.claude/skills/testing-patterns/SKILL.md` | 테스트 경로 |
| `.claude/skills/ui-testing/SKILL.md` | UI 테스트 경로, 빌드 명령 |
| `.claude/skills/ship/SKILL.md` | xcodegen 명령 |

## Implementation Steps

### Step 1: 디렉토리 리네이밍

```bash
git mv Dailve/ DUNE/
git mv DailveWatch/ DUNEWatch/
git mv DailveTests/ DUNETests/
git mv DailveUITests/ DUNEUITests/
```

- **Verification**: `ls -d DUNE/ DUNEWatch/ DUNETests/ DUNEUITests/`

### Step 2: 파일 리네이밍

```bash
git mv DUNE/Resources/Dailve.entitlements DUNE/Resources/DUNE.entitlements
git mv DUNEWatch/DailveWatch.entitlements DUNEWatch/DUNEWatch.entitlements
git mv DUNE/App/DailveApp.swift DUNE/App/DUNEApp.swift
git mv DUNEWatch/DailveWatchApp.swift DUNEWatch/DUNEWatchApp.swift
```

- **Verification**: 파일 존재 확인

### Step 3: project.yml 전체 업데이트

- `name: Dailve` → `name: DUNE`
- 모든 scheme 이름: `Dailve` → `DUNE`, `DailveTests` → `DUNETests`, `DailveWatch` → `DUNEWatch`, `DailveUITests` → `DUNEUITests`
- 모든 target 이름: 동일 패턴
- `PRODUCT_NAME: Dailve` → `PRODUCT_NAME: DUNE` (iOS)
- `PRODUCT_NAME: DailveWatch` → `PRODUCT_NAME: DUNEWatch` (watchOS)
- `CODE_SIGN_ENTITLEMENTS` 경로 업데이트
- source path: `../DailveWatch` → `../DUNEWatch`
- HealthKit 권한 문구: "Dailve" → "DUNE" (4곳)
- `TEST_HOST` 경로: `Dailve.app` → `DUNE.app`
- `INFOPLIST_KEY_CFBundleDisplayName: DUNE` 추가 (iOS + Watch)
- **변경 금지**: `PRODUCT_BUNDLE_IDENTIFIER`, `iCloud.com.raftel.dailve`, `WKCompanionAppBundleIdentifier`

### Step 4: Swift 소스 코드 수정

- `DUNEApp.swift`: `struct DailveApp: App` → `struct DUNEApp: App`
- `DUNEWatchApp.swift`: `struct DailveWatchApp: App` → `struct DUNEWatchApp: App`
- `WorkoutShareCard.swift`: `Text("Dailve")` → `Text("DUNE")`
- `DesignSystem.swift`: 주석 "Dailve" → "DUNE"
- `QuickStartPickerView.swift`: "Dailve app" → "DUNE app"
- `RoutineListView.swift`: `.navigationTitle("Dailve")` → `.navigationTitle("DUNE")`
- `WatchSessionManager.swift`: 주석 업데이트

### Step 5: 빌드 스크립트 업데이트

- `scripts/build-ios.sh`: `Dailve/project.yml` → `DUNE/project.yml`, `Dailve/Dailve.xcodeproj` → `DUNE/DUNE.xcodeproj`, `SCHEME="Dailve"` → `SCHEME="DUNE"`
- `scripts/hooks/pre-commit.sh`: 디렉토리 패턴 업데이트

### Step 6: .claude/ 인프라 업데이트

- `.claude/rules/testing-required.md`
- `.claude/rules/navigation-ownership.md`
- `.claude/skills/xcode-project/SKILL.md`
- `.claude/skills/testing-patterns/SKILL.md`
- `.claude/skills/ui-testing/SKILL.md`
- `.claude/skills/ship/SKILL.md`

### Step 7: 빌드 검증

- `scripts/build-ios.sh` 실행
- xcodegen generate 성공 확인
- 빌드 성공 확인

## 변경하지 않는 항목 (명시)

| 항목 | 이유 |
|------|------|
| `com.raftel.dailve` (bundle ID) | 사용자 명시적 지시 |
| `com.raftel.dailve.watchkitapp` (Watch bundle ID) | bundle ID 유지 |
| `com.raftel.dailve.tests` / `.uitests` | bundle ID 유지 |
| `iCloud.com.raftel.dailve` (CloudKit) | bundle ID 연동 |
| `com.raftel.dailve.*` UserDefaults keys | 기존 데이터 호환 |
| `com.dailve.*` UserDefaults keys | 기존 데이터 호환 |
| Logger subsystem `com.raftel.dailve` | bundle ID 관행 |
| `.entitlements` 파일 내용 | CloudKit 동기화 |
| `WKCompanionAppBundleIdentifier: com.raftel.dailve` | Watch-iOS 연동 |
| `docs/` 과거 문서의 "Dailve" 참조 | 역사적 기록 유지 |
| `.claude/agent-memory/` 내 "Dailve" 참조 | 에이전트 메모리 (별도 갱신) |
| CLAUDE.md Correction Log 내 경로 참조 | 역사적 기록 유지 |

## Edge Cases

| Case | Handling |
|------|----------|
| 기존 사용자 업데이트 시 홈 화면 이름 | iOS가 CFBundleDisplayName 변경 시 자동 반영 |
| Watch 앱 이름 동기화 | Watch target에도 CFBundleDisplayName 설정 |
| .xcodeproj 경로 변경 | xcodegen이 project.yml 기반으로 재생성하므로 자동 처리 |
| CI/CD 파이프라인 | 현재 없음 (스크립트만 수정) |

## Testing Strategy

- Unit tests: `DUNETests/` 경로에서 정상 실행 확인
- Manual verification:
  - `xcodegen generate --spec DUNE/project.yml` 성공
  - `scripts/build-ios.sh` 빌드 성공
  - 시뮬레이터 홈 화면 "DUNE" 표시 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| git mv 후 히스토리 추적 | 낮음 | 낮음 | git은 rename detection 지원 |
| xcodegen 재생성 실패 | 낮음 | 높음 | project.yml 수정 후 즉시 검증 |
| pre-commit hook 패턴 미스매치 | 중 | 낮음 | 스크립트 수정 후 테스트 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 변경 범위가 넓지만 모두 기계적 치환. Bundle ID 유지로 데이터 안전. xcodegen 기반이므로 프로젝트 파일 재생성 용이.
