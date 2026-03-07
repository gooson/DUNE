---
tags: [localization, xcstrings, LocalizedStringKey, SwiftUI, cloud-sync, consent-sheet]
category: general
date: 2026-03-08
severity: important
related_files:
  - DUNE/Presentation/Shared/CloudSyncConsentView.swift
  - Shared/Resources/Localizable.xcstrings
related_solutions:
  - docs/solutions/general/localization-gap-audit.md
  - docs/solutions/testing/2026-03-08-e2e-phase2-today-settings-regression.md
---

# Solution: Cloud Sync Consent Helper Localization Leak

## Problem

Cloud sync consent sheet의 설명 bullet 3개가 ko/ja locale에서도 영어로 그대로 노출됐다.
launch dismiss flow 자체는 정상이라 UI 테스트는 통과했지만, 첫 실행에 노출되는 안내 문구가 번역되지 않는 shipping regression이었다.

### Symptoms

- `CloudSyncConsentView`의 "Private & Encrypted", "Seamless Sync", "Local Option" row가 비영어 locale에서도 영어로 표시됨
- 같은 sheet 안의 title, body, CTA는 번역되는데 bullet rows만 영어로 남아 화면 일관성이 깨짐
- e2e phase 2 작업 후 review 단계에서만 발견돼, English launch 기준 UI 테스트만으로는 잡히지 않음

### Root Cause

문제는 두 가지가 겹쳐 있었다.

1. `InfoRow` helper가 `String` 파라미터를 받아 `Text(title)` / `Text(description)`로 렌더링하면서 `LocalizedStringKey` 경로를 우회했다.
2. 해당 6개 문구가 `Localizable.xcstrings`에 등록돼 있지 않아, helper 타입을 고쳐도 번역 리소스가 없는 상태였다.

이 패턴은 `.claude/rules/localization.md`의 Leak Pattern 1과 동일하다.

## Solution

`CloudSyncConsentView` 내부 helper signature를 `LocalizedStringKey`로 변경하고, 누락된 consent copy를 string catalog에 ko/ja 번역과 함께 수동 등록했다.
이후 focused UI regression으로 consent sheet open/dismiss 동작이 유지되는지 다시 확인했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Shared/CloudSyncConsentView.swift` | `InfoRow.title` / `InfoRow.description`를 `String` → `LocalizedStringKey`로 변경 | SwiftUI `Text()`가 localization key path를 사용하게 만들기 위해 |
| `Shared/Resources/Localizable.xcstrings` | consent bullet title/description 6개 키에 `extractionState: manual` + ko/ja 번역 추가 | helper 수정 후 실제 번역 리소스까지 연결하기 위해 |

### Key Code

```swift
private struct InfoRow: View {
    let icon: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(description)
            }
        }
    }
}
```

```json
"Private & Encrypted": {
  "extractionState": "manual",
  "localizations": {
    "ja": { "stringUnit": { "state": "translated", "value": "非公開かつ暗号化" } },
    "ko": { "stringUnit": { "state": "translated", "value": "비공개 및 암호화" } }
  }
}
```

## Prevention

첫 실행 안내 화면처럼 테스트가 주로 English locale로만 도는 surface는, UI flow 검증과 별개로 localization leak review를 따로 해야 한다.
특히 helper가 `Text()`에 전달할 copy를 받는 구조라면 타입과 xcstrings 커버리지를 항상 같이 확인한다.

### Checklist Addition

- [ ] View/helper가 `Text()`에 전달할 레이블을 받을 때 `String` 대신 `LocalizedStringKey`를 사용했는지 확인
- [ ] 새 user-facing copy를 추가했으면 `Localizable.xcstrings`에 en/ko/ja가 모두 등록됐는지 확인
- [ ] English-only UI regression이 통과하더라도 first-launch sheet/empty state/info row는 별도 localization leak 점검을 수행

### Rule Addition (if applicable)

새 규칙 추가는 불필요하다.
기존 `.claude/rules/localization.md`의 Leak Pattern 1과 review checklist가 이미 정확히 이 사례를 커버한다.

## Lessons Learned

localized CTA와 title이 정상이어도, helper 내부의 `String` 경유 copy는 별도로 새는 경우가 있다.
또한 UI 테스트 안정화 작업은 접근성/fixture만이 아니라 locale-safe rendering contract까지 같이 점검해야, English 기준 pass 뒤에 숨어 있는 shipping regression을 막을 수 있다.
