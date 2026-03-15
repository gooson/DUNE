---
source: brainstorm/posture-assessment-system
priority: p2
status: done
created: 2026-03-15
updated: 2026-03-16
---

# Injury 시스템 연계

## 설명

자세 문제 부위를 기존 Injury 시스템과 연동.
- 자세 문제 → 부상 위험 알림 (예: 거북목 → 목/어깨 부상 위험)
- InjuryBodyMapView에 자세 관련 위험 부위 표시
- 자세 점수 변화와 부상 기록 상관관계 분석

## Phase

Phase 3: 히스토리 + 트렌드

## 영향 파일

- `DUNE/Domain/Models/Injury.swift`
- `DUNE/Presentation/Injury/`
