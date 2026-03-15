---
tags: [visionos, speech, tts, localization, accessibility]
category: architecture
date: 2026-03-16
severity: important
related_files:
  - DUNE/Presentation/Vision/VisionVoiceWorkoutEntryViewModel.swift
  - DUNEVision/Presentation/Activity/VisionVoiceWorkoutEntryCard.swift
  - DUNETests/VisionVoiceWorkoutEntryViewModelTests.swift
  - Shared/Resources/Localizable.xcstrings
  - todos/140-done-p2-vision-voice-feedback-confirmation.md
related_solutions:
  - docs/solutions/architecture/2026-03-08-vision-pro-voice-workout-entry-foundation.md
  - docs/solutions/architecture/2026-03-08-vision-pro-voice-entry-persistence.md
---

# Solution: Vision Voice Feedback Confirmation

## Problem

Vision Pro voice quick entry는 transcript review와 single-entry save까지는 연결됐지만, review/save 이후의 사용자 피드백은 generic text 한 줄에 머물러 있었다. 또한 parsed draft를 미세 조정하려면 transcript를 다시 손봐야 했고, 새 quick adjust affordance를 추가하면 접근성 라벨도 같이 챙겨야 했다.

### Symptoms

- review/save 후 어떤 운동이 저장 준비/저장 완료됐는지 locale-aware summary가 보이지 않았다.
- draft preview에서 reps/weight/duration/distance를 바로 조정할 수 없었다.
- icon-only quick adjust 버튼은 VoiceOver 기준으로 의미가 드러나지 않았다.

### Root Cause

F3를 foundation과 persistence까지 먼저 ship하면서, confirmation UX/TTS/lightweight editing 같은 polish layer가 별도 범위로 남았다. 그 결과 feedback 생성 로직이 generic message에 묶여 있었고, speech output도 transcription path와 분리된 abstraction이 없었다.

## Solution

`VisionVoiceWorkoutEntryViewModel`에 locale-aware summary builder와 `VisionVoiceWorkoutSpeaking` abstraction을 추가하고, `VisionVoiceWorkoutEntryCard`에는 metric quick adjust UI와 accessibility label을 붙였다. review/save confirmation은 `xcstrings` format string으로 관리하고, transcription 중에는 spoken feedback를 생략하도록 state gating을 넣었다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Vision/VisionVoiceWorkoutEntryViewModel.swift` | speaker protocol, localized summary builder, quick adjust action, transcript edit 시 speech stop 추가 | text/TTS confirmation과 lightweight editing을 shared state layer에서 테스트 가능하게 유지 |
| `DUNEVision/Presentation/Activity/VisionVoiceWorkoutEntryCard.swift` | draft metric quick adjust UI, icon button accessibility label 추가 | visionOS surface에서 transcript 재입력 없이 draft를 조정하고 VoiceOver도 대응 |
| `DUNETests/VisionVoiceWorkoutEntryViewModelTests.swift` | review/save summary, speech trigger, draft adjust, transcript edit stop coverage 추가 | polish layer 회귀를 deterministic test로 고정 |
| `Shared/Resources/Localizable.xcstrings` | `Ready to save %@.`, `Saved %@.`, `%@ reps`, adjust accessibility labels 추가 | en/ko/ja confirmation/accessibility copy를 일관되게 관리 |
| `todos/020-in-progress-p3-vision-pro-phase4-social-advanced.md` | F3 진행 현황을 confirmation polish 완료 기준으로 갱신 | 상위 TODO 상태를 실제 ship 범위와 일치 |
| `todos/023-in-progress-p2-vision-phase4-remaining.md` | 남은 F3 범위를 spatial audio + multi-step editing으로 축소 | 다음 batch 범위를 더 명확하게 유지 |

### Key Code

```swift
private func reviewFeedbackMessage(for draft: VisionVoiceWorkoutDraft) -> String {
    String(
        format: String(localized: "Ready to save %@."),
        locale: currentLocale,
        draftSummary(for: draft)
    )
}

private func speakFeedback(_ message: String) {
    guard !isListening, !message.isEmpty else { return }
    speaker.speak(message, localeIdentifier: localeIdentifier)
}
```

```swift
Button(action: decrement) {
    Image(systemName: "minus.circle.fill")
}
.buttonStyle(.bordered)
.accessibilityLabel(decrementLabel)
```

## Prevention

voice follow-up처럼 UX polish가 남는 기능은 foundation/persistence ship 직후 별도 TODO로 분리해 닫는 편이 안전하다. 특히 icon-only control을 추가할 때는 접근성 라벨과 localized format string을 같은 변경에 포함해야 나중에 품질 게이트에서 뒤늦게 막히지 않는다.

### Checklist Addition

- [ ] icon-only control을 추가할 때 `accessibilityLabel`을 함께 넣었는지 확인한다.
- [ ] TTS/voice feedback는 transcription service와 분리된 protocol로 감쌌는지 확인한다.
- [ ] localized confirmation summary는 `xcstrings` format string과 targeted test로 함께 고정한다.

### Rule Addition (if applicable)

새 `.claude/rules/` 추가는 필요 없었다. 기존 `localization.md`, `testing-required.md`, `design-system`/UX 기준 안에서 해결 가능했다.

## Lessons Learned

Vision Pro voice entry는 full spatial audio를 기다리지 않아도 TTS fallback, localized summary, quick adjust만으로 체감 완성도가 크게 올라간다. 또한 polish 단계의 접근성 이슈는 구현 직후보다 품질 게이트에서 더 잘 드러나므로, icon-only affordance가 생기는 순간 바로 라벨까지 넣는 습관이 중요하다.
