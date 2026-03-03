---
tags: [notification, ux, ui, design-system, navigation, today-tab]
date: 2026-03-04
category: brainstorm
status: draft
---

# Brainstorm: Notifications 디자인 UX/UI 통합 개선

## Problem Statement

현재 `NotificationHubView`는 기본 `List` 중심으로 구성되어 있어, Today/Activity/Wellness 탭에서 사용하는 배경/카드/모션 패턴과 시각적 일관성이 낮다.
또한 알림 항목 탭 시 `route == nil`이면 화면 전환이 발생하지 않아, 사용자가 "탭했는데 아무 일도 안 일어남"으로 인지할 가능성이 있다.

## Target Users

- Today 탭에서 알림 히스토리를 빠르게 확인하는 iPhone/iPad 사용자
- 알림 타입(건강 이상/수면/걸음/PR 등)을 한눈에 구분하고 싶은 사용자
- 알림 탭 시 항상 다음 행동(상세 보기, 대체 화면, 설정 이동)이 보장되길 원하는 사용자

## Success Criteria

1. 빈 상태 화면이 디자인 시스템(`TabWaveBackground`, 카드 스타일)과 시각적으로 통일된다.
2. 모든 알림 row에 타입 기반 아이콘이 노출되어 정보 인지 속도가 향상된다.
3. 알림 허브가 단순 리스트가 아니라 카드형 정보 구조(우선순위/읽음 상태)로 구분된다.
4. 알림 탭 시 100% 목적지 전환 또는 명시적 fallback 화면 전환이 발생한다.
5. 카드 등장/상태 전환 애니메이션을 포함하되, 접근성(감소된 동작 설정) 대응을 유지한다.
6. 최종 디자인 품질은 "이쁘면 됨" 기준으로 내부 리뷰에서 시각 만족 합의를 통과한다.

## Proposed Approach

### 1) Visual Structure (일관성)

- 배경: `List` 기본 배경 대신 `TabWaveBackground` 적용
- 컨테이너: 알림 row를 `InlineCard` 또는 `StandardCard` 기반으로 정렬
- 빈 상태: `ContentUnavailableView` 대신 기존 `EmptyStateView` 패턴으로 통일

### 2) Notification Row Redesign

- 좌측 leading에 타입 아이콘 추가 (`HealthInsight.InsightType` 기반)
- 읽지 않음 상태는 점(dot) + 카드 border/tint로 이중 표현
- 보조 정보:
  - 상대 시간(현재 유지)
  - 목적지 라벨(예: Workout Detail, Health Trend)
- 시각효과:
  - 첫 진입 시 row staggered fade/slide (reduce motion 시 비활성)
  - 읽음 처리 시 `DS.Animation.snappy`로 tint 완화

### 3) Always-Navigable Tap Policy (핵심)

현 상태:
- `open(itemID:)`에서 `route`가 없으면 읽음 처리만 하고 이동 없음

개선 정책:
- 알림 탭 시 반드시 아래 중 하나로 이동
  1. `route` 존재: 기존 목적지로 이동
  2. `route` 없음 + 타입 매핑 가능: 타입별 기본 목적지(상세 화면)로 이동
     - 예: `sleepComplete` → Wellness/Sleep 관련 상세
     - 예: `stepGoal` → Activity/걸음 관련 상세
  3. 위 2개 모두 불가: `NotificationTargetNotFoundView` 유사 fallback 화면으로 이동

즉, "무반응 탭" 케이스를 0으로 만든다.

### 4) Information Architecture

- 헤더 영역(요약): 미읽음 개수 + 빠른 액션(`Read All`, `Delete`, `Notification Settings`)
- 본문: 최신순 카드 리스트
- 그룹핑(선택): `Today / Earlier` 2섹션 (MVP에서는 단일 리스트 유지 가능)
- 빈 상태 CTA(추천): `알림 설정 열기`를 primary로 제공
- 빈 상태 보조 CTA(선택): `Today로 돌아가기`

### 5) Icon System Mapping

`HealthInsight.InsightType`별 제안 아이콘:
- `hrvAnomaly`: `waveform.path.ecg`
- `rhrAnomaly`: `heart.fill`
- `sleepComplete`: `moon.fill`
- `stepGoal`: `figure.walk`
- `weightUpdate`: `scalemass`
- `bodyFatUpdate`: `percent`
- `bmiUpdate`: `number`
- `workoutPR`: `trophy.fill`

(설정 화면 매핑과 동일 규칙 재사용)

## Constraints

### 기술적 제약

- `List` 커스터마이징 범위 제한으로 카드형 디자인을 위해 `ScrollView + LazyVStack` 전환 가능성 검토 필요
- 탭 라우팅은 현재 `NotificationRoute`가 `workoutDetail` 중심이라 타입별 default destination 규약 추가 필요
- 과도한 애니메이션은 성능/가독성 저하 가능, `accessibilityReduceMotion` 대응 필수

### 디자인 제약

- 기존 탭 대비 과한 시각 효과는 정보 밀도와 충돌 가능
- 다크 모드에서 border/tint 대비(최소 opacity) 유지 필요

## Edge Cases

- `route`의 대상 데이터가 삭제됨: fallback 화면으로 전환
- 오래된 알림에 타입은 있으나 상세 데이터 없음: 타입별 허브/요약 화면으로 이동
- 연속 탭: 중복 push 방지(동일 목적지 debounce)
- 미읽음이 많은 경우(100+): 초기 렌더 성능 저하 방지 필요

## Scope

### MVP (Must-have)

- [ ] 빈 상태 UI를 디자인 시스템 기반으로 교체
- [ ] 알림 row 아이콘 추가 (타입 매핑)
- [ ] 카드형 row 스타일 적용
- [ ] 탭 시 무조건 이동 정책(목적지 or fallback) 적용
- [ ] 읽음/미읽음 + 삭제 액션 동시 지원
- [ ] 헤더에 `Read All` + `Delete` + 설정 이동 액션 정리
- [ ] 카드 등장/상태 전환 애니메이션 포함 (reduce motion 대응)

### Nice-to-have (Future)

- `Today / Earlier` 그룹핑
- 필터(미읽음만, 타입별)
- 스와이프 액션(읽음/삭제)
- subtle parallax/wave 반응형 효과

## Decisions (2026-03-04)

1. 성공 기준: 정량보다 시각 만족 우선("이쁘면 됨")
2. 기본 이동 목적지: 타입별 상세 화면 우선
3. 기능 범위: 읽음/미읽음 + 삭제 둘 다 MVP 포함
4. 빈 상태 CTA: 추천안 채택 (`알림 설정 열기` primary)
5. 애니메이션: 카드 등장 애니메이션 포함

## Next Steps

- [ ] `/plan notifications-ux-ui-integration-improvement` 으로 구현 계획 생성
- [ ] 타입별 기본 목적지 매핑표 확정
- [ ] `NotificationHubView` wireframe(v1) -> 구현
- [ ] iPhone/iPad UI 테스트 시나리오 추가
