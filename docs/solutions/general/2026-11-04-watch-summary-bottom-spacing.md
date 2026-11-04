---
tags: [watchos, swiftui, safe-area-inset, workout-summary, spacing]
date: 2026-11-04
category: general
status: implemented
severity: minor
related_files:
  - DUNEWatch/Views/SessionSummaryView.swift
  - DUNEWatchUITests/Smoke/WatchWorkoutFlowSmokeTests.swift
---

# Watch 운동 요약 하단 여백

## Problem

운동 요약을 맨 아래까지 스크롤하면 마지막 운동 내역과 고정된 완료 버튼이 붙어 보였다. `safeAreaInset(edge: .bottom, spacing: 0)`이 스크롤 영역과 버튼 사이의 간격을 없애고 있었다.

## Solution

`SessionSummaryView`의 하단 inset 간격을 Watch 토큰 `DS.Spacing.lg`(12pt)로 바꿨다. 저장 오류의 재시도 버튼에도 같은 간격을 적용하며 기존 버튼 높이와 저장 동작은 유지한다. [레이아웃 기준](../../design/layout-map/watch-summary-spacing.md)에 배치를 기록했다.

기존 캡처 테스트 3개는 홈에서 아직 화면 밖에 있는 탐색 버튼을 확인하다 실패했다. 요약 검증에 불필요한 홈 카드 탐색을 없애도록 기존 `--ui-watch-home-empty` fixture를 해당 캡처에만 지정했다. 앱의 홈 동작은 수정하지 않았다.

## Validation

전용 Apple Watch SE 3 (40mm), watchOS 27.2에서 유산소 요약 1건과 fixture 보정 후 근력·계단·저장 오류 캡처 3건이 통과했다. `.xcodebuild/watch-summary-spacing.log.result.json`의 최초 실패 3건은 홈 탐색 단계였으며, `.xcodebuild/watch-summary-spacing-retry.log.result.json`에 해당 3건의 통과를 별도로 보존한다. 앱 빌드·String Catalog 포맷 검사·diff 공백 검사도 통과했다.

[실제 화면 맵](../../design/phone-design-map/actual/watch/index.html)의 F01·F02·F03·F06·F07을 새로 캡처했다. F03은 맨 아래 스크롤 상태에서 운동 내역과 완료 버튼 사이 여백을 확인했다. F05 저장 중은 재캡처하지 않아 이전 이미지를 이 변경의 완료 증거로 사용하지 않는다. 기본 글씨만 확인했으며 요약 진입 시 기존 지표 가림 문제는 이번 수정 범위에 포함하지 않았다.

출하 전 기존 아이콘 작업과 분리한 `fix/watch-summary-bottom-spacing` 브랜치에 최신 `main`을 적용해 근력 요약 UI 1건을 추가로 실행했다. `.xcodebuild/watch-summary-ship-integration.log.result.json`에서 1/1 통과를 확인했고, 해당 실행의 F01·F03 새 원본으로 갱신했다. 5개 전문 관점과 최종 PR·앱 품질 리뷰에는 미해결 P1/P2/P3이 없다.

## Prevention

고정 버튼이 있는 스크롤 화면은 맨 아래 상태에서 마지막 내용과 버튼 사이의 간격을 확인한다. 캡처 테스트는 대상 화면과 무관한 홈 카드 위치에 의존하지 않는 fixture로 시작한다.

## Lessons Learned

하단 inset의 `spacing`은 스크롤 내용과 고정 버튼의 시각적 분리를 정한다. 버튼 자체를 작게 만들지 않고 이 간격으로 마지막 내용 아래 여유를 확보할 수 있다.
