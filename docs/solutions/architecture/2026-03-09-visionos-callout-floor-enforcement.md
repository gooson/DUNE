---
tags: [visionos, typography, callout, swiftui, readability, dunevision]
date: 2026-03-09
category: solution
status: implemented
---

# visionOS Callout Floor Enforcement

## Problem

`todos/022`를 닫는 시점에 `VisionSharePlayWorkoutCard`의 마지막 `.caption`만 정리된 것으로 보였지만,
리뷰 단계에서 `DUNEVision` 전역에 `.subheadline`과 `.footnote`가 여전히 남아 있었다.
이 상태로는 "visionOS text는 최소 `.callout`"이라는 완료 기준이 실제 코드와 맞지 않았다.

## Solution

### 전역 grep으로 남은 위반 지점을 다시 찾았다

아래 검색으로 `DUNEVision` 안의 callout 미만 typography를 전부 재확인했다.

```sh
rg -n "\.font\(\.(subheadline|footnote|caption|caption2)" DUNEVision -g '*.swift'
```

이 결과를 기준으로 `VisionExerciseFormGuideView`, `VisionVolumetricExperienceView`,
`VisionImmersiveExperienceView`, `VisionDashboardWindowScene` 등 남아 있던 view의
`.subheadline`/`.footnote`를 `.callout` 계열로 일괄 상향했다.

### typography closure 기준을 코드 수준으로 맞췄다

- 설명/보조 문구는 `.callout`
- 강조가 필요한 보조 값은 `.callout.weight(...)`
- 기존 headline/title 계층은 유지

즉, hierarchy는 유지하되 공간 가독성 하한선만 `.callout`으로 올렸다.

### 정적 검색과 빌드로 closeout을 검증했다

- 같은 `rg` 명령을 다시 실행해 `DUNEVision`에서 callout 미만 text style이 0건임을 확인했다.
- `xcodebuild -project DUNE/DUNE.xcodeproj -scheme DUNEVision -destination 'generic/platform=visionOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build`가 현재 `HEAD`에서 성공했다.
- `VisionWindowPlacementPlannerTests` 재실행은 이번 변경과 무관한 `DUNETests/AICoachingMessageServiceTests.swift:42` compile failure 때문에 여전히 막혀 있음을 분리 확인했다.

## Prevention

- visionOS UX polish TODO를 닫기 전에는 전역 grep으로 `.subheadline`, `.footnote`, `.caption`, `.caption2` 잔존 여부를 먼저 확인한다.
- 개별 view spot fix만으로 closure를 선언하지 말고, cross-surface design rule은 반드시 codebase-level search 결과와 함께 닫는다.
- 완료 메모에는 "정적 검색 결과"와 "현재 HEAD build 결과"를 같이 남겨서 backlog와 코드 상태가 다시 어긋나지 않게 한다.

## Lessons Learned

visionOS 가독성 규칙처럼 횡단 관심사 성격의 polish 항목은 마지막 한 파일만 고치는 방식으로는 닫을 수 없다.
종료 기준이 "특정 화면 수정"이 아니라 "코드베이스 전체에서 규칙 위반 0건"이어야 review와 backlog 상태가 일치한다.
