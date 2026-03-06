---
tags: [muscle-map, 3d, svg, realitykit, usdz, visionos, asset-pipeline, activity]
date: 2026-03-07
category: brainstorm
status: draft
---

# Brainstorm: SVG 기반 Muscle Map 3D 자산 고도화

## Problem Statement

현재 Muscle Map은 두 가지 자산 수준이 어긋나 있다.

- 2D 쪽은 `MuscleMapData.swift` 기준으로 SVG 경계 데이터가 비교적 정교하다.
- 3D 쪽은 `MuscleMap3DView.swift` 기준으로 RealityKit procedural rig가 들어가 있지만, primitive 조합 중심이라 해부학 정밀도와 자산 재사용성이 낮다.

즉, 지금 상태는 "2D 데이터는 아깝고, 3D 데이터는 아직 제품 자산으로 보기 어려운 중간 상태"에 가깝다.

이번 고도화의 목표는 단순 렌더링 개선이 아니라, **현재 SVG를 reference/segmentation source로 활용해 새로운 3D muscle dataset을 만들고**, 그 dataset을 iPhone/iPad와 visionOS에서 함께 재사용 가능한 형태로 정리하는 것이다.

결과물은 화면 하나가 아니라 아래 3개여야 한다.

- **3D source asset**: anatomy/base mesh, submesh, material slot, naming 규칙을 갖춘 원본 자산
- **runtime-ready package**: RealityKit / USD / USDZ 기반 런타임 자산
- **mapping contract**: `MuscleGroup`과 3D entity/submesh를 연결하는 안정적인 데이터 계약

## Target Users

- **주 사용자**: 운동 고숙련자, 근비대/퍼포먼스 중심 사용자
- **확장 사용자**: visionOS에서 spatial fitness experience를 기대하는 얼리어답터
- **사용자 기대**:
  - 근육 위치를 실제 공간감으로 이해하고 싶음
  - 전면/후면뿐 아니라 측면과 사선 각도에서도 균형을 보고 싶음
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
  - 측면/사선 시점에서도 근육 위치와 균형을 이해할 수 있을 것
  - 같은 dataset을 iPhone/iPad와 visionOS에서 재사용할 수 있을 것
  - DUNE의 시그니처 경험으로 기억될 것

## Proposed Approach

### 권장안: SVG를 직접 3D로 extrude하지 말고, SVG를 3D segmentation atlas로 사용

가장 현실적인 방향은 **고품질 anatomical base mesh를 먼저 확보하고**, 현재 SVG를 아래 용도로 사용하는 hybrid pipeline이다.

1. **SVG as reference**
   - front/back SVG path를 근육 경계 reference로 사용
   - 현재 `MuscleGroup` 13개와 2D path를 canonical label source로 유지
2. **Base mesh authoring**
   - neutral athletic body를 기준으로 3D anatomy mesh 제작 또는 도입
   - 깊이감, 겹침, silhouette, side volume은 DCC 툴에서 설계
3. **3D segmentation**
   - 3D mesh를 `MuscleGroup` 기준의 submesh 또는 named entity로 분리
   - 좌/우는 메시 레벨에서 분리 가능하되, runtime에서는 현재 symmetric data 모델에 맞게 동일 그룹으로 묶음
4. **Runtime packaging**
   - USD/USDZ로 export
   - Reality Composer Pro / RealityKit에서 scene, material, collision proxy, LOD 구성
5. **App mapping**
   - `MuscleGroup -> Entity[]` manifest 고정
   - Recovery / Volume / No Data / Selected state를 동일 contract 위에 입힘

핵심 판단은 이것이다.

- **SVG는 final 3D geometry source가 아니라 segmentation/reference source로 써야 한다**
- **Vision Pro 수준 자산은 topology, depth, material, hit-test, LOD까지 포함한 3D asset pipeline이 필요하다**

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

### 추천 스택과 제작 파이프라인

| 옵션 | 판단 | 이유 |
|------|------|------|
| **DCC base mesh + SVG-guided segmentation + USD/USDZ + RealityKit** | **채택** | 실제 3D 자산 품질, hit-testing, visionOS 재사용성까지 확보 가능 |
| SVG direct extrusion / lofting | 비추천 | 측면 볼륨, 겹침, topology, deformations 품질이 visionOS 기준에 못 미칠 가능성 큼 |
| procedural primitive rig 유지 | 기각 | prototype으로는 충분하지만 premium asset으로는 한계 명확 |

### 권장 산출물

- `muscle-body-master.blend` 또는 동급 source scene
- `muscle-body-runtime.usd` / `usdz`
- `muscle-group-map.json`
  - entity name
  - muscle group
  - optional left/right flag
  - optional collision proxy name
- material preset
  - neutral shell
  - recovery overlay
  - volume overlay
  - selected highlight
- LOD / collision 정책

### Apple 플랫폼 정합성

Apple 공식 문서 기준으로 visionOS/RealityKit 자산 파이프라인은 `RealityView` + `ModelEntity` + USD 계열 자산을 중심으로 잡는 편이 맞다. `Reality Composer Pro`는 scene authoring과 asset organization 역할을 하고, USD는 Apple 쪽 3D 표준 경로다.

## Asset Requirements

- athlete-neutral 포즈의 3D body model 1종
- 근육군별 분리된 mesh/entity
- shell / muscle / highlight layer 구분
- iPhone/iPad용 LOD와 visionOS용 LOD 분리 가능 구조
- material slot 정리
- entity naming 규칙 확정
- collision proxy 또는 enlarged hit area 전략
- source-of-truth 문서화

핵심은 코드보다 **모델 asset 구조를 먼저 맞추는 것**이다. 모델이 근육군별로 잘 나뉘지 않으면, 이후의 탭/색상/선택/LOD/visionOS 확장이 전부 불안정해진다.

## Constraints

- **플랫폼 우선순위**: iPhone / iPad + visionOS 재사용 가능 구조
- **성능 우선순위**: 상호작용 중 frame drop이 체감되면 안 됨
- **도메인 제약**: 현재 데이터 모델은 13 muscle groups만 지원하며 좌우 비대칭 데이터가 없음
- **구현 리스크**:
  - 3D 자산 제작/정리 비용이 큼
  - SVG와 3D mesh 경계가 1:1로 맞지 않을 수 있음
  - 작은 근육의 탭 정확도 확보가 필요
  - Recovery/Volume를 3D material에 자연스럽게 입히는 스타일 가이드가 필요
  - asset licensing / source ownership 정리가 필요
- **호환성 요구**: 기존 상세 패널, Recovery/Volume 설명 sheet, muscle selection 흐름과 충돌 없이 붙어야 함

## Edge Cases

- **No Data**: 근육은 회색으로 유지
- **Occlusion**: 가려진 근육은 자동 카메라 보정 또는 보조 선택 UI 필요
- **Small Hit Target**: 전완/삼두/승모처럼 작은 부위는 proxy collider 또는 selection margin 필요
- **Model Load Failure**: 3D asset 로드 실패 시 현재 expanded 2D map으로 fallback
- **Mode Switch During Selection**: 선택 근육은 유지하되 색상 체계만 변경
- **iPad Layout**: 큰 화면에서는 3D viewer와 detail panel을 동시 배치하는 split layout 고려 가능
- **visionOS Volume/Window 전환**: 같은 asset이라도 UI attachment와 camera defaults는 별도 튜닝 필요
- **Future asymmetry**: 좌/우 데이터가 생기면 현재 그룹 contract를 깨지 않고 확장 가능해야 함

## Scope

### MVP (Must-have)

- high-fidelity 3D body/muscle source asset 1종
- `MuscleGroup` 13개 대응 submesh/entity mapping
- iPhone/iPad에서 동작하는 RealityKit viewer
- visionOS에서 재사용 가능한 USD asset package
- 360도 회전 + pinch zoom + reset
- 근육 탭 선택
- Recovery / Volume 모드 전환
- 데이터 없는 근육 회색 처리
- 선택 근육 강조 애니메이션
- 기존 muscle detail 정보와 연동
- DUNE다운 프리미엄 모션과 비주얼 톤

### Nice-to-have (Future)

- Front / Back / Left / Right quick camera presets
- layer toggle (skin / muscle / highlight only)
- time scrubber (최근 7일 회복 변화를 재생)
- guided workout suggestion overlay
- 좌우 비대칭 데이터 지원
- female / neutral body variants
- visionOS volumetric viewer 고도화
- skeletal animation / breathing idle / onboarding sequence

## Open Questions

- 3D 바디 모델을 내부 제작할지, 외부 anatomical base asset을 도입할지
- SVG를 어디까지 source-of-truth로 둘지: label/mask 기준인지, shape generation 기준인지
- DUNE 브랜드에 맞는 realism level을 어느 정도로 가져갈지
- 3D viewer를 detail 전용 경험으로 둘지, Activity 메인 카드 preview까지 확장할지
- side view 전용 camera preset을 MVP에 포함할지, 자유 회전만으로 충분할지
- muscle entity naming 규칙과 source ownership을 asset 단계에서 어떻게 고정할지
- visionOS를 `same asset, different scene` 수준으로 볼지, 별도 spatial interaction을 포함할지

## Next Steps

- [ ] 사용자 답변으로 realism level, asset source, Vision Pro scope 확정
- [ ] `/plan muscle-map-real-3d` 로 asset pipeline, RealityKit integration, visionOS reuse 전략을 세부 계획으로 분해
