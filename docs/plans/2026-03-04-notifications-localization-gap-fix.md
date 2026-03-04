---
tags: [notifications, localization, xcstrings, notification-hub]
category: plan
topic: notifications-localization-gap-fix
date: 2026-03-04
status: implemented
confidence: high
related_solutions:
  - docs/solutions/general/localization-gap-audit.md
  - docs/solutions/general/2026-03-04-notification-hub-ux-ui-integration-improvement.md
  - docs/solutions/general/2026-03-01-localization-leak-pattern-fixes.md
related_brainstorms:
  - docs/brainstorms/2026-03-01-full-localization-xcstrings.md
---

# Implementation Plan: Notifications Localization Gap Fix

## Context

`NotificationHubView`에 사용자 대면 문자열이 일부 `String` 경로로 렌더링되거나 한국어 하드코딩으로 남아 있어 다국어(locale 전환) 시 번역 누락이 발생했다.
특히 unread summary, destination hint, empty/fallback message에서 `localization.md`의 leak pattern(보간 String, String 타입 전달, 하드코딩 문구) 리스크가 있었다.

## Requirements

### Functional

- Notifications 화면의 사용자 대면 문자열을 모두 localization 경로로 정렬한다.
- 기존 UI 동작(read/unread/delete, destination routing)은 변경하지 않는다.
- String Catalog에 신규 키를 추가하고 en/ko/ja 번역을 모두 채운다.

### Non-functional

- 기존 notification hub UX/레이아웃/접근성 동작에 영향이 없어야 한다.
- `localization.md` 규칙(영어 키 전략, String(localized:) 사용)을 준수한다.
- 변경 후 iOS 빌드가 통과해야 한다.

## Approach

`NotificationHubView`에서 localization leak이 발생하는 문자열 경로를 정리한다.
`Text` 문구는 `LocalizedStringKey` 경로를 유지하고, helper가 `String`을 반환하는 경우에는 `String(localized:)`를 적용한다.
동시에 `Localizable.xcstrings`에 누락 키를 추가해 ko/ja 번역을 함께 반영한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 코드만 수정하고 xcstrings는 Xcode 추출에 의존 | 빠름 | 번역 누락 상태 지속 가능 | ❌ |
| xcstrings만 보강하고 코드 경로는 유지 | 파일 변경 적음 | String 경로 leak이 남음 | ❌ |
| 코드 경로 + xcstrings 동시 정리 | 누락/회귀를 함께 차단 | 수정 범위가 2파일로 증가 | ✅ |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Presentation/Dashboard/NotificationHubView.swift` | modify | unread summary/empty/fallback/destination hint 문자열의 localization 경로 정렬 |
| `DUNE/Resources/Localizable.xcstrings` | modify | 신규 키 번역 추가, 기존 미번역 키 번역 보강 |

## Implementation Steps

### Step 1: NotificationHubView 문자열 경로 정리

- **Files**: `DUNE/Presentation/Dashboard/NotificationHubView.swift`
- **Changes**:
  - unread 요약 문구를 `Text("\(unreadCount) unread notifications")` 경로로 분리
  - 한글 하드코딩 메시지를 영어 키로 교체
  - destination hint를 `String(localized:)` 기반으로 전환
  - fallback 액션 라벨을 의미 충돌 없는 키(`Go Back`)로 정리
- **Verification**:
  - 컴파일 성공
  - Notifications 화면에서 문구가 정상 표시

### Step 2: String Catalog 누락 키 보강

- **Files**: `DUNE/Resources/Localizable.xcstrings`
- **Changes**:
  - `%lld unread notifications`, `%@ Detail`, `Notification Settings` 등 누락 키 추가
  - `This action removes every notification from your inbox.`에 ko/ja 번역 추가
  - 신규/수정 키의 ko/ja 번역 상태를 translated로 채움
- **Verification**:
  - `jq -e . DUNE/Resources/Localizable.xcstrings` 통과
  - 대상 키 ko/ja 값 조회 시 누락 없음

### Step 3: 품질 검증

- **Files**: 변경 파일 전체
- **Changes**:
  - iOS 시뮬레이터 빌드 실행
- **Verification**:
  - `xcodebuild -project DUNE/DUNE.xcodeproj -scheme DUNE -destination 'generic/platform=iOS Simulator' build` 성공

## Edge Cases

| Case | Handling |
|------|----------|
| unread count가 0일 때 | `Inbox is all caught up` 키 사용 |
| metric category별 hint | `"%@ Detail"` + `category.displayName`로 locale 반영 |
| route/destination 누락 | `Destination Unavailable` + 설명/Go Back 제공 |

## Testing Strategy

- Unit tests: 없음 (뷰 문자열/카탈로그 변경으로 `testing-required.md`의 테스트 면제 대상)
- Integration tests: iOS 빌드로 컴파일/리소스 통합 확인
- Manual verification: Notifications 화면 진입 후 summary/empty/fallback 문구 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 기존 문자열 키와 중복/충돌 | Low | Medium | 키 검색 후 추가, JSON 검증 수행 |
| locale별 문구 길이 차이로 UI 줄바꿈 변동 | Medium | Low | 기존 lineLimit 유지, 카드 레이아웃 유지 |
| 동적 보간 키 번역 누락 | Low | Medium | `%@ Detail`, `%lld unread notifications` 별도 키 추가 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 변경 범위가 NotificationHubView + String Catalog로 국소적이며, 빌드/JSON 검증으로 회귀 위험을 낮췄다.
