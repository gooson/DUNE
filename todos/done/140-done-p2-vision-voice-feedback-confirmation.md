---
source: brainstorm/vision-pro-production-roadmap
priority: p2
status: done
created: 2026-03-16
updated: 2026-03-16
---

# visionOS voice feedback + confirmation polish

## 설명

`todos/023-done-p2-vision-phase4-remaining.md`로 정리된 F3 후속 중 이번 배치에서 닫을 수 있는 범위를 분리한다. 현재 voice quick entry는 transcript review와 single-entry save까지는 가능하지만, locale-aware confirmation, audio feedback, lightweight draft editing은 아직 부족하다.

## 구현 범위

- review/save 이후 locale-aware confirmation message를 제공한다.
- save 완료 시 audio-first feedback(TTS fallback)를 제공한다.
- draft preview에서 reps/weight/duration/distance를 quick adjust 방식으로 수정할 수 있게 한다.
- 관련 문자열을 en/ko/ja로 추가하고 테스트를 보강한다.

## 검증 기준

- [x] review/save 시 confirmation copy가 locale-aware summary를 표시한다.
- [x] transcription 중에는 speech feedback가 끼어들지 않는다.
- [x] strength/cardio draft의 quick adjust가 저장 규칙과 일치한다.
- [x] build와 targeted unit test가 통과한다.

## 참고

- `docs/plans/2026-03-16-vision-voice-feedback-confirmation.md`
- `docs/solutions/architecture/2026-03-08-vision-pro-voice-workout-entry-foundation.md`
- `docs/solutions/architecture/2026-03-08-vision-pro-voice-entry-persistence.md`
- `todos/023-done-p2-vision-phase4-remaining.md`
