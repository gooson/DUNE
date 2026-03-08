---
tags: [foundation-models, tool-calling, healthkit, dashboard, shared-health-snapshot]
category: architecture
date: 2026-03-09
severity: important
related_files:
  - DUNE/Data/Services/HealthDataQAService.swift
  - DUNE/Domain/Protocols/HealthDataQuestionAnswering.swift
  - DUNE/Presentation/Dashboard/DashboardView.swift
  - DUNE/Presentation/Dashboard/HealthDataQASheet.swift
  - DUNE/Presentation/Dashboard/HealthDataQAViewModel.swift
  - DUNETests/HealthDataQAServiceTests.swift
  - DUNETests/HealthDataQAViewModelTests.swift
related_solutions:
  - docs/solutions/architecture/2026-03-09-foundation-models-integration-pattern.md
  - docs/solutions/architecture/2026-03-08-on-device-prediction-features.md
  - docs/solutions/architecture/2026-02-24-wellness-readiness-shared-snapshot-parity.md
---

# Solution: Health Data Q&A Tool Calling Pattern

## Problem

Today 탭에서 사용자가 최근 건강 데이터를 자연어로 질문할 수 있는 인터페이스가 없었고, Foundation Models를 붙이더라도 raw HealthKit dump를 그대로 프롬프트에 넣으면 토큰 예산과 안전성 모두 불리했습니다.

### Symptoms

- 사용자는 sleep, recovery, workout 패턴을 직접 질문할 수 없었음
- Foundation Models 세션에 넣을 compact context와 tool 호출 경계가 정의되지 않았음
- shared snapshot이 비어 있을 때 sleep fallback 조회가 현재 날짜 창을 한 번 덜 계산할 위험이 있었음

### Root Cause

- 기존 Foundation Models 적용은 단일 메시지 생성 중심이어서 멀티턴 Q&A용 contract와 tool surface가 없었음
- HealthKit 데이터를 요약 없이 그대로 전달하는 공통 규칙이 없었음
- 일(day) 단위 fallback 조회에서 `start ... now` 범위를 그대로 넘기면 당일 윈도우가 빠질 수 있었음

## Solution

Dashboard entry, session view model, Data-layer Q&A service를 분리하고, Foundation Models에는 compact baseline summary + tool summaries만 노출했습니다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Domain/Protocols/HealthDataQuestionAnswering.swift` | Q&A 프로토콜/응답 모델 추가 | Domain은 `FoundationModels`를 모르도록 유지 |
| `DUNE/Data/Services/HealthDataQAService.swift` | `LanguageModelSession` + tool set + fallback 구현 | 멀티턴 Q&A와 compact summary 조회를 한 곳에서 관리 |
| `DUNE/Presentation/Dashboard/HealthDataQAViewModel.swift` | 메시지 상태/중복 전송 가드 추가 | 전송 중 draft 유실과 stale append 방지 |
| `DUNE/Presentation/Dashboard/HealthDataQASheet.swift` | Q&A 시트 및 unsupported 상태 UI 추가 | Today 탭에서 최소 범위 UX 제공 |
| `DUNE/Presentation/Dashboard/DashboardView.swift` | Today 탭 진입 카드/시트 연결 | 기능 노출 |
| `DUNETests/HealthDataQAServiceTests.swift` | baseline/tool/fallback/day-window 테스트 추가 | 요약 포맷과 fallback 회귀 고정 |
| `DUNETests/HealthDataQAViewModelTests.swift` | busy state/draft 보존 테스트 추가 | 멀티턴 전송 상태 회귀 고정 |

### Key Code

```swift
actor HealthDataQAService: HealthDataQuestionAnswering {
    private var session: LanguageModelSession?

    private func activeSession() async throws -> LanguageModelSession {
        if let session { return session }

        let newSession = LanguageModelSession(
            tools: [
                ConditionSummaryTool(contextBuilder: contextBuilder),
                SleepSummaryTool(contextBuilder: contextBuilder),
                WorkoutSummaryTool(contextBuilder: contextBuilder),
                RecoverySummaryTool(contextBuilder: contextBuilder)
            ],
            instructions: await makeInstructions()
        )
        session = newSession
        return newSession
    }
}

func makeSleepSummary(days: Int) async -> String {
    let endDate = nowProvider()
    let startDate = calendar.date(byAdding: .day, value: -(boundedDays - 1), to: calendar.startOfDay(for: endDate))
        ?? calendar.startOfDay(for: endDate)
    let queryEndDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate))
        ?? endDate

    let fetched = try await sleepService.fetchDailySleepDurations(start: startDate, end: queryEndDate)
    ...
}
```

## Prevention

### Checklist Addition

- [ ] Foundation Models 프롬프트에는 raw HealthKit dump 대신 compact summary/tool output만 넣기
- [ ] 멀티턴 view model에서는 `isSending` 경로에서 draft를 먼저 비우지 않기
- [ ] 일 단위 fallback 조회는 `endDate`를 다음 날 시작 시각까지 확장해 현재 날짜 누락을 막기
- [ ] unsupported device copy는 실제 노출 방식과 모순되지 않게 확인하기

### Rule Addition (if applicable)

기존 `.claude/rules/healthkit-patterns.md`, `.claude/rules/swift-layer-boundaries.md`, `.claude/rules/localization.md`로 커버 가능해서 신규 룰 추가는 하지 않았습니다.

## Lessons Learned

- on-device Q&A는 "세션 유지"보다 "tool surface를 얼마나 작고 명확하게 자르느냐"가 품질에 더 직접적입니다.
- shared snapshot이 있어도 fallback live query 경로는 별도 테스트가 필요합니다. 날짜 범위 계산은 작은 차이로도 하루가 빠집니다.
- busy state 회귀는 UI 테스트보다 view model 단위 테스트로 훨씬 저렴하게 잠글 수 있습니다.
