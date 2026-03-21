---
source: brainstorm/vision-pro-features
priority: p3
status: done
created: 2026-03-05
updated: 2026-03-22
---

# Vision Pro Phase 4-5: 소셜 + 고급 기능

## 목표
SharePlay 소셜 기능 및 고급 입력 방식 구현.

## 범위

### Shared Workout Space (G1)
- SharePlay로 친구와 운동 데이터 공유
- 각자의 세트/랩이 공간에 실시간 표시

### Voice-First Workout Entry (F3)
- "벤치프레스 80kg 8회" 음성 입력
- SFSpeechRecognizer + NLP 파싱

### Exercise Form Guide (C5)
- spatial guide foundation: exercise search + setup/form cue panel + target muscle visualization
- 차후: 3D 아바타 시연 및 실물 크기 가이드 배치
- Body tracking API 성숙 후 자세 비교

### Multi-Window Dashboard (E1)
- 각 메트릭을 독립 윈도우로 분리
- openWindow action으로 공간 배치

## 진행 현황

- [x] E1 Multi-Window Dashboard
  - condition/activity/sleep/body 전용 visionOS window 추가
  - 메인 dashboard에서 각 window open action 연결
  - shared workspace view model + unit test 추가
  - launch-arg smoke + screenshot artifact로 primary runtime placement 검증 완료
- [x] G1 Shared Workout Space foundation
  - Train 탭에서 SharePlay session start/join + realtime workout board 추가
  - GroupSessionMessenger로 exercise/set/rep/phase 상태를 참가자 간 동기화
  - late join participant replay와 local-only fallback 처리
- [x] F3 Voice-First Workout Entry
  - speech capture + command parser + draft preview foundation 추가
  - single-entry workout history 저장과 SwiftData exercise stack 연결 완료
  - locale-aware confirmation, TTS fallback, quick adjust editing 완료
  - true spatial audio cue와 multi-step session editing은 roadmap research로 전환
- [x] C5 Exercise Form Guide foundation
  - Activity 탭에서 지원 운동 guide 검색/선택
  - form cue + equipment + target muscle panel 추가
  - full avatar/body tracking 버전은 후속 scope로 유지

## 메모

- `/run` 배치로 G1 foundation(SharePlay workout board), E1, F3 foundation(speech capture + parser + draft preview) + single-entry persistence + confirmation polish까지 ship 완료됐다.
- 2026-03-22 기준 이 문서가 active에 남아 있던 이유는 shipped foundation과 future capability note가 한 파일에 섞여 있었기 때문이다.
- SharedWorldAnchors/spatial alignment, true spatial audio, body tracking, full-avatar는 hardware/API maturity와 실기기 검증이 필요한 roadmap note이며 active executable TODO로는 더 이상 유지하지 않는다.
- voice confirmation polish는 `todos/140-done-p2-vision-voice-feedback-confirmation.md`에서 정리했다.
- Phase 5A 실데이터 연결은 `todos/021-done-p1-vision-real-data-pipeline.md`로 정리됐다.
- Phase 5B UX polish 구현은 `todos/022-done-p2-vision-ux-polish.md`로 종료됐다.
- runtime spatial placement primary smoke는 `todos/107-done-p2-vision-window-placement-runtime-validation.md`로 닫았다.
- no-anchor utilityPanel fallback은 `todos/144-done-p3-vision-window-placement-no-anchor-fallback.md`로 닫았다.

## 완료 메모

- Phase 4-5에서 ship 가능한 foundation scope(E1/G1/F3/C5)는 모두 `done` 상태의 구현/solution 문서로 뒷받침된다.
- 남아 있던 advanced capability 아이디어는 `docs/brainstorms/2026-03-05-vision-pro-features.md`의 roadmap note로 유지하고, 이후 다시 실행할 때는 구체 acceptance criteria가 있는 새 TODO로 재생성한다.

## 기술 요구사항
- GroupActivities (SharePlay)
- SFSpeechRecognizer
- Body tracking (ARKit)
- SharedWorldAnchors (visionOS 26)

## 참고
- `docs/brainstorms/2026-03-05-vision-pro-features.md` Categories E, F, G
