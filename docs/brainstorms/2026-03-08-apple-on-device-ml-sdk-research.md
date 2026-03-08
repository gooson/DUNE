---
tags: [apple-intelligence, foundation-models, core-ml, on-device-ml, ai]
date: 2026-03-08
category: brainstorm
status: draft
---

# Brainstorm: Apple 온디바이스 ML SDK 리서치 & DUNE 적용 가능 기능

## 1. Apple ML SDK 전체 지도

Apple은 여러 레이어의 ML 프레임워크를 제공한다. 아래에서 위로 갈수록 추상화 수준이 높다.

```
┌─────────────────────────────────────────────┐
│        Foundation Models (iOS 26+)          │  ← 온디바이스 LLM (3B 파라미터)
│   텍스트 생성/분류/추출/요약, Tool Calling    │
├─────────────────────────────────────────────┤
│     High-Level Frameworks                    │
│  Vision │ NaturalLanguage │ SoundAnalysis    │  ← 특화 도메인 ML
│  Speech │ Translation                        │
├─────────────────────────────────────────────┤
│           Core ML (iOS 11+)                  │  ← 범용 ML 추론 엔진
│      .mlmodel / .mlpackage 포맷              │
├─────────────────────────────────────────────┤
│      Create ML (macOS/iPadOS)                │  ← 모델 학습 도구
│   tabular, image, text, sound 등             │
├─────────────────────────────────────────────┤
│    Metal Performance Shaders / Accelerate    │  ← 하드웨어 가속 (Neural Engine, GPU)
└─────────────────────────────────────────────┘
```

---

## 2. 각 프레임워크 상세

### 2.1 Foundation Models Framework (★ 신규, iOS 26+)

**정체**: Apple Intelligence를 구동하는 ~3B 파라미터 온디바이스 LLM에 직접 접근하는 Swift API.

**핵심 기능**:
- **텍스트 생성**: 요약, 분류, 추출, 자연어 응답
- **Guided Generation** (`@Generable`): Swift struct/enum에 매크로를 붙이면 LLM이 해당 구조체 형태로 출력을 강제 (constrained decoding). 구조화된 데이터 추출에 핵심
- **Tool Calling**: LLM이 앱 내 함수를 호출할 수 있음 (Tool 프로토콜 구현)
- **Streaming**: 실시간 토큰 스트리밍
- **Multi-turn Session**: `LanguageModelSession`으로 대화 컨텍스트 유지

**코드 예시**:
```swift
import FoundationModels

@Generable
struct WorkoutAnalysis {
    @Guide(description: "오늘의 운동 요약 (1-2문장)")
    let summary: String
    @Guide(description: "개선 포인트")
    let improvements: [String]
    @Guide(.anyOf(["excellent", "good", "moderate", "poor"]))
    let overallRating: String
}

let session = LanguageModelSession()
let analysis: WorkoutAnalysis = try await session.respond(
    to: "사용자가 오늘 벤치프레스 4세트(80kg), 스쿼트 3세트(100kg)를 수행함. 전날 수면 6시간, HRV 45ms",
    generating: WorkoutAnalysis.self
).content
```

**성능 수치** (iPhone 15 Pro 기준):
- ~0.6ms per prompt token (time-to-first-token)
- ~30 tokens/second 생성 속도
- ~3B 파라미터, 혼합 2-bit/4-bit 양자화 (평균 3.7 bits-per-weight)

**주요 API**:
- `SystemLanguageModel` — 모델 접근점, `.availability`로 사용 가능 여부 확인
- `LanguageModelSession` — 상태 유지 대화 세션
- `.respond(to:generating:)` — 구조화 출력 생성
- `.streamResponse(to:)` — 스트리밍 응답
- `.prewarm(promptPrefix:)` — 모델 사전 로드 (첫 응답 속도 개선)
- `GenerationOptions` — temperature (0.0-2.0), sampling (greedy/top-k/top-p)

**제약사항**:
- **디바이스**: iPhone 15 Pro+ (A17 Pro), M1+ iPad/Mac만 지원
- **저장 공간**: ~7GB 필요 (Apple Intelligence 활성화)
- **컨텍스트 윈도우**: 4,096 토큰 (입출력 합산, 유동 분할)
- **한계**: 세계 지식이나 고급 추론에는 약함 — 분류/추출/요약에 최적화
- **사용자 설정**: Apple Intelligence가 Settings에서 활성화되어야 함
- **지역**: Apple Intelligence 미지원 지역에서는 사용 불가
- **watchOS 미지원**: iOS/iPadOS/macOS/visionOS만 지원 (watchOS 언급 없음)
- **`@Generable` 제약**: 프로퍼티 순서가 중요 (의존성 있는 프로퍼티는 뒤에 배치), 모든 프로퍼티가 항상 생성됨

### 2.2 Core ML (iOS 11+)

**정체**: 학습된 ML 모델을 앱에 내장하여 온디바이스 추론하는 범용 엔진.

**핵심 기능**:
- `.mlmodel` / `.mlpackage` 포맷 지원
- PyTorch, TensorFlow, scikit-learn 모델을 `coremltools`로 변환
- Neural Engine / GPU / CPU 자동 스케줄링
- 모델 컴파일은 빌드 타임에 수행 (런타임 오버헤드 최소)

**활용 예시**: 커스텀 예측 모델 (수면 패턴 예측, 부상 위험도 예측 등)

### 2.3 Create ML (macOS/iPadOS)

**정체**: 코드 없이 또는 Swift로 ML 모델을 학습하는 도구.

**지원 모델 타입**:
| 타입 | 용도 |
|------|------|
| Tabular Classification/Regression | 구조화 데이터 예측 |
| Image Classification | 이미지 분류 |
| Object Detection | 이미지 내 객체 탐지 |
| Sound Classification | 오디오 분류 |
| Text Classification | 텍스트 분류 |
| Word Tagging | 개체명 인식 |
| Activity Classification | 센서 데이터 기반 활동 분류 |
| Hand Pose Classification | 손 제스처 인식 |
| Body Pose Classification | 자세 분류 |

**핵심**: `Activity Classification`이 건강 앱에 특히 관련 — CoreMotion 센서 데이터로 운동 종류 자동 인식 가능.

### 2.4 Vision Framework (iOS 11+)

- 얼굴/신체/손 포즈 감지
- 이미지 분류, 객체 탐지
- 텍스트 인식 (OCR)
- **Body Pose Estimation**: 운동 자세 분석에 활용 가능

### 2.5 Natural Language Framework (iOS 12+)

- 감정 분석 (sentiment)
- 언어 감지
- 토큰화, 품사 태깅
- 텍스트 임베딩

### 2.6 SensorKit (iOS 14+)

- 가속도계, 자이로스코프 데이터 수집
- 주변 조도, 키보드 사용 패턴 등
- **주의**: 사용자 동의 + Apple 승인 필요 (연구용)

---

## 3. DUNE 앱 적용 가능 기능 아이디어

### Tier 1: Foundation Models 활용 (높은 임팩트, 구현 용이)

#### 3.1 AI 코칭 메시지 자연어 생성
- **현재**: `CoachingEngine`이 템플릿 기반으로 인사이트 생성 (rule-based)
- **개선**: Foundation Models로 같은 데이터를 자연스러운 코칭 메시지로 변환
- **장점**: 매번 다른 표현, 개인화된 톤, 맥락 인식 메시지
- **구현**: `CoachingInput` → LLM 프롬프트 → `@Generable CoachingMessage`

```swift
@Generable
struct AICoachingMessage {
    @Guide(description: "짧고 격려하는 제목 (10자 이내)")
    let title: String
    @Guide(description: "개인화된 코칭 메시지 (2-3문장)")
    let message: String
    @Guide(.anyOf(["recovery", "training", "sleep", "motivation"]))
    let category: String
}
```

#### 3.2 운동 요약 리포트 생성
- 주간/월간 운동 데이터를 자연어 요약으로 변환
- "이번 주 하체 볼륨이 20% 증가했어요. 스쿼트 PR을 경신한 것이 주요 원인입니다."

#### 3.3 자연어 운동 검색/입력
- "어깨 운동 추천해줘" → Foundation Models가 의도 파싱 → 운동 라이브러리 검색
- Tool Calling으로 `ExerciseLibrary` 쿼리 연결
- **SmartGym 사례 참고**: 자연어로 워크아웃 루틴 생성

#### 3.4 건강 데이터 질의응답
- "내 수면 패턴 어때?" → 최근 7일 수면 데이터 요약
- "컨디션 점수가 왜 낮아?" → ConditionScore 구성 요소 분석 후 자연어 설명
- Tool Calling으로 HealthKit 쿼리 함수와 연결

#### 3.5 Workout Template 자연어 생성
- "상체 위주로 30분짜리 운동 만들어줘" → Guided Generation으로 구조화된 템플릿 출력
- 현재 `WorkoutRecommendationService`의 rule-based 추천을 자연어 인터페이스로 보완

### Tier 2: Core ML / Create ML 활용 (중간 임팩트, 커스텀 모델 필요)

#### 3.6 수면 품질 예측 모델
- Create ML Tabular Regression으로 학습
- 입력: HRV, RHR, 취침 시간, 운동 강도, 카페인 섭취 등
- 출력: 예상 수면 점수
- "오늘 이 상태로 자면 수면 점수 약 72점 예상"

#### 3.7 부상 위험도 예측
- 입력: 근육별 피로도, 연속 운동일, 볼륨 증가율, 수면 부족
- 출력: 부상 위험 확률 (0-100)
- Create ML Tabular Classification으로 학습 가능

#### 3.8 운동 자동 분류 (Activity Classification)
- Create ML Activity Classification 활용
- CoreMotion 가속도 데이터로 운동 종류 자동 감지
- Watch에서 "운동 시작" 버튼 없이 자동 감지 → 확인만 요청

### Tier 3: Vision / Advanced (낮은 우선순위, 높은 기술 난이도)

#### 3.9 운동 자세 분석 (Vision Body Pose)
- 카메라로 운동 자세 촬영 → Body Pose Estimation
- 스쿼트 깊이, 데드리프트 척추 정렬 등 피드백
- **SwingVision 사례 참고**: Core ML + Foundation Models 결합

#### 3.10 식단 사진 분석
- Vision 이미지 분류 + Foundation Models 텍스트 생성
- 음식 사진 → 칼로리/영양소 추정 + 자연어 설명

---

## 4. 우선순위 평가 매트릭스

| 기능 | 임팩트 | 구현 난이도 | 디바이스 제약 | 추천 |
|------|--------|------------|-------------|------|
| AI 코칭 메시지 | ★★★★★ | 낮음 | A17+ only | **MVP 1순위** |
| 운동 요약 리포트 | ★★★★☆ | 낮음 | A17+ only | **MVP 2순위** |
| 건강 데이터 Q&A | ★★★★☆ | 중간 | A17+ only | MVP 3순위 |
| 자연어 운동 검색 | ★★★☆☆ | 중간 | A17+ only | Future |
| Template 자연어 생성 | ★★★☆☆ | 중간 | A17+ only | Future |
| 수면 품질 예측 | ★★★★☆ | 높음 | 제약 없음 | Future (데이터 축적 필요) |
| 부상 위험도 예측 | ★★★★☆ | 높음 | 제약 없음 | Future (데이터 축적 필요) |
| 운동 자동 분류 | ★★★☆☆ | 높음 | Watch 필요 | Future |
| 운동 자세 분석 | ★★★★★ | 매우 높음 | 카메라 필요 | Future (v2+) |
| 식단 사진 분석 | ★★☆☆☆ | 높음 | 카메라 필요 | 보류 (앱 범위 밖) |

---

## 5. 아키텍처 고려사항

### Foundation Models 미지원 디바이스 대응
```
if LanguageModelSession.isAvailable {
    → Foundation Models 기반 AI 코칭
} else {
    → 기존 CoachingEngine (rule-based) fallback
}
```

**핵심 원칙**: Foundation Models는 기존 기능의 "향상(enhancement)"이지 "대체(replacement)"가 아님. 미지원 디바이스에서도 동일한 핵심 기능이 동작해야 함.

### Layer Boundary
- `FoundationModels` import는 **Presentation 또는 새로운 AI Service 레이어**에 한정
- Domain은 `FoundationModels`를 import하지 않음
- AI 생성 결과도 Domain 모델(`CoachingInsight` 등)로 변환하여 전달

### 프라이버시
- 모든 추론이 온디바이스 → 서버 전송 없음
- HealthKit 데이터가 LLM 프롬프트에 포함되지만, 온디바이스이므로 프라이버시 안전
- Apple의 Acceptable Use Requirements 준수 필요

---

## 6. 경쟁 앱 레퍼런스

| 앱 | Foundation Models 활용 | 특징 |
|----|----------------------|------|
| **SmartGym** | 자연어→구조화 루틴, Smart Trainer 추천 | 운동 추천+조정 |
| **SwingVision** | Core ML 영상 분석 + FM 피드백 생성 | 비디오 분석 + 자연어 |
| **7 Minute Workout** | 자연어 운동 생성, 동기부여 피드백 | 부상 회피 조건 파싱 |

---

## Open Questions

1. Foundation Models가 한국어/일본어 프롬프트를 얼마나 잘 처리하는가? (다국어 지원 범위)
2. `LanguageModelSession`의 추론 시간은 얼마인가? (UI 반응성 영향)
3. 4,096 토큰 제한에서 7일치 운동 기록 + 건강 데이터를 모두 담을 수 있는가?
4. watchOS에서 Foundation Models를 사용할 수 있는가? (WWDC 문서에 watchOS 언급 없음)
5. Apple의 Acceptable Use Requirements에서 건강 데이터 기반 조언이 허용되는가?

---

## 7. 관심 기능 심화 분석

사용자 선택: AI 코칭 메시지, 건강 데이터 Q&A, 자연어 운동 생성, 수면/부상 예측 모델

### 7.1 AI 코칭 메시지 (Foundation Models) — 구현 상세

**현재 시스템**: `CoachingEngine` → 트리거 평가 → 우선순위 정렬 → 템플릿 메시지
**개선 방향**: 동일한 `CoachingInput` 데이터를 LLM에게 전달하여 자연어 메시지 생성

**구현 전략**:
```
CoachingInput → (1) 기존 CoachingEngine → priority/category 결정
             → (2) Foundation Models → 자연어 message 생성
             → CoachingInsight (기존 모델 유지, message만 AI 생성)
```

**핵심 이점**:
- 매일 다른 표현으로 신선한 코칭 경험
- 데이터 맥락을 종합한 자연스러운 연결 ("어제 수면이 짧았지만 HRV가 회복됐네요")
- 기존 CoachingEngine의 priority 로직은 그대로 유지 (안정성 보장)

**Fallback**: `SystemLanguageModel` 미지원 시 기존 템플릿 메시지 사용

**추정 작업량**: 2-3일 (Service 레이어 추가 + View 연결 + fallback)

### 7.2 건강 데이터 Q&A (Foundation Models + Tool Calling) — 구현 상세

**컨셉**: 대시보드에 채팅 인터페이스 추가. 사용자가 자연어로 질문하면 Tool Calling으로 데이터 조회 후 답변.

**Tool 설계**:
```swift
struct FetchConditionScoreTool: Tool {
    let name = "getConditionScore"
    let description = "오늘의 컨디션 점수와 구성 요소를 조회"
    @Generable struct Arguments { let date: String }
    func call(arguments: Arguments) async throws -> ToolOutput { ... }
}

struct FetchSleepDataTool: Tool {
    let name = "getSleepData"
    let description = "특정 기간의 수면 데이터를 조회"
    @Generable struct Arguments { let days: Int }
    func call(arguments: Arguments) async throws -> ToolOutput { ... }
}

struct FetchWorkoutHistoryTool: Tool {
    let name = "getWorkoutHistory"
    let description = "최근 운동 기록을 조회"
    @Generable struct Arguments { let days: Int; let muscleGroup: String? }
    func call(arguments: Arguments) async throws -> ToolOutput { ... }
}
```

**4096 토큰 제한 대응**:
- Tool이 반환하는 데이터를 요약 형태로 압축 (raw JSON 대신 pre-aggregated summary)
- 예: 7일 수면 데이터 → "avg 7.2h, min 5.5h, max 8.1h, trend: improving"

**UI**: 기존 대시보드 하단에 FloatingButton → Sheet로 채팅 UI

**추정 작업량**: 5-7일 (Tool 구현 + 채팅 UI + 세션 관리)

### 7.3 자연어 운동 생성 (Foundation Models + Guided Generation) — 구현 상세

**컨셉**: "어깨 30분" → `@Generable WorkoutTemplate` 구조체로 출력

```swift
@Generable
struct AIWorkoutTemplate {
    @Guide(description: "운동 이름")
    let name: String
    @Guide(description: "운동 목록")
    let exercises: [AIExerciseSlot]
    @Guide(description: "예상 소요 시간 (분)")
    @Guide(.range(10...120))
    let estimatedMinutes: Int
}

@Generable
struct AIExerciseSlot {
    @Guide(description: "운동 이름 (영어, exercises.json 기준)")
    let exerciseName: String
    @Guide(.range(1...10))
    let sets: Int
    @Guide(.range(1...30))
    let reps: Int
}
```

**과제**: LLM이 exercises.json의 운동 이름을 정확히 매칭해야 함
- **해결**: Tool Calling으로 `searchExercise(query:)` 도구 제공하여 라이브러리 검색 후 정확한 이름 사용
- 또는 `@Guide(.anyOf([...]))` 로 운동 이름 목록을 제한 (토큰 소비 주의)

**추정 작업량**: 4-5일 (Generable 모델 + Tool + 기존 Template 시스템 연결)

### 7.4 수면/부상 예측 모델 (Core ML + Create ML) — 구현 상세

**수면 품질 예측**:
- **학습 데이터**: 사용자의 과거 데이터 (HRV, RHR, 운동 강도, 취침 시간 → 수면 점수)
- **모델**: Create ML `MLRegressor` (Tabular Regression)
- **On-device personalization**: `MLUpdateTask`로 사용자 개인 데이터에 맞춤 fine-tuning
- **최소 데이터**: 30일 이상 축적 후 활성화 권장

**부상 위험도 예측**:
- **학습 데이터**: 피로도 패턴, 볼륨 증가율, 수면 부족, 과거 부상 이력
- **모델**: Create ML `MLClassifier` (위험/주의/안전 3단계)
- **과제**: 부상 레이블이 있는 학습 데이터 수집이 어려움
- **대안**: rule-based 위험도 산출 후 Foundation Models로 자연어 경고 메시지 생성

**추정 작업량**:
- 수면 예측: 2-3주 (데이터 파이프라인 + 모델 학습 + 통합)
- 부상 예측: 3-4주 (데이터 레이블링 문제로 더 오래 걸림)

---

## Scope 정의

### MVP (Foundation Models 기반, 빠른 구현)
1. AI 코칭 메시지 자연어 생성 (기존 CoachingEngine 향상)
2. 운동 요약 리포트 (주간/월간)

### Phase 2 (Tool Calling 활용)
3. 건강 데이터 Q&A 채팅 인터페이스
4. 자연어 운동 생성

### Phase 3 (Core ML / Create ML, 데이터 축적 후)
5. 수면 품질 예측 모델
6. 부상 위험도 예측 (rule-based → ML 전환)

---

## Next Steps

- [ ] Foundation Models 다국어 성능 테스트 (한/영/일) — 프로토타입 필요
- [ ] Phase 1 구현: `/plan ai-coaching-enhancement`
- [ ] Apple Acceptable Use Requirements 확인 (건강 데이터 조언 허용 범위)
- [ ] 데이터 축적 파이프라인 설계 (Phase 3 준비)
