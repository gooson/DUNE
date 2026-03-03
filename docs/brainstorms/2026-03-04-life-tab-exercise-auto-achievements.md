---
tags: [life-tab, habit, healthkit, workout, auto-achievement, weekly-goal]
date: 2026-03-04
category: brainstorm
status: draft
---

# Brainstorm: Life 탭 운동 자동 달성 시스템

## Problem Statement
현재 Life 탭은 사용자가 직접 `New Habit`을 만들고 체크/입력하는 흐름이 중심이다.  
운동은 HealthKit과 연동되지만, 주간 운동 목표(예: 주 5회, 주 15km 러닝, 부위별 근력 빈도)를 자동으로 달성 등록해 주는 시스템이 없어 반복 입력 부담이 발생한다.

## Target Users
- HealthKit 기반으로 운동을 기록하는 iPhone/Apple Watch 사용자
- 주간 목표를 중심으로 루틴을 관리하는 사용자
- 수동 체크보다 자동 피드백을 선호하는 사용자

## Success Criteria
- 자동 등록 정확도(HealthKit 연동 데이터 기준)가 높고 일관적일 것
- 월요일 시작 주간 기준으로 규칙이 예측 가능하게 동작할 것
- 과거 기록에도 소급 적용되어 첫 진입 시에도 누적 달성 상태가 반영될 것

## Proposed Approach
- `New Habit`과 분리된 `Auto Workout Achievements` 섹션을 Life 탭에 추가
- HealthKit 연동 운동 기록만 집계하여 주간 규칙 엔진으로 달성 여부 계산
- 규칙:
  - 주간 운동 5회 이상
  - 주간 운동 7회 이상
  - 주간 근력 운동 3회 이상
  - 주간 부위별 근력 3회 이상 (가슴/등/하체/어깨/팔)
  - 주간 러닝 15km 이상
- 현재 주 진행률 + 주간 연속 달성(streak) 제공

## Constraints
- HealthKit 원천 데이터가 누락되거나 sync 지연 시 자동 등록 결과도 지연될 수 있음
- 주간 기준은 사용자 로캘이 아니라 **월요일 시작 고정** 요구사항을 만족해야 함
- 기존 Habit 모델/수동 입력 흐름과 충돌 없이 공존해야 함

## Edge Cases
- HealthKit 연결 실패/권한 거부 상태에서 자동 달성 섹션 표시 정책
- 중복 운동 기록(동일 workout ID) 집계 중복 방지
- 거리 단위 혼재(km/m) 데이터 방어
- 주 경계(일요일↔월요일) 및 타임존 변경 시 계산 일관성
- 근력 분류가 어려운 운동 타입(기록에 근육 정보가 없는 경우) 처리

## Scope
### MVP (Must-have)
- HealthKit 기반 자동 집계
- 월요일 시작 주간 계산
- 소급 적용
- 아래 규칙 전부 포함:
  - 주 5회/7회 운동
  - 근력 3회
  - 부위별 3회
  - 러닝 15km

### Nice-to-have (Future)
- 사용자별 규칙 커스터마이즈
- 알림/배지 연동
- 달성 이유(근거 운동 목록) drill-down 상세 화면

## Open Questions
- 없음 (요구사항 확정 완료)

## Next Steps
- [ ] /plan 으로 구현 계획 생성
