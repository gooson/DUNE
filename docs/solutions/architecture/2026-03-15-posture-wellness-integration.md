---
tags: [posture, wellness-score, integration, codable, confidence, async-score-propagation]
date: 2026-03-15
category: solution
status: implemented
---

# Posture → Wellness Score 통합 + 신뢰도 표시

## Problem

Posture Assessment 시스템이 독립적으로 동작하여 Wellness Score에 반영되지 않았음.
측정 결과에서 신뢰도(confidence)가 표시되지 않아 PT/트레이너 활용도가 제한적.

## Solution

### 1. PostureMetricResult에 confidence 필드 추가

- `confidence: Double` (0.0-1.0) 추가, `init`에서 clamp
- Backward-compatible Codable: `decodeIfPresent` + default 1.0
- 기존 JSON 데이터는 자동으로 confidence = 1.0으로 디코딩

```swift
init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    confidence = min(1.0, max(0.0,
        try container.decodeIfPresent(Double.self, forKey: .confidence) ?? 1.0
    ))
}
```

### 2. WellnessScore에 postureScore 통합

- 가중치: Sleep 35%, Condition 30%, Body 20%, Posture 15%
- `postureScore: Int?` — nil이면 나머지 컴포넌트로 re-normalize
- `CalculateWellnessScoreUseCase`의 기존 re-normalization 로직이 자동 처리

### 3. 비동기 postureScore 전파 패턴

**문제**: `postureScore`는 `@Query` 기반 View에서 ViewModel로 전달되는데,
`loadData()` 완료 후에 도착하면 wellnessScore가 stale 상태로 남음.

**해결**: `postureScore`에 `didSet` → `recalculateWellnessScore()` 호출.

```swift
var postureScore: Int? {
    didSet {
        if postureScore != oldValue { recalculateWellnessScore() }
    }
}
```

### 4. jointConfidence 계산

- 모든 관절 직접 탐지 + midpoint 미사용 → 1.0 (badge 미표시)
- 모든 관절 직접 탐지 + midpoint 사용 → 0.7
- 부분 관절 탐지 → ratio * 0.9
- 빈 required 배열 → 1.0 (guard)

## Prevention

- Score를 비동기로 전파하는 패턴 사용 시 항상 `didSet` + recalculate 고려
- 외부에서 들어오는 Int 점수는 항상 0-100 clamp 적용
- Codable 필드 추가 시 `decodeIfPresent` + default로 backward compatibility 보장
- JSON 기반 SwiftData 필드는 스키마 마이그레이션 불필요 (큰 장점)
