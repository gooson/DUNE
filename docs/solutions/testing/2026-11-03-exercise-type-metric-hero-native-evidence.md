---
tags: [swiftui, training-volume, exercise-type, accessibility, native-capture, provenance]
category: testing
date: 2026-11-03
status: implemented
severity: important
related_files:
  - DUNE/Presentation/Activity/TrainingVolume/ExerciseTypeDetailView.swift
  - DUNEUITests/Full/ActivityExerciseRegressionTests.swift
  - DUNEUITests/Full/ExerciseTypeHealthKitVariantUITests.swift
related_solutions:
  - docs/solutions/testing/2026-03-08-training-volume-daily-volume-scroll-and-day-bucket-alignment.md
---

# Solution: 운동 종류 상세의 실제 값과 기기별 원본 근거 유지

## Problem

### Symptoms

운동 종류 상세의 선택적 무게 볼륨과 거리, 시간 중심 운동 및 원래 유형 아이콘을 같은 가짜 수치로 표현하면 실제 원천과 화면 의미가 달라진다. 최대 접근성 글씨에서는 중간 Training Volume 카드의 중심이 화면 밖에 있어도 일부가 보이고 탭 가능할 수 있다. 과거 디자인맵 이미지의 공통 인덱스 버전은 개별 PNG의 실제 실행 버전을 증명하지 않는다.

### Root Cause

운동별 선택적 값과 이전 기간은 같은 데이터 계약을 따르지만 표시 가능 여부가 다르다. 큰 카드의 중심을 가시성 조건으로 강제하면 실제 탭 가능한 뷰포트 교차를 실패로 오인한다. 기기별 과거 PNG, 테스트 실행과 접근성 계층을 연결하지 않으면 비교 출처를 과장할 수 있다.

## Solution

### Changes Made

| 파일 | 변경 | 이유 |
|---|---|---|
| `ExerciseTypeDetailView.swift` | 실제 양수 볼륨, 시간, 칼로리, 세션 순으로 가능한 hero 값을 선택하고 선택적 거리·볼륨과 기존 유형/장비 아이콘을 보존한다. 비교 기간 캡션은 분석 차트의 시작일에서 한 번만 표시한다. | 원천에 없는 수치와 반복 날짜를 만들지 않는다. |
| 같은 View | 새 Duration/ Sessions 지표의 hero 및 비교 아이콘을 A06의 `timer` / `figure.strengthtraining.traditional`과 정렬한다. 기존 최근 세션의 `clock`과 유형별 아이콘은 유지한다. | 새 지표 영역의 의미를 일관되게 표시한다. |
| `ActivityExerciseRegressionTests.swift` | 기존 hittable 검사 후 큰 카드의 실제 viewport 교차를 확인하고 기존 header reveal/tap과 상세 assertion을 유지한다. | 화면에 일부 보이는 실제 카드의 도달 가능성을 검증한다. |
| `ExerciseTypeHealthKitVariantUITests.swift` | 실제 seed에서 네 HealthKit 유형의 Week 상세를 검증하고 캡처한다. | 장비·원천별 값과 상세 경로를 확인한다. |

### Key Code

이전 기간 표시는 `trendData.first?.date`의 분석 시작일을 기준으로 선택 기간만큼 이전 날짜를 계산하고 시작점을 얻지 못하면 일반 이전 기간 설명을 사용한다. 기간 집계는 main에 반영된 A06의 명시적인 로컬 달력 범위를 그대로 상속하며, A07에서 ViewModel이나 분석 서비스를 변경하지 않는다. 기존 최근 세션, 기간 선택과 차트 데이터 원천을 보존한다.

## Prevention

### Checklist Addition

- [ ] 유형별 원본 아이콘과 실제 선택적 수치의 유무를 수동 운동과 HealthKit 운동 각각 확인한다.
- [ ] 커다란 카드의 실제 viewport 교차와 hittability를 확인하고, 상세 진입·기존 assertion을 유지한다.
- [ ] 과거 PNG와 AX를 같은 테스트, 기기, 액션, checkpoint 및 실행 결과에 연결한다. 전체 batch가 실패해도 개별 selector가 통과한 경우 그 범위만 기록한다.
- [ ] 공통 ViewModel의 실제 날짜 계약과 이전 기간 캡션을 함께 확인한다.

### Rule Addition (if applicable)

새 규칙 추가 없음. 기존 실행·출처 검증 규칙을 적용하며 `.claude` 원본은 수정하지 않았다.

## Lessons Learned

대용량 글씨의 가시성은 카드 중심의 위치와 다르며, 시각 비교의 출처는 기기별·상태별로 증명해야 한다. 동일 모델의 다른 시뮬레이터도 같은 인스턴스로 표현하지 않는다.

## 현재 검증 및 미완료 범위

AEDF 소스에서 iPad 일반 수동/HK 2/2 및 별도 승인된 dark MAX 1/1, Phone 일반 수동/HK 2/2, Duo 접힘 2/2와 펼침 2/2가 실제 통과했다. 현재 양성 case는 총 9개다. Duo는 같은 소유 기기를 순서대로 사용했고 각 자세에서 14/14 실제 캡처 ACK와 0°/LCD 및 180°/LCD-1 readback을 확인했다. 검증 뒤 소유 시뮬레이터 세 대를 모두 삭제했다.

과거 iPad MAX 원본 두 실패(첫 묶음 3개 중 2 PASS/1 FAIL, 두 번째 1 FAIL)는 보존했다. 별도 승인된 추가 실행은 한 번 소모해 1 PASS, 남은 실행은 0이다. 원본 A20 manual selector는 6개 중 5 PASS/1 FAIL 묶음에서 개별 PASS했고 원본 HK selector는 2/2 PASS 묶음에서 개별 PASS했다. PNG/AX/manifest와 selector를 연결하되 동일 모델의 다른 인스턴스를 같은 기기로 표현하지 않는다. iPad 외 과거 맵 PNG의 정확한 모델·실행 버전·AX 및 Duo 자세는 확인되지 않았다. Phone/iPad는 manual Week, Duo는 manual Month끼리 비교하며, 원래 인덱스의 iPad map-before도 별도로 보존한다.

[실제 캡처와 출처](../../design/full-redesign-map/review/a07-exercise-type-native-2026-11-03/index.html)는 4개 A07 행과 Activity 보드만 갱신한다. 다른 화면과 이전 갤러리·Watch는 해시로 보존했다. 네 HealthKit 유형의 A20 원본/현재 비교와 각 기기의 보조 상태도 포함한다.

현재 AEDF iOS 빌드와 iOS 단위 CI(2739 Swift Testing + 12 XCTest)가 통과했다. Watch CI는 대상 destination ID 누락으로 테스트 시작 전 exit64가 발생했으며 전체 CI 통과로 표현하지 않는다. A06의 기존 focused 34개 unit과 성공한 CI는 변경되지 않은 공통 business 코드의 main40→AEDF blob 동일성 범위에서만 재사용한다. 새 A07 로컬 전체 unit 실행은 하지 않았다.

선택 차트의 날짜 formatter/calendar 작업 두 건에 대한 성능 P3는 측정된 지연 없이 캐시 상태와 locale/calendar 무효화 복잡도를 늘리는 tradeoff로 보류했다. 좁은 주간 차트의 날짜 눈금 밀집은 원래 차트에서도 보이는 제한이며 이번 지표·히어로 개편에서 고쳤다고 주장하지 않는다. 큰 글씨 검사는 iPad 대상이며 Phone MAX, live VoiceOver, 실제 사용 중 접힘 연속성이나 새 3M/6M 네이티브 검증으로 확대하지 않는다.
