---
tags: [charts, long-press, scroll, regression, interaction, shared-components, activity]
date: 2026-03-08
category: brainstorm
status: draft
---

# Brainstorm: 차트 롱프레스 회귀 및 전 그래프 상호작용 통합

## Problem Statement

최근 차트 롱프레스 selection 방식이 공통 overlay 기반으로 바뀌면서, 사용자가 체감하는 상호작용 품질이 오히려 나빠졌다.

현재 확인된 핵심 증상은 다음과 같다.

- 주간 차트에서 롱프레스하면 현재 기간이 유지되지 않고, 기간이 바뀐 것처럼 그래프가 좁아진다
- 롱프레스와 차트 가로 스크롤이 경쟁하면서 selection 대신 scroll이 먼저 먹거나, 반대로 차트 자체가 자연스럽게 스크롤되지 않는다
- 차트마다 interaction 방식이 달라져서 어떤 화면은 공통 overlay를 쓰고, 어떤 화면은 여전히 기존 `chartXSelection`을 사용한다
- 결과적으로 사용자는 “어떤 차트는 롱프레스가 이상하고, 어떤 차트는 스크롤이 안 되고, 어떤 차트는 아직 통합도 안 된” 상태로 느낀다

이 문제는 특정 화면 하나의 버그가 아니라, 차트 interaction 시스템이 두 가지 상태를 동시에 만족하지 못하는 데서 발생한다.

1. selection 모드에서는 가시 범위와 기간이 고정되어야 한다
2. non-selection 모드에서는 차트 scroll이 자연스럽게 유지되어야 한다

핵심 목표는 모든 그래프에서 다음을 동시에 만족시키는 것이다.

1. 롱프레스해도 현재 기간과 visible range가 흔들리지 않는다
2. 차트 자체의 가로 스크롤은 정상 동작한다
3. 모든 그래프가 동일한 interaction 규칙을 사용한다

## Target Users

- Health 상세 차트에서 최근 추세를 직접 탐색하는 iPhone 사용자
- 주간, 월간, 6개월, 연간 차트를 같은 방식으로 사용하고 싶은 사용자
- Activity, Wellness, Dashboard 등 서로 다른 화면을 오가며 차트 interaction 일관성을 기대하는 사용자

## Success Criteria

1. 주간 차트에서 롱프레스해도 period 세그먼트나 visible range가 바뀐 것처럼 보이지 않는다
2. 롱프레스 시작 전에는 차트 가로 스크롤이 정상 동작하고, selection이 활성화된 뒤에는 스크롤과 selection이 동시에 경쟁하지 않는다
3. selection 종료 후에는 즉시 차트 스크롤이 다시 자연스럽게 동작한다
4. 공통화된 chart와 아직 미통합인 Activity chart 모두 동일한 interaction 규칙을 사용한다
5. 모든 그래프에서 overlay, selection indicator, haptic trigger 기준이 일관된다
6. `week`, `month`, `sixMonths`, `year` 전 기간에서 회귀 없이 동작한다

## Proposed Approach

### 1) selection 상태와 scroll 상태를 명확히 분리

현재 구조는 hold-based drag selection과 chart horizontal scroll이 같은 터치 흐름 안에서 경쟁할 가능성이 높다.

- selection 대기 상태
- selection 활성 상태
- scroll 허용 상태

이 세 상태를 암묵적으로 섞지 말고 명시적으로 분리해야 한다.

특히 사용자가 주간 차트에서 롱프레스할 때는 “selection으로 들어가는 동안 chart scroll이 visible domain을 밀지 않도록” 제어해야 한다.

### 2) 공통 selection pipeline을 회귀 관점에서 재설계

이미 공통화된 차트들은 `chartOverlay + DragGesture + hold activation` 구조를 사용하고 있다. 하지만 지금 목표는 “overlay를 띄우는 것”이 아니라 “scroll과 selection의 우선순위를 안정화하는 것”이다.

추후 유지보수를 고려하면, 이 계층은 느슨한 modifier 조합보다 재사용 가능한 gesture state machine 수준으로 설계하는 편이 낫다.

따라서 공통 helper는 다음 책임을 가져야 한다.

- hold activation threshold 관리
- activation 전 movement slop 처리
- selection 활성화 시 scroll lock 처리
- 종료 시 상태 복구
- snapped point 기준 haptic/overlay 갱신

즉, 단순 좌표 계산 helper가 아니라 interaction state machine으로 재정리할 필요가 있다.

### 3) 전 그래프를 하나의 통합 규칙으로 묶기

현재 코드베이스에는 두 계열이 공존한다.

- 최근 공통 overlay 방식으로 바뀐 shared charts
- 여전히 `chartXSelection` 기반인 Activity charts

대표 후보는 다음과 같다.

- shared: `AreaLineChartView`, `BarChartView`, `DotLineChartView`, `RangeBarChartView`, `HeartRateChartView`, `SleepStageChartView`
- activity: `DailyVolumeChartView`, `TrainingLoadChartView`, `StackedVolumeBarChartView`, `ReadinessTrendChartView`, `SubScoreTrendChartView`, `ExerciseTypeDetailView`

이번 범위는 특정 차트만 핫픽스하는 것이 아니라, “selection이 있는 그래프는 모두 같은 interaction contract를 따른다”로 정리하는 것이 맞다.

추가로 현재 목록에 없는 차트라도 selection UX가 존재하거나 새로 추가될 예정이라면 동일 contract에 편입될 수 있어야 한다. 즉, 이번 설계는 현재 차트 목록 대응에 그치지 않고 “앱 전반의 selection chart 공통 규약”이 되어야 한다.

### 4) period 변화처럼 보이는 체감을 별도 회귀 항목으로 다루기

사용자 관점에서는 실제로 세그먼트 값이 바뀌었는지보다, “주간에서 롱프레스했더니 월간처럼 보였다”는 체감이 더 중요하다.

따라서 구현 시에는 내부 period 값 변경 여부와 별개로 다음 항목을 검증해야 한다.

- 롱프레스 중 `scrollPosition`이 이동하는가
- `chartXVisibleDomain` 체감이 흔들리는가
- visible range label이 바뀌는가
- selection이 시작되기 전에 chart가 먼저 수평 이동하는가

즉, period 상태값 자체만 보면 놓치는 UX regression을 visible range 관점에서 같이 봐야 한다.

### 5) 차트 scroll 복구를 독립 목표로 둔다

이번 이슈는 “롱프레스가 이상함”만이 아니라 “차트 자체가 스크롤이 안 됨”도 포함한다.

따라서 수정 목표는 둘 중 하나가 아니라 둘 다다.

- 롱프레스 안정화
- 차트 scroll 복구

selection을 고치면서 scroll을 죽이거나, scroll을 살리면서 selection을 포기하면 해결로 보지 않는다.

## Constraints

- shared chart layer에서 해결해야 하며, 화면별 예외 처리로 누적시키면 안 된다
- 기존 `scrollPosition` binding, visible range label, summary recalculation 흐름을 깨뜨리면 안 된다
- trend line, axis, accessibility descriptor, glass styling은 유지해야 한다
- `week`, `month`, `sixMonths`, `year`의 domain 단위 차이를 고려해야 한다
- Activity 쪽 미통합 차트까지 포함해도 구조가 과도하게 복잡해지지 않아야 한다

## Edge Cases

1. 롱프레스 시작 전에 손가락이 약간 흔들리는 경우 scroll로 해석될지 selection으로 해석될지 애매한 상태
2. 주간처럼 좁은 visible domain에서 작은 x 이동만으로도 체감이 크게 흔들리는 경우
3. selection 종료 후 scroll lock이 풀리지 않아 차트가 계속 안 움직이는 경우
4. 반대로 scroll 종료 후 selection state가 남아 overlay가 잘못 유지되는 경우
5. `chartXSelection` 기반 차트와 공통 overlay 기반 차트가 혼재하여 화면별 UX가 달라지는 경우
6. 데이터가 적은 차트와 많은 차트에서 동일 threshold가 다르게 느껴지는 경우
7. first/last point 근처에서 overlay clamp와 scroll gesture가 동시에 어색해지는 경우

## Scope

### MVP (Must-have)

- [ ] 롱프레스 중 visible range가 바뀌지 않도록 selection/scroll 상태를 분리
- [ ] selection 종료 후 차트 가로 스크롤이 즉시 복구되도록 보장
- [ ] 공통 selection helper를 interaction state 기준으로 재설계
- [ ] shared chart 회귀를 동일 기준으로 정리
- [ ] 아직 미통합인 selection chart를 공통 규칙으로 편입
- [ ] 전 기간(`week`, `month`, `sixMonths`, `year`)에서 period 유지와 scroll 동작을 검증

### Nice-to-have (Future)

- [ ] selection/scroll 상태 전환에 대한 UI gesture test 추가
- [ ] 차트 유형별 threshold 미세 조정 전략 정리
- [ ] scroll과 selection 상태를 재사용 가능한 modifier로 더 추상화

## Decisions

1. 공통 helper는 modifier 조합 수준이 아니라 gesture state machine 수준으로 확장한다. 기준은 장기 유지보수성과 화면 간 일관성이다.
2. Activity 차트 포함 모든 selection 차트는 동일 interaction contract에 편입한다. shared/activity 구분 없이 앱 전체에서 같은 UX를 사용한다.
3. 회귀 검증은 unit test만으로 끝내지 않고, 가능하면 UI gesture test까지 추가한다. 순수 수학/상태는 unit test로, 실제 제스처 경쟁과 scroll 회귀는 UI test로 보완한다.

## Next Steps

- [ ] `/plan chart-long-press-scroll-regression` 으로 구현 계획 생성
