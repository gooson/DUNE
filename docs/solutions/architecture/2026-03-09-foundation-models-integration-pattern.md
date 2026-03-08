---
tags: [foundation-models, on-device-ai, protocol-pattern, layer-boundaries, coaching]
date: 2026-03-09
category: solution
status: implemented
---

# Foundation Models 통합 패턴

## Problem

Apple Foundation Models (iOS 26+, A17 Pro+)를 기존 앱에 통합할 때 레이어 경계를 유지하면서 graceful fallback을 제공해야 한다. Domain 레이어는 `FoundationModels` framework를 import할 수 없다.

## Solution

### 3계층 프로토콜 패턴

```
Domain (프로토콜만)  →  Data/Services (FM 구현)  →  Presentation (주입/호출)
```

1. **Domain**: `CoachingMessageEnhancing` 프로토콜 — `Foundation`만 import, `Sendable` 준수
2. **Data**: `AICoachingMessageService` — `FoundationModels` import, `@Generable` 정의, 세션 관리
3. **Presentation**: ViewModel init parameter로 주입 (기본값 제공)

### @Generable 구조체 설계

```swift
@Generable(description: "도메인 컨텍스트 설명")
struct AICoachingMessage {
    @Guide(description: "필드별 생성 가이드")
    var title: String
    @Guide(description: "필드별 생성 가이드")
    var message: String
}
```

### Fallback 전략 (3단계)

1. `SystemLanguageModel.default.isAvailable == false` → 원본 반환
2. `session.respond()` 실패 → 원본 반환
3. 빈/유효하지 않은 결과 → 원본 반환

### 세션 관리

- `LanguageModelSession`은 per-call로 생성 (lightweight init)
- `struct` + `Sendable` 유지 — mutable state 없이 thread-safe
- `@unchecked Sendable`로 session을 저장하면 data race/force-unwrap 위험 발생하므로 지양

### Race Condition 방지

```swift
let expectedInsightID = insight.id
enhanceCoachingTask = Task {
    let enhanced = await enhancer.enhance(...)
    guard !Task.isCancelled,
          focusInsight?.id == expectedInsightID else { return }
    // apply
}
```

- Cancel-before-spawn + ID 검증으로 stale 결과 방지

### AI 출력 검증

- `trimmingCharacters(in: .whitespacesAndNewlines)` 후 빈 문자열 체크
- 길이 제한: title 50자, message 200자 (`.prefix(N)`)

## Prevention

| 실수 | 방지 패턴 |
|------|----------|
| Domain에 FoundationModels import | 프로토콜을 Domain에, 구현을 Data에 분리 |
| 미지원 기기 크래시 | `isAvailable` static property 체크 |
| @unchecked Sendable + mutable session | per-call session 생성 (struct Sendable 유지) |
| 비동기 결과 race | expectedID 패턴으로 stale 결과 무시 |
| 과도한 AI 출력 | prefix 길이 제한 |

## 참고 파일

- `DUNE/Domain/Protocols/CoachingMessageEnhancing.swift`
- `DUNE/Data/Services/AICoachingMessageService.swift`
- `DUNE/Data/Services/FoundationModelReportFormatter.swift` (기존 참고 패턴)
- `DUNE/Presentation/Dashboard/DashboardViewModel.swift`
