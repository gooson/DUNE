---
tags: [posture, voice-coaching, avfoundation, speech-synthesis, exercise-form]
date: 2026-03-22
category: plan
status: draft
---

# Plan: 음성 코칭 (Phase 4D)

## Overview

운동 폼 체크 중 checkpoint 판정 결과를 음성으로 피드백하여, 화면을 보지 않고도 교정 가능하게 한다.

## Affected Files

| Layer | File | Role | Change |
|-------|------|------|--------|
| Domain | `Domain/Models/FormCoachingMessage.swift` | 교정 메시지 데이터 모델 | **NEW** |
| Domain | `Domain/Services/FormVoiceCoach.swift` | 음성 코칭 서비스 (AVSpeechSynthesizer) | **NEW** |
| Domain | `Domain/Models/ExerciseFormRule.swift` | 체크포인트별 교정 메시지 추가 | MODIFY |
| Domain | `Domain/Models/ExerciseFormState.swift` | — | 변경 없음 |
| Presentation | `Presentation/Posture/RealtimePostureViewModel.swift` | FormVoiceCoach 연결 | MODIFY |
| Presentation | `Presentation/Posture/RealtimePostureView.swift` | 음성 코칭 토글 버튼 | MODIFY |
| Shared | `Shared/Resources/Localizable.xcstrings` | en/ko/ja 교정 메시지 번역 | MODIFY |
| Tests | `DUNETests/FormVoiceCoachTests.swift` | 음성 코칭 유닛 테스트 | **NEW** |

## Implementation Steps

### Step 1: FormCoachingMessage 모델 (Domain)

교정 메시지를 나타내는 데이터 구조체.

```swift
struct FormCoachingMessage: Sendable, Identifiable {
    let id = UUID()
    let checkpointName: String
    let message: String          // 이미 localized된 메시지
    let priority: Priority       // .warning(즉시), .caution(큐잉)

    enum Priority: Int, Comparable, Sendable {
        case caution = 0   // 주의 → 큐잉
        case warning = 1   // 위험 → 즉시

        static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
}
```

### Step 2: ExerciseFormRule — checkpoint 교정 메시지 추가

`FormCheckpoint`에 `coachingCue: String` 필드 추가. 간결한 교정 명령.

```swift
struct FormCheckpoint {
    // ... existing fields ...
    let coachingCue: String   // e.g. "Go deeper", "Keep your back straight"
}
```

3개 built-in rule (squat, deadlift, overhead press) 각각에 교정 메시지 추가.

### Step 3: FormVoiceCoach 서비스 (Domain)

핵심 로직:
- `AVSpeechSynthesizer` 래핑
- checkpoint 상태가 `.caution`/`.warning`이면 해당 `coachingCue`를 발화
- **반복 억제**: 동일 checkpoint는 최소 5초 간격
- **우선순위**: `.warning` → 현재 발화 중이더라도 큐에 우선 삽입
- **언어 자동 감지**: `Locale.current.language.languageCode` 기반 AVSpeechSynthesisVoice 선택
- **AVAudioSession**: `.playback` + `.duckOthers` (음악과 공존)

```swift
final class FormVoiceCoach {
    private let synthesizer = AVSpeechSynthesizer()
    private var lastSpokenTimes: [String: Date] = [:]  // checkpointName → lastSpoken
    private let cooldown: TimeInterval = 5.0
    private var isEnabled: Bool = false

    func setEnabled(_ enabled: Bool)
    func processFormState(_ state: ExerciseFormState, rule: ExerciseFormRule)
    func stop()
}
```

**Layer 고려사항**: `AVSpeechSynthesizer`는 AVFoundation 소속이지만 Domain에 넣지 않고 Data layer에 놓는 것도 고려. 그러나 이 서비스는 UI/SwiftData를 import하지 않고 Foundation+AVFoundation만 사용하므로, `Domain/Services/`에 배치해도 layer boundary 규칙을 위반하지 않음. 단, `import AVFoundation`이 필요하므로 **Data/Services/로 배치**.

**수정**: Domain에는 순수 로직만 → `FormVoiceCoach`는 `Data/Services/`에 배치.

### Step 4: RealtimePostureViewModel 연결

- `FormVoiceCoach` 인스턴스 보유
- `applyState()` 내에서 formState가 변경될 때마다 `voiceCoach.processFormState()` 호출
- `isVoiceCoachingEnabled: Bool` @Published 프로퍼티 추가
- `toggleVoiceCoaching()` 메서드 추가
- stop() 시 voiceCoach.stop() 호출

### Step 5: RealtimePostureView — 음성 코칭 토글

- 기존 toolbar에 speaker 아이콘 버튼 추가 (formMode 활성 시에만 표시)
- `speaker.wave.3` / `speaker.slash` 아이콘 토글
- 버튼 탭 → `viewModel.toggleVoiceCoaching()`

### Step 6: Localization (xcstrings)

- 교정 메시지 en/ko/ja 3개 언어:
  - Squat: "Go deeper" / "더 내려가세요" / "もっと深く"
  - Squat back: "Keep your back straight" / "허리를 펴세요" / "背中をまっすぐに"
  - Deadlift hip hinge: "Hinge at your hips" / "엉덩이를 뒤로 빼세요" / "股関節から曲げて"
  - Deadlift knee: "Bend your knees slightly" / "무릎을 살짝 굽히세요" / "膝を軽く曲げて"
  - OHP arm: "Extend your arms fully" / "팔을 끝까지 펴세요" / "腕を完全に伸ばして"
  - OHP shoulder: "Press straight overhead" / "머리 위로 똑바로 밀어세요" / "真上に押して"

### Step 7: Tests

`FormVoiceCoachTests.swift`:
- cooldown 동작: 5초 이내 동일 checkpoint 재발화 차단 확인
- priority 동작: warning이 caution보다 우선 처리
- 활성/비활성 토글: disabled 상태에서 발화 안 함
- formState 처리: normal 상태에서는 발화하지 않음
- 전체 checkpoint 커버리지: 각 운동의 모든 checkpoint에 coachingCue 존재

## Test Strategy

| 대상 | 테스트 방법 | Framework |
|------|-----------|-----------|
| FormVoiceCoach cooldown | 시간 조작 (Date injection) | Swift Testing |
| FormVoiceCoach priority | mock 상태로 호출 순서 검증 | Swift Testing |
| coachingCue 존재 | allBuiltIn 순회하며 빈 문자열 체크 | Swift Testing |
| AVSpeechSynthesizer | 실기기 수동 테스트 (시뮬레이터 미지원) | Manual |

## Risks / Edge Cases

| Risk | Mitigation |
|------|------------|
| TTS 시뮬레이터 미지원 | `AVSpeechSynthesizer` 호출을 별도 메서드로 격리, 테스트에서 mock 가능 |
| TTS 지연 > 500ms | `rate` 높임 (0.5 → 0.55), `preUtteranceDelay = 0` |
| 음악 앱과 충돌 | `.duckOthers` 옵션으로 음악 볼륨 일시 감소 |
| 빠른 렙에서 메시지 폭주 | cooldown 5초 + 현재 발화 중이면 큐 건너뜀 |
| 언어 감지 실패 | fallback to "en" |
| 운동 종료 후에도 발화 | `stop()` 에서 `synthesizer.stopSpeaking(at: .immediate)` |
