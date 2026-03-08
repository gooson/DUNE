---
tags: [3d, muscle-map, volume-map, realitykit, usdz, anatomy, z-anatomy]
date: 2026-03-08
category: brainstorm
status: draft
---

# Brainstorm: 볼륨맵 3D 퀄리티 업그레이드

## Problem Statement

현재 볼륨맵은 react-native-body-highlighter의 SVG 패스를 RealityKit `MeshResource(extruding:)`으로 압출하는 pseudo-3D 방식이다.
앞/뒤 레이어 2장(z-offset ±0.07)으로 구성되어 실제 회전 시 "판떼기" 느낌이 나고, 해부학적 사실성이 부족하다.

**목표**: 해부학적으로 정확한 3D 인체 메시로 교체하여 fitness app 수준에서 인상적인 근육 시각화 달성.

## Target Users

- DUNE iOS/visionOS 사용자
- 근력 운동자가 볼륨/리커버리 데이터를 직관적으로 파악
- 시각적 퀄리티가 앱 차별화 요소

## Success Criteria

1. 360도 회전 시 해부학적으로 자연스러운 근육 형태
2. 14개 MuscleGroup별 독립적 색상/크기 제어
3. iPhone에서 60fps 유지 (30K triangles 이하)
4. iOS + visionOS 동일 에셋 공유

## 조사 결과

### 3D 인체 모델 소스

| 소스 | 근육 분리 | 라이선스 | 장단점 |
|------|----------|----------|--------|
| **Z-Anatomy** (Blender) | O (개별 메시) | CC BY-SA 2.1 JP | 이미 분리됨, 5개 언어, attribution 필수 |
| **BodyParts3D** (OBJ) | O (1,523개 파트) | CC BY-SA 2.1 JP | Z-Anatomy의 원본 데이터 |
| **MakeHuman** | X (단일 스킨) | AGPL + CC0 출력 | 깔끔한 라이선스, 근육 분리 수동 작업 필요 |
| **SMPL** | X (단일 메시) | 학술 무료/상용 별도 | 체형 파라미터 100개, Swift 미지원 |

### 상용 SDK

| SDK | iOS 지원 | 특징 | 비용 |
|-----|----------|------|------|
| **BioDigital Human** | iOS SDK (WebView) | 의학 수준 정확도 | Business plan (문의) |
| **Zygote** | 모델 라이선스 | 최고 품질 | 로열티/구독 |

### 현재 코드 아키텍처 (교체 대상)

```
MuscleMap3DScene.swift     → 핵심: SVG→MeshResource 압출, 앞/뒤 레이어
MuscleMapData.swift        → SVG 패스 데이터 (react-native-body-highlighter 기반)
MuscleMap3DView.swift      → UIViewRepresentable, 제스처, 상태 관리
```

## Proposed Approach: Z-Anatomy 기반 USDZ 파이프라인

### Phase 1: 에셋 제작 (Blender 작업)

1. Z-Anatomy `.blend` 다운로드
2. MuscleGroup enum 14개 ↔ Z-Anatomy 근육 매핑 테이블 작성:

| MuscleGroup | Z-Anatomy 구조 (병합 대상) |
|-------------|---------------------------|
| chest | pectoralis_major_L/R |
| back | latissimus_dorsi_L/R, teres_major, infraspinatus |
| shoulders | deltoid_anterior/lateral/posterior_L/R |
| biceps | biceps_brachii_L/R |
| triceps | triceps_brachii_L/R |
| forearms | brachioradialis, extensor/flexor groups |
| core | rectus_abdominis, obliquus_externus/internus |
| quads | rectus_femoris, vastus_lateralis/medialis/intermedius |
| hamstrings | biceps_femoris, semitendinosus, semimembranosus |
| glutes | gluteus_maximus/medius |
| calves | gastrocnemius, soleus |
| traps | trapezius |
| lats | latissimus_dorsi (back과 분리 시) |
| hip | hip_flexors, adductors |

3. Blender 스크립트로 자동화:
   - 불필요한 구조 제거 (혈관, 신경, 내장, 뼈)
   - 근육을 14그룹으로 Join
   - Decimate modifier (mobile target: 전체 10K-30K tri)
   - 스켈레톤 실루엣 레이어 (반투명 참조용, 선택적)
4. USDZ 익스포트: Blender → USD → `usdzconvert` 또는 Reality Converter
5. Entity naming convention: `muscle_{groupName}` (예: `muscle_chest`)

### Phase 2: RealityKit 코드 교체

**변경 전** (현재):
```swift
// SVG path → MeshResource(extruding:) → 앞/뒤 레이어
let mesh = try await MeshResource(extruding: shape, extrusionOptions: options)
```

**변경 후**:
```swift
// USDZ → Entity hierarchy → named entity 접근
let bodyModel = try await Entity(named: "muscle_body", in: .main)
let chestEntity = bodyModel.findEntity(named: "muscle_chest")

// 색상 변경
var material = PhysicallyBasedMaterial()
material.baseColor = .init(tint: volumeColor)
material.roughness = .init(floatLiteral: 0.7)
chestEntity?.model?.materials = [material]
```

**재사용 가능한 부분**:
- `MuscleMap3DView.swift`: 제스처 핸들링 (pan/pinch/tap)
- `MuscleMap3DState.swift`: 카메라 상태 관리
- Volume/Recovery 색상 로직 전체
- `MuscleMap3DMeshCache`: USDZ Entity 캐싱으로 전환

**교체 대상**:
- `MuscleMapData.swift`: SVG 패스 → USDZ 에셋 참조로 교체
- `MuscleMap3DScene.swift`: 메시 생성 → Entity 로드로 교체
- Collision shape 생성 로직

### Phase 3: visionOS 통합

현재 visionOS는 별도 geometric primitives 사용 → 동일 USDZ 모델 공유로 통합:
- `VisionSpatialSceneSupport.swift`의 `VisionBodyRig` 교체
- RealityView에서 동일 USDZ 로드
- visionOS에서는 더 높은 LOD 허용 가능 (M 시리즈 GPU)

## Constraints

### 기술적
- RealityKit USDZ 로드: 비동기, 첫 로드 시 약간의 지연
- BlendShape/Morph Target: RealityKit 지원 확인 필요 (iOS 17+)
- 폴리곤 예산: iPhone에서 30K tri 이하 권장
- USDZ 파일 크기: 앱 번들 증가 (예상 2-5MB)

### 라이선스
- Z-Anatomy/BodyParts3D: CC BY-SA 2.1 Japan
  - Attribution 필수 (앱 내 크레딧)
  - ShareAlike: 수정된 모델을 재배포 시 동일 라이선스
  - 앱 번들에 포함 시 "재배포"로 해석될 수 있음 → 법적 검토 권장
- 대안: MakeHuman 기반 자체 제작 (CC0 출력) → 라이선스 완전 자유

### 리소스
- 3D 아티스트 작업 필요 (Blender 최적화, 그루핑, UV)
- 또는 Blender Python 스크립트 자동화 + 수동 QA

## Edge Cases

- 모델 로드 실패 시 → 현재 SVG 압출 방식으로 fallback
- 저사양 기기 → LOD (Level of Detail) 2단계 (high/low poly)
- 메모리 압박 → MeshCache eviction 정책
- 새 MuscleGroup 추가 시 → USDZ 에셋 재생성 필요

## Scope

### MVP (Must-have)
- [ ] Z-Anatomy 또는 MakeHuman 기반 14개 근육군 USDZ 에셋
- [ ] RealityKit Entity 기반 로드/렌더링 (iOS)
- [ ] 근육군별 색상 동적 변경 (volume/recovery 모드)
- [ ] 기존 제스처(pan/pinch/tap) 유지
- [ ] 선택 시 하이라이트 효과

### Nice-to-have (Future)
- [ ] BlendShape로 볼륨에 따른 근육 팽창/수축 애니메이션
- [ ] 피부(스킨) 투명도 슬라이더
- [ ] visionOS 동일 모델 공유
- [ ] 해부학 레이어 토글 (근육 → 뼈)
- [ ] LOD 자동 전환 (거리/기기별)
- [ ] watchOS 최적화 버전 (극단적 low-poly)

## Open Questions

1. **라이선스**: CC BY-SA로 앱 번들에 포함 시 ShareAlike 조건 적용 범위? → 법적 검토 또는 CC0인 MakeHuman 경로 선택
2. **에셋 제작**: 직접 Blender 작업 vs 외주? 자동화 스크립트로 얼마나 커버 가능?
3. **BlendShape**: RealityKit에서 morph target 지원 수준? 볼륨 애니메이션 MVP에 포함?
4. **성능 예산**: 정확한 triangle 수 기준? iPhone 15 기준 vs iPhone 12 기준?
5. **기존 SVG 모드 유지**: fallback으로 유지? 완전 교체?

## 참고 리소스

- [Z-Anatomy](https://www.3dart.it/en/free-3d-anatomy/) - 오픈소스 3D 해부학 아틀라스 (Blender)
- [BodyParts3D](https://dbarchive.biosciencedbc.jp/en/bodyparts3d/download.html) - 1,523개 해부학 파트 OBJ
- [MakeHuman](https://static.makehumancommunity.org/makehuman.html) - 오픈소스 인체 모델링 (CC0 출력)
- [SMPL](https://smpl.is.tue.mpg.de/) - 파라메트릭 인체 모델 (학술)
- [BioDigital Human iOS SDK](https://github.com/biodigital-inc/human-ios-sdk) - 상용 해부학 SDK
- [Blender→RealityKit](https://github.com/radcli14/blender-to-realitykit) - 파이프라인 예제
- [RealityKit Documentation](https://developer.apple.com/documentation/realitykit) - Apple 공식
- [SceneKit→RealityKit Migration](https://developer.apple.com/videos/play/wwdc2025/288/) - WWDC25

## Next Steps

- [ ] 라이선스 결정: Z-Anatomy(CC BY-SA) vs MakeHuman(CC0) 중 택 1
- [ ] Z-Anatomy .blend 다운로드 후 근육 구조 탐색
- [ ] Blender 자동화 스크립트 프로토타입 (근육 그루핑 + decimation)
- [ ] USDZ 테스트 익스포트 → RealityKit 로드 검증
- [ ] `/plan` 으로 구현 계획 생성
