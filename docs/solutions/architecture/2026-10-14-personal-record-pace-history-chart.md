---
tags: [personal-records, pace, healthkit, chart, period-filter]
category: architecture
date: 2026-10-14
status: draft
severity: important
related_files:
  - DUNE/Presentation/Activity/PersonalRecords/PersonalRecordsDetailViewModel.swift
  - DUNE/Presentation/Activity/PersonalRecords/PersonalRecordsDetailView.swift
related_solutions:
  - docs/solutions/architecture/2026-03-29-pr-visual-enhancement.md
---

# Solution: 최고 페이스 기록 그래프의 데이터 공급

## Problem

### Symptoms

- 개인 기록 상세에서 과거 최고 페이스는 카드에 표시되지만, `월` 타임라인에는 “이 기간에 기록이 없습니다.”가 나타났다.
- 최고 페이스를 갱신하지 않은 운동의 페이스 변화는 그래프에서 볼 수 없었다.

### Root Cause

개인 기록 저장소는 운동 종류별 **현재 최고값 하나**를 보관한다. 타임라인은 이 최고 기록 목록을 다시 선택 기간으로 필터링했다. 따라서 최고값 달성일이 기간 밖이면 그래프 데이터가 비고, 최근 운동을 했더라도 새 PR이 아니면 점이 생기지 않았다. 현재 최고 카드와 기간 그래프가 서로 다른 질문에 답한다는 점도 화면에 드러나지 않았다.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `PersonalRecordsDetailViewModel.swift` | 최근 운동을 즉시 반영하고, 최고 페이스 선택 시 최근 1년 HealthKit 운동을 조회해 유효한 페이스를 날짜순 차트 데이터로 구성 | 선택 기간의 실제 페이스 변화를 표시 |
| `PersonalRecordsDetailView.swift` | 최고 페이스 그래프를 “페이스 기록”으로 표시하고 로딩·조회 실패 상태를 구분 | 그래프의 데이터 의미를 명확히 전달 |
| `ActivityView.swift`, `NotificationPersonalRecordsPushView.swift` | 이미 조회한 최근 운동을 상세 화면에 전달 | 차트의 첫 표시를 기다리지 않게 함 |
| `PRChipBar.swift` | 종류별 접근성 식별자를 추가 | 최고 페이스 선택 UI 회귀 검증 |
| `PersonalRecordsDetailViewModelTests.swift` | 과거 최고값과 최근 운동, 유효성 검사, 중복 제거, 1년 조회, 화면 전환 중 취소와 운동 목록 갱신 테스트 추가 | 같은 결함의 재발 방지 |

### Key Code

```swift
// Keep the all-time best separate from the selected-period pace series.
currentBest = byKind.min { $0.value < $1.value }
chartData = chartSource
    .filter { $0.date >= range.start && $0.date <= range.end }
    .sorted { $0.date < $1.date }
```

HealthKit 운동은 ID로 중복 제거한다. 조회된 운동과 일치하지 않는 저장된 PR은 차트에 남겨 과거 최고 기록이 사라지지 않게 한다. 페이스가 유한하고 60~3,600초/km 범위이며 거리 기반 운동인 경우만 사용한다. 페이스 차트는 실제 측정값보다 빠른 중간값이 생기지 않도록 선형 보간으로 연결한다.

최근 운동 목록이 바뀌면 기존 조회 결과를 무효화하고 새 목록으로 점을 교체한다. 조회마다 세대 번호를 확인해 오래 걸린 이전 조회가 최신 점을 덮지 않게 한다. 화면의 종류 선택 작업이 취소돼도 이미 시작한 조회는 ViewModel에서 완료한다.

## Prevention

- 기간별 추이 그래프를 만들 때 저장소의 “현재 최고값”이 실제 시계열인지 확인한다.
- 최고값과 시계열은 별도로 검증한다. 특히 최고 기록 달성일이 선택 기간 밖이고 최근 운동은 기간 안인 경우를 테스트한다.
- 외부 운동 조회 결과가 기존 기록과 겹칠 때 운동 ID로 한 점만 남긴다.
- 비동기 차트 조회는 선택 화면의 취소·재진입과 운동 목록 변경을 함께 검증한다.

## Lessons Learned

현재 최고 기록을 표시할 데이터와 기간별 변화를 표시할 데이터는 수명과 갱신 조건이 다르다. 최고 기록 한 건을 기간 차트에 재사용하면 기록은 존재해도 그래프가 비는 화면이 생긴다.
