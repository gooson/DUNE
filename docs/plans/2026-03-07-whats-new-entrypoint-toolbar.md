---
topic: whats-new-entrypoint-toolbar
date: 2026-03-07
status: implemented
confidence: high
related_solutions:
  - docs/solutions/architecture/2026-03-07-whats-new-release-surface.md
  - docs/solutions/general/2026-03-04-dashboard-notification-badge-clipping.md
related_brainstorms: []
---

# Implementation Plan: What's New Entry Point Toolbar

## Context

Today 탭 최상단의 `What's New` 카드는 새 기능을 항상 화면 상단에 고정해 주요 지표 흐름을 방해한다. 새 기능 진입점은 유지하되, 알림과 같은 툴바 위치로 이동하고, 업데이트 직후 사용자에게만 build 번호 기준 첫 진입 가이드를 제공해야 한다.

## Requirements

### Functional

- Today 탭 상단의 `What's New` 카드 제거
- Today 네비게이션 툴바에 독립 `What's New` 아이콘 추가
- 새 build 첫 진입 시 `TipKit` 가이드 1회 노출
- 현재 build의 `What's New`를 아직 열지 않았으면 툴바 아이콘에 `new` 점 표시
- `What's New` 상세 화면과 기존 deep link 라우팅 유지

### Non-functional

- 기존 Notification/Settings 툴바와 충돌 없이 정렬
- `TipKit` 초기화가 앱 시작 흐름(splash, consent)을 깨지 않아야 함
- 상태 저장은 build 번호 기준으로 안정적으로 재현 가능해야 함
- UI 회귀를 막기 위한 unit/UI 테스트 추가

## Approach

기존 `fullScreenCover` 자동 노출을 제거하고, `WhatsNewStore`를 build 기준 `tip shown` / `entry opened` 상태 저장소로 확장한다. Today 탭 툴바에 `What's New` 아이콘을 추가하고, 새 build에서 아직 tip을 본 적 없을 때만 `TipKit popoverTip`을 노출한다. `new` 점은 현재 build의 `What's New`를 사용자가 직접 열기 전까지 유지한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 기존 자동 풀스크린 유지 + 카드만 제거 | 구현이 단순 | 사용 흐름 강제, 사용자 요구와 불일치 | 기각 |
| Notification Hub 안에 `What's New` 통합 | 진입점 수 감소 | 공지/새 기능 개념 혼합, 독립 아이콘 요구 불충족 | 기각 |
| 툴바 아이콘 + `TipKit` + build 저장 | 흐름 방해 최소화, 업데이트 사용자만 안내 | 저장 상태가 2종류로 늘어남 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/App/DUNEApp.swift` | update | `TipKit` configure 및 기존 자동 `What's New` modal 제거 |
| `DUNE/Data/Persistence/WhatsNewStore.swift` | update | build 기준 tip/open 상태 저장 API 추가 |
| `DUNE/Presentation/Dashboard/DashboardView.swift` | update | 상단 카드 제거, 툴바 `What's New` 아이콘/배지/TipKit 연결 |
| `DUNE/Presentation/WhatsNew/WhatsNewView.swift` | update | 화면 실제 열람 시점에 build 확인 상태 반영 |
| `DUNE/Presentation/Settings/SettingsView.swift` | update | 보조 진입점 열람도 동일한 build 확인 상태로 반영 |
| `DUNETests/WhatsNewStoreTests.swift` | update | build 상태 저장 분기 테스트 추가 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | update | 새 툴바 접근성 ID 추가 |
| `DUNEUITests/Smoke/DashboardSmokeTests.swift` | update | Today 툴바 `What's New` 진입 smoke test로 갱신 |
| `docs/solutions/general/2026-03-07-whats-new-toolbar-tipkit-entrypoint.md` | add | 변경 패턴 문서화 |

## Implementation Steps

### Step 1: Persisted build state 재정의

- **Files**: `DUNE/Data/Persistence/WhatsNewStore.swift`, `DUNETests/WhatsNewStoreTests.swift`
- **Changes**: version 기반 auto-present 저장 API를 `lastOpenedBuild` 중심 build 저장 구조로 교체하고, 배지 표시 여부 판단 메서드 추가
- **Verification**: Swift Testing으로 same-build / new-build / empty-build 분기 검증

### Step 2: Today 툴바 진입점 이동

- **Files**: `DUNE/Presentation/Dashboard/DashboardView.swift`
- **Changes**: 상단 `whatsNewEntryCard` 삭제, 툴바 아이콘/`new` 점/`TipKit` popover 추가, 탭 내 수동 라우팅 유지
- **Verification**: UI smoke test에서 툴바 아이콘 존재 및 `What's New` 화면 이동 확인

### Step 3: 앱 시작 노출 흐름 단순화

- **Files**: `DUNE/App/DUNEApp.swift`
- **Changes**: 자동 `fullScreenCover` 제거, `Tips.configure()` 추가, splash/consent 이후에는 수동 툴바 진입만 사용
- **Verification**: 빌드 시 `TipKit` import/link 정상 확인, 앱 시작 시 기존 consent 흐름 회귀 없음

## Edge Cases

| Case | Handling |
|------|----------|
| build 번호가 비어 있음 | tip/배지 비활성화 |
| 사용자가 tip만 닫고 `What's New`를 열지 않음 | 같은 build에서 tip은 재노출하지 않되 `new` 점은 유지 |
| 새 build인데 catalog에 해당 release가 없음 | 아이콘은 유지하되 `new` 점/TipKit 비활성화 |

## Testing Strategy

- Unit tests: `WhatsNewStore`의 build 기준 상태 저장/판단 분기 검증
- UI tests: Today 툴바 `What's New` 버튼 존재 및 화면 이동 smoke test
- Manual verification: 새 build/기존 build 상태에서 tip 1회 노출, `new` 점 해제 시점 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| `TipKit` 초기화 누락으로 tip 미표시 | low | medium | `DUNEApp` 초기 task에서 configure 호출 |
| 툴바 아이콘 오버레이가 잘리거나 겹침 | medium | medium | 기존 notification badge 패턴과 동일한 overlay/frame 사용 |
| build 상태 저장 기준 변경으로 기존 유저 상태 초기화 | medium | low | 새 key로 분리하고 empty build 방어 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 `What's New` 라우팅과 수동 화면은 이미 구현돼 있어, 이번 작업은 노출 계층과 저장 상태만 재배치하면 된다.
