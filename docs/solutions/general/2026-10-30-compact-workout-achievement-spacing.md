---
tags: [swiftui, workout, achievement, badge, spacing, design-map]
category: general
date: 2026-10-30
severity: minor
related_files:
  - DUNE/Presentation/Shared/Components/UnifiedWorkoutRow.swift
related_solutions: []
---

# 최근 운동 성취 배지와 행 여백 정리

## Problem

최근 운동의 5K 성취가 별도 버튼처럼 보이고 행의 높이가 불필요하게 커졌다. 26×30pt 메달 원판에 아래로 이동한 리본을 겹치고, 바깥 그라데이션·테두리·8pt 세로 패딩을 더한 것이 원인이다. 내용의 2pt 행간에 비해 성취 장식이 과도했다.

## Solution

`UnifiedWorkoutRow`의 compact 전용 성취 표시를 작은 금색 `medal.fill`/`trophy.fill`과 caption2 텍스트로 바꿨다. 배경·테두리·리본·고정 프레임·내부 패딩을 제거하고 정보 행간은 DS.Spacing.xs(4pt)로 통일했다. PR 여부·운동별 성취 매칭·중복 제거·전체 목록의 배지는 유지한다. VoiceOver는 기존 성취/개인 기록 설명을 한 요소로 읽는다. 기존 큰 글씨 세로 전환과 여러 성취의 가로/세로 적응 배치도 유지한다.

## Validation

- `git diff --check`: 통과.
- 표준 iOS 빌드: 통과 (`BUILD SUCCEEDED`). `.xcodebuild/workout-badge-build.log`.
- UI/실제 화면: 미수행. 현재 worktree에 등록된 iPhone·iPad·Duo UDID 세 개가 실제 Simulator 목록에 없다. 다른 worktree 기기는 사용하지 않는다.
- A01 최근 운동: iPhone·iPad·Duo 접힘/펼침, 기본/큰 글씨 상태 새 캡처 미갱신. 기존 PNG를 새 증거로 사용하지 않았다.
- 재개 조건: 현재 worktree 소유 기기의 실제 존재·이름·UDID를 복구·대조한 뒤 최근 운동 성취와 큰 글씨 상태를 표준 실행기로 확인한다.

## Prevention

- 목록의 보조 성취 정보는 인접 날짜·요약의 글씨 크기와 정보 위계에 맞춘다.
- 장식 offset이 레이아웃 프레임 밖으로 벗어나지 않는지 확인한다.
- 작은 배지 때문에 전체 행 높이가 늘거나 버튼으로 오해되지 않는지 실제 화면에서 확인한다.

## Lessons Learned

운동 내역에서 성취의 의미는 작은 아이콘과 텍스트로도 전달할 수 있다. 메달 자체의 장식보다 정보 사이의 일관된 간격이 목록을 읽는 데 도움이 된다.


## Review and Ship 후속

5개 코드 리뷰 관점과 SwiftUI·Apple UX·UI 테스트·앱 품질 정적 검토에서 P1/P2/P3 결함은 발견되지 않았다. 기존 Live Activity PR #864를 포함하지 않도록 main 기반 `codex/compact-workout-achievement` 브랜치를 `/private/tmp/Health-workout-badge-review`에 분리했다. 그곳에서도 repository simulator 실행 잠금이 사용 중이어서 새 기기 생성과 UI 검증은 시작하지 못했다. 원인 해소 근거 없이 재실행하지 않으며 필수 검증 전 PR 생성·머지를 진행하지 않는다. [리뷰와 재개 조건](../../reviews/2026-10-30-compact-workout-achievement.md).
