---
tags: [activity, personal-records, consistency, exercise-mix, training-volume, detail-view, info-button]
date: 2026-02-23
category: brainstorm
status: draft
---

# Brainstorm: Activity 탭 상세 화면 및 UX 개선

## Problem Statement

Activity 탭의 3가지 UX 문제:

1. **Training Volume 타이틀 중첩**: `SectionGroup(title: "Training Volume")`과 `TrainingVolumeSummaryCard` 내부 `headerRow` 양쪽에서 "Training Volume" 타이틀을 렌더링하여 이중 표시
2. **상세 화면 미연결**: Personal Records, Consistency, Exercise Mix 3개 섹션은 NavigationLink가 없어 탭해도 상세 화면으로 이동 불가
3. **Info 버튼 부재**: Recovery Map에는 `info.circle` + `.sheet` 패턴이 있지만, 위 3개 섹션에는 설명 진입점이 없음

## Target Users

- 운동을 꾸준히 기록하는 사용자
- 자신의 운동 성과(PR, 일관성, 운동 구성)를 상세히 분석하고 싶은 사용자

## Success Criteria

- Training Volume 타이틀이 1회만 표시됨
- Personal Records / Consistency / Exercise Mix 각각 탭 시 상세 분석 화면으로 이동
- 각 섹션에 info 버튼이 있어 섹션 설명을 확인할 수 있음
- info 버튼 sheet은 Recovery Map의 FatigueAlgorithmSheet과 동일한 수준의 구조화된 설명 제공

## Proposed Approach

### 1. Training Volume 타이틀 중첩 해결

**결정**: 카드 내부 헤더 제거

- `TrainingVolumeSummaryCard.headerRow` 제거
- `SectionGroup(title: "Training Volume")` 타이틀만 유지
- 카드 내부에는 메트릭 + 미니 차트만 남김

**영향 파일**: `TrainingVolumeSummaryCard.swift`

### 2. 상세 화면 구현 (차트 + 분석 포함)

Training Volume Detail View 수준의 상세 분석 화면 3개 생성:

#### 2-1. Personal Records Detail View

- **전체 PR 목록**: 운동별 최고 기록 (현재 카드는 8개 제한)
- **PR 타임라인 차트**: 시간에 따른 PR 달성 추이 (Swift Charts)
- **카테고리별 필터**: 운동 유형별 PR 분류
- **기간 필터**: 최근 1개월 / 3개월 / 6개월 / 전체
- **PR 상세**: 각 PR 탭 시 해당 운동의 무게 진행 차트

#### 2-2. Consistency Detail View

- **Streak 히스토리**: 과거 streak 목록 (시작일-종료일, 일수)
- **월간 운동 캘린더**: GitHub 잔디밭 스타일의 운동 빈도 히트맵
- **주간/월간 트렌드 차트**: 운동 빈도 변화 추이
- **요일별 패턴**: 어떤 요일에 가장 많이 운동하는지 분석
- **목표 대비 달성률**: 주당 운동 목표 vs 실제

#### 2-3. Exercise Mix Detail View

- **전체 운동 빈도**: 현재 카드 6개 제한 → 전체 목록
- **운동 분포 도넛 차트**: 카테고리별 비율 시각화
- **시간 경과에 따른 변화**: 월별 운동 구성 변화 추이
- **근육군 커버리지**: 운동이 커버하는 근육군 분석
- **추천**: 부족한 운동 유형 제안

### 3. Info 버튼 추가

**패턴**: Recovery Map의 `info.circle` + `.sheet(isPresented:)` 재사용

각 섹션의 SectionGroup 헤더에 info 버튼 추가:

#### Personal Records Info Sheet
- PR 기록 방식 설명 (1RM, 세트 최대 무게 등)
- "NEW" 배지 기준 (최근 7일 이내)
- PR이 갱신되는 조건

#### Consistency Info Sheet
- Streak 계산 방식 (연속 운동일 기준)
- 월간 목표 기준
- 휴식일 포함 여부 설명

#### Exercise Mix Info Sheet
- 빈도 계산 기간 (최근 N일)
- 균형 잡힌 운동 구성의 중요성
- 퍼센티지 계산 방식

### 4. Navigation 구조

```swift
// 새 Navigation Destination enum
enum ActivityDetailDestination: Hashable {
    case personalRecords
    case consistency
    case exerciseMix
}

// ActivityView에 추가
.navigationDestination(for: ActivityDetailDestination.self) { destination in
    switch destination {
    case .personalRecords: PersonalRecordsDetailView()
    case .consistency: ConsistencyDetailView()
    case .exerciseMix: ExerciseMixDetailView()
    }
}
```

## Constraints

- **기술적**: SwiftData `@Query`로 운동 데이터 접근, Swift Charts로 시각화
- **데이터**: 운동 기록이 충분하지 않은 초기 사용자 대응 (empty state 필수)
- **성능**: 전체 기록 분석 시 대량 데이터 처리 최적화 필요

## Edge Cases

- **데이터 없음**: 운동 기록이 없는 사용자 → empty state + 운동 시작 유도
- **단일 운동만 기록**: Exercise Mix에서 100% 하나만 표시 → "다양한 운동을 시도해보세요" 안내
- **Streak 0일**: 현재 진행 중인 streak 없음 → 마지막 운동일 표시 + 재시작 유도
- **PR 없음**: 무게 기록이 없는 유산소 운동만 → 유산소 PR (거리, 시간) 표시 또는 안내

## Scope

### MVP (Must-have)
- [ ] Training Volume 타이틀 중첩 제거
- [ ] Personal Records Detail View (전체 목록 + PR 타임라인 차트)
- [ ] Consistency Detail View (streak 히스토리 + 월간 캘린더)
- [ ] Exercise Mix Detail View (전체 목록 + 분포 차트)
- [ ] 3개 섹션 NavigationLink 연결
- [ ] 3개 섹션 Info 버튼 + Info Sheet

### Nice-to-have (Future)
- [ ] PR 상세 → 운동별 무게 진행 차트
- [ ] 요일별 운동 패턴 분석
- [ ] 근육군 커버리지 분석
- [ ] 부족한 운동 유형 추천
- [ ] 기간 필터 (1/3/6개월/전체)

## Open Questions

1. PR 기준은 1RM인가, 세트 최대 무게인가? (현재 코드 확인 필요)
2. Streak 계산에서 휴식일(예: 일요일)은 끊김으로 처리하는가?
3. Exercise Mix의 빈도 계산 기간은 고정(예: 30일)인가, 전체 기간인가?

## Next Steps

- [ ] `/plan activity-tab-detail-views` 으로 구현 계획 생성
