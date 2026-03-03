---
tags: [healthkit, notification, background, HRV, workout, PR, smart-alert]
date: 2026-03-03
category: brainstorm
status: draft
---

# Brainstorm: 백그라운드 HealthKit 감지 → 스마트 알림

## Problem Statement

앱이 백그라운드 상태일 때 HealthKit에 새 건강/운동 데이터가 기록되면, 사용자에게 **의미 있는 알림**을 보낸다.
단순 "데이터 도착" 알림이 아니라, **평소 범위를 벗어난 건강 지표** 또는 **운동 개인 기록(PR) 달성**처럼
행동을 유도하는 인사이트를 전달한다.

## Target Users

- DUNE 앱 사용자 (iOS 26+)
- HRV/RHR/수면 등 건강 지표를 매일 추적하는 사용자
- 운동 기록을 남기고 PR 달성을 중시하는 사용자

## Success Criteria

1. 백그라운드에서 HealthKit 변경 감지 → 30초 이내 로컬 알림 전송
2. 건강 데이터: 평소 범위(baseline) 대비 유의미한 변동 시에만 알림 (알림 피로 방지)
3. 운동 데이터: PR 달성 시 매번 알림
4. 사용자가 타입별 on/off 설정 가능
5. 알림 탭 → 앱 내 해당 데이터 상세 화면으로 딥링크

## 참고 앱 알림 패턴

| 앱 | 알림 방식 |
|----|----------|
| **Athlytic** | PR 달성 시 "Top Effort" 알림 + 월간/연간/역대 비교 카드 |
| **Whoop** | HRV/수면 기반 "Recovery Score" 알림 (아침 한 번) |
| **Oura** | Readiness Score + 평소 대비 변동 알림 |
| **Apple Fitness** | Move/Exercise/Stand 목표 달성 알림 |
| **Perform** | 주요 지표 변동 시 "plan adjustment" 알림 |

→ **핵심 인사이트**: 최고의 앱들은 "데이터 도착"이 아니라 "행동 유도 인사이트"를 알림

## Proposed Approach

### 아키텍처 개요

```
HKObserverQuery (기존)
    ↓ change detected
HealthKitObserverManager (기존)
    ↓ type + anchor
NotificationEvaluator (NEW)
    ├─ HealthInsightEvaluator: baseline 비교 → 유의미 변동?
    └─ WorkoutPREvaluator: PR 달성 여부?
    ↓ criteria met
NotificationService (NEW)
    ├─ throttle check (타입당 하루 1회 / 운동은 매번)
    ├─ UNUserNotificationCenter.add()
    └─ deep link URL 첨부
```

### 알림 대상 8개 타입 + 트리거 조건

| 타입 | 빈도 | 트리거 조건 | 알림 예시 |
|------|------|------------|----------|
| **HRV** | 하루 1회 | 7일 평균 대비 ±20% 이상 | "오늘 HRV 42ms — 평소보다 25% 낮아요" |
| **RHR** | 하루 1회 | 7일 평균 대비 ±15% 이상 | "안정시 심박수 72bpm — 평소보다 높아요" |
| **Sleep** | 하루 1회 | 수면 기록 완료 시 항상 (+ 점수) | "수면 기록 완료: 7h 23m, 수면 점수 82" |
| **Steps** | 하루 1회 | 일일 목표 달성 시 | "오늘 걸음 10,000보 달성!" |
| **Weight** | 하루 1회 | 새 기록 시 항상 (+ 변화량) | "체중 기록: 73.2kg (어제 대비 -0.3)" |
| **Body Fat** | 하루 1회 | 새 기록 시 항상 | "체지방률 기록: 18.5%" |
| **BMI** | 하루 1회 | 새 기록 시 항상 | "BMI 업데이트: 23.1" |
| **Workout** | 매번 | PR 달성 시 | "벤치프레스 PR! 100kg x 5 — 역대 최고 볼륨" |

### 핵심 컴포넌트

#### 1. NotificationService (로컬 알림 인프라)

```
Domain/Services/NotificationService.swift (protocol)
Data/Services/NotificationServiceImpl.swift (구현)
```

- `UNUserNotificationCenter` 래핑
- 권한 요청 (`requestAuthorization`)
- 알림 발송 (`scheduleLocalNotification`)
- 딥링크 URL scheme 관리
- 타입별 throttle 관리 (UserDefaults anchor)

#### 2. HealthInsightEvaluator (건강 데이터 평가)

```
Domain/UseCases/HealthInsightEvaluator.swift
```

- 타입별 baseline 계산 (7일 이동평균)
- 현재값 vs baseline 비교 → 유의미 변동 판정
- 알림 메시지 생성 (값 + 변화량 + 해석)

#### 3. WorkoutPREvaluator (운동 PR 평가)

```
Domain/UseCases/WorkoutPREvaluator.swift
```

- 운동 종류별 PR 기준:
  - 근력: 최대 중량, 최대 볼륨(weight × reps), 최대 1RM
  - 유산소: 최장 거리, 최단 시간(동일 거리), 최대 속도
- SwiftData ExerciseRecord에서 히스토리 조회
- PR 달성 판정 + 메시지 생성

#### 4. Observer → Notification 연결

`HealthKitObserverManager`에서 observer fire 시:
1. **기존**: `coordinator.requestRefresh()` (UI 갱신)
2. **추가**: `notificationEvaluator.evaluate(type:)` (알림 판정)

### Anchor Query 전략

`HKObserverQuery`는 "변경 있음"만 알려줌. **어떤 샘플이 새건지**는 `HKAnchoredObjectQuery`로 확인 필요.

```swift
// 타입별 anchor를 UserDefaults에 저장
// observer fire → anchor query → 새 샘플만 추출 → 평가
let anchor = loadAnchor(for: sampleType)
let anchorQuery = HKAnchoredObjectQuery(
    type: sampleType,
    predicate: nil,
    anchor: anchor,
    limit: HKObjectQueryNoLimit
) { query, added, deleted, newAnchor, error in
    saveAnchor(newAnchor, for: sampleType)
    evaluate(newSamples: added ?? [])
}
```

### 설정 화면

```
Settings > Notifications
├─ 알림 허용 (마스터 토글)
├─ 건강 데이터 알림
│   ├─ HRV 이상 감지
│   ├─ 안정시 심박수 이상 감지
│   ├─ 수면 기록 완료
│   ├─ 걸음 수 목표 달성
│   ├─ 체중 기록
│   ├─ 체지방률 기록
│   └─ BMI 업데이트
└─ 운동 알림
    └─ PR 달성 알림
```

## Constraints

### 기술적 제약

- **백그라운드 실행 시간**: iOS는 백그라운드 delivery 시 ~30초 실행 시간만 허용
  - Baseline 계산이 30초 안에 완료되어야 함
  - 복잡한 통계는 포그라운드에서 미리 캐싱 → 백그라운드에서는 캐시 참조만
- **로컬 알림 전용**: 서버 인프라 없음 → 리모트 푸시 불가
  - `UNUserNotificationCenter` 로컬 알림만 사용
- **Anchor 영속성**: 앱 재설치 시 anchor 초기화 → 초기 중복 알림 가능성
- **HKObserverQuery 특성**: 앱 재시작 시 모든 observer가 한 번 fire됨

### 기존 코드 영향

- `HealthKitObserverManager`: observer callback에 notification evaluator 호출 추가
- `AppRefreshCoordinator`: notification 평가 트리거 추가 가능
- `DUNEApp`: `UNUserNotificationCenter.delegate` 설정 필요
- `Info.plist`: 이미 `remote-notification` background mode 있음 (추가 설정 불필요)

## Edge Cases

### 중복 알림 방어
- 앱 재시작 시 observer 일괄 fire → anchor 기반으로 이미 처리된 샘플 skip
- 같은 타입 하루 여러 번 fire → UserDefaults에 `lastNotificationDate[type]` 저장

### Baseline 부족
- 앱 설치 초기 7일간은 baseline 데이터 부족
- → 7일 미만이면 해당 타입 스마트 알림 비활성 (단순 기록 알림만)

### 수면 데이터 특수성
- 수면은 여러 단계(awake, REM, deep, core)가 개별 샘플로 들어옴
- 마지막 단계(기상) 감지 시에만 "수면 기록 완료" 알림 1회

### 운동 PR 판정
- 같은 운동의 정의가 애매할 수 있음 (바벨 벤치 vs 덤벨 벤치)
- → `ExerciseType` 기준으로 PR 판정 (변형은 별도 타입)

### 알림 권한 거부
- 사용자가 알림 권한 거부 → 설정에서 안내 문구 표시
- 시스템 설정에서 재허용 후 앱에서 재등록

### Background Delivery 미보장
- iOS가 백그라운드 delivery를 보장하지 않음 (배터리 상태, 시스템 부하에 따라 지연/누락)
- → 포그라운드 전환 시에도 미발송 알림 체크 + 발송

## Scope

### MVP (Must-have)

- [ ] `NotificationService` 프로토콜 + 구현 (권한 요청, 발송, throttle)
- [ ] `HealthInsightEvaluator` (7일 baseline 비교, 8개 타입)
- [ ] `WorkoutPREvaluator` (근력: 최대 중량/볼륨, 유산소: 최장 거리/최단 시간)
- [ ] Anchor query 기반 새 샘플 감지
- [ ] 타입별 알림 on/off 설정 화면
- [ ] 알림 탭 → 앱 해당 화면 딥링크
- [ ] 알림 메시지 3개 언어 (en/ko/ja)
- [ ] 건강 데이터: 타입당 하루 1회 throttle
- [ ] 운동 데이터: PR 달성 시 매번

### Nice-to-have (Future)

- 알림 히스토리 화면 (과거 알림 목록)
- 알림 시간대 설정 (예: 오전 6~10시만)
- 주간 요약 알림 ("이번 주 HRV 평균 +8%, 좋은 흐름!")
- Watch 알림 연동 (iOS 알림 → Watch mirror는 기본 지원)
- 친구/가족 PR 축하 알림 (소셜 기능)
- 알림 민감도 커스텀 (±20% → 사용자가 조절)
- 리모트 푸시 (서버 인프라 구축 시)

## Open Questions

1. **Baseline 계산을 어디서 할 것인가?**
   - 옵션 A: 포그라운드에서 캐싱 → 백그라운드에서 캐시 참조 (안전, 30초 제약 회피)
   - 옵션 B: 백그라운드에서 직접 계산 (간단하지만 30초 제약 위험)
   - → A가 안전. `AppRefreshCoordinator`의 refresh 결과를 캐싱

2. **운동 PR 판정의 데이터 소스?**
   - 옵션 A: SwiftData `ExerciseRecord`에서 직접 조회
   - 옵션 B: HealthKit `HKWorkout`에서 조회
   - → A가 적합 (세트/중량/횟수 상세 데이터는 SwiftData에만 있음)

3. **수면 "완료" 시점 감지 방법?**
   - `HKCategoryType.sleepAnalysis` observer가 fire될 때, 가장 최근 수면 세션의 endDate가 현재 시각 기준 일정 범위 내인지 확인
   - 또는 `inBed` 카테고리의 endDate 기준

4. **알림 설정 저장 위치?**
   - UserDefaults (단순, 디바이스 로컬)
   - SwiftData (CloudKit 동기화 → 멀티 디바이스 설정 공유)
   - → MVP: UserDefaults, 추후 CloudKit 동기화

## Next Steps

- [ ] `/plan healthkit-background-notifications` 으로 구현 계획 생성
- [ ] Baseline 캐싱 전략 상세 설계
- [ ] 알림 메시지 카피 작성 (en/ko/ja)
- [ ] 설정 화면 UI 설계
