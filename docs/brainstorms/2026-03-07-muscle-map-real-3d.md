---
tags: [muscle-map, 3d, realitykit, usdz, engagement, brand, activity]
date: 2026-03-07
category: brainstorm
status: draft
---

# Brainstorm: Muscle Map 실제 3D 전환

## Problem Statement

현재 Muscle Map 흐름은 2D SVG body diagram을 중심으로 구성되어 있고, `MuscleMap3DView`도 front/back SVG를 `rotation3DEffect`로 회전시키는 pseudo-3D에 가깝다. 이 방식은 다음 한계가 있다.

- **실제 입체감 부족**: 몸통 두께, 측면 실루엣, 근육의 겹침(occlusion)이 표현되지 않음
- **고숙련자 관점의 해상도 부족**: 등/광배/승모, 둔근/햄스트링, 전완/상완 같은 부위의 공간적 이해가 제한됨
- **브랜드 차별화 한계**: 현재 경험은 "잘 만든 2D" 수준이며, 프리미엄 피트니스 앱으로서의 wow factor가 부족함
- **체류시간 확장 여지**: 사용자가 한 번 보고 지나가는 정보형 화면에 머무르기 쉬움

목표는 단순히 2D를 돌려 보이게 하는 것이 아니라, **실제 3D 인체/근육 모델 위에 Recovery/Volume 데이터를 입혀서** 몰입감, 근육 이해도, 브랜드 차별화를 동시에 끌어올리는 것이다.

## Target Users

- **주 사용자**: 운동 고숙련자, 근비대/퍼포먼스 중심 사용자
- **사용자 기대**:
  - 근육 위치를 실제 공간감으로 이해하고 싶음
  - 전면/후면뿐 아니라 측면과 비스듬한 각도에서도 균형을 보고 싶음
  - 앱이 "초보자용 체크리스트"가 아니라 고급 트레이닝 도구처럼 느껴지길 원함
- **필수 인터랙션**:
  - 회전
  - 줌
  - 근육 탭
  - Recovery/Volume 오버레이 전환
  - 선택 근육 강조 및 상세 정보 확인

## Success Criteria

- **Primary KPI**: Muscle Map 상세 화면 평균 체류시간 증가
- **권장 목표치**: 출시 후 4주 내 평균 체류시간 **+25% 이상**
- **정성 목표**:
  - 사용자가 "실제 3D"라고 인지할 것
  - 근육 위치/균형 이해가 기존 대비 더 직관적일 것
  - DUNE의 시그니처 경험으로 기억될 것

## Proposed Approach

### 권장안: RealityKit + 세그먼트된 USDZ 인체 모델

실제 3D 전환의 기본안은 **`RealityView` 기반의 RealityKit 렌더링 + 근육군별로 분리된 USDZ 모델**이다.

- `MuscleGroup` 13개(`chest`, `back`, `shoulders`, `biceps`, `triceps`, `quadriceps`, `hamstrings`, `glutes`, `calves`, `core`, `forearms`, `traps`, `lats`)를 기준으로 색상 매핑
- 모델 내부는 근육군별 submesh 또는 named entity로 분리
- 좌/우 메시가 분리되더라도 현재 도메인 데이터는 좌우 비대칭을 표현하지 않으므로, **동일 MuscleGroup 색상을 양쪽에 동시에 적용**
- 데이터 없는 근육은 사용자 요청대로 **회색(gray)** 처리
- 기존 Recovery/Volume 로직은 재사용하고, 표현 레이어만 3D로 교체

### 시각 방향

권장 비주얼은 의학 교재형 리얼리즘보다, **정확한 해부학 비율 위에 DUNE답게 스타일라이즈된 athletic anatomy**다.

- 기본 바디 쉘: 차분한 중성 톤
- 활성 근육: Recovery/Volume에 따라 색상 강조
- 선택 근육: rim light, halo, camera focus로 강조
- idle motion: 아주 미세한 breathing / light sweep / selection pulse
- 금지 방향: 의료용 앱처럼 차갑고 과도하게 생물학적인 비주얼

### 인터랙션 설계

- **Orbit 회전**: 한 손 드래그로 360도 회전
- **Zoom**: pinch로 확대/축소
- **Tap Select**: 근육 탭 시 해당 부위 강조 + 기존 detail panel 연동
- **Double-tap Reset**: 카메라와 선택 상태 초기화
- **Mode Toggle**: Recovery / Volume 전환
- **Camera Assist**: 작은 근육이나 가려진 부위 탭 시 살짝 자동 회전 또는 focus easing

### 데이터 매핑

| 상태 | 표현 |
|------|------|
| Recovery | 현재 `FatigueLevel` 색상 체계 재사용 |
| Volume | 현재 `weeklyVolume` 기반 intensity 체계 재사용 |
| No Data | 중립 회색 |
| Selected | halo + rim light + detail panel |

## Technical Direction

### 추천 스택

| 옵션 | 판단 | 이유 |
|------|------|------|
| **RealityKit + USDZ segmented model** | **채택** | 실제 3D, hit-testing, SwiftUI 통합, 향후 visionOS 재사용 가능 |
| SceneKit + procedural mesh | 보류/비추천 | SVG 기반에서 "진짜 3D 근육" 품질을 만들기 어렵고 유지비가 큼 |
| 현재 pseudo-3D 유지 | 기각 | 목표인 실제 3D, 몰입감, 브랜드 차별화를 충족하지 못함 |

### 권장 구조

- `MuscleMap3DSceneView`
  - `RealityView` 래퍼
  - 모델 로드, 카메라 설정, gesture 연결
- `MuscleMap3DRenderer`
  - `MuscleGroup -> Entity[]` 매핑 관리
  - mode별 material 업데이트
- `MuscleMap3DSelectionController`
  - hit-test 결과를 `MuscleGroup`으로 변환
  - selection / focus / reset 관리
- `MuscleMap3DStyle`
  - recovery / volume / no-data / selected 색상 및 emission 값 정의

### 자산 요구사항

- athlete-neutral 포즈의 3D body model 1종
- 근육군별 분리된 mesh/entity
- iPhone/iPad용 경량화된 polygon budget
- material slot 정리
- entity naming 규칙 확정

핵심은 코드보다 **모델 asset 구조를 먼저 맞추는 것**이다. 모델이 근육군별로 잘 나뉘지 않으면, 이후의 탭/색상/선택 경험이 전부 불안정해진다.

## Constraints

- **플랫폼 우선순위**: iPhone / iPad 중심
- **성능 우선순위**: 최우선은 아니지만, 상호작용 중 끊김이 체감되면 안 됨
- **도메인 제약**: 현재 데이터 모델은 13 muscle groups만 지원하며 좌우 비대칭 데이터가 없음
- **구현 리스크**:
  - 3D 자산 제작/정리 비용이 큼
  - 작은 근육의 탭 정확도 확보가 필요
  - Recovery/Volume를 3D material에 자연스럽게 입히는 스타일 가이드가 필요
- **호환성 요구**: 기존 상세 패널, Recovery/Volume 설명 sheet, muscle selection 흐름과 충돌 없이 붙어야 함

## Edge Cases

- **No Data**: 근육은 회색으로 유지
- **Occlusion**: 가려진 근육은 자동 카메라 보정 또는 보조 선택 UI 필요
- **Small Hit Target**: 전완/삼두/승모처럼 작은 부위는 proxy collider 또는 selection margin 필요
- **Model Load Failure**: 3D asset 로드 실패 시 현재 expanded 2D map으로 fallback
- **Mode Switch During Selection**: 선택 근육은 유지하되 색상 체계만 변경
- **iPad Layout**: 큰 화면에서는 3D viewer와 detail panel을 동시 배치하는 split layout 고려 가능

## Scope

### MVP (Must-have)

- 실제 3D 인체/근육 모델 1종
- `MuscleGroup` 13개 대응
- 360도 회전 + pinch zoom + reset
- 근육 탭 선택
- Recovery / Volume 모드 전환
- 데이터 없는 근육 회색 처리
- 선택 근육 강조 애니메이션
- 기존 muscle detail 정보와 연동
- iPhone / iPad 대응 레이아웃
- DUNE다운 프리미엄 모션과 비주얼 톤

### Nice-to-have (Future)

- Front / Back / Left / Right quick camera presets
- layer toggle (skin / muscle / highlight only)
- time scrubber (최근 7일 회복 변화를 재생)
- guided workout suggestion overlay
- 좌우 비대칭 데이터 지원
- female / neutral body variants
- visionOS volumetric viewer 재사용

## Open Questions

- 3D 바디 모델을 내부 제작할지, 외부 anatomical base asset을 도입해 경량화할지
- DUNE 브랜드에 맞는 realism level을 어느 정도로 가져갈지
- 3D viewer를 detail 전용 경험으로 둘지, Activity 메인 카드 preview까지 확장할지
- side view 전용 camera preset을 MVP에 포함할지, 자유 회전만으로 충분할지
- muscle entity naming 규칙을 asset 단계에서 어떻게 고정할지

## Next Steps

- [ ] `/plan muscle-map-real-3d` 로 RealityKit 구조, asset pipeline, 기존 `MuscleRecoveryMapView`/`MuscleMap3DView` 대체 전략을 세부 계획으로 분해
