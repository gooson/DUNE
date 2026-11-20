---
tags: [avfoundation, avqueueplayer, audio-session, artist-theme, arctic-dawn]
category: architecture
date: 2026-11-20
severity: important
related_files:
  - DUNE/Presentation/Shared/Components/ArtistThemeBackground.swift
  - DUNETests/ArtistThemeEditionTests.swift
related_solutions:
  - architecture/2026-11-19-artist-theme-native-rollout.md
---

# 장식용 테마 영상 재생 중 외부 음악 유지

## 증상과 원인

오로라 테마로 알림을 열었을 때 듣던 음악이 멈췄다는 보고가 있었다. 알림 선택 핸들러는 화면 이동을 요청하고, 활성 상태가 된 탭이나 상세 화면에서 테마 영상이 시작된다. 오로라 자산에는 영상 트랙만 있다. 기본 오디오 연결 상태에서는 음소거된 플레이어도 재생을 시작할 때 앱의 공유 오디오 세션을 활성화할 수 있다. [Apple의 플레이어 오디오 연결 동작](https://developer.apple.com/documentation/avfoundation/avplayer/disconnectedfromsystemaudio)

## 수정

공용 배경 뷰는 빈 `AVQueuePlayer`를 만들고 `setDisconnectedFromSystemAudio(true)`를 호출한다. 완료 콜백이 메인 액터에서 현재 플레이어의 객체 동일성을 확인한 뒤 영상 루프를 연결하고 재생한다. 준비 중 뷰가 사라지거나 다른 테마를 선택하면 이전 요청은 재생을 시작할 수 없다. 영상의 첫 프레임이 준비될 때까지 기존 포스터가 보인다.

## 재발 방지

무음 파일 검사와 함께 실제 뷰가 만든 플레이어의 `disconnectedFromSystemAudio` 값을 확인한다. 알림함에서 운동 알림을 여는 UI 검사는 상세 화면 이동을 검증한다. 실기기 청취 확인 시에는 다른 앱에서 음악을 재생하고 시스템 알림을 눌러 오로라 모션이 시작되는 동안 같은 곡이 계속 진행되는지 확인한다.
