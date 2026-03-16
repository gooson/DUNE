---
source: review/pr-reviewer
priority: p3
status: done
created: 2026-03-15
updated: 2026-03-15
---

# 테스트 force unwrap을 #require로 교체

## 문제

`#expect(metric != nil)` 후 `metric!.value` force unwrap 사용 중.
`#expect`는 실패해도 실행을 중단하지 않아 force unwrap 크래시 위험.

## 해결 방향

```swift
let metric = try #require(results.first { $0.type == .shoulderAsymmetry })
#expect(metric.value > 3.0)
```

## 영향 파일

- `DUNETests/PostureAnalysisServiceTests.swift`
- `DUNETests/PostureAssessmentViewModelTests.swift`
