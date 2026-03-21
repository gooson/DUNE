---
source: brainstorm/realtime-video-posture-analysis
priority: p3
status: done
created: 2026-03-15
updated: 2026-03-22
---

# 실시간 영상 자세 분석 — 상위 항목

이 TODO는 Phase 4A~4D를 묶는 상위 항목입니다.
개별 Phase는 #140~#143에서 관리합니다.

## 브레인스톰

`docs/brainstorms/2026-03-16-realtime-video-posture-analysis.md`

## Phase 구성

| Phase | TODO | 설명 |
|-------|------|------|
| 4A | #140 | 실시간 스켈레톤 + 각도 표시 (MVP) |
| 4B | #141 | 운동 폼 판정 |
| 4C | #142 | 세트 녹화 & 리플레이 |
| 4D | #143 | 음성 코칭 |

## 기술 전략

듀얼 파이프라인: 2D 연속 (30fps) + 3D 주기적 (3-5fps)
타겟 디바이스: A17+ 전용
카메라: 삼각대 고정 전제 (핸드헬드는 Future)

## 잔여 항목

- #142 (Phase 4C: 세트 녹화 & 리플레이)는 독립 TODO로 별도 추적
