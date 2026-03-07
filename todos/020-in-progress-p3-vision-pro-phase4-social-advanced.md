---
source: brainstorm/vision-pro-features
priority: p3
status: in-progress
created: 2026-03-05
updated: 2026-03-07
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
- [ ] G1 Shared Workout Space
- [ ] F3 Voice-First Workout Entry
- [x] C5 Exercise Form Guide foundation
  - Activity 탭에서 지원 운동 guide 검색/선택
  - form cue + equipment + target muscle panel 추가
  - full avatar/body tracking 버전은 후속 scope로 유지

## 메모

- 이번 배치는 `/run`으로 E1만 ship 완료.
- SharePlay(GroupActivities/SharedWorldAnchors)와 voice/body tracking/full-avatar는 capability 및 API 스캐폴드가 별도 필요하므로 후속 구현으로 남김.

## 기술 요구사항
- GroupActivities (SharePlay)
- SFSpeechRecognizer
- Body tracking (ARKit)
- SharedWorldAnchors (visionOS 26)

## 참고
- `docs/brainstorms/2026-03-05-vision-pro-features.md` Categories E, F, G
