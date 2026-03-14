---
source: manual
priority: p2
status: done
created: 2026-03-15
updated: 2026-03-15
---

# 자세 측정 앱 진입점 추가

## 설명

PostureCaptureView가 구현되었지만 앱 내 진입 경로가 없음.
Wellness 탭 Physical 섹션에 카드/버튼 추가하여 자세 측정 시작 가능하게 연결.

## 고려사항

- Wellness 탭 Physical 섹션 내 배치
- sheet 또는 fullScreenCover로 제시
- 카메라 권한 미부여 시 안내

## 영향 파일

- `DUNE/Presentation/Wellness/` (진입 카드)
- `DUNE/Presentation/Posture/PostureCaptureView.swift`
