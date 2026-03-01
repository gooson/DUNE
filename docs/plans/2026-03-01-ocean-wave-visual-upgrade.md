---
tags: [ocean-cool, wave, animation, visual, theme]
date: 2026-03-01
category: plan
status: draft
---

# Plan: Ocean Cool Wave 파형 개선

## Summary

Ocean Cool 테마의 파도 배경을 일본 전통 파도 문양 스타일로 개선.
가변 높이, 흰색 포말, 호/동심원 물결 패턴 추가.

## Affected Files

| File | Action | Description |
|------|--------|-------------|
| `DUNE/.../OceanWaveShape.swift` | Modify | crestHeight/crestSharpness 파라미터 추가 |
| `DUNE/.../OceanWaveBackground.swift` | Modify | stroke + foam + arc 레이어 추가 |
| `DUNE/.../OceanArcPattern.swift` | Create | 호/동심원 물결 패턴 Shape |
| `DUNETests/OceanWaveShapeTests.swift` | Modify | 새 파라미터 테스트 |
| `DUNETests/OceanArcPatternTests.swift` | Create | arc 패턴 테스트 |

## Implementation Steps

### Step 1: OceanWaveShape에 가변 amplitude 추가

**파일**: `OceanWaveShape.swift`

새 파라미터:
- `crestHeight: CGFloat = 0` (0~0.4, 저주파 envelope)
- `crestSharpness: CGFloat = 0` (0~0.15, 고주파 날카로움)

공식 변경:
```
y = centerY + amp × [
    sin(θ + phase)
  + steepness × sin(2θ + phase + harmonicOffset)
  + crestHeight × sin(0.5θ + phase × 0.3)       // NEW: envelope
  + crestSharpness × sin(3θ + phase × 1.5)      // NEW: sharpness
]
```

OceanWaveOverlayView에도 해당 파라미터 전달.

### Step 2: 파도 꼭대기 흰색 stroke

**파일**: `OceanWaveShape.swift` (OceanWaveOverlayView 수정)

OceanWaveOverlayView에 옵션 추가:
- `strokeColor: Color? = nil`
- `strokeWidth: CGFloat = 1`

stroke가 있으면 .fill() 위에 .stroke() overlay 추가.
path를 fill + stroke 재활용 (stroke는 fill path에서 하단 close 제거).

별도 stroke-only Shape를 만들어 fill Shape 위에 overlay하는 방식이 깔끔:
- `OceanWaveStrokeShape`: OceanWaveShape와 동일한 path 계산, 하단 close 없이 line만.

### Step 3: Foam gradient Shape

**파일**: `OceanWaveShape.swift` (새 뷰 추가)

`OceanFoamOverlayView`:
- OceanWaveShape와 동일한 파라미터로 파도 꼭대기 y좌표 계산
- 꼭대기에서 아래로 얇은 영역 (rect 높이의 3%)에 흰색→투명 gradient
- Surface/Mid 레이어에 적용

### Step 4: OceanArcPattern Shape 생성

**파일**: `OceanArcPattern.swift` (신규)

동심 반원/호를 반복 배치하는 Shape:
- 파라미터: `arcCount`, `arcSpacing`, `baseRadius`, `phase`
- 호 배치: 화면 가로로 일정 간격으로 반복
- 각 위치에 크기가 다른 동심 호 3~4개
- 선 두께: 0.5~1pt
- Animatable: phase로 느린 수평 drift

### Step 5: OceanWaveBackground 3종 업데이트

**Tab** (OceanTabWaveBackground):
- Deep/Mid/Surface 레이어에 crestHeight/crestSharpness 적용
- Surface/Mid에 stroke overlay (OceanFoam, 0.4/0.2 opacity)
- Surface에 foam gradient overlay
- Arc 패턴 레이어 추가 (deep~mid 사이, mid~surface 사이)

**Detail** (OceanDetailWaveBackground):
- crestHeight 70%, crestSharpness 70%
- stroke만 (foam gradient 생략)
- Arc 패턴 간소화 (1레이어만)

**Sheet** (OceanSheetWaveBackground):
- crestHeight 50%, crestSharpness 50%
- stroke만 (얇게)
- Arc 패턴 없음

### Step 6: 테스트

- `OceanWaveShapeTests`: crestHeight/crestSharpness 테스트 추가
- `OceanArcPatternTests`: 기본 path 생성, bounds, 빈 rect 테스트
