---
tags: [posture, exercise-form, voice-coaching, phase-gating, testing, inactive-checkpoint]
category: architecture
date: 2026-03-22
severity: important
related_files:
  - DUNE/Domain/Models/ExerciseFormState.swift
  - DUNE/Domain/Services/ExerciseFormAnalyzer.swift
  - DUNE/Data/Services/FormVoiceCoach.swift
  - DUNE/Presentation/Posture/Components/FormCheckOverlay.swift
  - DUNETests/ExerciseFormAnalyzerTests.swift
  - DUNETests/FormVoiceCoachTests.swift
related_solutions:
  - docs/solutions/architecture/2026-03-22-exercise-form-check-pipeline.md
  - docs/solutions/architecture/2026-03-22-voice-coaching-pipeline.md
status: implemented
---

# Solution: Gate Inactive Checkpoints Before Feedback

## Problem

운동 폼 분석기는 active phase 밖의 checkpoint도 `.normal`로 내보냈다. 이 값은 "측정하지 않음"이 아니라 "좋음"으로 해석되기 때문에, 음성 코칭과 오버레이가 setup/lockout 프레임에서도 실제 평가가 끝난 것처럼 보이거나 칭찬을 말할 수 있었다.

### Symptoms

- `FormVoiceCoach`가 active phase가 아닌 checkpoint의 `.normal` 상태를 positive cue 후보로 취급했다.
- `FormCheckOverlay`가 평가되지 않은 checkpoint를 active 상태와 시각적으로 구분하지 못했다.
- `AVSpeechSynthesizer` 기반 테스트는 실제 말하기 여부를 직접 검증하기 어려워 회귀를 잡기 어려웠다.
- iOS/watch unit target에 `Foundation` import가 빠져 테스트 빌드가 깨졌다.

### Root Cause

`CheckpointResult`가 "현재 phase에서 평가 대상인지"를 표현하지 못해, downstream consumer가 `status`만 보고 의미를 추론했다. active/inactive라는 제어 정보가 타입 밖에 숨어 있었고, 테스트도 side effect를 직접 관찰할 수 없는 구조였다.

## Solution

`CheckpointResult`에 `isActivePhase`를 추가하고, analyzer가 각 frame에서 이를 계산해 함께 전달하도록 바꿨다. 이후 feedback consumer는 `status`만 보지 않고 먼저 `isActivePhase`를 검사하게 수정했다. 테스트는 speech hook을 주입해 실제 spoken cue를 단정할 수 있게 만들었다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Domain/Models/ExerciseFormState.swift` | `CheckpointResult.isActivePhase` 추가 | 평가 여부를 결과 타입에 명시 |
| `DUNE/Domain/Services/ExerciseFormAnalyzer.swift` | phase별 활성 여부 계산 및 score/filter에 재사용 | consumer가 동일 기준을 공유하도록 보장 |
| `DUNE/Data/Services/FormVoiceCoach.swift` | inactive checkpoint skip, test speech hook 추가 | inactive praise 방지 및 deterministic test 지원 |
| `DUNE/Presentation/Posture/Components/FormCheckOverlay.swift` | inactive checkpoint를 muted style로 표시 | "미평가"와 "정상"을 시각적으로 분리 |
| `DUNETests/ExerciseFormAnalyzerTests.swift` | inactive flag 회귀 테스트 추가 | analyzer contract 보호 |
| `DUNETests/FormVoiceCoachTests.swift` | spoken cue 직접 검증 + inactive skip 테스트 추가 | voice coaching 회귀 차단 |
| `DUNEWatchTests/GaitAnalyzerTests.swift` | `Foundation` import 추가 | watch unit target 빌드 복구 |

### Key Code

```swift
let isActivePhase = checkpoint.activePhases.contains(currentPhase)

results.append(CheckpointResult(
    checkpointName: checkpoint.name,
    isActivePhase: isActivePhase,
    status: isActivePhase ? checkpoint.evaluate(degrees: degrees) : .normal,
    currentDegrees: degrees
))

for result in state.checkpointResults {
    guard result.isActivePhase else { continue }
    ...
}
```

## Prevention

### Checklist Addition

- [ ] 결과 타입이 consumer에게 필요한 제어 정보를 충분히 담고 있는지 확인한다.
- [ ] `normal` 같은 성공 상태를 "미평가"의 대체값으로 재사용하지 않는다.
- [ ] AVFoundation, network, timer 같은 side effect 서비스는 테스트 전용 observation hook 또는 injectable dependency를 둔다.
- [ ] test target에서 새 Foundation 심볼을 쓰면 import 누락 여부까지 함께 확인한다.

### Rule Addition (if applicable)

새 규칙 파일 추가는 불필요했다. 대신 form pipeline 변경 리뷰 시 "inactive 결과가 downstream에서 positive/visible 상태로 해석되지 않는가"를 점검 항목으로 삼는다.

## Lessons Learned

- frame-by-frame 분석 결과는 값 자체보다 "언제 유효한 값인가"를 함께 전달해야 downstream 오해를 막을 수 있다.
- UI와 voice feedback이 같은 domain result를 소비할 때는 active/inactive semantics를 공통 타입 수준에서 고정하는 편이 안전하다.
- side-effecting 서비스를 관찰 가능한 구조로 만들면 테스트가 "컴파일만 되는 상태"에서 "행동을 검증하는 상태"로 올라간다.
