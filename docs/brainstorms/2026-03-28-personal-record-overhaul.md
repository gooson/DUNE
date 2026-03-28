---
tags: [personal-record, strength, 1rm, swiftdata, pr-history]
date: 2026-03-28
category: brainstorm
status: draft
---

# Brainstorm: Personal Record System Overhaul

## Problem Statement

현재 PR 시스템의 한계:
1. **Strength PR이 단순 평균 중량만 추적** — 1RM, 렙별 PR, 볼륨 PR 미지원
2. **PR 히스토리 미보존** — 최고 기록만 저장, 시간에 따른 성장 추이 불가
3. **UserDefaults 저장** — 구조적 한계 (쿼리 불가, CloudKit 미연동, 확장성 부족)
4. **PR 달성 UX 부재** — 세션 종료 시 축하 화면 없음, 대시보드 노출 부족

## Target Users

- 근력 운동 중심 사용자: 벤치프레스/스쿼트/데드리프트 등 주요 리프트 PR 추적
- 유산소 운동 사용자: 페이스/거리/칼로리 등 기존 PR 유지
- 성장 동기 부여가 필요한 사용자: PR 타임라인으로 진행 상황 시각화

## Success Criteria

- [ ] 1RM 추정치 기반 PR 감지 및 표시 동작
- [ ] 3RM, 5RM, 10RM 렙 레인지별 PR 추적 동작
- [ ] 운동별 단일 세션 총 볼륨 PR 추적 동작
- [ ] PR 히스토리가 SwiftData에 저장되고 타임라인 그래프로 표시
- [ ] 세션 종료 시 달성 PR 축하 화면 표시
- [ ] 대시보드에 최근 PR 위젯 표시
- [ ] 기존 UserDefaults PR → SwiftData 마이그레이션 완료
- [ ] 기존 리워드 시스템(레벨/배지/포인트) 유지 + 새 PR 타입 리워드 확장

## Proposed Approach

### Phase 1: 데이터 모델 & 저장소 리뉴얼

**SwiftData 마이그레이션**
- `PersonalRecordEntry` @Model 생성 (PR 히스토리 보존용)
- `PersonalRecordStore` UserDefaults → SwiftData 래퍼로 전환
- 기존 UserDefaults 데이터 → SwiftData 일회성 마이그레이션
- CloudKit 자동 동기화 확보

**새 PR 타입 모델링**

```
PersonalRecordEntry (@Model)
├── id: UUID
├── exerciseName: String
├── activityType: String (WorkoutActivityType rawValue)
├── kind: PRKind (1rm, repMax3, repMax5, repMax10, volume, pace, distance, calories, duration, elevation)
├── value: Double
├── date: Date
├── isCurrent: Bool (현재 최고 기록 여부)
├── context: PRContext? (HR, 날씨, steps 등)
└── metadata: PRMetadata? (reps, weight, formula 등)
```

### Phase 2: 1RM & 렙 PR 감지 로직

**1RM 추정 (Epley 공식)**
- `estimated1RM = weight × (1 + reps / 30)`
- 적용 조건: reps ≤ 10 (10렙 초과 시 정확도 급감)
- 세트별 1RM 계산 → 세션 내 최고값 = 해당 운동 1RM

**렙 레인지별 PR (3RM, 5RM, 10RM)**
- 정확히 N렙 세트의 최고 중량 추적
- 예: 5RM PR = "5렙으로 들어올린 최고 중량"

**볼륨 PR**
- 운동별 단일 세션 총 볼륨 = Σ(weight × reps) for all sets
- 세션 단위 비교

**감지 플로우**
```
세트 완료 → StrengthPRDetector 호출
  ├── 1RM 추정 계산 (Epley)
  ├── 해당 렙수의 repMax PR 비교
  ├── 세션 누적 볼륨 계산
  └── 기존 PR과 비교 → 신규 PR 목록 반환
```

### Phase 3: UI/UX 개선

**세션 종료 축하 화면**
- 운동 완료 시 달성 PR이 있으면 축하 오버레이
- PR 종류별 아이콘 + 이전 기록 대비 개선폭 표시
- 공유 가능한 카드 생성 (기존 WorkoutShareCard 확장)

**PR 타임라인 그래프**
- 운동별 시간에 따른 PR 변화 차트
- 1RM / 렙PR / 볼륨 세그먼트 전환
- 이전 기록 대비 delta 표시

**대시보드 PR 위젯**
- 최근 7일 내 달성 PR 요약 카드
- InsightCard 스타일로 대시보드에 통합

**PersonalRecordsDetailView 리뉴얼**
- 운동별 PR 보드 (1RM, 3RM, 5RM, 10RM, Volume 한 화면)
- 타임라인 그래프 (기간 선택 가능)
- 리워드/마일스톤 섹션 유지

### Phase 4: 리워드 시스템 확장

- 기존 레벨/배지/포인트 마이그레이션
- 새 PR 타입별 배지 추가 (1RM Club, Volume King 등)
- 연속 PR 달성 streak 배지

## Constraints

- **기술적**: SwiftData VersionedSchema 마이그레이션 필요 (swiftdata-cloudkit.md 규칙 준수)
- **1RM 공식 한계**: 10렙 초과 시 Epley 부정확 → 10렙 이하만 1RM 계산
- **bodyweight 운동**: 1RM 개념 부적합 → 렙 PR / 볼륨 PR만 적용
- **CloudKit 전파**: 잘못된 PR 데이터 전파 방지 → 입력 시점 검증 강화
- **기존 데이터 호환**: UserDefaults → SwiftData 마이그레이션 무손실 필수

## Edge Cases

- **운동 이름 변경**: 커스텀 운동 이름 변경 시 PR 히스토리 연결 유지
- **단위 변경**: kg ↔ lbs 전환 시 PR 값 변환
- **0렙/0중량 세트**: PR 계산에서 제외
- **bodyweight 운동**: 중량 = 0 → 1RM/중량 PR 비활성, 렙수/볼륨만 추적
- **데이터 삭제**: ExerciseRecord 삭제 시 PR 재계산 필요 여부
- **동일 날짜 복수 세션**: 세션별 독립 볼륨 PR 비교

## Scope

### MVP (Must-have)
- 1RM 추정 PR (Epley) 감지 및 표시
- 3RM, 5RM, 10RM 렙 레인지 PR
- 볼륨 PR (운동별 세션 총 볼륨)
- PR 히스토리 SwiftData 저장 + 타임라인 그래프
- 세션 종료 축하 화면 (달성 PR 요약)
- 대시보드 최근 PR 위젯
- UserDefaults → SwiftData 마이그레이션
- 리워드 시스템 유지 + 새 PR 타입 리워드

### Nice-to-have (Future)
- 운동 중 실시간 PR 알림 (세트 완료 즉시)
- Watch PR 알림 연동
- PR 달성 시 소셜 공유 (Instagram Story 등)
- 운동별 PR 예측 (현재 추이 기반)
- 사용자 정의 PR 타입 (커스텀 목표)
- Brzycki/복수 공식 선택 옵션

## Open Questions

1. ExerciseRecord 삭제 시 PR도 롤백할 것인가, 아니면 "한번 달성한 PR은 유지"인가?
2. 카디오 PR도 SwiftData로 통합할 것인가, 아니면 strength만 먼저?
3. PR 타임라인 차트의 기간 범위 (1개월/3개월/6개월/1년/전체)?
4. 대시보드 PR 위젯의 정확한 위치와 우선순위 (InsightCard vs 전용 섹션)?

## Competitive Research (2026-03-28)

### 벤치마크 앱 분석 요약

| 기능 | Strong | Hevy | Fitbod | Strava | NRC |
|------|--------|------|--------|--------|-----|
| **1RM 추적** | Yes | Yes | Yes (Estimated Strength) | - | - |
| **렙별 PR** | - | **Set Records (1~N렙)** | - | - | - |
| **볼륨 PR** | Yes | Yes (세트/세션) | Yes | - | - |
| **실시간 감지** | - | **Live PR Banner** | - | - | Partial |
| **타임라인 차트** | 1RM+Volume 라인그래프 | 3M/1Y/All 기간선택 | 7개 메트릭 차트 | Year-over-year | - |
| **축하 UX** | 최소 | 배너+공유카드 | 워크아웃 리포트 | 메달/크라운/트로피 | 뱃지+하이파이브 |
| **공유 카드** | - | **비주얼 PR 카드** | Yes | Kudos | - |

### 핵심 인사이트

1. **Hevy의 Set Records 테이블**: 렙수별(1렙, 2렙, 3렙...) 최고 중량을 표로 표시 → **채택: 운동별 렙수-중량 매트릭스**
2. **Strong의 Predicted RM**: 현재 1RM에서 2RM, 3RM, 5RM 예측값 표시 → **참고만** (Epley 역산으로 가능)
3. **Hevy의 기간 선택 차트**: 3개월/1년/전체 세그먼트 → **채택: 기존 TimePeriod 패턴과 통일**
4. **Fitbod의 Muscle Strength Score**: 근육 그룹별 집계 강도 → **Future** (현재 MuscleMap과 연계 가능)
5. **Strava의 Best Efforts**: 활동 내 어디서든 최고 구간 자동 감지 → **카디오에 적용 가능 (Future)**
6. **축하 UX는 moderate가 최적**: Hevy 스타일 배너 (과하지 않고 동기 부여)

### UI/UX 설계 방향 (Activity 탭 통합)

**기존 차트 패턴과 일관성 유지**:
- `PersonalRecordsDetailView` → `MetricDetailView`와 동일한 패턴 적용
- Period picker (week/month/3month/6month/year/all)
- Scrollable DotLineChart (1RM, 볼륨 등 메트릭별)
- Summary stats + highlights
- Activity 탭 → PersonalRecordsSection → PersonalRecordsDetailView (기존 네비게이션 유지)

**세션 종료 축하 화면**:
- 기존 `WorkoutCompletionSheet` 내 PR 달성 섹션 추가
- Hevy 스타일: PR 종류 + 이전 기록 대비 delta + 아이콘

## Open Questions (Resolved)

1. ~~ExerciseRecord 삭제 시 PR도 롤백?~~ → **한번 달성한 PR은 유지** (Hevy/Strong 동일 정책)
2. ~~카디오 PR도 SwiftData?~~ → **이번 MVP에서는 기존 UserDefaults 유지, strength PR 타입 확장에 집중** (SwiftData 마이그레이션은 별도 Phase)
3. ~~PR 타임라인 기간 범위?~~ → **기존 TimePeriod 패턴과 동일** (week/month/3month/6month/year)
4. ~~대시보드 PR 위젯 위치?~~ → **Activity 탭 PersonalRecordsSection 강화** (대시보드 위젯은 Future)

## Next Steps

- [ ] `/plan personal-record-overhaul` 으로 구현 계획 생성
