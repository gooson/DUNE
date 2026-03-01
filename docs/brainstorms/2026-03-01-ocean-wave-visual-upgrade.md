---
tags: [ocean-cool, wave, animation, visual, theme]
date: 2026-03-01
category: brainstorm
status: draft
---

# Brainstorm: Ocean Cool Wave 파형 개선

## Problem Statement

현재 Ocean Cool 테마의 파도 배경이 단순한 sine + 2차 하모닉 조합으로, 참조 이미지(일본화풍 높은 파도 + 흰색 포말 + 동심원 물결)와 비교하면 시각적 깊이감과 역동성이 부족하다.

**핵심 문제**:
1. 모든 파도가 비슷한 높이 → 높이 솟아오르는 파도 없음
2. 흰색 포말이 거의 보이지 않음 (opacity 0.06, amplitude 0.008)
3. 파도 사이 물결/호 패턴이 없음 → 밋밋한 느낌

**참조 이미지 특성**:
- 파도가 높이 솟아올라 곡선을 그리며 앞으로 쏟아짐
- 파도 꼭대기와 사이에 뚜렷한 흰색 포말/윤곽
- 파도 사이 동심원/호 형태의 흰색 물결 패턴 (일본 전통 파도 문양)
- 여러 레이어의 파도가 겹치며 깊이감 표현

## Target Users

- 앱 사용자 중 Ocean Cool 테마 선택자
- 시각적 미학을 중시하는 사용자

## Success Criteria

1. **높이감**: 파도의 일부 구간이 다른 구간보다 눈에 띄게 높음
2. **흰색 표현**: 파도 윤곽과 꼭대기에 뚜렷한 흰색이 보임
3. **물결 패턴**: 파도 사이에 호/원호 형태의 패턴이 시각적으로 인식됨
4. **성능**: 120fps 유지, body 리렌더 시 path 계산 O(1)
5. **일관성**: Tab/Detail/Sheet 전체에 스케일만 다르게 적용

## Proposed Approach

### A. 가변 Amplitude (OceanWaveShape 개선)

현재 공식:
```
y = centerY + amplitude × [sin(θ + phase) + steepness × sin(2θ + phase + offset)]
```

개선 공식 (3차/4차 하모닉 추가):
```
y = centerY + amplitude × [
    sin(θ + phase)                                    // 기본
  + steepness × sin(2θ + phase + offset)              // 비대칭 (기존)
  + crestHeight × sin(0.5θ + phase × 0.3)            // 저주파 envelope → 일부 파도 높게
  + crestSharpness × sin(3θ + phase × 1.5)           // 고주파 → 파도 꼭대기 날카로움
]
```

**새 파라미터**:
- `crestHeight`: 0.0~0.4 (저주파 envelope 강도)
- `crestSharpness`: 0.0~0.15 (고주파 날카로움)

**장점**: 기존 120-point 구조 유지, 추가 sin 연산 2회뿐

### B. 흰색 포말 표현 (2가지 동시 적용)

#### B-1. 파도 꼭대기 흰색 스트로크

각 OceanWaveOverlayView에 `.stroke()` 오버레이:
- 색상: OceanFoam (거의 흰색)
- 두께: 1.5~2pt (surface), 1pt (mid), 0.5pt (deep)
- Opacity: 0.4 (surface) → 0.15 (deep)

#### B-2. Foam Gradient Shape

파도 꼭대기에서 아래로 흰색→투명 gradient를 가진 얇은 Shape:
- 기존 파형의 y좌표를 공유하되 높이를 제한 (rect 높이의 2~3%)
- LinearGradient: OceanFoam(opacity 0.5) → clear
- Surface/Mid 레이어에만 적용

### C. 동심원/호 물결 패턴

**별도 Shape**: `OceanArcPattern`
- 파도 사이 공간에 반원/호를 반복 배치
- 호 크기: 작은 것부터 큰 것까지 3~4단계
- 색상: OceanFoam, opacity 0.08~0.15
- 애니메이션: 천천히 scale 또는 opacity 펄스 (선택적)
- 위치: 파도 레이어 사이 (deep~mid 사이, mid~surface 사이)

**구현 방식**:
- Path에 `addArc(center:radius:startAngle:endAngle:)` 반복
- 호 중심은 파도 valley 위치에서 파생
- 정적 패턴 (phase 연동 불필요) 또는 느린 drift

### D. 적용 범위 스케일링

| 배경 유형 | 높이감 | 포말 | 호 패턴 | 스케일 |
|-----------|--------|------|---------|--------|
| Tab | 100% | 전체 | 전체 | 1.0 |
| Detail | 70% | stroke만 | 간소화 | 0.7 |
| Sheet | 50% | stroke만 | 없음 | 0.5 |

## Constraints

### 기술적
- **성능**: Shape.path(in:) 내 무거운 연산 금지 (rules: performance-patterns)
- **120 sample points**: 기존 pre-computation 구조 유지
- **Animatable**: phase만 animate, 나머지는 static
- **Accessibility**: reduceMotion 시 모든 애니메이션 비활성

### 구현 복잡도
- OceanWaveShape에 파라미터 2개 추가 (crestHeight, crestSharpness)
- Stroke 오버레이는 기존 overlay 패턴 활용
- ArcPattern은 신규 Shape → 테스트 필수

## Edge Cases

1. **Dynamic Type / 작은 화면**: 파도가 콘텐츠를 가리지 않도록 maxHeight 제한
2. **iPad 큰 화면**: amplitude가 과도하게 커지지 않도록 포인트 단위 상한
3. **다크 모드**: OceanFoam이 배경과 충분한 대비 유지 (현재 다크 모드 값 확인 필요)
4. **reduceMotion**: 정적 상태에서도 시각적으로 의미 있는 파형

## Scope

### MVP (Must-have)
- [x] OceanWaveShape에 가변 amplitude (crestHeight/crestSharpness 파라미터)
- [x] 파도 꼭대기 흰색 stroke 오버레이
- [x] Foam gradient Shape
- [x] Tab/Detail/Sheet 전체 적용
- [x] OceanWaveShapeTests 업데이트

### Nice-to-have (Future)
- [ ] 동심원/호 물결 패턴 (별도 Shape)
- [ ] 호 패턴 느린 pulse 애니메이션
- [ ] Tab preset별 패턴 밀도 차별화

**수정**: 사용자가 풀 구현 요청 → 호 패턴도 MVP에 포함

### MVP (Revised)
- OceanWaveShape에 가변 amplitude (crestHeight/crestSharpness 파라미터)
- 파도 꼭대기 흰색 stroke 오버레이
- Foam gradient Shape
- 동심원/호 물결 패턴 Shape
- Tab/Detail/Sheet 전체 적용
- 테스트 업데이트

## Open Questions

1. 호 패턴의 밀도와 크기 — 실제 렌더링 후 튜닝 필요
2. crestHeight/crestSharpness 최적값 — 실제 디바이스에서 확인 필요
3. Detail/Sheet에서 호 패턴을 얼마나 간소화할지

## Next Steps

- `/plan ocean-wave-visual-upgrade` 으로 구현 계획 생성
- 파일 영향 범위: OceanWaveShape, OceanWaveBackground, OceanWaveOverlayView + 신규 ArcPattern
