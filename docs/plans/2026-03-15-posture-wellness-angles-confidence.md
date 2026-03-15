---
tags: [posture, wellness-score, angles, confidence, integration]
date: 2026-03-15
category: plan
status: draft
---

# Posture: Wellness Score 통합 + 상세 각도 표시 + 신뢰 구간 표시

## Problem Statement

Posture 시스템이 독립적으로 동작하고 있어 Wellness Score에 반영되지 않음.
또한 측정 결과에서 상세 각도 수치와 측정 신뢰도가 표시되지 않아
PT/트레이너 활용도가 제한적.

## Scope

3개 TODO 번들:
- **#118 (P2)**: WellnessScore에 Posture Score 통합
- **#130 (P3)**: 상세 각도 수치 표시 (PT/트레이너용)
- **#134 (P3)**: 측정 신뢰 구간 표시

## Affected Files

| 파일 | 변경 유형 | 설명 |
|------|----------|------|
| `Domain/Models/WellnessScore.swift` | 수정 | `postureScore` 필드 추가 |
| `Domain/Models/PostureMetric.swift` | 수정 | `PostureMetricResult`에 `confidence` 필드 추가 |
| `Domain/UseCases/CalculateWellnessScoreUseCase.swift` | 수정 | postureScore를 가중치 계산에 포함 |
| `Data/Persistence/Models/PostureAssessmentRecord.swift` | - | JSON 기반이라 모델 변경 불필요 (confidence는 PostureMetricResult에 Codable로 추가) |
| `Domain/Services/PostureAnalysisService.swift` | 수정 | confidence 값 생성 로직 |
| `Presentation/Wellness/WellnessViewModel.swift` | 수정 | postureScore를 WellnessScore 계산에 전달 |
| `Presentation/Wellness/WellnessScoreDetailView.swift` | 수정 | Posture 컴포넌트 표시 |
| `Presentation/Posture/PostureDetailView.swift` | 수정 | 상세 각도 + 신뢰도 표시 |
| `Presentation/Posture/PostureResultView.swift` | 수정 | 상세 각도 + 신뢰도 표시 |
| `Presentation/Shared/Extensions/PostureMetric+View.swift` | 수정 | confidence 표시 헬퍼 |
| `Presentation/Shared/DesignSystem.swift` | 수정 | DS.Color.posture 토큰 추가 |
| `Shared/Resources/Colors.xcassets` | 수정 | MetricPosture 색상 에셋 추가 |
| `Shared/Resources/Localizable.xcstrings` | 수정 | 새 문자열 번역 추가 |
| `DUNETests/` | 신규 | 테스트 파일 추가 |

## Implementation Steps

### Step 1: PostureMetricResult에 confidence 필드 추가

- `PostureMetricResult`에 `confidence: Double` 필드 추가 (0.0-1.0, default 1.0)
- Codable 호환 (JSON 기반 저장이므로 기존 데이터는 default로 디코딩)
- `CodingKeys`와 커스텀 `init(from:)` 구현으로 backward-compatible decoding

**Verification**: 기존 JSON이 confidence 없이도 디코딩 가능한지 테스트

### Step 2: PostureAnalysisService에서 confidence 생성

- 각 metric 측정 시 관절 존재 여부 + 관절 간 거리 합리성으로 confidence 산출
- 관절 누락: 0.0 (unmeasurable), 일부 의존 관절 불확실: 0.5-0.8, 정상: 0.85-1.0
- 기존 `unmeasurable` 상태는 confidence = 0.0과 동치

**Verification**: 모든 metric에 confidence가 할당되는지 확인

### Step 3: WellnessScore에 postureScore 통합

- `WellnessScore`에 `postureScore: Int?` 추가
- 가중치 재배분: Sleep 35%, Condition 30%, Body 20%, Posture 15%
- `CalculateWellnessScoreUseCase.Input`에 `postureScore: Int?` 추가
- 기존 re-normalization 로직이 postureScore nil일 때도 정상 동작
- `narrativeMessage`에 posture 포함

**Verification**: postureScore nil/non-nil 모두 정상 점수 계산

### Step 4: WellnessViewModel에서 posture score 전달

- 최신 PostureAssessmentRecord를 @Query 또는 fetch로 가져와 overallScore 사용
- WellnessScoreUseCase에 postureScore 전달

**Verification**: Wellness 탭에서 posture score가 반영된 종합 점수 확인

### Step 5: WellnessScoreDetailView에 Posture 컴포넌트 추가

- ScoreCompositionCard에 Posture 행 추가 (15%, DS.Color.posture)
- DetailScoreHero subScores에 Posture 추가
- Labels.calculationBullets 업데이트
- DS.Color.posture 토큰 + MetricPosture 색상 에셋 추가

**Verification**: Wellness Score Detail에서 Posture 컴포넌트 표시

### Step 6: PostureDetailView에 상세 각도 + 신뢰도 표시

- metricRow에 각도 수치를 더 눈에 띄게 표시 (기존에도 value 있음)
- 각 metric 행에 confidence badge 추가 (opacity circle + percentage)
- confidence < 0.7 시 "재촬영 권장" 라벨 표시
- PostureResultView에도 동일 적용

**Verification**: 각 metric에 각도값과 confidence가 함께 표시

### Step 7: Localization + 테스트

- 새 문자열 xcstrings 등록 (en/ko/ja)
- CalculateWellnessScoreUseCase 테스트 업데이트
- PostureMetricResult confidence 디코딩 테스트
- Confidence 표시 로직 테스트

## Test Strategy

- `CalculateWellnessScoreUseCaseTests`: postureScore 포함/미포함 시 점수 계산
- `PostureMetricResultTests`: confidence backward-compatible decoding
- `PostureAnalysisServiceTests`: confidence 생성 로직

## Risks & Edge Cases

| Risk | Mitigation |
|------|-----------|
| 기존 JSON에 confidence 없음 | Codable default decoding (1.0) |
| 가중치 변경으로 기존 점수 변동 | postureScore nil이면 기존 3항목으로 re-normalize |
| PostureAssessmentRecord 없는 사용자 | postureScore = nil → 기존과 동일 |
| SwiftData schema 변경 불필요 | JSON 문자열 기반이라 스키마 영향 없음 |
