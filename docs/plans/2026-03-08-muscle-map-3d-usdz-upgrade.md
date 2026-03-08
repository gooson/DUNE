---
tags: [muscle-map, 3d, usdz, realitykit, makehuman]
date: 2026-03-08
category: plan
status: approved
---

# USDZ 기반 3D 근육맵 업그레이드

## 목표

현재 SVG 경로 압출(extrusion) 방식의 의사-3D 근육맵을 MakeHuman(CC0) 기반 USDZ 메시로 완전 교체하여 해부학적 사실성을 확보한다.

## 의사결정 요약

| 항목 | 결정 |
|------|------|
| 3D 모델 소스 | MakeHuman (CC0 라이선스 — 확장성 우수) |
| 에셋 제작 | 직접 Blender 작업 (외주 없음) |
| SVG fallback | 없음 — 완전 교체 |
| 범위 (MVP) | iOS만. visionOS는 TODO #098 |

## 현재 아키텍처 (교체 대상)

```
MuscleMapData.swift (SVG 경로 데이터)
  → MuscleBodyPart (SVG parse → Path)
    → MuscleMap3DGeometry (Path → MeshResource extrusion)
      → MuscleMap3DMeshCache (캐싱)
        → MuscleMap3DScene (Entity 조립 + body shell primitives)
          → MuscleMap3DViewer (UIViewRepresentable + ARView)
            → MuscleMap3DView (SwiftUI 컨테이너)
```

**교체 범위**: MuscleMapData, MuscleBodyPart/MuscleBodyShape, MuscleMap3DGeometry, MuscleMap3DMeshCache, MuscleMap3DScene의 메시 생성/조립 로직
**보존 범위**: MuscleMap3DMode, MuscleMap3DVolumeIntensity, MuscleMap3DDisplayState, MuscleMap3DState(카메라 상수), 색상 해석 로직, MuscleMap3DViewer(제스처), MuscleMap3DView(UI)

## Affected Files

| 파일 | 변경 유형 | 설명 |
|------|----------|------|
| `DUNE/Presentation/Shared/Components/MuscleMap3DScene.swift` | **대규모 수정** | SVG extrusion → USDZ Entity 로드, body shell 제거 |
| `DUNE/Presentation/Shared/Components/MuscleMapData.swift` | **삭제 가능** | SVG 경로 데이터 — USDZ로 대체. 단, 2D 맵에서 아직 참조하면 유지 |
| `DUNE/Presentation/Shared/Components/MuscleBodyShape.swift` | **유지** | 2D SVG 맵(ExerciseMuscleMapView, InjuryBodyMapView 등)에서 사용 |
| `DUNE/Presentation/Activity/MuscleMap/MuscleMap3DView.swift` | **소규모 수정** | makeUIView에서 USDZ 로딩 연동 |
| `DUNE/Resources/Assets.xcassets/` 또는 번들 | **추가** | USDZ 에셋 파일 |
| `DUNE/project.yml` | **수정** | USDZ 리소스 포함 |

### MuscleMapData.swift 참조 확인

2D SVG 맵에서 사용 여부:
- `ExerciseMuscleMapView.swift` → `svgFrontParts`, `svgBackParts` 사용
- `InjuryBodyMapView.swift` → SVG 데이터 사용
- `MuscleRecoveryMapView.swift` → SVG 데이터 사용
- `MuscleMapDetailView.swift` → SVG 데이터 사용

**결론**: MuscleMapData.swift는 2D 뷰에서 여전히 사용되므로 **삭제하지 않고 유지**. 3D 씬에서만 참조를 끊는다.

## Implementation Steps

### Step 1: USDZ 에셋 준비

MakeHuman에서 인체 메시를 생성하고 Blender에서 13개 근육군별로 분리 + USDZ 익스포트.

**에셋 요구사항**:
- 파일: `muscle_body.usdz` (단일 파일, 내부 Entity 계층)
- Entity 네이밍: `muscle_{rawValue}` (예: `muscle_chest`, `muscle_back`, ...)
- 13개 MuscleGroup case 각각에 대응하는 mesh entity
- body shell → USDZ에 포함된 전체 몸 외곽 메시 (기존 primitive 대체)
- 폴리곤 예산: 전체 ~50K 이하 (모바일 최적화)
- 머티리얼: 기본 white/gray (런타임에서 동적 색상 적용)

**Blender 워크플로우**:
1. MakeHuman에서 기본 인체 모델 생성 (근육 표현 레벨 조정)
2. Blender로 import
3. 근육군별 메시 분리 (13 groups)
4. 각 메시를 `muscle_{rawValue}` 명명
5. 전체 body outline 메시 추가 (shell 역할)
6. Decimate modifier로 폴리곤 최적화
7. USDZ 익스포트 (Blender USDZ exporter)

**Verification**: `muscle_body.usdz` 파일이 번들에 포함되고, 13개 근육군 Entity가 이름으로 검색 가능

### Step 2: MuscleMap3DScene 리팩터링 — USDZ 로딩

기존 SVG extrusion 로직을 USDZ Entity 로딩으로 교체.

**변경 내용**:
1. `MuscleMap3DGeometry` enum 제거 (SVG→좌표 변환 불필요)
2. `MuscleMap3DMeshCache` 제거 (USDZ Entity가 자체 메시 포함)
3. `prepareIfNeeded()` → USDZ 파일 로드 + Entity 계층 구축
4. `installBodyShell()` → USDZ 내 shell entity 사용 (primitive 조립 제거)
5. `makeModelEntity()` → Entity.findEntity(named:) + clone()

**새 로딩 패턴**:
```swift
// USDZ 로드 (비동기, 한 번만)
let bodyEntity = try await Entity(named: "muscle_body", in: nil)

// 근육군별 entity 검색
for muscle in MuscleGroup.allCases {
    if let entity = bodyEntity.findEntity(named: "muscle_\(muscle.rawValue)") {
        // clone + material 설정 + muscleRoots[muscle]에 추가
    }
}
```

**보존할 로직**:
- `MuscleMap3DMode`, `MuscleMap3DVolumeIntensity`, `MuscleMap3DDisplayState` 그대로 유지
- `MuscleMap3DState` (카메라 거리, yaw, pitch, 확대 범위) 유지 — 값만 USDZ 스케일에 맞게 조정
- `muscleRoots: [MuscleGroup: Entity]` 딕셔너리 패턴 유지
- `updateColors()` 로직 유지 (SimpleMaterial 색상 변경)
- `focusMuscle()`, `handleTap()` 유지

**Verification**: 앱 실행 시 3D 근육맵이 USDZ 메시로 렌더링되고, 기존 제스처(회전/확대/탭)가 동작

### Step 3: 색상 시스템 적용 (SimpleMaterial → USDZ Entity)

기존 색상 해석 로직을 USDZ entity의 ModelComponent material에 적용.

**변경 내용**:
1. `updateColors()` 내 `ModelEntity` 접근 방식 변경
   - 기존: `entity.model?.materials = [material]`
   - 신규: Entity 계층에서 `ModelEntity` 검색 → material 교체
2. USDZ entity는 중첩 Entity 구조일 수 있으므로 재귀적 ModelEntity 검색 필요
3. `SimpleMaterial` 사용 유지 (baseColor.tint + roughness)

**유틸리티 함수**:
```swift
private func applyMaterial(_ material: SimpleMaterial, to entity: Entity) {
    if var model = entity as? ModelEntity {
        model.model?.materials = [material]
    }
    for child in entity.children {
        applyMaterial(material, to: child)
    }
}
```

**Verification**: recovery 모드에서 근육별 HSB 그라데이션 색상 적용, volume 모드에서 intensity 기반 색상 적용

### Step 4: 리소스 통합 및 프로젝트 설정

USDZ 파일을 프로젝트에 통합하고 빌드 파이프라인 설정.

**변경 내용**:
1. USDZ 파일을 `DUNE/Resources/` 또는 `DUNE/Presentation/Shared/Resources/` 에 배치
2. `project.yml`에 리소스 경로 추가 (xcodegen이 번들에 포함하도록)
3. MuscleMapData.swift에서 3D 관련 참조 정리 (2D 전용으로 범위 축소)
4. 기존 `MuscleMap3DGeometry.descriptors` 참조 정리

**Verification**: `scripts/build-ios.sh` 성공, USDZ가 앱 번들에 포함

### Step 5: 정리 및 dead code 제거

교체로 불필요해진 코드 제거.

**제거 대상**:
- `MuscleMap3DGeometry` enum (SVG→3D 좌표 변환)
- `MuscleMap3DMeshCache` class (extrusion 캐시)
- `MuscleMap3DScene.installBodyShell()` 내 primitive 조립 코드
- `MuscleMap3DScene.makeModelEntity()` 내 SVG extrusion 로직

**유지 대상**:
- `MuscleMapData.swift` — 2D 뷰에서 사용
- `MuscleBodyShape.swift` — 2D 뷰에서 사용
- `SVGPathParser` — 2D 뷰에서 사용

**Verification**: 빌드 성공 + 2D 근육맵(ExerciseMuscleMapView, InjuryBodyMapView 등) 정상 동작 유지

## 테스트 전략

| 테스트 | 유형 | 검증 항목 |
|--------|------|----------|
| USDZ 로딩 | Unit | Entity 로드 성공 + 13개 근육 entity 검색 |
| 색상 적용 | Unit | recovery/volume 모드별 색상 변환 정확성 |
| 기존 테스트 보존 | Regression | `MuscleMapDetailViewModelTests` 통과 |
| 2D 맵 무영향 | Regression | ExerciseMuscleMapView, InjuryBodyMapView 정상 렌더 |

## 리스크 & 엣지 케이스

| 리스크 | 대응 |
|--------|------|
| MakeHuman 근육 분리 품질 | Blender에서 수동 조정 + 리토폴로지 |
| USDZ 파일 크기 | Decimate modifier로 50K poly 이하 유지, ~2-5MB 목표 |
| Entity.findEntity 실패 | 로드 시 13개 모두 검증 + 누락 시 로그 경고 |
| USDZ 내 material 구조 | 로드 후 모든 material을 SimpleMaterial로 교체 |
| 기존 카메라 상수 불일치 | USDZ 모델 스케일에 맞춰 MuscleMap3DState 값 조정 |
| 앱 런치 시 로딩 지연 | Entity 캐싱 (static let shared 패턴 또는 prepareIfNeeded 유지) |

## 참고 문서

- `docs/brainstorms/2026-03-08-muscle-map-3d-upgrade.md`
- `docs/solutions/architecture/2026-03-07-svg-extruded-muscle-map-shared-scene.md`
- `docs/solutions/architecture/2026-03-07-muscle-map-real-3d-procedural-rig.md`
