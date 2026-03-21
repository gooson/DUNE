---
tags: [posture, voice-coaching, avspeechsynthesizer, realtime, cooldown, localization]
date: 2026-03-22
category: architecture
status: implemented
---

# Voice Coaching Pipeline (Phase 4D)

## Problem

운동 폼 체크(Phase 4B)는 시각적 피드백만 제공했다. 운동 중 화면을 볼 수 없는 사용자에게 음성으로 교정 피드백을 제공할 방법이 없었다.

## Solution

기존 `ExerciseFormAnalyzer` 파이프라인에 `FormVoiceCoach`를 추가. checkpoint 판정 결과(caution/warning)를 `AVSpeechSynthesizer`를 통해 음성으로 피드백.

### Architecture

```
ExerciseFormRule (Domain)
    └─ FormCheckpoint.coachingCue: raw English key (locale-free)

FormVoiceCoach (Data/Services)
    └─ processFormState() → cooldown check → priority selection → speak
    └─ speak() → String(localized:) at speak-time → AVSpeechUtterance
    └─ Cached: checkpointsByName per rule, AVSpeechSynthesisVoice per init

RealtimePostureViewModel (Presentation)
    └─ applyState() → voiceCoach.processFormState()
    └─ toggleVoiceCoaching() ↔ toolbar speaker button
```

### Key Design Decisions

1. **Raw key in Domain, localize at speak time**: 초기 구현은 `String(localized:)` in static let. 리뷰에서 P2 — Domain은 locale-free 유지. 해결: `coachingCue`는 raw English key 저장, `FormVoiceCoach.speak()`에서 `String(localized: String.LocalizationValue(text))`로 런타임 resolve.

2. **FormCoachingMessage in Data layer**: 초기 구현은 Domain에 배치. 리뷰에서 P1 — Data-layer 전용 DTO는 Domain에 불필요. 해결: FormVoiceCoach.swift 내부로 이동.

3. **Hot-path 최적화**: `processFormState()`는 30fps 경로. 초기 구현은 매 프레임 Dictionary rebuild + Array build. 리뷰에서 P2 — O(N) 불필요 할당. 해결:
   - `cachedCheckpoints`: rule 변경 시에만 invalidate
   - `isSpeaking` guard를 루프 전으로 이동 (대부분 early exit)
   - inline max tracking (Array 할당 제거)

4. **Cooldown 5초 + single-message-per-frame**: 빠른 렙에서 메시지 폭주 방지.

5. **AVAudioSession duckOthers**: 음악과 공존, 코칭 시 볼륨 자동 감소.

### Files

| Layer | File | Role |
|-------|------|------|
| Domain | `ExerciseFormRule.swift` | `coachingCue` field (raw English key) |
| Data | `FormVoiceCoach.swift` | TTS + cooldown + priority + FormCoachingMessage |
| Presentation | `RealtimePostureViewModel.swift` | voiceCoach lifecycle |
| Presentation | `RealtimePostureView.swift` | speaker toggle button |
| Tests | `FormVoiceCoachTests.swift` | cooldown, priority, toggle, coverage |

## Prevention

### Domain locale-free 패턴
- Domain 모델에 `String(localized:)` 호출 금지 → raw key 저장, Data/Presentation에서 resolve
- static let 안에서 locale-dependent 초기화는 프로세스 수명 동안 고정됨 → 동적 resolve 사용

### 30fps hot-path 패턴 (FormVoiceCoach 추가)
- 규칙 불변 데이터의 Dictionary 조회 → init/set 시점에 캐시, frame마다 rebuild 금지
- early exit 가드를 루프/할당 이전에 배치
- 중간 배열 불필요 → inline max tracking

## Lessons Learned

1. AVSpeechSynthesizer는 시뮬레이터에서 무음이지만 API 호출은 정상 동작 — 유닛 테스트에서 cooldown/priority 로직 검증 가능
2. Domain model의 `static let` + `String(localized:)`는 프로세스 시작 시 locale을 캡처해 고정함 — 런타임 언어 변경에 대응 불가
3. 음성 코칭은 시각 피드백과 독립적으로 토글 가능해야 함 — 운동 중 번갈아 사용하는 패턴이 자연스러움
