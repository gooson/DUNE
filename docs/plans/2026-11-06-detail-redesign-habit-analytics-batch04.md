---
tags: [detail-redesign, habits, history, heatmap, targeted-ui]
date: 2026-11-06
category: plan
status: approved
related_solutions: [2026-03-22-history-sheet-triple-close-fix, 2026-03-22-heatmap-card-detail-pattern]
---

# L05·L06·L07·L08 습관 이력·분석 묶음

관련 구현·빌드·검증을 공유하고 PR은 화면별로 유지한다. 선행 L02/L04/L09는 PR #932/#933/#934로 일반 머지했으며, 이번 시작점은 그 머지의 최신 main이다. 원래 기록·날짜·90일 데이터·계산·아이콘·내비게이션을 보존한다.

## Research and Approach

원본은 LifeView의 HabitHistorySheet, HabitManagementView의 HabitHistoryDetailSheet, HabitHeatmapDetailView, WeeklyHabitReportView다. 기존 history sheet의 NavigationStack 중복 닫기 문제와 히트맵 상세 패턴 해결 문서를 확인했다. 새 NavigationStack을 추가하지 않는다. L05/L06는 원래 단일 Close·medium/large detents와 모든 행/조건부 Past Record를 하나의 스크롤에 두고, 실제 습관명·아이콘·기록 수를 HeroCard로 읽는다. L07은 실제 90일 총 완료와 평균·연속·활동일을, L08은 실제 기간·완료율·분자/분모·이전 주 비교를 강조한다. 기존 Best/Needs Improvement 기호를 MAX에서도 보존한다. 고정 헤더를 확대하는 대안은 짧은 sheet의 행 영역을 차지하므로 선택하지 않았다.

## Affected Files

| 화면 | App 소유 파일 | 기존 기능 불변 |
|---|---|---|
| L05 | LifeView.swift의 HabitHistorySheet | entries 순서·action/date/value/늦은 기록·빈 상태·Past Record·Close |
| L06 | HabitManagementView.swift의 HabitHistoryDetailSheet | cachedLogSnapshots·sortedEntries·값/날짜·empty·Close·management restore |
| L07 | HabitHeatmapDetailView.swift | validData·총합/평균/연속/활동일·90일 grid·legend·요일/조건부 chart |
| L08 | WeeklyHabitReportView.swift | report 비율·분자/분모·previousWeekRate·best/worst·trend 색/기호 |
| 공유 | LifeRegressionTests.swift, 레이아웃/테마 네 맵, 실제 맵/해결 문서 | 나머지 L02/L04 UI 함수와 L09 Flow/Duo 검사 소스를 보존 |

## Implementation Steps

1. 현재 파일 SHA를 private v4 App 및 v3 UI 제안의 실제 원본과 대조한다. 다섯 patch의 적용 가능성만 확인됐으며 실행 통과로 취급하지 않는다. 과거 L06 compatibility patch는 v3에 흡수되어 다시 적용하지 않는다.
2. 네 layout/theme 맵·계획을 먼저 커밋한다. 이후 App은 화면별 네 커밋으로 나누고, UI 후보는 최종 L02/L04 기초 함수들을 보존해 별도 커밋한다.
3. 소스 독립 리뷰 및 실행 계약을 먼저 확정한다. SDK에는 실제 App/UI 컴파일이 포함되므로 같은 source의 build-only를 반복하지 않는다. 순수 계산·저장 변경이 없어 구현을 복제하는 unit test를 만들지 않는다.
4. 아래 19개 정확한 메서드·프로필 조합을 네 실행으로 나누고 전용 기기는 한 번에 한 대만 사용한다. 결과·실패·원인·횟수를 모두 보존하며 실패 selector만 근거 있는 조건부 재검증을 한다.
5. 각 실제 PNG/AX를 기기·MAX·소스·상태와 묶어 독립 검토한다. map의 같은 화면 행만 갱신하고 unrelated 행을 보존한다. 문서화·최종 게시 차이 리뷰 후 화면별 PR 네 개를 일반 머지한다.

## Testing Strategy

- 기본 네 메서드: LifeRegressionTests의 testHabitHistoryShowsSeededEntriesAndDismisses, testVisualAuditHabitManagement, testVisualAuditHabitHeatmap, testVisualAuditWeeklyReport. iPhone·iPad·Duo closed/open에 각 4개로 16개다.
- 접힌 Duo MAX 두 메서드: testHabitHistoryAndManagementAtMaximumAccessibilitySize와 testHabitAnalyticsAtMaximumAccessibilitySize. 각 메서드가 두 화면을 확인하므로 18 SDK 조합/20 화면 기여다.
- 외곽 스크롤로 바뀐 L05 empty composition의 기존 소비자 testHabitHistoryShowsEmptyStateForHabitWithoutLogs를 iPhone에만 한 번 추가해 최종 19 SDK 조합/21 화면 기여로 한다. 새 테스트를 늘리거나 모든 프로필의 empty를 반복하지 않는다.
- 실행 수: iPhone 5, iPad 4, Duo closed normal4+MAX2 6, Duo open 4. Closed SDK 한 aggregate의 normal/MAX는 실제 메서드·MAX 재진입과 캡처를 구별해 두 프로필로 판정하며 동일 실행을 중복 합산하지 않는다.
- 기존 opt-in visual audit가 skip되지 않도록 DUNEUITests-DuoAudit plan과 표준 host capture wrapper를 사용한다. 그 wrapper의 단일 built-in display 경로는 iPhone/iPad에도 적용되고, hinge/motion 명령은 Duo의 해당 소유 기기에만 적용한다. 실행기·공통 helper·plan 파일 자체는 수정하지 않는다.
- 각 worktree SDK는 하나, jobs2/indexOFF/병렬OFF, UI wall1200/소유deadline1250/outer1300과 case300을 유지한다. 0건·skip·누락 selector·실패는 통과가 아니다.

## Edge Cases and Limits

medium sheet의 hero/행/Close, MAX의 긴 제목·단위·표·기호, 기록 없음, iPad inspector와 sheet 공존, 실제 뒤로/닫기 이후 화면 이탈을 확인한다. 새 AX ID는 실제 scroll/리프 Text/Button에만 둔다. 실제 데이터로만 표시하고 임의 기록/평균을 만들지 않는다. Watch/widget에 소비자가 없고 shared production/theme 로직 변경은 없다. full suite·Dark·VoiceOver·실기기·전체 테마 검증을 주장하지 않는다. 실제 캡처 이전에는 시안만 완료된 상태로 표시한다.
