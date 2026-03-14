---
tags: [3d, muscle-map, usdz, realitykit, visual-quality]
date: 2026-03-15
category: brainstorm
status: draft
---

# Brainstorm: 고퀄리티 3D 근육맵 구축

## Problem Statement

현재 3D 근육맵은 capsule/cylinder/sphere 프리미티브를 배치한 34KB USDZ로,
해부학적 형태가 전혀 없어 "근육맵"이라 볼 수 없는 수준.
교과서 수준(Level B)의 해부학적 정확도로 업그레이드 필요.

## 현재 상태

| 항목 | 현재 |
|------|------|
| 에셋 | `muscle_body.usdz` (34KB) |
| 생성 | `scripts/generate-muscle-usdz.py` (프리미티브) |
| 근육 그룹 | 13개 (MuscleGroup enum) |
| 메쉬 | capsule/sphere 조합 → 근육 형태 없음 |
| 체표 | body_shell (캡슐 13개 조합) |

## Target Users

- 근력 운동 사용자 (회복/볼륨 시각화)
- 앱스토어 스크린샷에 노출 → 비주얼 퀄리티가 전환율에 직접 영향

## Success Criteria

1. 개별 근육이 해부학적으로 식별 가능 (대흉근, 삼각근 등 형태 구분)
2. 기존 13개 그룹 이상으로 세분화 (예: 삼각근 전면/측면/후면)
3. iOS 실시간 렌더링 성능 유지 (60fps)
4. visionOS에서도 동일 에셋 사용 가능
5. 기존 MuscleMap3DScene 코드의 entity naming 호환 유지

## 에셋 소싱 옵션

### Option A: TurboSquid — Anatomy Male Muscular System ($199) ⭐ 추천

| 항목 | 값 |
|------|---|
| 가격 | $199 |
| 폴리곤 | 98,617 (TurboSmooth OFF) — iOS 최적 |
| 분리 메쉬 | 543 objects, 360+ 개별 근육 |
| 포맷 | MAX, FBX, OBJ, C4D, LWO, MA |
| 라이센스 | Royalty Free — 모바일 앱 임베딩 허용 |
| 장점 | 저폴리 기반이라 decimation 불필요, 의학 용어 네이밍 |

### Option B: CGTrader — Full Body Muscle Anatomy ($89)

| 항목 | 값 |
|------|---|
| 가격 | $89 |
| 폴리곤 | 1,200,066 |
| 분리 메쉬 | 136 parts |
| 포맷 | OBJ, FBX, C4D, STL |
| 라이센스 | Royalty Free |
| 장점 | 저렴, 충분한 분리 |
| 단점 | 1.2M poly → iOS용 decimation 필요 |

### Option C: Z-Anatomy (무료, CC BY-SA 4.0)

| 항목 | 값 |
|------|---|
| 가격 | 무료 |
| 분리 메쉬 | 5,000+ 해부학 구조 |
| 포맷 | Blender (.blend), OBJ |
| 라이센스 | CC BY-SA 4.0 — 상업적 사용 가능, 귀속+동일조건 필수 |
| 장점 | 무료, 최고 수준 세분화, BodyParts3D 기반 |
| 단점 | share-alike 조건 (앱 코드 공개 아님, 파생 에셋만 해당), Blender 후처리 필요 |

### Option D: CGTrader — Medical Edition ($999)

| 항목 | 값 |
|------|---|
| 가격 | $999 |
| 폴리곤 | ~433K |
| 분리 메쉬 | 600+ 개별 근육 (기시/정지점 포함) |
| 라이센스 | Royalty Free |
| 장점 | 의료급 정확도 |
| 단점 | 피트니스 앱에는 과도, 가격 높음 |

## 추천 전략

### 1차: Z-Anatomy (무료) 로 프로토타입 + 워크플로우 검증

- CC BY-SA 라이센스 확인 (USDZ 임베딩이 "파생 저작물"인지 법적 해석 필요)
- Blender → USDZ 파이프라인 확립
- 근육 그룹 매핑 테이블 작성
- 성능 프로파일링

### 2차: TurboSquid ($199) 로 프로덕션 에셋

- CC BY-SA 리스크 없는 Royalty Free
- 98K poly로 iOS 최적
- 360+ 개별 근육 → 세분화된 MuscleGroup enum 확장 가능

## 기술 파이프라인

```
구매/다운로드 (FBX/OBJ)
    ↓
Blender 가공
    ├─ 근육 그룹별 parent 정리 (muscle_chest, muscle_back 등)
    ├─ 세분화 그룹 추가 (muscle_shoulders_anterior 등)
    ├─ body_shell 메쉬 생성 (투명 피부)
    ├─ decimation (필요시)
    ├─ UV/material cleanup
    └─ USDZ export
    ↓
Xcode / Reality Composer Pro 검증
    ↓
기존 MuscleMap3DScene 코드 연동
    ├─ entity naming convention 매핑
    ├─ MuscleGroup enum 확장 (세분화)
    └─ collision shape 재생성
```

## 코드 변경 범위

### 변경 필요

| 파일 | 변경 내용 |
|------|----------|
| `muscle_body.usdz` | 고퀄리티 에셋으로 교체 |
| `generate-muscle-usdz.py` | 제거 또는 보관 (수동 에셋으로 대체) |
| `MuscleGroup.swift` | 세분화 case 추가 (optional) |
| `MuscleMap3DScene.swift` | entity name 매핑 업데이트, collision shape 조정 |
| `MuscleMap3DView.swift` | 세분화 UI (muscle strip 확장) |

### 변경 불필요 (호환 유지)

- `MuscleMap3DState` — entity naming convention 유지 시
- `MuscleMapDetailViewModel` — 데이터 레이어 동일
- Color/material 로직 — SimpleMaterial 그대로 적용
- visionOS `VisionMuscleMapExperienceView` — 같은 USDZ 로드

## 근육 세분화 제안

| 현재 (13) | 세분화 후 (25+) |
|-----------|----------------|
| chest | chest (대흉근 유지) |
| back | back_upper (승모근 중부), back_lower (척추기립근) |
| shoulders | shoulders_anterior, shoulders_lateral, shoulders_posterior |
| biceps | biceps (유지) |
| triceps | triceps_long, triceps_lateral |
| forearms | forearms_flexor, forearms_extensor |
| core | core_rectus, core_obliques, core_transverse |
| quadriceps | quadriceps_rectus, quadriceps_vastus |
| hamstrings | hamstrings (유지) |
| glutes | glutes_maximus, glutes_medius |
| calves | calves_gastrocnemius, calves_soleus |
| traps | traps_upper, traps_lower |
| lats | lats (유지) |

> 세분화는 에셋 확보 후 2차 작업. 1차는 기존 13그룹 호환으로 에셋만 교체.

## Constraints

- **Blender 작업 필요**: 사용자가 직접 못함 → 에이전트가 스크립트로 자동화하거나, 최소 가공으로 사용 가능한 에셋 선택
- **파일 크기**: 제한 없음 (다만 앱 번들 크기 영향 — 10MB 이하 권장)
- **성능**: iPhone 기준 60fps 유지 (100K poly 이하 권장, 200K 이하 허용)
- **visionOS**: 동일 에셋 — poly budget 여유 있음 (500K+ 가능)

## Edge Cases

- USDZ 로드 실패 → 기존 fallback (에러 로그 + 빈 씬)
- entity name 불일치 → Blender export 시 naming convention 강제
- decimation 후 UV 깨짐 → Blender decimate modifier 설정 주의
- visionOS에서 poly 수 다른 LOD → 향후 LOD 시스템 (TODO #100)

## Scope

### MVP (Must-have)

- [ ] 고퀄리티 USDZ 에셋 확보 (구매 또는 무료)
- [ ] Blender → USDZ 변환 파이프라인
- [ ] 기존 13 그룹 entity naming 호환
- [ ] body_shell 메쉬 포함
- [ ] iOS 성능 검증 (100K poly 이하)
- [ ] 기존 MuscleMap3DScene 코드 호환

### Nice-to-have (Future)

- [ ] 25+ 세분화 근육 그룹
- [ ] PBR 텍스처 (normal map, roughness map)
- [ ] LOD 자동 전환
- [ ] 여성 체형 에셋
- [ ] 애니메이션 (근육 수축/이완)

## Open Questions

1. Z-Anatomy CC BY-SA → USDZ 앱 번들 임베딩이 share-alike 파생물에 해당하는가?
2. Blender 자동화 스크립트로 가공 가능한 범위는? (entity rename, decimation, USDZ export)
3. 세분화 시 MuscleGroup enum 변경 → SwiftData migration 필요한가? (현재 rawValue 저장 방식 확인)
4. 남성/여성 체형 분리 필요성 (MVP 이후)

## Next Steps

- [ ] 에셋 선택 확정 (Z-Anatomy 프로토 vs TurboSquid 직행)
- [ ] Blender 자동화 스크립트 작성 (Python bpy)
- [ ] `/plan` 으로 구현 계획 생성
