---
source: brainstorm/posture-assessment-system
priority: p2
status: ready
created: 2026-03-15
updated: 2026-03-15
---

# WellnessScore에 Posture Score 통합

## 설명

기존 WellnessScore 시스템에 Posture Score를 새 항목으로 추가.
종합 Wellness 점수 계산에 자세 점수 반영.

## 고려사항

- 가중치 결정 (다른 항목과의 균형)
- 자세 측정이 없는 경우 fallback (평가 없음 처리)
- WellnessScore 계산 로직 수정

## Phase

Phase 2: 점수화 + 시각화

## 영향 파일

- `DUNE/Domain/Models/WellnessScore.swift`
- `DUNE/Presentation/Wellness/`
