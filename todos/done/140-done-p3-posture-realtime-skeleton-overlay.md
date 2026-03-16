---
source: brainstorm/realtime-video-posture-analysis
priority: p3
status: done
created: 2026-03-16
updated: 2026-03-16
---

# Phase 4A: 실시간 스켈레톤 + 각도 표시

## 설명

카메라 피드에서 실시간으로 3D 자세를 분석하여 스켈레톤과 주요 각도를 오버레이 표시.

## 주요 작업

1. **듀얼 파이프라인 구축**
   - 2D 연속 감지 (매 프레임, 30fps 목표)
   - 3D 주기적 감지 (3-5fps, 별도 큐)
   - 2D↔3D 보간으로 부드러운 전환

2. **실시간 각도 오버레이**
   - 무릎 굴곡각, 허리 기울기, 어깨 각도 실시간 표시
   - 기존 `BodyGuideOverlay` Canvas 확장
   - 색상 코딩: 정상(녹)/주의(황)/경고(적)

3. **실시간 자세 점수**
   - 기존 `PostureAnalysisService` 재활용
   - 점수 스무딩 (이동평균, 급격한 변화 방지)

4. **RealtimePoseTracker 서비스**
   - `Data/Services/RealtimePoseTracker.swift`
   - 관절 시계열 버퍼 (최근 5초)
   - 3D 샘플링 스케줄링 + 실패 시 fallback

## 기술 제약

- A17+ 전용 (Neural Engine 활용)
- 카메라 고정 전제
- `VNDetectHumanBodyPose3DRequest` 프레임당 ~50-100ms → 매 프레임 불가

## 착수 조건

- Phase 1-3 안정화 완료 (현재 완료)
- A17 Pro에서 3D 감지 fps 벤치마크 선행

## 검증 기준

- [ ] 2D 스켈레톤 30fps 유지 (프레임 드롭 < 5%)
- [ ] 3D 분석 최소 3fps 달성
- [ ] 각도 오버레이가 관절 위치에 정확히 매핑
- [ ] 일시적 감지 실패 시 graceful degradation (마지막 유효 결과 유지)
