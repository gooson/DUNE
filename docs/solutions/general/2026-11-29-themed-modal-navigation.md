---
tags: [swiftui, navigationstack, toolbar, sheet, artist-theme, ui-testing, dynamic-type]
category: general
date: 2026-11-29
severity: important
related_files:
  - DUNE/Presentation/Exercise/ExerciseView.swift
  - DUNE/Presentation/Exercise/ExerciseSessionDetailView.swift
  - DUNE/Presentation/Shared/Components/ArtistThemeBackground.swift
  - DUNEUITests/Visual/ArtistThemeNativeUITests.swift
related_solutions:
  - 2026-10-30-cardio-share-modal-background-and-drag.md
---

# iOS 모달의 내비게이션과 테마 원화

## 문제

좁은 화면에서 운동 상세를 열면 내비게이션 아래에 별도 완료 행이 나타났다. 이 행까지 시스템 표면이 노출되면서 파티스리 원화가 어두운 띠 아래에서 시작했다. 공용 작가 테마 시트는 상단과 좌측의 강한 음영 때문에 같은 테마의 일반 상세와 차이가 났다. 수동 운동 상세에서는 저장된 분류인 `strength`가 제목으로 노출됐고, 추천 장비의 큰 제목은 최대 접근성 글자 크기에서 일부가 잘렸다.

## 해결

- 좁은 운동 상세 시트의 `NavigationStack`에서 하나의 닫기 버튼을 관리한다. W28의 이름 편집은 상세 화면이 우측 버튼으로 제공한다. 넓은 운동 상세 패널은 자체 하단 완료를 사용한다.
- 공용 테마 시트의 음영은 상세 화면과 같은 세로 그라디언트를 쓴다. 일반 시트가 정지 원화를 쓰는 기존 동작은 유지한다. 아틀라스 공유는 불투명한 표시 표면과 기존 스크롤, 표시 크기, 닫기 방법을 유지한다.
- 수동 운동 상세와 이력은 운동 요약과 같은 운동명을 표시한다. 이력 조회에는 기존 운동 정의 ID를 사용한다. 추천 장비는 접근성 글자 크기에서 인라인 제목을 사용하고 본문 제목을 여러 줄에 표시한다.

## 재확인 방법

- 라이트·다크에서 새 PNG를 직접 열어 원화, 제목, 닫기·편집 버튼의 배치를 확인한다. 운동 이름 편집 취소, 상세 닫기와 같은 기록 다시 열기, 짧은 닫기 제스처 취소를 XCTest로 확인한다.
- 내비게이션 아래에서 스크롤 뷰가 늘어날 수 있다. 버튼이 내비게이션 안에 있는지 검사할 때 스크롤 뷰의 시작 좌표 대신 해당 `NavigationBar`의 프레임을 쓴다. UIKit이 노출한 제목은 바의 identifier로 일치시킨다. 제목의 위치가 필요한 검사는 바 안의 실제 `StaticText` 좌표를 확인한다.
- 앱 시트의 닫기·저장 책임과 플랫폼 공유·카메라 같은 자체 표시 표면을 확인한다. 정지 원화 자산의 포함 여부도 빌드에서 확인한다.

[레이아웃 기준](../../design/layout-map/modal-navigation.md) · [실제 화면과 기기별 출처](../../design/phone-design-map/actual/modal-navigation-2026-11-29/index.html)
