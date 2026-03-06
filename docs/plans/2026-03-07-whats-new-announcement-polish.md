---
topic: whats-new-announcement-polish
date: 2026-03-07
status: completed
confidence: medium
related_brainstorms:
  - docs/brainstorms/2026-03-07-whats-new-space.md
related_solutions:
  - docs/solutions/architecture/2026-03-07-whats-new-release-surface.md
---

# Implementation Plan: What's New Announcement Polish

## Context

현재 `What's New` 상세 화면은 실제 캡처 자산이 없어 추상적인 fallback artwork에 의존하고 있고, detail 하단의 `기능 열기` CTA는 동작 신뢰성이 낮다. 이번 작업은 공지 화면을 "읽고 이해하는 release surface"로 다시 맞추는 데 목적이 있다.

## Goals

- 각 feature detail에 실제 screenshot처럼 읽히는 이미지 자산을 제공한다.
- list row에서도 이미지 preview가 보여 공지 전달력을 높인다.
- `기능 열기` CTA를 제거하고, 그에 따라 불필요해지는 `What's New` deep link 라우팅 코드를 정리한다.
- 관련 UI 테스트와 문서를 현재 UX에 맞게 갱신한다.

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/WhatsNew/WhatsNewView.swift` | update | row/detail 레이아웃을 screenshot-first 구조로 정리, CTA 제거 |
| `DUNE/Domain/Models/WhatsNew.swift` | update | `destination` 등 미사용 모델 정리 |
| `DUNE/Data/Persistence/WhatsNewManager.swift` | update | deep link bridge 제거 후 release catalog 역할로 단순화 |
| `DUNE/App/DUNEApp.swift` | update | pending destination 정리, auto-present dismiss 흐름 단순화 |
| `DUNE/App/ContentView.swift` | update | `What's New` route signal/state 제거 |
| `DUNE/Presentation/Dashboard/DashboardView.swift` | update | 수동 진입 경로에서 obsolete closure 제거 |
| `DUNE/Presentation/Settings/SettingsView.swift` | update | 수동 진입 경로에서 obsolete closure 제거 |
| `DUNE/Presentation/Activity/ActivityView.swift` | update | obsolete `What's New` signal 제거 |
| `DUNE/Presentation/Wellness/WellnessView.swift` | update | obsolete `What's New` signal 제거 |
| `DUNE/Resources/Assets.xcassets` | add | `whatsnew-*` screenshot-style image assets 추가 |
| `DUNEUITests/Helpers/UITestHelpers.swift` | update | 제거된 CTA identifier 정리 |
| `DUNEUITests/Smoke/SettingsSmokeTests.swift` | update | detail 존재/이미지 존재 기준으로 smoke test 재작성 |
| `docs/solutions/architecture/...` | update/add | CTA 제거 + screenshot 자산 전략 문서화 |

## Implementation Steps

### Step 1: Screenshot-first UI refactor

- `WhatsNewFeatureRow`를 thumbnail 포함 card형 row로 변경
- detail 화면은 large artwork + 설명만 남기고 CTA를 제거
- image asset 미존재 fallback도 screen-like mock capture 방향으로 보강

### Step 2: Remove obsolete deep link plumbing

- `WhatsNewView`의 `onOpenDestination` closure 제거
- `WhatsNewDestination`, manager route bridge, app/content signal 연결 제거
- 관련 Dashboard/Settings/Activity/Wellness wiring 정리

### Step 3: Add artwork assets

- 각 `WhatsNewFeature`에 대응하는 `whatsnew-*` asset을 추가
- 자산은 실제 앱 screenshot처럼 읽히는 device-frame 기반 PNG로 생성
- asset naming은 기존 `imageAssetName` 규칙을 유지

### Step 4: Verification and docs

- unit/UI tests 갱신
- targeted build/test 실행
- 해결 내용을 solution doc에 남기고 ship 준비

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| screenshot 자산 품질이 실제 앱 톤과 어긋남 | Medium | Medium | DS 색상/타이포 느낌을 재사용하고 fallback도 동일 톤으로 맞춤 |
| deep link 제거 중 unused signal 정리가 누락됨 | Medium | Medium | `rg`로 `whatsNew` route/signal 전수 검색 후 정리 |
| UI 테스트가 기존 open button 전제를 유지 | High | Low | smoke test를 detail/image 존재 검증으로 즉시 전환 |

## Verification

- `What's New` row/detail이 이미지 중심으로 표시된다.
- detail 화면에 `기능 열기` 버튼이 더 이상 노출되지 않는다.
- `Settings > About > What's New` 및 Today entry에서 정상 진입한다.
- `xcodebuild test` 대상 테스트가 통과한다.

## Outcome

- screenshot-style `whatsnew-*` asset 11종을 추가해 fallback artwork 의존도를 제거했다.
- `What's New` detail CTA와 전역 route bridge를 제거해 공지 화면을 read-only release surface로 단순화했다.
- `DUNETests`, `DUNEUITests` 대상 검증이 현재 설치된 iPhone 17 simulator에서 통과했다.
