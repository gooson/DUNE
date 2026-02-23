---
tags: [activity, personal-records, cardio, healthkit, integration]
date: 2026-02-23
category: brainstorm
status: draft
---

# Brainstorm: Personal Record 근력+유산소 통합 및 HealthKit 확장

## Problem Statement

현재 Activity 탭의 Personal Record는 근력(무게) 중심으로 계산/표시되어 유산소 성과가 충분히 반영되지 않습니다. 또한 HealthKit에서 이미 가져오는 심박/걸음수/날씨/실내 여부 같은 정보가 PR 경험에 통합되지 않아, 운동 성과를 종합적으로 이해하기 어렵습니다.

## Target Users

- 근력과 유산소를 함께 수행하는 사용자
- Apple Watch/HealthKit 기반으로 운동을 기록하는 사용자
- PR 달성 맥락(심박, 환경 정보)까지 함께 확인하고 싶은 사용자

## Success Criteria

- Activity 탭 PR가 근력+유산소 통합 리스트로 표시된다
- 유산소 PR 5종(페이스/거리/시간/칼로리/고도)이 반영된다
- PR 계산은 HealthKit 우선, 수동 기록 보조 정책을 따른다
- PR 표시 시 가능한 경우 심박(avg/max/min), 걸음수, 날씨/실내 정보를 함께 제공한다
- HealthKit 권한 거부/데이터 없음 시 해당 카드 숨김 + 안내 문구가 표시된다

## Proposed Approach

### 1) PR 모델 통합

- 기존 근력 PR(`StrengthPersonalRecord`)과 유산소 PR(`PersonalRecordType`)를 하나의 표시 모델로 통합
- 예시: `ActivityPersonalRecordItem`
  - `metricType` (strengthWeight / fastestPace / longestDistance / longestDuration / highestCalories / highestElevation)
  - `value`, `unit`, `date`, `title`, `isRecent`
  - `activityType`, `source` (HealthKit/manual), `workoutID`
  - optional enrichment: `heartRateAvg/Max/Min`, `stepCount`, `weather`, `isIndoor`

### 2) 계산 파이프라인

- 근력 PR: 기존 `StrengthPRService` 기반 로직 재사용
- 유산소 PR: 기존 `PersonalRecordService` + `PersonalRecordStore` 재사용
- 병합 전략:
  - HealthKit 워크아웃으로 유산소 PR 계산
  - 수동 기록으로 근력 PR 계산
  - 동일 metric 내 최고치(또는 페이스는 최저치)만 유지
  - 최종적으로 통합 리스트로 정렬(기본: 최근 달성일)

### 3) HealthKit 확장 정보 통합

- PR 계산 핵심값: pace/distance/duration/calories/elevation
- 추가 표시값: HR(avg/max/min), step count, weather, indoor
- 표시 정책:
  - 값이 존재할 때만 노출
  - 누락 시 카드 레이아웃이 깨지지 않게 optional row 처리

### 4) UI 반영

- `PersonalRecordsSection` 입력 타입을 통합 모델 배열로 변경
- 카드 단위로 metric별 아이콘/단위/색상 분기
- `PersonalRecordsDetailView` 차트도 metric 타입에 따라 축/포맷 분기
  - pace는 값이 작을수록 좋은 지표임을 반영
- `PersonalRecordsInfoSheet` 문구를 근력+유산소 통합 기준으로 갱신

### 5) 권한/빈 데이터 UX

- HealthKit 권한 거부 또는 HK 값 부재:
  - 해당 유산소 PR 카드 숨김
  - 섹션 내 안내 문구 노출 (예: "HealthKit 권한을 허용하면 유산소 PR을 볼 수 있어요.")
- 수동 기록만 있는 경우:
  - 근력 PR은 정상 노출

## Constraints

- 기존 Activity PR 경로는 근력 전용이므로 타입 전환 시 영향 범위가 넓음
- 페이스는 "낮을수록 좋음", 나머지는 "높을수록 좋음"으로 비교 기준이 다름
- HealthKit 데이터는 일부 세션에서 누락 가능(특히 날씨/걸음수)
- 권한 상태/데이터 가용성에 따른 조건부 렌더링이 필요

## Edge Cases

- HealthKit 권한 거부: 유산소 PR 카드 숨김 + 안내 문구 표시
- 거리 기반 운동인데 distance/pace 누락: 해당 metric PR 계산 스킵
- 센서 이상치: 기존 validation 범위 유지 (pace, distance, elevation, HR)
- 동률 기록: 동일 값일 때 우선순위 정책 필요(최초 달성 vs 최신 달성)
- 실내 운동: weather 없음 + indoor만 있을 수 있음

## Scope

### MVP (Must-have)

- [ ] Activity PR를 근력+유산소 통합 리스트로 전환
- [ ] 유산소 PR 5종(페이스/거리/시간/칼로리/고도) 반영
- [ ] HealthKit 우선 + 수동 보조 정책 반영
- [ ] HR(avg/max/min), 걸음수, 날씨/실내 정보 연결
- [ ] 권한 거부/데이터 없음 시 카드 숨김 + 안내 문구 처리

### Nice-to-have (Future)

- [ ] PR 필터(전체/근력/유산소)
- [ ] PR 갱신 하이라이트 애니메이션/토스트 강화
- [ ] 월간/분기 PR 추세 비교

## Resolved Questions

- Purpose: Activity 탭 PR를 근력+유산소 통합 리스트로 변경
- Cardio PR 지표: 페이스/거리/시간/칼로리/고도
- HealthKit 통합 범위: PR 필수값 + 심박(avg/max/min) + 걸음수 + 날씨/실내
- 소스 정책: HealthKit 우선 + 수동 기록 보조
- 빈 데이터 정책: 해당 카드 숨김 + 안내 문구

## Open Questions

- 확장 정보(HR/날씨/실내)를 카드 본문에 상시 노출할지, 상세에서만 노출할지
- 동률 PR 발생 시 기준(최초 달성/최신 달성)
- 통합 리스트 정렬 우선순위(최신 달성일/metric 중요도)

## Next Steps

- [ ] `/plan personal-record-cardio-healthkit-integration` 으로 구현 계획 생성
