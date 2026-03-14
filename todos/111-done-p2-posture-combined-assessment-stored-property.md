---
source: review/swift-ui-expert
priority: p2
status: done
created: 2026-03-15
updated: 2026-03-15
---

# combinedAssessment를 stored property로 변환

## 문제

`combinedAssessment`가 computed property로 매 접근마다:
1. 새 `CombinedPostureAssessment` 인스턴스 생성
2. 매번 다른 `Date()` 할당 (시맨틱 오류)
3. `PostureResultView.body`에서 다중 접근 시 불필요한 allocation

## 해결 방향

`frontAssessment`/`sideAssessment` 변경 시점에 stored property로 갱신

## 영향 파일

- `DUNE/Presentation/Posture/PostureAssessmentViewModel.swift`
