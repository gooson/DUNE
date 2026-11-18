---
tags: [forest, woodcut, fog, swiftui, animation, reduced-motion]
date: 2026-11-18
category: solution
status: implemented
related_files:
  - DUNE/Presentation/Shared/Components/ForestWaveBackground.swift
  - DUNE/Presentation/Shared/Components/ForestHeroArtwork.swift
  - DUNETests/ForestSilhouetteShapeTests.swift
---

# 숲 목판화에서 솔잎과 안개를 독립적으로 움직이기

## 문제

숲 그림 전체를 천천히 이동시키면 짧게 보는 동안 변화를 알아보기 어렵다. 수관 전체에 기울기를 주면 굵은 가지까지 휘어 흔들림이 과해진다. 승인된 시안에서는 가장 큰 변화가 앞안개와 골안개의 농도이고, 나무에서 움직이는 부분은 가는 잔가지와 솔잎 끝이다.

## 구현

- 원화의 가로세로 비율과 자르는 기준점을 한 번 정해 원화와 두 투명 솔잎 레이어에 같이 쓴다. 두 마스크의 중심·반경은 [브라우저 시안의 `forest-plate`](../../design/theme-map/themes/forest-green-direction.html) 좌표를 따른다. 마스크 아래에는 원화를 그대로 그린다.
- 24초를 한 주기로 삼아 앞안개의 위치와 농도를 먼저 바꾸고, 낮은 골안개는 나중까지 남겨 둔다. 같은 안개 질감을 두 번 사용한다. 원본 SVG의 필터는 에셋을 만들 때 래스터화하고 앱에서는 투명 PNG를 합성한다.
- 원화는 타임라인 바깥에 두고 작은 움직임과 안개만 초당 최대 20회 갱신한다. 동작 줄이기·저전력·비활성 상태에서는 9초 시점의 농도를 쓴다. 테마 선택 샘플도 앱의 동일한 정지 그림을 사용한다.
- Activity·Wellness·Life 카드는 콘텐츠와 그림을 별도 영역으로 배치한다. 폭이 좁거나 글씨가 크거나 Activity의 주간 기록을 펼치면 장식이 아래로 이동한다. 알림과 운동 목록은 기존 실루엣을 명시적으로 선택한다.

## 재발 방지

모션을 바꾸면 한 주기의 시작·중간·맑은 시점·재충전·반복 경계를 비교한다. 솔잎의 이동량과 재생 조건은 `ForestCanopyMotionTests`가 검증한다. 기기에서는 같은 위치의 Today 화면을 정상 속도로 연속 촬영해 탭 전환 뒤에도 두 안개층이 걷히는지 확인한다. 정지 캡처로는 카드의 잘림·글자·조작 영역을 확인할 수 있다.
