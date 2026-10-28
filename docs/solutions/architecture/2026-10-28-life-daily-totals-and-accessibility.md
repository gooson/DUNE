---
tags: [life, habits, swiftdata, daily-total, cloudkit, accessibility]
category: architecture
date: 2026-10-28
severity: important
status: verified-selected-scope
related_files:
  - DUNE/Presentation/Life/HabitLogResolution.swift
  - DUNE/Presentation/Life/LifeViewModel.swift
  - DUNE/Presentation/Life/HabitPastRecordSheet.swift
  - DUNE/Presentation/Life/HabitCompletionChartView.swift
related_solutions:
  - 2026-03-22-auto-linked-habit-section-routing.md
---

# Solution: Life 날짜별 총합 대체와 접근성 그룹 보존

## Problem

지난 날짜에 놓친 실천을 입력할 때 같은 날 기록을 더하면 재저장한 총합이 중복된다. 관계 그래프에 도착한 로그와 별도 조회 로그의 시점이 달라 진행률·이력·주기·알림이 서로 다른 값을 읽을 수 있었다.

### Symptoms

- 어제 30분을 40분으로 고쳐도 70분으로 합산될 위험이 있었다.
- 다른 기기의 옛 기록이 합류하면 지운 기록이 다시 나타날 수 있었다.
- 차트 상위 ID가 제목·선택기·플롯에 전파돼 제목 ID가 사라졌다. 완료율 제목 자체는 실제 PNG에 표시됐다.
- 시트 안의 검증 오류가 루트 alert로 전달돼 빈 이름 저장 후 입력 폼이 닫혔다.

### Root Cause

증분 로그와 날짜별 총합의 의미가 구분되지 않았다. 또한 SwiftUI 컨테이너의 접근성 경계와 시트별 오류 표시 책임이 명시되지 않았다.

## Solution

### Changes Made

| File | Change | Reason |
|---|---|---|
| HabitLogResolution.swift | `[dune-life-daily-total]` 표식, 날짜별 최신 총합 선택, 안정적인 동률 처리 | 레거시 증분을 보존하면서 새 총합 중복 방지 |
| LifeViewModel.swift | 관계·조회 로그 병합, 삭제 전 검증, 과거 날짜·원천 제한 | 잘못된 입력으로 기존 데이터가 사라지지 않도록 함 |
| HabitPastRecordSheet.swift | 그날 총합 입력, 실제 입력 시각 분리, 주기 미리보기 | 과거 실천일과 나중 기록한 사실을 함께 보존 |
| LifeView.swift / HabitReminderSyncView.swift | 동일 resolver 소비, undo 내용 일치 검사, 시트 오류 격리 | 진행·이력·알림의 읽기 의미 통일 |
| HabitCompletionChartView.swift | `.accessibilityElement(children: .contain)` | 상위 차트와 개별 제목·선택기의 ID 경계 분리 |

### Key Code

0 입력은 사용자 화면에서 기록 해제지만, 저장소에는 최신 수동 총합 0 표식을 남긴다. 최신 표식이 이전 로그를 억제한 뒤 진행률·이력에서는 0을 제외한다. 자동 로그는 이 수동 대체 규칙에 포함하지 않는다. 실제 `completedAt`은 입력 시각이고 `date`는 선택한 실천일이다.

단위 검증은 9개 관련 suite의 113개 테스트가 통과했다. UI에서는 링 104pt, 이름 편집, 빈 이름 저장 시 폼 유지, 밝음·어두움·최대 글씨 히어로가 후속 실행에서 통과했다. 최종 접근성 그룹 수정과 주간 행/언어 검사 수정은 아직 실행 확인 전이다. 이 문서는 UI 게이트 완료나 PR 머지를 뜻하지 않는다.

## Prevention

- 날짜별 총합을 읽는 소비자는 관계와 조회 결과를 함께 전달하고 같은 resolver를 사용한다.
- SwiftData 테스트에서 관계를 nil로 만드는 것은 역관계도 바꾸므로, 조회 그래프 차이를 재현할 때 같은 논리 UUID의 별도 소유 객체를 사용한다.
- 자동 로그·skip/snooze·동률 시각·0 표식·재저장·undo 동기화 충돌을 함께 검증한다.
- 상위 식별자를 추가할 때 제목과 버튼 ID가 실제 AX 트리에 각각 남는지 확인한다.
- 시트 입력 오류를 시트가 표시하게 하고, 루트 alert는 활성 입력 시트와 경쟁하지 않게 한다.

### Checklist Addition

- [ ] 총합 교체가 동기화 합류 후에도 한 번만 계산되는가?
- [ ] 재저장·0·취소 후 진행률·이력·다음 일정이 같은 snapshot을 사용하는가?
- [ ] UI 검사가 실제 스크롤 가시성과 명시한 언어를 기준으로 조회하는가?

### Rule Addition

`.claude/**` 변경은 제안하지 않는다. 기존 데이터 정합성·접근성·조건부 재시도 규칙을 적용한다.

## Lessons Learned

데이터 입력의 의미를 명시해야 시각적 요약도 정확해진다. 화면에 보이는 제목이 존재해도 접근성 ID는 부모 modifier에 의해 달라질 수 있으므로, 실패 PNG와 AX 트리를 함께 읽어 수정 원인을 좁힌다. 재시도 한도에 도달하면 패치와 미검증 범위를 보존하고 같은 실행을 다른 이름으로 반복하지 않는다.

## 최종 검증

관련unit113개와 Life 선택26개, iPad1개, Duo외부/내부 각3개가 통과했다. 소스 일치·범위·실패 이력은 [최종 보고](../../reviews/2026-10-28-life-flow/README.md)에서 구분한다. 모든 CloudKit 동시성·전체 접근성 인증으로 확대하지 않는다.
