---
tags: [muscle-map, 3d, realitykit, procedural-rig, interaction, hit-testing, focus-orbit]
category: architecture
date: 2026-03-07
severity: important
related_files:
  - DUNE/Presentation/Activity/MuscleMap/MuscleMap3DView.swift
  - DUNE/Presentation/Activity/MuscleMap/MuscleMapDetailView.swift
  - DUNETests/MuscleMapDetailViewModelTests.swift
related_solutions:
  - architecture/2026-02-27-muscle-map-detail-view-integration.md
  - architecture/2026-02-27-muscle-map-volume-mode-integration.md
---

# Solution: Muscle Map 3D를 pseudo-3D에서 RealityKit 실제 3D로 전환

## Problem

### Symptoms

- 기존 `MuscleMap3DView`는 front/back SVG를 `rotation3DEffect`로 돌리는 수준이라 실제 입체 구조를 전달하지 못함
- 사용자는 전후면 전환만 볼 수 있고, 줌/회전/실제 3D 탭 탐색이 불가
- 고숙련자 기준으로 근육 위치 이해도와 브랜드 차별화가 부족

### Root Cause

실제 3D 바디/근육 자산 파이프라인이 없는 상태에서, 화면 요구사항만 먼저 대응하려고 2D SVG를 회전시키는 placeholder 구현이 남아 있었다.

## Solution

### Approach: `RealityKit + ARView(.nonAR)` procedural rig

외부 USDZ 제작 없이도 이번 턴에서 실제 3D를 만들기 위해, `RealityKit` primitive mesh를 조합한 procedural body rig로 전환했다. 근육 강조/색상 상태 계산은 Swift 레벨의 순수 함수로 두고, 렌더링/gesture는 `UIViewRepresentable` 내부 `ARView` coordinator가 담당한다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Activity/MuscleMap/MuscleMap3DView.swift` | pseudo-3D SVG 회전 뷰를 RealityKit 기반 실제 3D 뷰로 전면 교체 | 실제 회전/줌/탭/선택 지원 |
| `DUNE/Presentation/Activity/MuscleMap/MuscleMap3DView.swift` | `MuscleMap3DState`, `MuscleMap3DScene`, `MuscleMap3DViewer` 추가 | 상태 계산과 렌더링 책임 분리 |
| `DUNE/Presentation/Activity/MuscleMap/MuscleMap3DView.swift` | shell collision 제거 + 선택 근육 auto-focus yaw 추가 | 3D 탭 hit-test 정확도와 뒤쪽 근육 가시성 보강 |
| `DUNETests/MuscleMapDetailViewModelTests.swift` | `MuscleMap3DState` 테스트 추가 | 기본 선택, display state, zoom clamp, yaw, rig coverage 회귀 방지 |

### Key Code

```swift
private func installBodyShell() {
    let shellRoot = Entity()

    for (index, part) in shellParts.enumerated() {
        let entity = ModelEntity(mesh: part.mesh, materials: [])
        entity.name = "shell-\(index)"
        entity.position = part.position
        entity.orientation = quaternion(fromDegrees: part.rotation)
        shellRoot.addChild(entity)
        shellModels.append(entity)
    }

    bodyRoot.addChild(shellRoot)
}

static func preferredYaw(for muscle: MuscleGroup) -> Float {
    switch muscle {
    case .back, .lats, .traps, .glutes, .hamstrings, .calves:
        .pi + 0.12
    case .triceps:
        .pi - 0.28
    default:
        defaultYaw
    }
}
```

`body shell`은 시각적 컨텍스트만 제공하고 interaction 대상이 아니므로 collision을 제거했다. 그렇지 않으면 shell이 근육 메시보다 먼저 hit-test에 걸려 3D 탭 선택이 불안정해진다. 또한 뒤쪽 근육 선택 시 rear-facing yaw로 자동 회전시켜, 선택 스트립과 실제 3D 모델의 의미가 일치하도록 했다.

## Prevention

### Checklist Addition

- [ ] RealityKit hit-test 대상이 아닌 장식 mesh에는 collision을 만들지 않는다
- [ ] 3D 모델 선택 UI를 추가하면, 선택된 파트가 실제로 보이는 카메라 방향까지 같이 검토한다
- [ ] 실제 3D 상호작용 로직은 순수 상태 계산(`MuscleMap3DState`)과 렌더링 coordinator로 나눠 테스트 가능하게 둔다

### Rule Addition (if applicable)

이번 변경만으로 새 rule 추가까지는 필요하지 않다. 다만 향후 3D UI 도입이 늘어나면 `.claude/rules/`에 "decorative mesh no collision" 규칙을 별도 문서로 분리할 가치가 있다.

## Lessons Learned

1. 외부 3D 자산이 없더라도 `RealityKit` primitive 조합만으로 pseudo-3D를 실제 3D 인터랙션으로 빠르게 대체할 수 있다.
2. 3D UI에서 시각 mesh와 interaction mesh를 분리하지 않으면 탭 정확도가 바로 무너진다.
3. 전후면 정보가 모두 중요했던 기존 2D 근육 맵을 3D로 바꿀 때는, 단순 회전 지원만으로는 부족하고 선택 시점의 auto-focus가 이해도를 크게 좌우한다.
