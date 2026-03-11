---
tags: [ai, foundation-models, workout-template, natural-language, localization, intent-parsing]
category: general
date: 2026-03-12
severity: important
related_files:
  - DUNE/Data/Services/AIWorkoutTemplateGenerator.swift
  - DUNE/Domain/Protocols/NaturalLanguageWorkoutGenerating.swift
  - DUNE/Presentation/Exercise/Components/CreateTemplateView.swift
  - DUNETests/AIWorkoutTemplateGeneratorTests.swift
  - Shared/Resources/Localizable.xcstrings
related_solutions:
  - docs/solutions/architecture/2026-03-09-natural-language-workout-template-generation.md
  - docs/solutions/general/2026-03-09-natural-language-workout-template-failure-debugging.md
  - docs/solutions/general/2026-03-12-activity-ai-workout-builder-entry.md
---

# Solution: AI workout builder natural-language reliability

## Problem

초보자형 자연어 요청이 AI workout builder에서 자주 실패했다. 모델 문제가 아니라,
자연어 의도 해석 없이 exercise catalog exact lookup으로 너무 빨리 내려가는 구조가 원인이었다.

### Symptoms

- `어깨 운동 만들어줘`, `집에서 맨몸 상체 운동` 같은 broad prompt가 템플릿 생성 실패로 끝났다.
- `burpee`, `mobility` 같은 unsupported 스타일 요청이 generic no-match처럼 보여 실패 이유가 불명확했다.
- 일본어 prompt와 `20分`, `1時間` 같은 시간 표현은 사실상 해석되지 않아 locale parity가 깨졌다.

### Root Cause

- `AIWorkoutTemplateGenerator`가 broad request를 body part / equipment / category / duration으로 먼저 구조화하지 않았다.
- unsupported / ambiguous / no-match 상태가 분리되지 않아 사용자 복구 문구가 거칠었다.
- heuristic table과 duration parsing이 한/영 위주라 일본어 locale이 fallback path로 빠졌다.

## Solution

생성 전에 prompt intent를 파싱하고, tool search는 exact-name lookup이 아니라
의도 기반 후보 확장 + score 정렬로 바꿨다. 동시에 unsupported/broad failure를 typed error로 분리하고,
UI에는 예시가 포함된 recovery copy를 노출했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Data/Services/AIWorkoutTemplateGenerator.swift` | `WorkoutPromptIntent`, preflight, keyword maps, scored search 도입 | 자연어 요청을 구조화하고 broad prompt를 catalog query로 확장하기 위해 |
| `DUNE/Domain/Protocols/NaturalLanguageWorkoutGenerating.swift` | `ambiguousPrompt`, `unsupportedRequest` error 추가 | 실패 이유를 typed path로 전달하기 위해 |
| `DUNE/Presentation/Exercise/Components/CreateTemplateView.swift` | broad / unsupported / no-match별 localized recovery message 추가 | 초보자에게 다음 입력 예시를 명확히 보여주기 위해 |
| `DUNETests/AIWorkoutTemplateGeneratorTests.swift` | broad Korean/Japanese prompt, home/bodyweight preference, unsupported preflight, Japanese duration 회귀 테스트 추가 | heuristic 회귀를 막기 위해 |
| `Shared/Resources/Localizable.xcstrings` | 새 에러 문구 ko/ja 번역 추가 | user-facing error copy를 locale-safe하게 유지하기 위해 |

### Key Code

```swift
let promptIntent = Self.promptIntent(for: trimmedPrompt)
if let preflightError = Self.preflightError(for: promptIntent) {
    throw preflightError
}

let matches = AIWorkoutTemplateGenerator.searchMatches(for: query, library: library)
```

```swift
static func requestedDurationMinutes(in normalizedQuery: String) -> Int? {
    let pattern = #"(?<!\d)(\d{1,3})\s*(분|시간|分|時間|min|mins|minute|minutes|hr|hrs|hour|hours)"#
    ...
}
```

## Prevention

### Checklist Addition

- [ ] 자연어 heuristic을 추가할 때 `ko/en/ja` parity를 filler phrase, keyword map, unsupported keyword, duration unit까지 함께 점검한다.
- [ ] broad request를 처리하는 새 분기에는 `ambiguous`, `unsupported`, `no-match` recovery copy가 각각 존재하는지 확인한다.
- [ ] search fallback이 generic all-exercise scan으로 내려갈 때도 score 0 후보가 그대로 노출되지 않는지 확인한다.

### Rule Addition (if applicable)

새 rule 파일은 추가하지 않았다. 이 문제는 문서화와 회귀 테스트로 관리하는 것이 현재 범위에 더 적합했다.

## Lessons Learned

- 온디바이스 LLM 품질 문제처럼 보이는 실패도 실제로는 tool contract와 catalog search shape 문제인 경우가 많다.
- beginner-facing natural language는 exact exercise name보다 body part / duration / equipment intent를 먼저 파악해야 성공률이 올라간다.
- locale 대응은 UI 번역만으로 끝나지 않고, heuristic parser와 duration regex까지 같이 맞춰야 한다.
