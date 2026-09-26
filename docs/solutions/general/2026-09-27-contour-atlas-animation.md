---
tags: [swiftui, contour-atlas, phase-animator, reduce-motion, scene-phase]
category: general
date: 2026-09-27
status: draft
severity: minor
related_files:
  - DUNE/Presentation/Shared/Components/ContourBackground.swift
  - DUNEUITests/Visual/ContourThemeTests.swift
related_solutions:
  - 2026-09-20-contour-atlas-theme
  - 2026-09-27-simulator-test-serialization
---

# Contour Atlas 배경 애니메이션

## Problem

Contour Atlas는 다른 움직이는 테마와 달리 등고선이 정적으로 표시됐다. 캐시된 지형과 불투명 카드의 가독성을 유지하면서 배경에 느린 움직임을 추가할 필요가 있었다.

## Solution

- 기존 `ContourLines` 좌표 캐시를 유지하고 `phaseAnimator`로 scale, rotation, offset만 바꾼다. 기본 레이어의 편도 시간은 8초, 왕복 주기는 16초다.
- Tab 보조 레이어는 편도 11초, 왕복 22초로 움직여 두 레이어의 반복 위치가 항상 같지 않게 한다.
- `waveReducedMotion`으로 시스템 동작 줄이기와 정적 미리보기 정책을 함께 적용한다. 비활성 scene과 Watch 스타일에서는 animator를 만들지 않는다.
- Scene 변경 시 0.4초 opacity 전환을 사용하며 동작 줄이기에서는 전환 애니메이션도 생략한다.
- 배경 clipping, hit-testing 비활성화, 접근성 트리 제외를 유지한다. 카드와 지도 참조 표시는 transform 대상에 넣지 않는다.
- UI 테스트에 백그라운드 진입 → 복귀 → Today/Activity/Settings 이동과 테마 선택 유지 검증을 추가했다.

## Validation

- 최신 main 병합 후 `scripts/build-ios.sh`: 성공(iOS 및 embedded Watch 컴파일).
- SwiftUI, Apple UX, UI-test 전문가의 코드 검토: actionable findings 없음.
- 앞선 시뮬레이터 캡처 두 장에서 등고선 위치 변화와 카드 위치 유지를 직접 확인했다.
- 전체 CI 회귀 실행: `https://github.com/gooson/DUNE/actions/runs/36263017318` (사용자 요청으로 전체 UI 대기 중단).
- CI iOS 단위 테스트: Swift Testing 2,236개 및 XCTest 9개 통과. Watch 단위 테스트: 129개 통과.
- 부가 Watch UI: 10개 중 7개 실패. 6개는 fixture 운동 식별자 탐색, 1개는 추가 무게 입력 요소 탐색 실패다. 해당 Watch 코드·테스트는 main 대비 변경이 없고 잠금 이후 10개 테스트가 실행됐으므로 변경된 잠금/Contour와의 인과관계는 확인되지 않았다. main baseline 실행이 없어 기존 실패라고 확정하지 않는다. 필수 iOS 전체 UI 결과와 별도로 기록한다.
- 보안·성능·구조·데이터 정합성·단순성 및 최종 PR 검토: P1/P2/P3 모두 0건. Agent-Native는 해당 파일 변경이 없어 제외했다.
- 별도 타임아웃 조사에서 시뮬레이터 경합을 제거한 picker 테스트는 180초 제한을 유지한 채 71.770초에 통과했다. 실행기 잠금과 워크트리 식별 회귀 테스트 9개도 통과했다.
- 한계: UI assertion은 화면 조작과 테마 선택을 확인한다. 픽셀 비교, 실제 기기 FPS/전력, 동작 줄이기 전환의 시각적 검증은 포함하지 않는다.

## Prevention

새 배경 모션은 기존 정적 미리보기·접근성·scene 정책을 함께 소비한다. 정적 지형 데이터를 프레임마다 다시 계산하지 않고, 장식 모션과 정보 카드의 레이아웃을 분리한다. 관련 테스트 통과를 전체 UI 회귀 통과로 보고하지 않는다.

## Lessons Learned

배경 전체를 새로 생성하는 대신 캐시된 도형의 transform만 바꾸면 기존 디자인을 유지하면서 움직임을 추가할 수 있다. 구현 이후 발견한 검증 환경 문제를 해결했더라도 원래 작업의 리뷰와 ship까지 다시 이어가야 완료다. 기존 규칙으로 다룰 수 있어 새 `.claude/rules`는 추가하지 않았다.

## 최종 게이트 변경

사용자가 전체 UI 결과를 기다리지 않고 스모크 통과를 기준으로 ship하도록 명시했다. 따라서 전체 UI 통과는 주장하지 않으며, 현재 브랜치의 스모크 결과를 최종 게이트로 사용한다. PR: https://github.com/gooson/DUNE/pull/776 .
