---
tags: [sleep, notification, apple-watch, bedtime, personalization]
category: architecture
date: 2026-03-07
severity: important
related_files: [DUNE/Domain/UseCases/CalculateAverageBedtimeUseCase.swift, DUNE/Data/Services/BedtimeWatchReminderScheduler.swift, DUNE/App/DUNEApp.swift, DUNE/App/ContentView.swift, DUNETests/CalculateAverageBedtimeUseCaseTests.swift]
related_solutions: [docs/solutions/healthkit/background-notification-system.md, docs/solutions/architecture/sleep-deficit-personal-average.md]
---

# Solution: 평균 취침 시간 기반 Apple Watch 취침 리마인더 구현

## Problem

요청사항은 "평균 취침 시간 30분 전에 Apple Watch를 안 차고 있으면 알려주기"였지만, 기존 PR은 brainstorm 문서만 추가되어 실제 앱 동작이 전혀 없었다.

### Symptoms

- 문서만 존재하고 실제 알림 스케줄 코드가 없음
- 취침 전 리마인더가 생성/갱신/정리되지 않음

### Root Cause

구현 단계(`/work`) 없이 아이디어 정리(`/brainstorm`) 결과만 반영되어 기능 코드와 테스트가 누락됨.

## Solution

최근 수면 stage 데이터에서 개인화 취침 시각을 계산하고, 해당 시각 30분 전에 반복 로컬 알림을 스케줄하는 런타임 서비스를 추가했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Domain/UseCases/CalculateAverageBedtimeUseCase.swift` | 평균 취침 시각 계산 유스케이스 추가 | 자정 경계(23:xx/00:xx) 평균 왜곡 방지 |
| `DUNE/Data/Services/BedtimeWatchReminderScheduler.swift` | 취침 리마인더 스케줄/제거 서비스 추가 | 실제 알림 기능 동작 구현 |
| `DUNE/App/DUNEApp.swift` | 런타임 시작 시 스케줄 refresh 호출 | 앱 시작 후 자동 반영 |
| `DUNE/App/ContentView.swift` | active 전환 시 refresh 호출 | 최신 수면 데이터 반영 |
| `DUNETests/CalculateAverageBedtimeUseCaseTests.swift` | 계산 로직 테스트 추가 | 핵심 시간 계산 안정성 검증 |

### Key Code

```swift
let bedtime = bedtimeCalculator.execute(input: .init(sleepStagesByDay: recentStages, calendar: calendar))
let triggerMinutes = (bedtimeMinutes - 30 + (24 * 60)) % (24 * 60)
```

## Prevention

기능 요청이 들어오면 brainstorm 결과만 남기지 않고 최소 실행 코드+테스트+라이프사이클 연결까지 한 PR에서 완료한다.

### Checklist Addition

- [ ] brainstorm 문서 추가 PR에는 반드시 "실행 코드 포함 여부"를 체크한다.
- [ ] 시간 기반 기능은 자정 경계 테스트를 최소 1개 이상 포함한다.

### Rule Addition (if applicable)

신규 룰 추가는 필요하지 않음.

## Lessons Learned

- 자정 전후 시간 데이터는 일반 평균이 아닌 wrap 처리(원형 평균에 준하는 보정)가 필요하다.
- 알림 기능은 권한/디바이스 상태 불충족 시 pending 정리 경로가 있어야 오동작을 줄일 수 있다.
