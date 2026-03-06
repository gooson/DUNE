---
topic: whats-new-space
date: 2026-03-07
status: completed
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-02-28-settings-hub-patterns.md
  - docs/solutions/architecture/2026-03-03-notification-inbox-routing.md
related_brainstorms:
  - docs/brainstorms/2026-03-07-whats-new-space.md
---

# Implementation Plan: What's New Space

## Context

앱 첫 설치 및 업데이트 이후 사용자가 핵심 기능을 빠르게 이해할 수 있도록, 스크린샷/이미지와 짧은 설명을 담은 `What's New` 공간이 필요하다. 이 공간은 서버 없이 번들 데이터로 동작해야 하고, 같은 버전에서는 한 번만 자동 표시되어야 하며, `Settings > About`에서도 다시 열 수 있어야 한다. 또한 각 카드에서 관련 화면의 상세 영역으로 이동할 수 있어야 한다.

## Requirements

### Functional

- 첫 설치와 앱 업데이트 후 `What's New` 자동 표시
- 같은 버전에서는 자동 재표시 금지
- `Settings > About`에서 수동 재진입 가능
- 버전별 highlights 카드 표시
- 카드 탭 시 관련 탭/상세 화면으로 deep link
- iPhone/Apple Watch 기능을 함께 소개
- 현재 릴리스 콘텐츠를 정적 번들 데이터로 제공

### Non-functional

- launch splash 및 iCloud consent sheet와 충돌하지 않을 것
- 기존 탭별 `NavigationStack` 구조를 유지할 것
- `en / ko / ja` 현지화 대응
- 실제 스크린샷이 없더라도 릴리스 직전 교체 가능한 구조일 것
- 수동/자동 진입 모두 UI 테스트 가능할 것

## Approach

표시 타이밍은 `DUNEApp`에서 관리하고, 실제 앱 내 deep link는 `ContentView`가 처리한다. `What's New` 데이터는 타입 안전한 Swift catalog로 관리하고, `UserDefaults` 기반 store가 현재 버전 표시 여부를 판정한다. 카드 선택 시 모달을 닫고 NotificationCenter 기반 브리지로 목적지를 전달해 각 탭이 기존 signal 패턴으로 상세 화면을 열도록 확장한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| `ContentView`가 직접 modal 표시 | 구현 단순 | consent sheet와 충돌 가능, startup 순서 제어 약함 | 기각 |
| 번들 JSON + 런타임 decode | 운영자가 데이터 편집 쉬움 | localization 연결 복잡, 타입 안정성 낮음 | 보류 |
| 정적 Swift catalog + store + bridge | 타입 안정성, 빠른 구현, 기존 구조와 정합성 높음 | 릴리스 데이터 편집이 코드 변경 기반 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/App/DUNEApp.swift` | update | splash/consent 이후 `What's New` 표시 타이밍 제어 |
| `DUNE/App/ContentView.swift` | update | `What's New` deep link 수신 및 탭/상세 라우팅 |
| `DUNE/Presentation/Settings/SettingsView.swift` | update | About 섹션에 `What's New` 재진입 링크 추가 |
| `DUNE/Presentation/Activity/ActivityView.swift` | update | 외부 `What's New` 목적지 진입 처리 |
| `DUNE/Presentation/Wellness/WellnessView.swift` | update | 외부 `What's New` 목적지 진입 처리 |
| `DUNE/Domain/Models/WhatsNew.swift` | add | release/item/destination 모델 정의 |
| `DUNE/Data/Persistence/WhatsNewStore.swift` | add | last-seen version 저장 및 자동 표시 판정 |
| `DUNE/Data/Persistence/WhatsNewManager.swift` | add | 릴리스 카탈로그 + route 브리지 |
| `DUNE/Presentation/WhatsNew/WhatsNewView.swift` | add | user-facing `What's New` UI |
| `DUNE/Resources/Localizable.xcstrings` | update | 새 사용자 문자열 추가 |
| `DUNETests/WhatsNewStoreTests.swift` | add | 표시 조건 및 버전 판정 테스트 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | update | 새 accessibility identifiers 추가 |
| `DUNEUITests/Smoke/SettingsSmokeTests.swift` | update | Settings에서 `What's New` 진입 확인 |

## Implementation Steps

### Step 1: Data model + presentation coordination

- **Files**: `WhatsNew.swift`, `WhatsNewStore.swift`, `WhatsNewManager.swift`, `DUNEApp.swift`
- **Changes**:
  - release/item/platform/destination 모델 정의
  - current release catalog 추가
  - 현재 버전과 last-seen version 비교 로직 구현
  - splash/consent 이후 auto-present 흐름 추가
  - dismiss 후 pending destination 전달 브리지 추가
- **Verification**:
  - 같은 버전이면 auto-present false
  - 첫 설치/새 버전이면 auto-present true
  - consent sheet가 먼저 닫힌 뒤 `What's New`가 표시됨

### Step 2: `What's New` UI + Settings entry

- **Files**: `WhatsNewView.swift`, `SettingsView.swift`, `Localizable.xcstrings`
- **Changes**:
  - hero, highlight cards, archive section UI 구현
  - 이미지가 없을 때도 동작하는 illustration fallback 추가
  - About 섹션에 수동 진입 링크 및 AX identifier 추가
  - 모든 새 copy를 localization 규칙에 맞게 등록
- **Verification**:
  - 수동 진입으로 `What's New` 화면이 열림
  - highlight 카드/버전 정보/닫기 액션이 정상 표시됨
  - ko/ja 번역 키 누락이 없음

### Step 3: Deep link routing integration

- **Files**: `ContentView.swift`, `ActivityView.swift`, `WellnessView.swift`
- **Changes**:
  - `What's New` destination 수신 처리 추가
  - Activity/Wellness에서 외부 signal로 detail destination push
  - Today/Settings existing routes와 함께 동작하도록 연결
- **Verification**:
  - 카드 탭 후 해당 탭/상세 화면으로 이동
  - 기존 notification routing과 충돌하지 않음
  - NavigationStack reset 없이 목적지 진입

### Step 4: Tests + final verification

- **Files**: `WhatsNewStoreTests.swift`, `UITestHelpers.swift`, `SettingsSmokeTests.swift`
- **Changes**:
  - store auto-present 조건 unit tests 추가
  - Settings smoke test에 `What's New` 재진입 검증 추가
  - 필요한 AX identifiers 반영
- **Verification**:
  - unit tests pass
  - targeted UI smoke test pass
  - iOS build 성공

## Edge Cases

| Case | Handling |
|------|----------|
| 첫 설치 직후 consent와 `What's New`가 동시에 필요 | consent 종료 후 `What's New` 판정 수행 |
| 같은 버전 재실행 | auto-present 생략, Settings에서만 수동 진입 |
| 이미지 asset 미준비 | built-in illustration fallback 사용 |
| watch card의 실제 in-app 전용 목적지 부재 | 관련 iPhone 화면(Activity/Settings)로 안전한 destination 제공 |
| 릴리스 카드 deep link가 사용 불가능한 데이터에 의존 | static detail destinations만 MVP에 채택 |

## Testing Strategy

- Unit tests: `WhatsNewStore`의 auto-present, markSeen, version comparison
- Integration tests: `ContentView` signal wiring은 build + smoke routing으로 검증
- Manual verification:
  - 첫 설치 시 auto-present
  - 같은 버전 재실행 시 미표시
  - Settings 재진입
  - 각 카드 tap → 목적지 이동

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| consent/launch/what's-new modal 타이밍 충돌 | Medium | High | `DUNEApp` 단일 오케스트레이션으로 제어 |
| deep link state가 기존 notification routing과 충돌 | Medium | Medium | 동일한 signal 패턴 재사용, route 분리 |
| 다국어 문자열 누락 | Medium | Medium | `.xcstrings` 업데이트와 smoke verification 포함 |
| 실제 스크린샷 부재로 시각 완성도 저하 | High | Low | illustration fallback + asset 교체 가능 구조 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**: 현재 탭/라우팅 구조와 잘 맞는 패턴이 이미 존재하지만, launch-level modal sequencing과 새 deep link 브리지는 실제 빌드/테스트 확인이 필요하다.
