---
tags: [life-tab, ux, design-system, consistency, habit, cleanup]
date: 2026-03-04
category: brainstorm
status: draft
---

# Brainstorm: Life 탭 UX 개선 (디자인 시스템 + 구조 일관성 + 깔끔한 UX)

## Problem Statement

Life 탭은 기능(수동 습관 체크, 주기형 습관, 운동 자동 달성)은 충분하지만, 화면 구조가 다른 탭(Today/Activity/Wellness) 대비 다소 분산되어 보인다.

- 섹션 구조가 `SectionGroup` 중심이 아니라 커스텀 블록 중심으로 구성되어 시각적 일관성이 약함
- 행 단위 보조 액션(Snooze/Skip/History)이 본문에 직접 노출되어 정보 밀도가 높고 스캔성이 떨어짐
- Hero/핵심 섹션 우선순위가 다른 탭의 "Hero → Section" 패턴과 다르게 느껴질 수 있음

핵심 문제는 "사용자가 오늘 해야 할 습관을 빠르게 파악하고 최소 탭으로 완료"해야 하는 화면에서, 정보 구조와 액션 밀도가 목적 대비 높다는 점이다.

## Target Users

- 매일 3~15개 습관을 반복 체크하는 사용자
- 운동 기록(HealthKit)과 라이프 루틴을 함께 관리하는 사용자
- iPhone 중심 사용 + iPad 대화면에서도 동일한 구조를 기대하는 사용자

## Success Criteria

1. 첫 화면 진입 후 3초 내 "오늘 할 일(남은 습관)"을 인지할 수 있다
2. 체크형/횟수형 핵심 액션 완료까지 평균 탭 수가 줄어든다
3. Life 탭 상위 구조가 Today/Activity/Wellness와 같은 패턴으로 인지된다
4. 보조 액션(편집/보관/스누즈/히스토리) 접근성은 유지하면서 기본 화면의 복잡도는 낮아진다
5. iPhone/iPad 모두에서 spacing, card depth, section rhythm이 디자인 시스템 토큰과 일치한다

## Proposed Approach

### 1) 상위 정보 구조 재정렬

다른 탭과 동일하게 `Hero → SectionGroup 묶음` 구조로 정렬한다.

- Hero: 오늘 진행률 + 남은 습관 수 + 핵심 CTA
- Section A: `My Habits` (오늘 액션 중심)
- Section B: `Auto Workout Achievements` (주간 목표 중심)

기본 화면은 "오늘 해야 할 것"을 먼저 보여주고, 자동 달성은 보조/강화 정보로 배치한다.

### 2) 디자인 시스템 컴포넌트 통일

Life 탭에서도 공통 컴포넌트 규칙을 명확히 적용한다.

- 섹션 래퍼: `SectionGroup` 사용으로 헤더/배경/테두리 스타일 통일
- 카드: `StandardCard`는 핵심 콘텐츠, `InlineCard`는 보조/로그성 정보로 용도 분리
- spacing/radius/typography는 `DS.Spacing`, `DS.Radius`, `DS.Typography`만 사용

### 3) 액션 단순화 (Clean UX)

행 본문에는 "오늘 완료에 필요한 최소 액션"만 유지하고 보조 액션은 접는다.

- 기본 노출: 완료/증감/값입력
- 보조 액션: `contextMenu` 또는 trailing menu/sheet로 이동 (Edit, Archive, Snooze, Skip, History)
- 주기형 습관의 상태 텍스트는 유지하되 버튼 나열은 축소

### 4) 상태 UX 정리

- 빈 상태: "No Habits Yet"에서 즉시 생성 가능한 단일 CTA 유지
- 부분 상태: 자동 달성 데이터 없음과 사용자 습관 없음을 분리해 메시지 명확화
- 새로고침: 타 탭과 동일한 `waveRefreshable` 패턴 적용 검토 (계산 재실행 중심)

### 5) iPad 구조 일관성

- iPad에서는 섹션 간 리듬은 유지하되, 필요 시 2열 배치(예: Auto Achievement 그룹)로 확장
- 카드 높이/텍스트 줄바꿈 정책을 고정해 레이아웃 점프 최소화

## Constraints

- 기존 Correction 규칙 유지:
  - SwiftData `@Query` 분리 구조(HabitListQueryView)로 부모 re-layout 최소화
  - O(1) lookup 캐시, 중복 계산 방지 로직 유지
- HealthKit 기반 자동 달성 계산 정확도 유지
- 라우팅/네비게이션 구조는 탭 루트 `NavigationStack` 원칙을 유지
- 접근성 식별자(`accessibilityIdentifier`)는 기존 자동화 테스트와 호환 유지

## Edge Cases

1. 습관 0개 + 자동 달성 데이터만 존재하는 경우 (무엇을 우선 노출할지)
2. 주기형 습관 due/overdue 상태에서 보조 액션을 숨겼을 때 발견 가능성 저하
3. 습관 수가 많은 경우(20+) 스크롤 성능 및 인지 피로
4. iPad split view/회전 시 섹션 재배치 안정성
5. 자동 달성 데이터 지연/누락 시 사용자 신뢰 저하 방지 메시지

## Scope

### MVP (Must-have)

- [ ] Life 탭 상위 구조를 `Hero → My Habits → Auto Achievements`로 정렬
- [ ] `SectionGroup` 기반 섹션 UI 통일
- [ ] 행 본문 액션 단순화(보조 액션 접기)
- [ ] 상태 메시지(빈 상태/자동 달성 없음) 분리 정리
- [ ] iPhone + iPad 레이아웃 검증

### Nice-to-have (Future)

- [ ] `My Habits`/`Auto Achievements` 순서 사용자 설정
- [ ] 습관 카드 drag & drop 재정렬 UX
- [ ] 주간 요약(완료율 변화, streak 변화) 별도 카드
- [ ] 보조 액션을 bottom sheet 기반으로 확장

## Open Questions

1. 기본 우선순위는 "오늘 습관"이 먼저가 맞는가, 아니면 "자동 달성 요약"을 상단에 유지할 것인가?
2. 보조 액션은 `contextMenu` 유지 vs 명시적 `...` 버튼(가시성 우선) 중 어느 쪽이 더 맞는가?
3. Life 탭 MVP에서 pull-to-refresh(`waveRefreshable`)를 UX 일관성 목적으로 넣을지, 계산 비용 최소화를 위해 생략할지?
4. iPad에서 Auto Achievement를 2열 카드로 고정할지, 1열 가독성 우선으로 갈지?

## Next Steps

- [ ] Open Questions 확정
- [ ] `/plan life-tab-ux-improvement` 으로 구현 계획 생성
