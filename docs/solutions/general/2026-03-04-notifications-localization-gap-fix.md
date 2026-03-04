---
tags: [notifications, localization, xcstrings, i18n, notification-hub]
category: general
date: 2026-03-04
status: implemented
severity: important
related_files:
  - DUNE/Presentation/Dashboard/NotificationHubView.swift
  - DUNE/Resources/Localizable.xcstrings
  - docs/plans/2026-03-04-notifications-localization-gap-fix.md
related_solutions:
  - docs/solutions/general/localization-gap-audit.md
  - docs/solutions/general/2026-03-01-localization-leak-pattern-fixes.md
---

# Solution: Notifications 화면 다국어 누락 보강

## Problem

Notifications 화면에서 일부 문자열이 다국어 경로를 우회하거나 번역 데이터가 비어 있어 locale 전환 시 영어/한국어가 혼합 노출되는 문제가 있었다.

### Symptoms

- unread summary가 locale에 따라 번역되지 않고 영어로 고정될 수 있음
- 빈 상태/목적지 없음 메시지에 한글 하드코딩이 남아 있음
- `This action removes every notification from your inbox.` 키가 xcstrings에 번역 없이 비어 있음

### Root Cause

- `NotificationHubView`의 일부 문자열이 `String` 기반 경로로 남아 localization lookup이 누락됨
- Notification 화면 신규 문구가 `Localizable.xcstrings`에 en/ko/ja 세트로 완결되지 않음
- 공통 키 `"Back"`이 도메인 맥락(등/背中) 번역과 충돌할 여지가 있어 화면 액션 라벨로 재사용하기 어려움

## Solution

NotificationHubView의 문자열 경로를 정리하고 String Catalog에 누락 키를 일괄 보강했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Dashboard/NotificationHubView.swift` | unread/empty/fallback/hint 문구를 localization 경로로 전환 | 사용자 대면 문자열의 locale 누락 방지 |
| `DUNE/Resources/Localizable.xcstrings` | `%lld unread notifications`, `%@ Detail`, `Go Back` 등 신규 키 + ko/ja 번역 추가 | 화면 신규 문구의 번역 완결성 확보 |
| `DUNE/Resources/Localizable.xcstrings` | `This action removes every notification from your inbox.` 번역 추가 | 기존 미번역 키 보강 |

### Key Code

```swift
if unreadCount > 0 {
    Text("\(unreadCount) unread notifications")
} else {
    Text("Inbox is all caught up")
}

return (String(localized: "\(category.displayName) Detail"), category.iconName)
```

## Prevention

### Checklist Addition

- [ ] NotificationHub/Feed 문자열 추가 시 `NotificationHubView`의 `String` 반환 helper를 우선 점검한다.
- [ ] 신규 화면 문구 반영 시 `.xcstrings`에서 ko/ja 값 누락 여부를 함께 확인한다.
- [ ] 액션 라벨은 도메인 의미가 겹치는 키(`Back` 등) 재사용 대신 문맥 명확 키(`Go Back`)를 사용한다.

### Rule Addition (if applicable)

기존 `.claude/rules/localization.md` 규칙 범위에서 커버 가능하여 신규 룰 추가는 생략했다.

## Lessons Learned

문자열 키 누락보다 더 자주 발생하는 회귀는 "lookup 경로 누락"이다. 화면 단에서 `String(localized:)`와 `LocalizedStringKey` 경계를 명확히 유지하고, 변경 즉시 xcstrings 번역 상태를 함께 검증해야 다국어 회귀를 줄일 수 있다.
