---
topic: artist-theme-audio-isolation
date: 2026-11-20
status: implemented
confidence: high
related_solutions: [2026-11-19-artist-theme-native-rollout]
related_brainstorms: []
---

# 테마 배경을 열 때 듣던 음악 유지

알림을 눌러 앱에 들어오면 활성 화면의 오로라 영상이 재생된다. 번들의 `arcticDawn.mp4`에는 비디오 트랙만 있지만, 기본 `AVQueuePlayer`는 재생을 시작하면서 공유 오디오 세션을 활성화할 수 있다.

## 구현 범위

1. `DUNE/Presentation/Shared/Components/ArtistThemeBackground.swift`에서 빈 플레이어를 시스템 오디오에서 분리한다. 비동기 완료 후 현재 뷰가 소유한 플레이어에만 루프를 붙이고 재생한다. 이 방식은 음성 코칭 등 다른 기능이 사용하는 앱의 오디오 설정을 보존한다.
2. `DUNETests/ArtistThemeEditionTests.swift`에서 실제 오로라 영상을 쓰는 뷰를 윈도우에 다시 붙이고 재생 중인 플레이어의 오디오 연결 상태를 검사한다. 뷰가 사라지거나 테마가 바뀌는 동안 이전 완료 콜백이 도착하는 경우를 고려한다.

## 검증

- iPhone 시뮬레이터에서 `ArtistThemeEditionTests`를 실행해 재생 조건, 무음 자산, 오디오 분리와 테마 대비를 확인한다.
- `ActivityExerciseRegressionTests/testNotificationWorkoutRouteOpensMockWorkoutDetail`로 알림함에서 상세 화면까지의 경로를 확인한다. 외부 음악 앱을 재생하는 실기기 상황은 별도 검증 범위다.
