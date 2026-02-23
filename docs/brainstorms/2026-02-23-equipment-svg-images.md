---
tags: [equipment, svg, illustration, exercise-picker, ui-improvement]
date: 2026-02-23
category: brainstorm
status: draft
---

# Brainstorm: Exercise Detail 기구 이미지 SVG 전환

## Problem Statement

현재 `EquipmentIllustrationView.swift` (814줄)에서 SwiftUI Canvas로 23종 기구를 수동 드로잉하고 있음.
- 56px 사이즈에서 세부 표현 한계
- 실제 기구 형태와 차이가 큼
- 새 기구 추가 시 드로잉 코드 작성 필요
- 유지보수 부담 (814줄 Canvas 코드)

**목표**: 외부 오픈소스 SVG를 활용하여 기구 일러스트를 일러스트 스타일 (2-3색, 벡터)로 교체

## Target Users

- 운동 초보자: 기구를 모르는 사용자가 이미지로 식별
- 경험자: 운동 선택 시 빠른 시각적 구분
- 전체 사용자: ExerciseDetailSheet에서 기구 정보 확인 시 직관적 이해

## Success Criteria

1. 23종 Equipment 모두 SVG 이미지로 교체
2. ExerciseDetailSheet (info 화면) + ExercisePickerView (필터 칩) 적용
3. 기존 Canvas 코드 대비 시각적 품질 향상
4. 라이선스 문제 없음 (CC0 또는 attribution-free)
5. 앱 번들 사이즈 영향 최소화

## 현재 구현 분석

### 영향 받는 파일

| 파일 | 역할 | 변경 내용 |
|------|------|----------|
| `EquipmentIllustrationView.swift` | Canvas 드로잉 (814줄) | SVG Image로 교체 또는 삭제 |
| `ExerciseDetailSheet.swift` | 기구 정보 섹션 | 이미지 사이즈 확대, 레이아웃 조정 |
| `ExercisePickerView.swift` | 기구 필터 칩 | 칩 아이콘을 SVG로 교체 |
| `Equipment+View.swift` | iconName (SF Symbol) | SVG asset 이름 매핑 추가 |
| `Assets.xcassets` | 이미지 에셋 | SVG 파일 23개 추가 |

### Equipment 전체 목록 (23종)

| 카테고리 | Equipment | 현재 iconName (SF Symbol) |
|----------|-----------|--------------------------|
| Free Weights | barbell | `dumbbell.fill` |
| | dumbbell | `dumbbell.fill` |
| | kettlebell | `dumbbell.fill` |
| | ezBar | `dumbbell.fill` |
| | trapBar | `dumbbell.fill` |
| Machines | smithMachine | `gearshape.fill` |
| | legPressMachine | `gearshape.fill` |
| | hackSquatMachine | `gearshape.fill` |
| | chestPressMachine | `gearshape.fill` |
| | shoulderPressMachine | `gearshape.fill` |
| | latPulldownMachine | `gearshape.fill` |
| | legExtensionMachine | `gearshape.fill` |
| | legCurlMachine | `gearshape.fill` |
| | pecDeckMachine | `gearshape.fill` |
| | cableMachine | `cable.connector` |
| Generic | machine | `gearshape.fill` |
| | cable | `cable.connector` |
| Bodyweight | bodyweight | `figure.stand` |
| | pullUpBar | `figure.strengthtraining.traditional` |
| | dipStation | `figure.strengthtraining.functional` |
| Small Equipment | band | `circle.dashed` |
| | trx | `line.diagonal` |
| | medicineBall | `circle.fill` |
| | stabilityBall | `circle.fill` |
| Other | other | `questionmark.circle` |

## SVG 소스 조사 결과

### 소스별 평가

| 소스 | 라이선스 | Attribution | 상업 사용 | 커버리지 | 일관성 | 추천 |
|------|---------|-------------|----------|---------|--------|------|
| **SVGRepo** | CC0/MIT | No | Yes | 12-15/23 | Low | 개별 선별 |
| **Flaticon Premium** | Premium | No | Yes | 18-22/23 | High | 예산 있으면 |
| **Flaticon Free** | Free | **YES** | 조건부 | 18-22/23 | High | Attribution 필요 |
| **IconPacks.net** | Free | No | Yes | 10-14/23 | High | 보충용 |
| **SF Symbols** | Apple | No | Yes (Apple) | 3-4/23 | Highest | 부분 활용 |
| **Noun Project** | CC BY/Sub | Yes(Free) | Yes | 15-20/23 | Low | 개별 선별 |
| **Figma Community** | Varies | Usually | Usually | 8-15/23 | High/pack | 조사 필요 |

### 기구별 가용성 매트릭스

| Equipment | SF Symbols | SVGRepo | Flaticon | 자체 제작 필요 |
|-----------|-----------|---------|----------|--------------|
| barbell | △ (dumbbell) | O | O | X |
| dumbbell | O | O | O | X |
| kettlebell | X | O | O | X |
| ezBar | X | △ | △ | **가능성 높음** |
| trapBar | X | X | X | **필요** |
| smithMachine | X | △ | O | X |
| legPressMachine | X | △ | O | X |
| hackSquatMachine | X | X | △ | **가능성 높음** |
| chestPressMachine | X | △ | O | X |
| shoulderPressMachine | X | △ | O | X |
| latPulldownMachine | X | △ | O | X |
| legExtensionMachine | X | △ | O | X |
| legCurlMachine | X | △ | O | X |
| pecDeckMachine | X | X | △ | **가능성 높음** |
| cableMachine | X | △ | O | X |
| machine (generic) | X | O | O | X |
| cable (generic) | X | △ | O | X |
| bodyweight | O (figure.*) | O | O | X |
| pullUpBar | X | O | O | X |
| dipStation | X | △ | △ | **가능성 높음** |
| band | X | O | O | X |
| trx | X | X | X | **필요** |
| medicineBall | X | O | O | X |
| stabilityBall | X | O | O | X |

**자체 제작 필요**: trapBar, trx (2개 확정)
**가용성 불확실**: ezBar, hackSquatMachine, pecDeckMachine, dipStation (4개)

## Proposed Approach

### 전략: Hybrid (SF Symbols + CC0 SVG + 자체 제작)

1. **SF Symbols 활용** (2-3개): dumbbell, bodyweight figure
2. **CC0 SVG 소싱** (15-18개): SVGRepo + IconPacks.net에서 일관된 스타일로 선별
3. **자체 SVG 제작** (2-6개): trapBar, trx 및 소싱 불가 기구

### 기술 구현: Asset Catalog SVG

- SVG 파일을 `Assets.xcassets`에 추가
- "Preserve Vector Data" = **ON** (다양한 사이즈에서 사용)
- `.renderingMode(.template)` 적용 → `foregroundStyle()` 지원
- 기존 `EquipmentIllustrationView` → `Image("equipment.{name}")` 교체

```swift
// 현재
EquipmentIllustrationView(equipment: .barbell, size: 56)

// 변경 후
Image("equipment.barbell")
    .resizable()
    .renderingMode(.template)
    .frame(width: 56, height: 56)
    .foregroundStyle(DS.Color.activity)
```

### 파일 구조

```
Assets.xcassets/
  Equipment/
    equipment.barbell.imageset/
      barbell.svg
      Contents.json
    equipment.dumbbell.imageset/
      dumbbell.svg
      Contents.json
    ... (23개)
```

## Constraints

### 기술적 제약
- iOS 26+ 타겟이므로 SVG in Asset Catalog 완전 지원
- `.renderingMode(.template)` 사용 시 다색 일러스트는 단색으로 렌더링됨
  → **2-3색 일러스트를 원하면 `.renderingMode(.original)` 사용 필요**
- Xcode Asset Catalog은 SVG viewBox 기반으로 intrinsic size 결정

### 라이선스 제약
- CC0/MIT만 사용 (attribution 불필요 소스 우선)
- Flaticon Free는 attribution 필요 → Premium 아니면 사용 지양
- 소싱한 SVG의 원본 라이선스를 `docs/licenses/` 에 기록

### 디자인 제약
- 23종 모두 **동일한 스타일** 유지 필수 (혼합 스타일은 비전문적)
- 현재 앱은 `DS.Color.activity` 단색 톤 → template mode 호환성
- ExercisePickerView 필터 칩은 작은 사이즈 (20-24pt) → 과도한 디테일 불가

## Edge Cases

1. **SVG 렌더링 실패**: Asset Catalog은 빌드 타임에 래스터화하므로 런타임 실패 없음
2. **새 Equipment 추가 시**: SVG 파일 추가 + Asset Catalog 등록 + Equipment+View.swift 매핑
3. **Dark Mode**: `.renderingMode(.template)` 사용 시 자동 대응. `.original`이면 별도 dark variant 필요
4. **접근성**: `Image` + `accessibilityLabel` 설정 필수
5. **다색 일러스트 + Dark Mode 충돌**: original mode에서 밝은 배경 전제 색상이 dark mode에서 안 보일 수 있음

## Scope

### MVP (Must-have)
- [ ] 23종 SVG 파일 소싱/제작
- [ ] Asset Catalog에 SVG 등록
- [ ] ExerciseDetailSheet 기구 섹션 이미지 교체 (56→80pt 확대 고려)
- [ ] ExercisePickerView 기구 필터 칩 아이콘 교체
- [ ] Equipment+View.swift에 `svgAssetName` 프로퍼티 추가
- [ ] 기존 EquipmentIllustrationView.swift 제거
- [ ] 라이선스 문서화

### Nice-to-have (Future)
- [ ] Custom SF Symbols로 전환 (3-weight template)
- [ ] 기구 사용법 애니메이션 (Lottie 등)
- [ ] 기구별 관련 운동 추천 화면
- [ ] 기구 3D 모델 뷰 (SceneKit/RealityKit)

## 렌더링 모드 결정

| 모드 | 장점 | 단점 | 적합 |
|------|------|------|------|
| `.template` (단색) | Dark Mode 자동, DS.Color 통일 | 색상 디테일 손실 | 현재 앱 톤 유지 |
| `.original` (다색) | 풍부한 시각 표현 | Dark Mode 별도 대응, 스타일 불일치 위험 | 디테일 중시 |

**권장**: `.template` 모드로 시작 → 단색 벡터 일러스트로 통일
- 이유: 현재 앱이 `DS.Color.activity` 단색 톤, Dark Mode 자동 대응, SF Symbols와 일관성

## Decisions (2026-02-23)

1. **렌더링 모드**: `.renderingMode(.template)` 단색 — Dark Mode 자동, DS.Color.activity 통일
2. **스타일 소싱 불가 시**: 전체 자체 제작은 future work. 현재는 CC0 소스에서 가능한 만큼 확보
3. **이미지 사이즈**: ExerciseDetailSheet에서 56pt → **80-100pt로 확대**
4. **기존 Canvas 코드**: SVG 전환 완료 후 삭제

## Next Steps

- [ ] `/plan equipment-svg` 으로 구현 계획 생성
- [ ] SVG 소싱 PoC: SVGRepo에서 5종 (barbell, dumbbell, kettlebell, cable, band) 다운로드 후 Asset Catalog 테스트
- [ ] 스타일 일관성 검증: 다운로드한 SVG 5종이 앱 디자인과 조화되는지 확인
