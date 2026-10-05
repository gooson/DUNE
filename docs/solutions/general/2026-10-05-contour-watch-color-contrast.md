---
tags: [watchos, contour, theme, asset-catalog, contrast]
category: solution
date: 2026-10-05
status: implemented
severity: important
related_files:
  - Shared/Resources/Colors.xcassets
  - scripts/tests/test-contour-watch-colors.py
related_solutions: [2026-09-20-contour-atlas-theme]
---

# Contour Atlas 워치 배경 대비 수정

## Problem

워치에서 새 테마의 밝은 배경과 흰 글씨가 겹쳐 내용을 읽기 어렵다.
공유 Contour 색상 26개는 universal 기본값과 dark appearance만 제공했다.
watchOS는 시스템 Dark Mode를 지원하지 않으므로 어두운 시스템 UI를 근거로
공유 자산의 dark variant가 선택될 것이라고 가정하면 안 된다.
`WatchWaveBackground`가 사용하는 `ContourBackground`는 이 색상을 불투명하게 채운다.

## Solution

26개 Contour 색상에 appearance 조건 없는 `idiom: watch` 항목을 추가하고
기존 dark palette 값을 지정했다. 배경뿐 아니라 ink, accent, 보조 글씨와 지표 색상도
동일한 팔레트를 사용한다. 기존 universal light/dark 값은 그대로 유지한다.

## Prevention

- 워치에서 공유하는 새 색상은 watch idiom을 명시하고 실제 기기에서 확인한다.
- `python3 scripts/tests/test-contour-watch-colors.py`로 모든 Contour 자산의 워치 변형과
  주요 텍스트/배경 대비 4.5:1 이상을 검사한다.
- 색상 JSON 검사는 실제 화면 렌더링 검증을 대신하지 않는다.

## Lessons Learned

어두운 UI와 dark appearance 자산 선택은 별개다. 플랫폼별 자산 선택을 명시해야
불투명 배경을 공유할 때 흰 글씨와 밝은 배경이 조합되는 문제를 방지할 수 있다.

## Validation

- 색상 회귀 검사 2개 통과.
- `actool --platform watchsimulator --target-device watch` 컴파일 통과.
- `xcodebuild build -scheme DUNEWatch -destination 'generic/platform=watchOS Simulator'`
  빌드 통과 (`/tmp/contour-watch-build.log`).
- `scripts/build-ios.sh`: iOS/embedded Watch 통합 빌드 성공.
- Watch UI 전체 실행: 기존 13개 통과, 새 테마 테스트의 컨테이너 AXID 검사 1개 실패.
  실제 버튼 AXID로 수정 후 해당 테스트 1개 통과 (`/tmp/contour-watch-ui-retry.log`).
- Apple Watch Series 12 (42mm), watchOS 27.0: 홈과 운동 목록 캡처에서
  어두운 배경과 흰 글씨 표시를 직접 확인.
- 추가 전체 재실행은 사용자의 핵심 작업·속도 우선 요청으로 대기 중 취소했다.
  최종 상태에서 단일 전체 실행 통과라고 주장하지 않는다.
- 보안/성능/아키텍처/데이터 정합성/단순성 및 SwiftUI/UX 리뷰: P1/P2/P3 0건.
- iPhone에서 실제 워치로 테마 동기화하는 실기기 흐름은 미검증.

## Reference

- [Apple Human Interface Guidelines: Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode)
