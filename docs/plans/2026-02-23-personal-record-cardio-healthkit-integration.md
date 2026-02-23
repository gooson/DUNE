---
topic: personal-record-cardio-healthkit-integration
date: 2026-02-23
status: draft
confidence: medium
related_solutions:
  - architecture/2026-02-23-activity-detail-navigation-pattern
  - architecture/2026-02-18-healthkit-dedup-implementation
  - general/2026-02-19-review-fix-chart-caching-error-propagation-value-validation
  - healthkit/healthkit-deduplication-best-practices
related_brainstorms:
  - 2026-02-23-personal-record-cardio-healthkit-integration
---

# Implementation Plan: Personal Records (근력+유산소 통합) + HealthKit 확장

## Context

현재 Activity 탭의 Personal Records는 `StrengthPersonalRecord` 기반으로 근력 PR만 노출합니다. 반면 유산소 PR(페이스/거리/시간/칼로리/고도) 로직은 `PersonalRecordService + PersonalRecordStore`로 이미 존재하지만 Exercise 리스트 뱃지 경로에만 연결되어 Activity PR 카드/상세에는 반영되지 않습니다.

이번 변경의 목표는 사용자 결정사항을 그대로 구현하는 것입니다:
- Activity PR를 **근력+유산소 통합 리스트**로 전환
- 유산소 PR 5종 포함 (페이스/거리/시간/칼로리/고도)
- 데이터 정책은 **HealthKit 우선 + 수동 기록 보조**
- HealthKit 확장 정보(HR avg/max/min, stepCount, weather, isIndoor)도 통합
- 권한 거부/데이터 없음 시 카드 숨김 + 안내 문구

## Requirements

### Functional

- Activity 탭 PR 섹션/상세에서 통합 모델을 사용한다 (근력 + 유산소).
- 유산소 PR는 `PersonalRecordType` 5종 기준으로 계산한다.
- 유산소 PR 값이 HealthKit에서 있으면 HealthKit 값을 채택하고, 없으면 수동 기록에서 fallback 계산한다.
- PR 카드/상세에서 가능한 경우 다음 부가 정보를 표시한다:
  - 심박: 평균/최대/최소
  - 걸음수
  - 날씨(온도/습도/상태), 실내/실외
- HealthKit 권한 거부 또는 데이터 부재 시 유산소 PR 카드를 숨기고 안내 문구를 표시한다.

### Non-functional

- 레이어 경계 유지:
  - Domain/UseCase는 SwiftUI/SwiftData 의존 금지
  - ViewModel은 `ModelContext` 직접 의존 금지
- 기존 HealthKit 값 검증 범위 규칙 유지 (pace/distance/elevation/HR finite + range guard).
- 기존 Activity 렌더 성능 패턴 유지 (`.task(id:)`, 캐시 기반 재계산 최소화).
- 기존 PR UX 패턴(SectionGroup, detail navigation, info sheet)을 최대한 재사용한다.

## Approach

핵심은 “통합 표시 모델 + 소스 우선순위 병합 로직”입니다.

1. 통합 PR 표시 모델(근력/유산소 공통)을 추가한다.
2. 기존 `StrengthPRService`와 `PersonalRecordService`는 그대로 재사용하고, 통합 조합은 신규 서비스에서 담당한다.
3. 유산소는 HealthKit 우선:
   - 1차: `PersonalRecordStore`에 저장된 유산소 PR 사용
   - 2차: 해당 metric이 비어 있을 때만 수동 기록에서 fallback 계산
4. `PersonalRecord`에 HealthKit 확장 컨텍스트(optional)를 저장해 Activity 카드/상세에서 즉시 표시한다.
5. Activity PR 섹션/상세/InfoSheet를 통합 모델 기준으로 변경한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| ActivityViewModel 내부에서 즉석 병합 | 파일 추가 최소화 | 비교/정렬/fallback 로직이 VM에 집중되어 테스트 어려움 | 미채택 |
| `PersonalRecordStore`만 사용 (수동 fallback 없음) | 구현 단순 | HealthKit 누락/권한 문제 시 유산소 PR 완전 소실 | 미채택 |
| 신규 통합 서비스 + Store/HK/수동 병합 | 테스트 가능, 정책 반영 명확 | 파일/타입 추가 필요 | **채택** |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `Dailve/Domain/Models/PersonalRecord.swift` | Modify | 유산소 PR에 연결된 HealthKit 확장 컨텍스트(optional) 필드 추가 |
| `Dailve/Domain/Services/PersonalRecordService.swift` | Modify | `buildRecords` 시 확장 컨텍스트를 함께 기록 |
| `Dailve/Data/Persistence/PersonalRecordStore.swift` | Modify | enriched PR 저장/복원, 초기 백필(backfill) 보조 메서드 |
| `Dailve/Domain/Models/ActivityPersonalRecord.swift` | Add | Activity PR 통합 표시 모델(근력/유산소 공통 DTO) |
| `Dailve/Domain/UseCases/ActivityPersonalRecordService.swift` | Add | HealthKit 우선 + 수동 fallback 병합 규칙 구현 |
| `Dailve/Presentation/Activity/ActivityViewModel.swift` | Modify | `personalRecords` 타입 전환, 통합 PR recompute, 안내 문구 상태 추가 |
| `Dailve/Presentation/Activity/Components/PersonalRecordsSection.swift` | Modify | 통합 카드 렌더링(단위/아이콘/보조정보), 안내 문구 표시 |
| `Dailve/Presentation/Activity/PersonalRecords/PersonalRecordsDetailViewModel.swift` | Modify | 통합 모델 로딩 + metric별 필터/정렬 지원 |
| `Dailve/Presentation/Activity/PersonalRecords/PersonalRecordsDetailView.swift` | Modify | mixed metric 대응 차트/그리드 UI로 전환 |
| `Dailve/Presentation/Activity/Components/PersonalRecordsInfoSheet.swift` | Modify | 근력+유산소 통합 기준으로 문구 개편 |
| `Dailve/Presentation/Shared/Extensions/WorkoutActivityType+View.swift` | Modify | 유산소 PR metric 표시용 라벨/아이콘/단위 유틸 추가 |
| `DailveTests/ActivityPersonalRecordServiceTests.swift` | Add | 통합 PR 병합 규칙 테스트 |
| `DailveTests/PersonalRecordServiceTests.swift` | Modify | enriched record 필드 생성/검증 케이스 추가 |
| `DailveTests/ActivityViewModelTests.swift` | Modify | 통합 PR 계산/안내 문구 상태 검증 추가 |

## Implementation Steps

### Step 1: 통합 PR 도메인 모델 + 병합 서비스 추가

- **Files**:
  - `Dailve/Domain/Models/ActivityPersonalRecord.swift` (new)
  - `Dailve/Domain/UseCases/ActivityPersonalRecordService.swift` (new)
- **Changes**:
  - `ActivityPersonalRecord` 추가:
    - `kind` (strengthWeight / fastestPace / longestDistance / longestDuration / highestCalories / highestElevation)
    - `value`, `date`, `isRecent`, `source`, `title`, `subtitle`, `workoutID`
    - optional context: `heartRateAvg/max/min`, `stepCount`, `weatherTemperature/Condition/Humidity`, `isIndoor`
  - 병합 규칙 구현:
    - 근력 PR: 기존 `StrengthPRService` 결과 변환
    - 유산소 PR: HealthKit 기록 우선, metric별로 없을 때만 수동 fallback
    - comparator: pace는 lower-is-better, 나머지는 higher-is-better
    - 정렬 기본: 최근 달성일 내림차순
- **Verification**:
  - 신규 테스트에서 HealthKit 우선/수동 fallback/페이스 비교 방향 검증

### Step 2: PersonalRecord 모델/서비스 확장 (enrichment 저장)

- **Files**:
  - `Dailve/Domain/Models/PersonalRecord.swift`
  - `Dailve/Domain/Services/PersonalRecordService.swift`
- **Changes**:
  - `PersonalRecord`에 optional enrichment 필드 추가 (Codable backward-compatible).
  - `buildRecords`가 `WorkoutSummary`의 HR/step/weather/indoor 정보를 함께 저장.
  - 기존 유효성 검증(값 범위, finite) 유지.
- **Verification**:
  - 기존 `PersonalRecordServiceTests` 통과
  - 신규 필드가 nil/값 모두 decode 가능한지 확인

### Step 3: PersonalRecordStore 보강 + 초기 백필 전략

- **Files**:
  - `Dailve/Data/Persistence/PersonalRecordStore.swift`
- **Changes**:
  - enriched PersonalRecord 저장/복원 반영.
  - `allRecords()` 결과를 Activity VM에서 바로 flatten 가능하도록 helper 추가.
  - 초기 백필 전략:
    - 앱 실행 중 PR store가 비어 있으면 긴 lookback(예: 3650일) HealthKit 조회 1회로 seed
    - 이후에는 주기적으로 최근 workout만 `updateIfNewRecords`로 증분 갱신
  - 권한 거부 시 store 갱신 실패를 Activity VM이 식별할 수 있도록 에러 전달 경로 정리.
- **Verification**:
  - store 공백 상태에서 seed 후 카드 생성 확인
  - seed 이후 재실행 시 중복 seed 방지 확인

### Step 4: ActivityViewModel 통합 PR 계산 경로로 전환

- **Files**:
  - `Dailve/Presentation/Activity/ActivityViewModel.swift`
- **Changes**:
  - `personalRecords` 타입을 통합 모델 배열로 교체.
  - `recomputeDerivedStats()`에서:
    - strength PR 생성
    - cardio PR store + manual fallback 병합
  - 상태 추가:
    - 예: `personalRecordNotice: String?` (권한 거부/데이터 없음 안내)
  - `loadActivityData()` 내에서 PR store 증분 업데이트 + 필요 시 초기 seed 실행.
- **Verification**:
  - 기존 Activity 기능(streak/frequency/weekly stats) 회귀 없음
  - 권한 없음/데이터 없음 상황에서 notice가 기대대로 설정됨

### Step 5: Activity PR UI(섹션/상세/정보시트) 갱신

- **Files**:
  - `Dailve/Presentation/Activity/Components/PersonalRecordsSection.swift`
  - `Dailve/Presentation/Activity/PersonalRecords/PersonalRecordsDetailViewModel.swift`
  - `Dailve/Presentation/Activity/PersonalRecords/PersonalRecordsDetailView.swift`
  - `Dailve/Presentation/Activity/Components/PersonalRecordsInfoSheet.swift`
  - `Dailve/Presentation/Shared/Extensions/WorkoutActivityType+View.swift`
- **Changes**:
  - Summary 카드:
    - metric별 단위/아이콘/포맷 분기 (kg, /km, km, min, kcal, m)
    - enrichment가 있을 때 보조 라인(HR/steps/weather/indoor) 표시
    - 유산소 카드가 없을 때 안내 문구 표시
  - Detail 화면:
    - mixed metric 대응 (metric 선택 필터 또는 metric별 섹션)
    - pace 축 포맷/정렬 방향 별도 처리
  - InfoSheet:
    - 기존 근력 설명 + 유산소 PR 계산/소스 정책/권한 안내 추가
- **Verification**:
  - iPhone/iPad 레이아웃 정상
  - empty/partial 데이터 상태에서 레이아웃 깨짐 없음

### Step 6: 테스트 추가 및 회귀 검증

- **Files**:
  - `DailveTests/ActivityPersonalRecordServiceTests.swift` (new)
  - `DailveTests/ActivityViewModelTests.swift`
  - `DailveTests/PersonalRecordServiceTests.swift`
- **Changes**:
  - 병합 규칙 단위 테스트:
    - HK 우선
    - HK 부재 시 수동 fallback
    - pace lower-is-better
    - 동률 처리(최초/최신 정책 고정)
  - VM 테스트:
    - notice 상태
    - 통합 PR 결과 개수/정렬
  - 기존 PR 테스트 회귀 보강
- **Verification**:
  - `swift test` 또는 `xcodebuild test`로 대상 테스트 통과

## Edge Cases

| Case | Handling |
|------|----------|
| HealthKit 권한 거부 | 유산소 PR 카드 숨김 + 안내 문구 표시, 근력 PR은 유지 |
| HealthKit에 pace/distance 일부 누락 | 해당 metric 계산 스킵, 가능한 metric만 노출 |
| 센서 이상치 (NaN, Inf, 비정상 범위) | 기존 guard 유지 (pace/distance/elevation/HR range validation) |
| 수동 기록만 존재 (HK 전무) | 수동 fallback으로 유산소 PR 생성 |
| 동률 PR | 정책을 명시적으로 고정(기본: 최신 달성 우선) |
| 날씨/실내 정보 없음 | 카드 보조 라인에서 해당 항목만 숨김 |

## Testing Strategy

- Unit tests:
  - `ActivityPersonalRecordServiceTests` 신규 작성 (핵심 병합 규칙 전부)
  - `PersonalRecordServiceTests` 확장 (enriched record 생성/검증)
  - `ActivityViewModelTests` 확장 (notice/통합 계산 검증)
- Integration tests:
  - Activity 탭 진입 후 PR 섹션/상세 드릴다운 흐름 확인
  - Exercise 탭 PR 뱃지 경로와 store 일관성 확인
- Manual verification:
  - HealthKit 허용/거부 각각에서 카드/안내문구 확인
  - HK-only / manual-only / mixed 데이터셋 각각 확인
  - iPhone, iPad(regular width)에서 카드/차트 레이아웃 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 초기 백필 쿼리 비용 증가 | Medium | High | 최초 1회 seed + 증분 업데이트로 제한 |
| 통합 모델 전환으로 UI 회귀 | Medium | Medium | 섹션/상세를 단계적으로 전환, 단위 테스트 선반영 |
| pace 비교 방향 실수 (min vs max) | Medium | High | 전용 테스트 케이스(경계값/동률) 추가 |
| 기존 Exercise PR 뱃지와 store 불일치 | Low | Medium | store 갱신 단일 경로 유지, 테스트에서 교차 검증 |

## Confidence Assessment

- **Overall**: Medium
- **Reasoning**:
  - 기존 구성요소(`StrengthPRService`, `PersonalRecordService`, `PersonalRecordStore`, Activity 상세 네비 패턴)를 재사용할 수 있어 구현 방향은 명확합니다.
  - 다만 “초기 백필 범위(lookback)와 통합 상세 차트 UX(metric 혼합)”는 실제 데이터 규모/화면 검증이 필요해 중간 수준 불확실성이 있습니다.
