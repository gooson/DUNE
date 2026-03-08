---
tags: [muscle-map, 3d, usdz, realitykit, migration]
date: 2026-03-08
category: solution
status: implemented
---

# USDZ 기반 3D 근육맵 마이그레이션

## Problem

기존 SVG 경로 압출(extrusion) 방식의 3D 근육맵은:
- `MeshResource(extruding:)` → 2D 실루엣의 의사-3D에 불과
- SVG 파싱 → 좌표 변환 → 메시 생성 파이프라인이 복잡 (4개 타입 체인)
- 해부학적 사실성 부족

## Solution

USDZ 메시 기반으로 완전 교체:

### 아키텍처 변경

```
Before:
MuscleMapData (SVG paths)
  → MuscleBodyPart (SVG parse)
    → MuscleMap3DGeometry (Path → MeshResource extrusion)
      → MuscleMap3DMeshCache (캐싱)
        → MuscleMap3DScene (Entity 조립)

After:
muscle_body.usdz (번들 에셋)
  → MuscleMap3DScene.loadUSDZEntity()
    → Entity.findEntity(named:) + clone
      → MuscleMap3DScene (Entity 조립)
```

### 핵심 패턴

**USDZ Entity 로딩**:
```swift
private func loadUSDZEntity() -> Entity? {
    guard let url = Bundle.main.url(forResource: "muscle_body", withExtension: "usdz") else {
        return nil
    }
    return try? Entity.load(contentsOf: url)
}
```

**Entity 네이밍 규약**: `muscle_{MuscleGroup.rawValue}` (예: `muscle_chest`, `muscle_back`)

**ModelEntity 수집 (BFS)**:
```swift
private func collectModelEntities(from root: Entity) -> [ModelEntity] {
    var models: [ModelEntity] = []
    var queue: [Entity] = [root]
    while !queue.isEmpty {
        let entity = queue.removeFirst()
        if let model = entity as? ModelEntity {
            models.append(model)
        }
        queue.append(contentsOf: entity.children)
    }
    return models
}
```

**hasPreparedGeometry 가드**: load 성공 후에만 `true` 설정. 실패 시 재시도 가능.

### 보존된 로직

- `MuscleMap3DMode`, `MuscleMap3DVolumeIntensity`, `MuscleMap3DDisplayState` 열거형
- `MuscleMap3DState` 카메라 상수 (yaw, pitch, zoom 범위)
- `SimpleMaterial` 기반 동적 색상 시스템
- `InputTargetComponent` + `generateCollisionShapes` 탭 감지
- Entity 계층 탐색 기반 muscle 식별 (`muscle(for:)`)

### 제거된 타입

- `MuscleMap3DPartDescriptor` — SVG 파트 기술자
- `MuscleMap3DGeometry` — SVG→MeshResource 변환
- `MuscleMap3DMeshCache` — 압출 메시 캐시

## Prevention

- USDZ entity 이름은 `MuscleGroup.rawValue`와 1:1 매핑 유지
- 새 근육군 추가 시 USDZ 에셋에도 해당 entity 필수
- `hasPreparedGeometry` flag는 성공 경로에서만 설정 (실패 시 false 유지)
- ModelEntity 수집은 재귀 대신 반복(BFS) 사용 — stack overflow 방지

## USDZ 에셋 생성

`scripts/generate-muscle-usdz.py` — USD Python (pxr) 기반 프로그래매틱 생성:
- 13개 근육군 + body_shell을 capsule/cylinder/sphere primitives로 구성
- 출력: `DUNE/Resources/Models/muscle_body.usdz` (34KB)
- 향후 MakeHuman/Blender 기반 고품질 에셋으로 교체 가능 (동일 entity 네이밍 유지)
