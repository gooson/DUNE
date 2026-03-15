---
topic: posture-features-bundle
date: 2026-03-16
status: draft
confidence: high
related_solutions:
  - general/2026-03-15-posture-history-views.md
  - general/2026-03-15-posture-visualization-enhancement.md
  - architecture/2026-03-15-posture-wellness-integration.md
related_brainstorms:
  - 2026-03-15-posture-assessment-system.md
---

# Implementation Plan: Posture Features Bundle (#128, #129, #131, #132)

## Context

4개 posture 관련 TODO를 통합 구현:
- **#128 (P2)**: Injury system integration — 자세 문제 부위를 Injury 시스템과 연동
- **#129 (P3)**: Measurement reminder — 주 1회 측정 리마인더
- **#131 (P3)**: Left-right comparison — 좌우 비대칭 상세 분석 뷰
- **#132 (P3)**: PDF report export — 전문 PDF 보고서 내보내기

## Requirements

### Functional

**#128 Injury Integration**
- PostureMetricType → BodyPart 매핑 (shoulderAsymmetry → shoulder, hipAsymmetry → hip 등)
- InjuryRiskAssessment에 postureRisk 팩터 추가 (자세 문제 → 부상 위험 기여)
- InjuryBodyMapView에 자세 위험 부위 표시 (자세 마커 오버레이)
- PostureDetailView에서 관련 부상 기록 표시

**#129 Measurement Reminder**
- 마지막 측정 이후 경과 일수 표시 (PostureHistoryView 상단)
- 로컬 알림으로 주 1회 측정 유도 (HealthInsight.postureReminder)
- 설정에서 리마인더 on/off + 요일 선택
- PostureReminderScheduler (BedtimeReminderScheduler 패턴 참조)

**#131 Left-Right Comparison**
- 좌우 비대칭 전용 상세 뷰 (PostureSymmetryView)
- 어깨/골반/무릎 좌우 차이를 mm 단위로 표시
- 비대칭 정도를 시각적 바 차트로 표현
- 3D 관절 좌표에서 좌우 각 joint의 실제 좌표값 추출

**#132 PDF Report Export**
- PDFKit 기반 보고서 생성
- 촬영 사진 (관절 오버레이 포함)
- 종합 점수 + 개별 지표 + 정상 범위 대비
- 이전 측정 대비 변화 (있을 경우)
- ShareLink로 내보내기

### Non-functional

- 기존 Layer boundary 준수 (Domain에 SwiftUI/SwiftData 금지)
- String(localized:) 패턴으로 3개 언어 지원
- 테스트: 새 UseCase/ViewModel에 대한 유닛 테스트

## Approach

4개 기능을 의존 순서대로 구현:
1. **Domain 확장** (매핑, UseCase) → Step 1-3
2. **UI 뷰** (SymmetryView, 리마인더 표시, PDF) → Step 4-7
3. **통합 연결** (Navigation, Wiring) → Step 8

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| PDF: UIGraphicsPDFRenderer | 직접 드로잉 제어 | 복잡한 레이아웃 코드 | **선택** — 자유로운 레이아웃 |
| PDF: SwiftUI → ImageRenderer → PDF | 간결한 코드 | iOS 16+ 제한, 페이지 분할 어려움 | 기각 |
| Reminder: 기존 NotificationService 확장 | 코드 재사용 | NotificationService는 즉시 전송 전용 | 기각 |
| Reminder: 별도 Scheduler | BedtimeReminderScheduler 패턴 재활용 | 새 파일 필요 | **선택** |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `Domain/Models/PostureMetric.swift` | Modify | PostureMetricType → BodyPart 매핑 추가 |
| `Domain/Models/HealthInsight.swift` | Modify | postureReminder InsightType 추가 |
| `Domain/Models/InjuryRiskAssessment.swift` | Modify | postureRisk FactorType 추가 |
| `Domain/UseCases/CalculateInjuryRiskUseCase.swift` | Modify | 자세 점수 기반 리스크 기여분 추가 |
| `Domain/Services/PostureAnalysisService.swift` | Modify | 좌우 개별 측정 API 추가 |
| `Data/Services/PostureReminderScheduler.swift` | **New** | 주 1회 로컬 알림 스케줄러 |
| `Data/Services/PostureReportGenerator.swift` | **New** | PDF 보고서 생성기 |
| `Presentation/Posture/PostureSymmetryView.swift` | **New** | 좌우 비대칭 상세 뷰 |
| `Presentation/Posture/PostureSymmetryViewModel.swift` | **New** | 좌우 분석 ViewModel |
| `Presentation/Posture/PostureHistoryView.swift` | Modify | 리마인더 배너, 좌우비교/PDF 버튼 추가 |
| `Presentation/Posture/PostureDetailView.swift` | Modify | 관련 부상 표시, PDF 공유 버튼, 좌우 비교 링크 |
| `Presentation/Injury/InjuryBodyMapView.swift` | Modify | 자세 위험 마커 오버레이 |
| `Presentation/Shared/Extensions/PostureMetric+View.swift` | Modify | 좌우 비교 관련 뷰 헬퍼 |
| `Shared/Resources/Localizable.xcstrings` | Modify | en/ko/ja 번역 추가 |

## Implementation Steps

### Step 1: PostureMetricType → BodyPart 매핑

- **Files**: `Domain/Models/PostureMetric.swift`
- **Changes**: PostureMetricType extension에 `var affectedBodyParts: [BodyPart]` computed property 추가
  - shoulderAsymmetry → [.shoulder]
  - hipAsymmetry → [.hip]
  - kneeAlignment → [.knee]
  - forwardHead → [.neck]
  - roundedShoulders → [.shoulder]
  - thoracicKyphosis → [.lowerBack]
  - kneeHyperextension → [.knee]
  - lateralShift → [.hip]
- **Verification**: 컴파일 확인, 모든 case 커버

### Step 2: InjuryRisk에 postureRisk 팩터 추가

- **Files**: `Domain/Models/InjuryRiskAssessment.swift`, `Domain/UseCases/CalculateInjuryRiskUseCase.swift`
- **Changes**:
  - FactorType에 `.postureIssue` case 추가
  - Input에 `postureWarningCount: Int` (warning 상태 메트릭 수), `postureScore: Int?` 추가
  - 가중치 재분배: postureIssue 5% 추가, 기존 비율 소폭 조정 (lowRecovery 10%→7.5%, muscleFatigue 25%→22.5%)
  - warning 2개 이상이면 기여도 증가
- **Verification**: 기존 CalculateInjuryRiskUseCaseTests 통과 + 새 posture 케이스 테스트

### Step 3: 좌우 개별 측정 API

- **Files**: `Domain/Services/PostureAnalysisService.swift`
- **Changes**:
  - `measureShoulderAsymmetryDetail()` → 좌/우 각각의 Y 좌표, 차이값, 높은 쪽/낮은 쪽 반환
  - `measureHipAsymmetryDetail()` → 동일 패턴
  - `measureKneeAlignmentPerSide()` → 좌/우 개별 Q-angle 반환 (현재는 worst만 반환)
  - 반환 타입: `SymmetryDetail` struct (leftValue, rightValue, difference, higherSide)
- **Verification**: 유닛 테스트로 좌우 값 검증

### Step 4: PostureSymmetryView + ViewModel

- **Files**: `Presentation/Posture/PostureSymmetryView.swift`, `PostureSymmetryViewModel.swift`
- **Changes**:
  - ViewModel: PostureAssessmentRecord에서 front joint positions → SymmetryDetail 계산
  - View: 어깨/골반/무릎 좌우 차이를 HStack 바 차트로 표현
  - mm 단위 차이 표시, 좌/우 어느 쪽이 높은지 화살표
  - 비대칭 severity 색상 (정상: green, 주의: yellow, 경고: red)
- **Verification**: Preview에서 시각적 확인

### Step 5: PostureReminderScheduler

- **Files**: `Data/Services/PostureReminderScheduler.swift`, `Domain/Models/HealthInsight.swift`
- **Changes**:
  - HealthInsight.InsightType에 `.postureReminder` 추가
  - PostureReminderScheduler: BedtimeReminderScheduler 패턴 참조
    - `static let settingsKey = "isPostureReminderEnabled"`
    - `static let reminderDayKey = "postureReminderDay"` (0=Sun...6=Sat, default=0)
    - `refreshSchedule()`: 마지막 측정일 기반으로 7일 이상이면 알림 예약
    - UNCalendarNotificationTrigger로 매주 특정 요일 10AM
  - PostureHistoryView 상단에 "마지막 측정: N일 전" 배너
- **Verification**: 유닛 테스트 (mock UNUserNotificationCenter)

### Step 6: PDF Report Generator

- **Files**: `Data/Services/PostureReportGenerator.swift`
- **Changes**:
  - UIGraphicsPDFRenderer 기반 PDF 생성
  - 페이지 1: 헤더(앱명, 날짜), 종합 점수 원형 차트, 전면/측면 사진
  - 페이지 2: 개별 메트릭 테이블 (지표명, 값, 상태, 점수), 정상 범위 비교
  - 선택적 페이지 3: 이전 측정 대비 변화 (MetricDelta 테이블)
  - 반환: `Data` (PDF)
- **Verification**: 생성된 PDF 파일 검증

### Step 7: UI 통합 — DetailView, HistoryView, InjuryBodyMap

- **Files**: `PostureDetailView.swift`, `PostureHistoryView.swift`, `InjuryBodyMapView.swift`
- **Changes**:
  - PostureDetailView:
    - toolbar에 ShareLink (PDF) 버튼
    - 관련 부상 기록 섹션 (자세 문제 BodyPart과 매칭되는 active injury 표시)
    - "좌우 비교" 버튼 → PostureSymmetryView push
  - PostureHistoryView:
    - 상단에 측정 리마인더 배너 (마지막 측정 N일 전, 7일 초과 시 강조)
  - InjuryBodyMapView:
    - `postureWarnings: [PostureMetricType]?` optional parameter
    - 자세 warning 부위에 별도 색상(보라) 마커 표시
- **Verification**: 빌드 성공, Preview 확인

### Step 8: Navigation + Wiring + Localization

- **Files**: `PostureHistoryView.swift`, `Localizable.xcstrings`
- **Changes**:
  - PostureSymmetryView navigation destination 등록
  - 새 문자열 en/ko/ja 번역 추가
  - 리마인더 설정 UI 연결 (기존 Settings 패턴 따름)
- **Verification**: 빌드 성공, 전체 navigation flow 확인

## Edge Cases

| Case | Handling |
|------|----------|
| Front-only 촬영 (side 없음) | 좌우 비교는 front metrics만 표시, side metrics "N/A" |
| 사진 없는 기록 (migration 데이터) | PDF에서 사진 섹션 placeholder |
| 자세 기록 0건 상태에서 리마인더 | 첫 측정 유도 메시지로 대체 |
| 관련 부상 기록 0건 | "관련 부상 기록 없음" 섹션 숨김 |
| PDF 생성 실패 | 에러 alert 표시, 빈 Data 반환 방지 |
| 알림 권한 미부여 | 리마인더 토글 시 권한 요청, 거부 시 설정 안내 |
| 좌우 joint 한쪽 unmeasurable | 측정 불가 표시, 해당 행에 "—" |

## Testing Strategy

- **Unit tests**:
  - PostureMetricType.affectedBodyParts 매핑 전수 검증
  - CalculateInjuryRiskUseCase — postureIssue 팩터 추가 후 기존 테스트 통과 + 새 케이스
  - PostureAnalysisService.SymmetryDetail — 좌우 값 계산 정확도
  - PostureSymmetryViewModel — 입력 → 출력 검증
  - PostureReminderScheduler — 스케줄 생성/취소 (mock notification center)
  - PostureReportGenerator — PDF Data 생성 (nil 아님, 크기 > 0)
- **Manual verification**:
  - PostureDetailView → 좌우 비교 navigate
  - PostureDetailView → PDF 공유 → 파일 저장 확인
  - InjuryBodyMapView에 자세 마커 표시 확인
  - 리마인더 배너 표시 + 알림 수신 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| InjuryRisk 가중치 변경으로 기존 테스트 실패 | Medium | Medium | 기존 테스트 값 조정 + 새 테스트 추가 |
| PDF 렌더링에서 사진 크기/해상도 이슈 | Low | Low | JPEG compression으로 크기 제한 |
| 알림 권한 UX 흐름 복잡 | Low | Low | BedtimeReminder 검증된 패턴 재사용 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 모든 필요 패턴이 기존 코드에 존재 (BedtimeReminderScheduler, InjuryBodyMapView, PostureAnalysisService). 새로운 API/프레임워크 도입 없음 (PDFKit은 Foundation). 변경 범위가 명확하고 기존 아키텍처 내에서 자연스러운 확장.
