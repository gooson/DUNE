---
source: review/swift-ui-expert
priority: p2
status: done
created: 2026-03-15
updated: 2026-03-15
---

# isSaving 에러 경로에서 리셋 누락 수정

## 문제

`saveAssessment()`에서 `modelContext.insert(record)` 실패 시 `didFinishSaving()` 호출되지 않아
`isSaving = true` 상태로 stuck → 버튼 영구 비활성화

## 해결 방향

void 함수이므로 `defer { viewModel.didFinishSaving() }` 또는 모든 경로에서 명시적 리셋

## 영향 파일

- `DUNE/Presentation/Posture/PostureCaptureView.swift`
- `DUNE/Presentation/Posture/PostureAssessmentViewModel.swift`
