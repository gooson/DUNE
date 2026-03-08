---
tags: [foundation-models, coaching, on-device-ai, generable]
date: 2026-03-09
category: plan
status: draft
---

# AI 코칭 메시지 (Foundation Models)

## 요약

기존 규칙 기반 `CoachingEngine`의 템플릿 메시지를 Apple Foundation Models로 자연어 개인화 메시지로 향상시킵니다.
A17 Pro+ 디바이스에서만 동작하며, 미지원 기기는 기존 템플릿 메시지를 유지합니다.

## 참조

- **TODO**: `todos/096-ready-p2-ai-coaching-messages.md`
- **Brainstorm**: `docs/brainstorms/2026-03-08-apple-on-device-ml-sdk-research.md` Section 7.1
- **기존 패턴**: `DUNE/Data/Services/FoundationModelReportFormatter.swift`
- **Solution**: `docs/solutions/architecture/2026-03-08-on-device-prediction-features.md`

## 설계 결정

### 핵심 전략

`CoachingEngine`은 변경하지 않습니다. 우선순위(P1~P9), 카테고리, 아이콘 선정 등 규칙 기반 로직은 그대로 유지하고,
생성된 `CoachingInsight`의 **메시지 텍스트만** Foundation Models로 개선합니다.

### 레이어 경계

```
Domain (CoachingMessageEnhancing protocol)
   ↑
Data/Services (AICoachingMessageService — import FoundationModels)
   ↑
Presentation (DashboardViewModel — inject & call)
```

- Domain: `FoundationModels` import 금지 → 프로토콜만 정의
- Data: Foundation Models 구현 + 템플릿 fallback
- Presentation: 프로토콜을 통해 호출

### @Generable 구조체

```swift
@Generable(description: "A personalized coaching message for a health & fitness app user")
struct AICoachingMessage {
    @Guide(description: "A warm, encouraging title in 3-6 words")
    var title: String

    @Guide(description: "A personalized coaching message in 1-2 sentences, empathetic and actionable")
    var message: String
}
```

### Fallback 전략

1. `SystemLanguageModel.default.isAvailable == false` → 기존 템플릿 반환
2. Foundation Models 호출 실패 → 기존 템플릿 반환
3. 빈 결과 → 기존 템플릿 반환

## 영향받는 파일

| 파일 | 변경 유형 | 설명 |
|------|----------|------|
| `DUNE/Domain/Protocols/CoachingMessageEnhancing.swift` | **신규** | 프로토콜 정의 |
| `DUNE/Data/Services/AICoachingMessageService.swift` | **신규** | Foundation Models 구현 |
| `DUNE/Presentation/Dashboard/DashboardViewModel.swift` | **수정** | AI 메시지 서비스 통합 |
| `Shared/Resources/Localizable.xcstrings` | **수정** | 새 UI 문자열 번역 (있을 경우) |
| `DUNE/DUNETests/AICoachingMessageServiceTests.swift` | **신규** | 유닛 테스트 |
| `DUNE/project.yml` | **수정 불필요** | xcodegen 자동 포함 (같은 폴더 구조) |

## 구현 Steps

### Step 1: Domain 프로토콜 정의

**파일**: `DUNE/Domain/Protocols/CoachingMessageEnhancing.swift`

```swift
protocol CoachingMessageEnhancing: Sendable {
    func enhance(insight: CoachingInsight, context: CoachingInput) async -> CoachingInsight
}
```

- `CoachingInsight`를 받아 메시지가 향상된 `CoachingInsight`를 반환
- `async`만 (throwing 아님 — 실패 시 원본 반환)
- 반환 타입이 non-optional (실패 시 원본 그대로)

**Verification**: 빌드 통과 + 프로토콜이 `Foundation`만 import

### Step 2: Foundation Models 서비스 구현

**파일**: `DUNE/Data/Services/AICoachingMessageService.swift`

1. `@Generable` 구조체 `AICoachingMessage` 정의
2. `AICoachingMessageService: CoachingMessageEnhancing` 구현
3. `SystemLanguageModel.default.isAvailable` 체크
4. `LanguageModelSession().respond(to:generating:)` 호출
5. 결과로 insight의 title/message 대체
6. 실패/미지원 시 원본 insight 반환
7. Locale 기반 프롬프트 언어 (ko/ja/en — `FoundationModelReportFormatter` 패턴)

**프롬프트 구성**:
- CoachingInput의 핵심 컨텍스트 (conditionScore, sleepMinutes, workoutStreak 등)
- InsightCategory, InsightPriority 정보
- 기존 템플릿 메시지 (참고용)
- 톤 지시: warm, empathetic, actionable, 1-2 sentences

**Verification**: 빌드 통과 + isAvailable false 시 원본 반환 테스트

### Step 3: DashboardViewModel 통합

**파일**: `DUNE/Presentation/Dashboard/DashboardViewModel.swift`

1. `CoachingMessageEnhancing` 프로퍼티 추가 (optional 또는 기본값)
2. `buildCoachingInsights()` 이후 `focusInsight`에 대해 AI 향상 호출
3. `coachingMessage` 업데이트
4. Cancel-before-spawn 패턴 적용 (기존 `reloadTask` 패턴 참조)

**통합 지점**: `buildCoachingInsights()` 호출 후, `coachingMessage` 할당 전에 async 향상

**Verification**: 빌드 통과 + AI 서비스 없이도 기존 동작 유지

### Step 4: 유닛 테스트

**파일**: `DUNE/DUNETests/AICoachingMessageServiceTests.swift`

- `AICoachingMessageService` isAvailable 판정 테스트 (시뮬레이터에서는 unavailable)
- Fallback 동작 테스트: unavailable 시 원본 insight 그대로 반환
- 프롬프트 빌드 로직 테스트 (public으로 노출된 경우)
- Mock `CoachingMessageEnhancing` conformance 테스트

**Framework**: Swift Testing (`@Suite`, `@Test`, `#expect`)

## 테스트 전략

| 레벨 | 범위 | 방법 |
|------|------|------|
| Unit | AICoachingMessageService fallback | Swift Testing, 시뮬레이터(isAvailable=false) |
| Unit | 프롬프트 빌드 로직 | 입력→프롬프트 문자열 검증 |
| Integration | DashboardViewModel | AI 서비스 없이 기존 동작 유지 확인 |
| Manual | A17 Pro+ 실기기 | AI 생성 메시지 품질 확인 |

## 리스크 & 엣지 케이스

| 리스크 | 대응 |
|--------|------|
| Foundation Models 미지원 기기 | isAvailable 체크 + 기존 템플릿 fallback |
| LLM 응답 지연 (>2초) | async 처리, UI는 즉시 템플릿 표시 → AI 완료 시 교체 |
| 부적절한 생성 메시지 | @Guide 제약 + 짧은 메시지 제한, 빈 결과 시 fallback |
| 4096 토큰 컨텍스트 초과 | CoachingInput 핵심 필드만 전달 (전체 아님) |
| 다국어 품질 | Locale 기반 프롬프트 언어 지시 |
| Swift 6 concurrency | Sendable 준수, @MainActor 주의 |

## 대안 비교

| 접근법 | 장점 | 단점 | 선택 |
|--------|------|------|------|
| CoachingEngine 내부 호출 | 통합 간단 | Domain에 FoundationModels import 필요 (규칙 위반) | X |
| ViewModel에서 후처리 | 레이어 경계 유지, 단순 | 기존 동작에 영향 없음 | **O** |
| 별도 AI 코칭 시스템 | 완전 분리 | 과잉 설계, 기존 CoachingEngine 중복 | X |

## 범위 외

- `insightCards` 전체의 AI 향상 (focusInsight만 대상)
- 대화형 코칭 (멀티턴 세션은 TODO #097 범위)
- 운동 추천 로직 변경 (TODO #098 범위)
