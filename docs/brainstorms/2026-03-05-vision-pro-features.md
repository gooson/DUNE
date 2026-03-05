---
tags: [visionos, vision-pro, spatial-computing, chart3d, realitykit, immersive, widgets]
date: 2026-03-05
category: brainstorm
status: draft
---

# Brainstorm: Vision Pro 특화 기능

## Problem Statement

DUNE 앱은 현재 iOS + watchOS만 지원한다. Apple Vision Pro (visionOS 26)는 공간 컴퓨팅을 통해 헬스/피트니스 데이터를 완전히 새로운 방식으로 시각화하고 체험할 수 있는 기회를 제공한다. 기존 2D 차트와 리스트 기반 UI를 넘어, 3D 시각화/몰입형 경험/공간 위젯 등으로 차별화된 건강 분석 경험을 제공하는 것이 목표이다.

## Target Users

- **Vision Pro 보유 피트니스 애호가**: 데이터를 더 깊이 탐색하고 싶은 사용자
- **홈짐 사용자**: Vision Pro를 착용하고 운동하는 사용자 (공간 위젯 활용)
- **명상/회복 관심자**: 몰입형 회복 세션에 관심 있는 사용자
- **데이터 분석 매니아**: 3D 산점도, 표면 그래프로 다차원 상관관계를 탐색하고 싶은 사용자

## Success Criteria

- iOS 앱 → visionOS 기본 포팅 완료 (Shared Space 윈도우)
- 1개 이상의 Vision Pro 전용 킬러 피처 (3D 차트 or Volumetric Body)
- Spatial Widget으로 일상적 glanceable 헬스 데이터 제공
- HealthKit 데이터 동기화가 iOS/watchOS/visionOS 간 원활히 작동

---

## 기능 카탈로그

### Category A: 3D 데이터 시각화 (Chart3D)

visionOS 26에서 Swift Charts 3D (Chart3D, PointMark 3D, SurfacePlot)가 도입됨. 기존 DUNE 차트 코드를 확장하기에 최적.

#### A1. 3D Condition Scatter (HRV × RHR × Sleep)

```
축: X = HRV(ms), Y = RHR(bpm), Z = Sleep Quality(%)
마크: PointMark — 색상=컨디션 등급, 크기=운동 볼륨
기간: 30/60/90일 데이터
```

- 컨디션이 좋은 날/나쁜 날의 클러스터를 공간에서 직관적으로 파악
- 회전 제스처로 각도를 바꿔 2축 상관관계도 확인 가능
- **DUNE 데이터 매핑**: `ConditionScore`, `HRVSample`, `HeartRateSummary`, `SleepSummary`

#### A2. 3D Training Volume Surface

```
축: X = 근육그룹(7개), Y = 주차(1-12주), Z = 볼륨(kg)
마크: SurfacePlot 또는 BarMark3D
```

- 어떤 근육을 어느 시기에 많이/적게 훈련했는지 지형처럼 파악
- **DUNE 데이터 매핑**: `ExerciseRecord`, `MuscleGroup`, 주간 볼륨 집계

#### A3. 3D Sleep Architecture Terrain

```
축: X = 날짜(30일), Y = 시간(22:00-08:00), Z = 수면단계(Awake/Core/Deep/REM)
마크: SurfacePlot — 색상=수면단계 gradient
```

- 수면 패턴의 날짜별 변화를 지형 표면으로 시각화
- 깊은 수면 구간이 "계곡"처럼, REM이 "능선"처럼 표현
- **DUNE 데이터 매핑**: `SleepStage`, `SleepSummary`

#### A4. 3D Heart Rate Landscape

```
축: X = 시간(24h), Y = 날짜(7일), Z = BPM
마크: SurfacePlot — 높이=심박수, 색상=zone
```

- 일중 심박수 변동 패턴을 7일치 누적하여 입체 지형화
- 운동 시간대의 "봉우리"와 수면 시간대의 "평원"이 시각적으로 구분
- **DUNE 데이터 매핑**: `HeartRateSample`, 시간별 집계

#### A5. 3D Metric Correlation Explorer

```
축: 사용자가 X/Y/Z 각 축에 원하는 메트릭을 선택
가능한 메트릭: HRV, RHR, Sleep, Steps, Weight, Body Fat, Training Volume
```

- 탐색적 데이터 분석 도구 — 사용자가 3축을 자유롭게 조합
- **DUNE 데이터 매핑**: `HealthMetric` 전체

---

### Category B: Volumetric 3D 모델 (RealityKit)

RealityKit + Model3D / RealityView로 3D 오브젝트를 Shared Space에 배치.

#### B1. 3D Body Composition Model

- **USDZ 인체 모델** 위에 근육그룹별 데이터를 색상 매핑
- 훈련 볼륨 → 밝기, 피로도 → 붉은색 강도, undertrained → 회색
- 360도 회전하며 전신 훈련 균형 한눈에 파악
- 기존 SVG body diagram의 3D 업그레이드 버전
- **구현 복잡도**: 높음 (USDZ 모델 제작 + ShaderGraph 커스텀)
- **DUNE 데이터 매핑**: `MuscleGroup` 볼륨, `MuscleRecoveryState`

#### B2. 3D Injury Map

- 인체 모델 위에 부상 위치를 3D 핀으로 표시
- 핀 색상=심각도, 크기=지속 기간
- 탭하면 부상 상세 정보 팝업 (ornament)
- **DUNE 데이터 매핑**: `InjuryRecord`, `BodyPart`

#### B3. Heart Rate Orb (Volumetric Widget)

- 실시간 심박수를 반영하는 맥동 3D 오브 (sphere)
- BPM에 따라 크기/색상/맥동 속도 변화
- Shared Space에서 다른 앱과 함께 상시 표시 가능
- **구현 복잡도**: 중간 (ShaderGraph + TimelineView + HealthKit observer)

#### B4. Training Volume Blocks

- 근육그룹별 훈련 볼륨을 3D 블록 (레고 스타일)으로 쌓아 올림
- 블록 높이=볼륨, 색상=근육그룹
- 주간 진행 상황을 물리적 "건물"처럼 시각화
- **구현 복잡도**: 중간 (RealityView + 기본 도형)

---

### Category C: Immersive Space 경험

ImmersiveSpace + progressive/mixed/full 몰입 스타일 활용.

#### C1. Condition Atmosphere (Progressive)

- 오늘의 컨디션 점수에 따라 주변 환경 분위기 변경
  - 90+ : 맑은 하늘, 따뜻한 빛
  - 70-89: 약간 흐린 하늘
  - 50-69: 안개 낀 환경
  - <50: 어두운 구름, 차가운 톤
- DUNE의 desert 테마와 연계 — 사막 환경에 컨디션 반영
- **구현 복잡도**: 중간-높음 (Skybox + 환경 전환 애니메이션)

#### C2. Mindful Recovery Session (Full)

- 컨디션이 낮을 때 제안하는 회복 세션
- Vision Pro 내장 호흡 추적 + 시각적 파티클 피드백
  - 들숨: 파티클 확산
  - 날숨: 파티클 수렴
- 세션 완료 후 HealthKit에 mindful minutes 기록
- DUNE 테마별 환경 (사막 일출, 숲, 바다)
- **참고**: Apple의 Mindfulness 앱과 유사하나, DUNE 컨디션 데이터와 연동이 차별점
- **구현 복잡도**: 높음 (호흡 감지 API + 파티클 시스템 + 환경 렌더링)

#### C3. Workout Review Theater (Mixed)

- 운동 완료 후 세트/랩 데이터를 공간 타임라인으로 펼침
- 타임라인 위를 걸으며(시선 이동) 각 세트의 상세 데이터 확인
- 심박수 곡선이 공간에 리본처럼 펼쳐짐
- **구현 복잡도**: 높음 (공간 레이아웃 + 제스처 내비게이션)

#### C4. Sleep Journey (Progressive)

- 어젯밤 수면 데이터를 시간순 공간 여행으로 체험
- 수면 단계별 환경 변화:
  - Awake: 밝은 공간
  - Core: 부드러운 안개
  - Deep: 깊은 심해 느낌
  - REM: 몽환적 색상 (꿈)
- 진행 바를 따라 자동 또는 수동 재생
- **구현 복잡도**: 높음 (다중 환경 전환 + 데이터 동기화)

#### C5. Exercise Form Guide (Mixed)

- 특정 운동의 올바른 자세를 3D 아바타로 시연
- 사용자 공간에 실물 크기 가이드 배치
- 차후: Vision Pro 카메라로 자세 비교 (body tracking API 성숙 후)
- **구현 복잡도**: 매우 높음 (3D 애니메이션 제작 필요)

---

### Category D: Spatial Widgets

visionOS 26 신기능. 공간에 고정, 재부팅 후 유지, glanceable 정보 제공.

#### D1. Condition Score Widget

- 오늘의 컨디션 점수 (숫자 + 등급)
- 어제 대비 변화 화살표
- 탭 → DUNE 앱 대시보드로 이동
- **Mounting style**: `.elevated` (기본)
- **크기**: Small/Medium

#### D2. Training Readiness Widget

- 훈련 준비도 표시 (Ready/Moderate/Rest)
- 추천 강도 아이콘
- 근육 피로도 미니 히트맵
- **Mounting style**: `.elevated`
- **활용**: 홈짐 벽에 배치

#### D3. Sleep Summary Widget

- 어젯밤 수면 시간 + 점수
- 수면 단계 미니 바 차트
- **Mounting style**: `.recessed` (창문처럼 배경과 어울림)

#### D4. Streak & Habit Widget

- 운동 연속일수 / 습관 완수율
- 링 형태 진행도 표시
- **Mounting style**: `.elevated`

#### D5. Live Heart Rate Widget

- HealthKit observer로 최신 심박수 표시
- BPM 숫자 + zone 색상
- **Mounting style**: `.elevated`
- **주의**: WidgetKit timeline 제약으로 "실시간"은 제한적 → 타임라인 빈도 최적화 필요

---

### Category E: Window & Navigation (Shared Space)

visionOS의 기본 윈도우 시스템을 활용한 기능.

#### E1. Multi-Window Dashboard

- 컨디션/운동/수면/바디컴포지션을 각각 독립 윈도우로 열기
- `@Environment(\.openWindow)` action으로 구현
- 사용자가 자유롭게 공간 배치
- **visionOS 26**: 윈도우가 사용자 위치를 자동 추적하는 옵션 추가

#### E2. Workout Planning Board

- 운동 템플릿을 카드 형태로 공간에 펼침
- 드래그로 순서 변경, 루틴 구성
- Object Manipulation API (visionOS 26) 활용
- **구현 복잡도**: 중간

#### E3. Side-by-Side Comparison

- 이번 주 vs 지난 주 데이터를 두 윈도우로 나란히 비교
- 동일 메트릭의 기간별 차이를 공간적으로 대비

#### E4. Ornament Quick Actions

- 메인 윈도우 하단 ornament에 빠른 액션 배치
  - 체중 기록
  - 운동 시작
  - 물 섭취 기록
- `.ornament(attachmentAnchor: .scene(.bottom))` 활용

#### E5. TabView Adaptation

- iOS의 수평 탭바가 visionOS에서 좌측 수직 탭바로 자동 변환
- `.sidebarAdaptable` 스타일이 visionOS에서 glass material로 렌더링
- 기존 iOS ContentView 구조 대부분 재사용 가능

---

### Category F: 고유 입력 & 인터랙션

#### F1. Eye-Gaze Metric Highlight

- 대시보드에서 메트릭 카드를 바라보면 자동 하이라이트
- 탭(손가락 모으기)으로 상세 뷰 진입
- visionOS 기본 hover effect 활용 (추가 코드 최소)

#### F2. Hand Gesture Quick Log

- 세트 완료 시 에어탭으로 빠른 기록
- 손 제스처로 무게/횟수 조절 (+ / - 스와이프)
- **주의**: 운동 중 정확한 제스처 인식 어려울 수 있음 → 보조 수단으로만

#### F3. Voice-First Workout Entry

- "벤치프레스 80kg 8회" 음성 입력
- Speech recognition + NLP로 파싱
- Apple Intelligence 기반 자연어 이해 (visionOS 26)
- **구현 복잡도**: 중간 (SFSpeechRecognizer + 파싱 로직)

#### F4. Spatial Audio Feedback

- 운동 세트 완료 시 공간 사운드 피드백
- 컨디션 점수에 따른 ambient sound
- 3D 사운드로 데이터 방향 인지 (왼쪽에서 소리 → 왼쪽 차트 주목)

---

### Category G: SharePlay & 소셜

#### G1. Shared Workout Space

- SharePlay로 친구와 같은 공간에서 운동 데이터 공유
- 각자의 세트/랩이 실시간으로 공간에 표시
- visionOS 26: SharedWorldAnchors로 정확한 공간 정렬

#### G2. Trainer-Client Session

- 트레이너가 클라이언트의 데이터를 공간에서 실시간 모니터링
- 자세 가이드를 클라이언트 공간에 배치
- **장기 비전** (SharePlay + body tracking 성숙 필요)

---

## 기술적 제약 & 고려사항

### visionOS HealthKit 제약

| 항목 | 상태 | 비고 |
|------|------|------|
| HealthKit 데이터 읽기 | ✅ 지원 | visionOS 2+ (WWDC24에서 도입) |
| HealthKit 데이터 쓰기 | ✅ 지원 | 운동 기록 등 |
| 실시간 심박수 | ⚠️ 제한적 | Vision Pro 자체 센서 없음, Watch 동기화 의존 |
| HealthKit observer | ✅ 지원 | 배경 업데이트 |
| Guest User 처리 | ⚠️ 필수 | Vision Pro 공유 시나리오 고려 |

### SwiftData + CloudKit 호환

- 기존 iOS/watchOS SwiftData 모델이 visionOS에서도 동작
- CloudKit 동기화로 디바이스 간 데이터 자동 공유
- **주의**: visionOS에서 SwiftData 쓰기 시 기존 migration 스키마 호환 확인 필요

### 기존 코드 재사용

| 레이어 | 재사용 가능성 | 비고 |
|--------|-------------|------|
| Domain | 100% | Foundation만 의존, 플랫폼 무관 |
| Data/HealthKit | 95% | HealthKit API 동일, 일부 가용 타입 차이 |
| Data/SwiftData | 100% | 동일 스키마 |
| Presentation/Shared | 80% | SwiftUI 공유, 일부 iOS 전용 modifier 교체 필요 |
| Presentation/Views | 50-70% | 레이아웃 조정 필요 (glass material, spatial layout) |
| Chart 코드 | 70% | 2D Chart → Chart3D 확장, 기존 2D도 그대로 동작 |

### 성능 고려

- Chart3D는 대량 데이터 포인트에서 렌더링 비용 높음 → 데이터 샘플링 필요
- RealityKit 모델은 메모리 사용량 주의 → LOD (Level of Detail) 적용
- Immersive Space는 GPU 집약적 → 파티클 수 제한, 환경 해상도 최적화

---

## 구현 우선순위 제안

### Phase 1: 기본 포팅 + Spatial Widgets (MVP)

1. **project.yml에 visionOS 타겟 추가**
2. **기존 iOS UI를 visionOS 윈도우로 렌더링** (최소 변경)
3. **TabView 좌측 수직 탭바 자동 변환 확인**
4. **Glass material 적용** (visionOS HIG)
5. **Spatial Widgets** (D1-D4) — WidgetKit 확장

### Phase 2: 3D 차트 (차별화)

6. **Chart3D 기반 3D Condition Scatter** (A1)
7. **Chart3D 기반 3D Training Volume** (A2)
8. **3D Metric Correlation Explorer** (A5) — 사용자 축 선택
9. **Multi-Window Dashboard** (E1)

### Phase 3: Volumetric 모델

10. **Heart Rate Orb** (B3) — 비교적 단순한 3D 오브젝트
11. **Training Volume Blocks** (B4) — 기본 도형 기반
12. **3D Body Composition Model** (B1) — USDZ 모델 필요

### Phase 4: Immersive Experience

13. **Condition Atmosphere** (C1) — 환경 분위기 변환
14. **Mindful Recovery Session** (C2) — 호흡 가이드
15. **Sleep Journey** (C4) — 수면 데이터 시각 여행

### Phase 5: 소셜 & 고급

16. **Shared Workout Space** (G1) — SharePlay
17. **Exercise Form Guide** (C5) — 3D 자세 가이드
18. **Voice-First Workout Entry** (F3) — 음성 입력

---

## 경쟁 앱 분석

| 앱 | Vision Pro 기능 | DUNE 차별점 |
|----|----------------|------------|
| **Apple Fitness+** | 몰입형 운동 비디오 | DUNE은 데이터 분석에 특화 — 3D 차트로 패턴 발견 |
| **Visutate** | 몰입형 명상 환경 | DUNE은 컨디션 데이터 기반 개인화된 회복 가이드 |
| **TRIPP** | 호흡 가이드 + 시각 효과 | DUNE은 HRV/RHR 데이터와 연동한 회복 필요성 판단 |
| **Lungy** | 공간 호흡 운동 | DUNE은 운동+수면+심박 종합 분석 위에 회복 세션 제공 |

**DUNE의 핵심 차별점**: 단순 명상/운동 앱이 아닌, **건강 데이터 3D 분석 + 데이터 기반 몰입 경험**의 결합.

---

## Open Questions

1. **visionOS 타겟 추가 시 Xcode project 구조**: 별도 앱 vs iOS 앱 확장(Designed for iPad)?
2. **USDZ 인체 모델 소싱**: Apple 제공 모델 활용 vs 커스텀 제작 vs Reality Composer Pro?
3. **HealthKit 데이터 가용성**: Vision Pro 단독 사용자(Watch 미보유) 시 어떤 데이터가 가용한가?
4. **Spatial Widget 업데이트 빈도**: WidgetKit 타임라인 제약 내에서 "실시간" 심박수 표시 가능한가?
5. **Chart3D 데이터 포인트 한계**: 성능 저하 없이 표시 가능한 최대 포인트 수는?
6. **운동 중 제스처 인식 정확도**: 손에 덤벨을 들고 있을 때 에어탭 인식률은?
7. **테마 시스템 연동**: DUNE의 desert/forest/ocean/sakura 테마를 Immersive Environment에 어떻게 매핑할 것인가?

---

## 참고 자료

- [Bring Swift Charts to the third dimension (WWDC25)](https://developer.apple.com/videos/play/wwdc2025/313/)
- [What's new in visionOS 26 (WWDC25)](https://developer.apple.com/videos/play/wwdc2025/317/)
- [What's new in visionOS 26 — Apple Developer](https://developer.apple.com/visionos/whats-new/)
- [26 Favorite Features in visionOS 26 — Step Into Vision](https://stepinto.vision/articles/twenty-six-of-my-favorite-features-and-apis-in-visionos-26/)
- [WWDC 2025: What's new for visionOS — Step Into Vision](https://stepinto.vision/articles/wwdc-2025-whats-new-for-visionos-developers/)
- [Get started with HealthKit in visionOS (WWDC24)](https://developer.apple.com/videos/play/wwdc2024/10083/)
- [Cook up 3D Charts with Swift Charts](https://artemnovichkov.com/blog/cook-up-3d-charts-with-swift-charts)
- [Apple Vision Pro Health App Opportunities](https://www.apple.com/newsroom/2024/03/apple-vision-pro-unlocks-new-opportunities-for-health-app-developers/)

## Next Steps

- [ ] `/plan vision-pro-phase1` 으로 기본 포팅 + Spatial Widgets 계획 생성
- [ ] `/plan vision-pro-chart3d` 으로 3D 차트 기능 구현 계획 생성
- [ ] visionOS 시뮬레이터에서 기존 iOS 코드 빌드 테스트
