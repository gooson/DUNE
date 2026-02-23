---
tags: [equipment, svg, illustration, ui]
date: 2026-02-23
category: plan
status: draft
---

# Plan: Equipment SVG 이미지 전환

## Summary

23종 기구의 Canvas 드로잉을 SVG 이미지 에셋으로 교체.
단색 template 렌더링, ExerciseDetailSheet (80pt) + ExercisePickerView 필터 칩 적용.

## Decisions (from Brainstorm)

- **렌더링**: `.renderingMode(.template)` 단색
- **사이즈**: ExerciseDetailSheet 56pt → 80pt 확대
- **소싱**: CC0 SVG 또는 자체 제작 (future work에서 외부 소스 교체 가능)
- **범위**: 전체 23종 한번에

## Affected Files

| File | Action | Description |
|------|--------|-------------|
| `Resources/Assets.xcassets/Equipment/` | **CREATE** | 23개 SVG imageset 폴더 |
| `Equipment+View.swift` | **MODIFY** | `svgAssetName` 프로퍼티 추가 |
| `ExerciseDetailSheet.swift` | **MODIFY** | EquipmentIllustrationView → Image, 80pt |
| `ExercisePickerView.swift` | **MODIFY** | 기구 필터 칩에 SVG 아이콘 추가 |
| `EquipmentIllustrationView.swift` | **DELETE** | 814줄 Canvas 코드 제거 |

## Implementation Steps

### Step 1: SVG 에셋 생성 + Asset Catalog 등록

23종 기구별 SVG 파일 생성 (단색 벡터, viewBox="0 0 64 64"):

```
Resources/Assets.xcassets/Equipment/
  Contents.json                          ← namespace group
  equipment.barbell.imageset/
    barbell.svg
    Contents.json                        ← preserves-vector-representation: true
  equipment.dumbbell.imageset/
    dumbbell.svg
    Contents.json
  ... (23개)
```

각 SVG는:
- viewBox="0 0 64 64"
- 단색 fill="#000000" (template mode에서 tint 적용)
- 스트로크 기반 일러스트 스타일
- 기구의 핵심 형태를 명확하게 표현

Contents.json 템플릿:
```json
{
  "images": [{ "filename": "{name}.svg", "idiom": "universal" }],
  "info": { "author": "xcode", "version": 1 },
  "properties": { "preserves-vector-representation": true }
}
```

### Step 2: Equipment+View.swift에 svgAssetName 추가

```swift
var svgAssetName: String {
    switch self {
    case .barbell: "equipment.barbell"
    case .dumbbell: "equipment.dumbbell"
    // ... 23종
    }
}
```

### Step 3: ExerciseDetailSheet 수정

```swift
// Before (line 162):
EquipmentIllustrationView(equipment: exercise.equipment, size: 56)
    .background(...)

// After:
Image(exercise.equipment.svgAssetName)
    .resizable()
    .renderingMode(.template)
    .aspectRatio(contentMode: .fit)
    .frame(width: 80, height: 80)
    .foregroundStyle(DS.Color.activity)
    .padding(DS.Spacing.sm)
    .background(DS.Color.activity.opacity(0.06), in: RoundedRectangle(cornerRadius: DS.Radius.sm))
```

### Step 4: ExercisePickerView 필터 칩 수정

```swift
// Before (equipmentChip): 텍스트만
Text(equipment.localizedDisplayName)

// After: 아이콘 + 텍스트
HStack(spacing: DS.Spacing.xxs) {
    Image(equipment.svgAssetName)
        .resizable()
        .renderingMode(.template)
        .aspectRatio(contentMode: .fit)
        .frame(width: 14, height: 14)
    Text(equipment.localizedDisplayName)
}
```

### Step 5: EquipmentIllustrationView.swift 삭제

- 814줄 Canvas 코드 완전 제거
- 참조하는 곳이 ExerciseDetailSheet 1곳뿐 (Step 3에서 교체 완료)

### Step 6: 빌드 검증

```bash
scripts/build-ios.sh
```

## Equipment SVG 목록 (23종)

| Equipment | Asset Name | SVG 설명 |
|-----------|-----------|----------|
| barbell | equipment.barbell | 긴 봉 + 양쪽 원판 |
| dumbbell | equipment.dumbbell | 짧은 봉 + 양쪽 원판 |
| kettlebell | equipment.kettlebell | 구형 + 상단 핸들 |
| ezBar | equipment.ez-bar | W자 커브 봉 + 원판 |
| trapBar | equipment.trap-bar | 육각 프레임 + 손잡이 |
| smithMachine | equipment.smith-machine | 수직 레일 + 바벨 |
| legPressMachine | equipment.leg-press | 경사 좌석 + 발판 |
| hackSquatMachine | equipment.hack-squat | 경사 등판 + 숄더패드 |
| chestPressMachine | equipment.chest-press | 좌석 + 전방 암 |
| shoulderPressMachine | equipment.shoulder-press | 좌석 + 상방 암 |
| latPulldownMachine | equipment.lat-pulldown | 상단 도르래 + 바 |
| legExtensionMachine | equipment.leg-extension | 좌석 + 전방 패드 |
| legCurlMachine | equipment.leg-curl | 좌석 + 후방 패드 |
| pecDeckMachine | equipment.pec-deck | 좌석 + 양쪽 암 |
| cableMachine | equipment.cable-machine | 프레임 + 도르래 + 케이블 |
| machine | equipment.machine | 범용 머신 실루엣 |
| cable | equipment.cable | 도르래 + 케이블 + 핸들 |
| bodyweight | equipment.bodyweight | 사람 실루엣 |
| pullUpBar | equipment.pull-up-bar | 수평 바 + 지지대 |
| dipStation | equipment.dip-station | 양쪽 평행바 |
| band | equipment.band | 루프형 탄성밴드 |
| trx | equipment.trx | 앵커 + 두 줄 + 핸들 |
| medicineBall | equipment.medicine-ball | 무거운 공 + 그립 라인 |
| stabilityBall | equipment.stability-ball | 큰 둥근 공 |
| other | equipment.other | 물음표 또는 범용 아이콘 |

## Risk & Mitigation

| Risk | Impact | Mitigation |
|------|--------|-----------|
| SVG가 template mode에서 깨짐 | 높음 | fill="#000" 단색, 스트로크 없이 fill path만 사용 |
| 80pt에서 디테일 부족 | 중간 | preserves-vector-representation으로 선명도 보장 |
| 기존 Canvas 삭제 후 빌드 실패 | 낮음 | Grep으로 참조 확인 완료 (1곳) |
