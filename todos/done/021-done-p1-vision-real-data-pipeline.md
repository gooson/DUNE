---
source: brainstorm/vision-pro-production-roadmap
priority: p1
status: done
created: 2026-03-08
updated: 2026-03-08
---

# Phase 5A: visionOS 실데이터 연결 + Critical Fix

## 완료 메모

- `feat(visionOS): connect real health data pipeline to all Vision views` 커밋으로 Vision Pro 실데이터 연결이 main에 반영됐다.
- `VisionTrainViewModel`, `ConditionScatter3DView`, `TrainingVolume3DView`, `VisionDashboardView`, `VisionWellnessView`, `VisionLifeView`가 실제 snapshot/workout 기반 흐름을 사용하도록 연결됐다.
- `BodyHeatmapSceneView`의 drag rotation이 delta 기반으로 정리됐고, `VisionTrainViewModelTests`가 추가됐다.
- 원안의 `SharedHealthSnapshot` exercise metadata 확장 대신 HealthKit direct query + shared snapshot 조합으로 단순화해 같은 사용자 목표를 달성했다.
- 구현 근거와 패턴은 `docs/solutions/architecture/2026-03-08-visionos-real-data-pipeline.md`에 기록돼 있다.

## 목표

모든 visionOS 화면이 실제 데이터로 동작하도록 데이터 파이프라인을 연결하고,
production 차단 수준의 critical UX 문제를 수정한다.

## 범위

### 1. Exercise Summary → SharedHealthSnapshot 확장

- SharedHealthSnapshot에 exercise metadata 추가:
  - 근육별 주간 volume (sets count)
  - 근육별 마지막 훈련 시각
  - 최근 7일 운동 세션 수
- iOS MirroringSharedHealthDataService가 exercise summary를 mirror에 포함
- HealthSnapshotMirrorMapper encode/decode 확장

### 2. VisionTrainView 실데이터 교체

- VisionMuscleMapDemoData 제거
- VisionTrainViewModel (또는 기존 VM 확장)이 mirror에서 exercise summary 읽기
- MuscleFatigueState를 exercise summary에서 계산
- Empty state: 운동 기록 없을 때 안내 메시지

### 3. Chart3D 실데이터 연결

- ConditionScatter3DView: generateSampleData → SharedHealthSnapshot 데이터
- TrainingVolume3DView: 데모 → exercise summary 데이터
- Empty state: 데이터 부족 시 placeholder 차트

### 4. Dashboard 윈도우 실데이터 검증

- VisionDashboardWorkspaceViewModel이 모든 summary를 정상 fetch하는지 검증
- Activity summary에 exercise metadata 반영
- "--" placeholder → 의미 있는 empty state

### 5. Critical UX Fix

- [x] Train tab 개발 설명 텍스트 제거 (VisionTrainView)
- [x] BodyHeatmapSceneView DragGesture를 delta 기반으로 수정
- [x] Wellness 탭 기본 UI (Sleep + Body Composition read-only)
- [x] Life 탭 기본 UI (Habit read-only)

## 검증 기준

- [x] visionOS 시뮬레이터에서 앱 실행 시 모든 탭에 데이터 표시 (mock 주입)
- [x] Train 탭에서 실제 근육 피로도 표시 (demo data 없음)
- [x] Chart3D에서 실제 condition/training 데이터 표시
- [x] Dashboard 4개 윈도우 모두 "--" 없이 값 표시
- [x] Wellness/Life 탭에 "Coming Soon" 아닌 실제 UI
- [x] placeholder/개발 텍스트 0건

## 기술 요구사항

- SharedHealthSnapshot 구조 확장 (backward compatible)
- HealthSnapshotMirrorMapper 버전 관리 (payloadVersion 증가)
- VersionedSchema 영향 확인 (HealthSnapshotMirrorRecord 변경 시)
- Swift Testing 테스트 추가 (snapshot encode/decode, fatigue calculation)

## 참고

- `docs/brainstorms/2026-03-08-vision-pro-production-roadmap.md`
- `docs/solutions/architecture/visionos-multi-target-setup.md`
- `docs/solutions/architecture/2026-03-07-visionos-mirror-sync-gating-and-spatial-fallback.md`
- `docs/solutions/architecture/2026-03-08-visionos-real-data-pipeline.md`
