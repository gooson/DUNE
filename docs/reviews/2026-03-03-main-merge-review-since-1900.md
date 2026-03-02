---
tags: [review, main, watchos, cardio, timing]
date: 2026-03-03
category: review
status: reviewed
---

# Code Review Report

> Date: 2026-03-03
> Scope: `2026-03-02 19:00 KST` 이후 `main` 머지 범위 전수 점검 (`a253708..28706aa`)
> Files reviewed: 287개 (대용량 diff 직접 점검 + 빌드 게이트)

## Summary

| Priority | Count | Status |
|----------|-------|--------|
| P1 - Critical | 0 | Must fix before merge |
| P2 - Important | 1 | Fixed |
| P3 - Minor | 0 | Nice to fix |

## P1 Findings (Must Fix)

없음.

## P2 Findings (Should Fix)

### [Performance Oracle / Data Integrity Guardian] Pause 시간이 cardio elapsed/pace에 포함됨

- **File**: `DUNEWatch/Managers/WorkoutManager.swift` (L769, L786), `DUNEWatch/Views/CardioMetricsView.swift` (L79)
- **Category**: performance, data
- **Issue**: watch cardio 세션에서 elapsed 계산이 wall-clock 기반이어서 pause 구간이 누적되어 pace가 느리게 왜곡됨.
- **Risk**: 사용자에게 표시되는 pace/시간 지표가 실제 운동 시간과 불일치하여 세션 품질 데이터 신뢰도를 저하시킬 수 있음.
- **Suggestion**: pause 누적/진행 중 pause를 제외한 active elapsed 계산을 단일 함수로 통합하고, pace/타이머 표시가 동일 함수를 사용하도록 정렬.
- **Resolution**: `WorkoutElapsedTime.activeElapsedTime(...)` 도입 및 pause lifecycle(`beginPause`/`endPause`) 반영 후 `CardioMetricsView` 타이머를 동일 경로로 변경.

## P3 Findings (Consider)

없음.

## Six-Perspective Notes

- Security Sentinel: 이번 수정은 권한/인증/외부 입력 경로 변경 없음.
- Performance Oracle: pause-aware elapsed로 cardio pace 계산 정확도 회복.
- Architecture Strategist: elapsed 계산을 단일 helper로 분리해 UI/매니저 중복 제거.
- Data Integrity Guardian: 운동 요약 지표의 시간 정합성 개선.
- Code Simplicity Reviewer: pause 상태 전이 로직을 `beginPause`/`endPause`로 명시화.
- Agent-Native Reviewer: 대용량 diff는 규칙대로 직접 리뷰하고 컴파일 게이트를 별도 수행.

## Quality Gate

- `xcodebuild -project DUNE/DUNE.xcodeproj -scheme DUNEWatch -destination 'generic/platform=watchOS' build -quiet` 통과
- `xcodebuild -project DUNE/DUNE.xcodeproj -scheme DUNE -destination 'generic/platform=iOS' build -quiet` 통과
- `xcodebuild -project DUNE/DUNE.xcodeproj -scheme DUNEWatchTests -destination 'generic/platform=watchOS' build -quiet` 통과
- `./scripts/test-unit.sh`는 CoreSimulatorService 연결 불가 환경으로 실행 실패 (테스트 케이스 실패가 아닌 실행 환경 이슈)

## Next Steps

- [ ] CoreSimulator 정상 환경에서 `DUNEWatchTests` 실행 확인
- [ ] 실기기에서 cardio pause/resume 후 pace drift 수동 검증
