---
tags: [design-system, hanok, theme, dancheong, jade, animation]
date: 2026-03-05
category: brainstorm
status: draft
---

# Brainstorm: 한옥 테마 고도화 (단청 리뉴얼)

## Problem Statement

현재 한옥 테마가 황토/갈색 earth-tone 위주로 구성되어 한옥의 핵심 시각 정체성인 **단청(丹靑)** 색감과 **옥색(翡色)** 을 반영하지 못함. 배경 Wave Shape(기와 곡선)은 이미 구현되어 있으나, 색상 팔레트와 애니메이션 정밀도가 부족.

## Target Users

- 한국 전통 미학을 선호하는 사용자
- 기존 earth-tone 팔레트가 밋밋하다고 느끼는 사용자

## Success Criteria

1. 옥색(celadon jade)이 테마의 primary identity로 인식됨
2. 단청 오방색이 Score/Metric 컬러에 자연스럽게 녹아듦
3. 기와 배경 Wave의 바람 흔들림이 체감됨
4. Light/Dark 모드 모두에서 가독성과 분위기 유지

## Current State Analysis

### 현재 색상 팔레트 (earth-tone)

| Token | Light | Dark | 비고 |
|-------|-------|------|------|
| HanokAccent | `#d3a474` (황토) | `#e0b482` | Primary accent |
| HanokBronze | `#3b3b3b` (암회) | `#b8afa3` | Hero text gradient start |
| HanokDusk | `#8a6913` (암황) | `#6b5a33` | Ring bottom, gradient end |
| HanokDeep | `#494133` (암갈) | `#332c22` | Wave back layer |
| HanokMid | `#8a6913` (암황) | `#6b5a33` | Wave mid layer |
| HanokMist | `#dfd6c5` (연크림) | `#9e9587` | Wave front layer |
| HanokSand | `#f5efe8` (백아) | `#beb7aa` | Decorative text |

### 현재 Score 색상

| Score | Light | Dark | 비고 |
|-------|-------|------|------|
| Excellent | `#c65b39` | `#da6c4d` | 적갈색 |
| Good | `#d3975a` | `#e0a86b` | 황갈색 |
| Fair | `#6b8a5e` | `#7d9f6f` | 녹색 |
| Tired | `#7a8a9a` | `#8e9ead` | 회청색 |
| Warning | `#495468` | `#5d687a` | 암청색 |

### 현재 배경 구현

- `HanokEaveShape`: sine + 2nd harmonic(추녀 uplift) + tile ripple(기와 골)
- 3레이어 parallax: Far(25s) / Mid(20s) / Near(16s)
- `HanjiTextureView`: pre-rendered 한지 섬유 텍스처
- 애니메이션: linear drift (일정 속도 흐름)

## Proposed Approach

### 1. 색상 팔레트: 단청 오방색 기반 리뉴얼

단청(丹靑)의 오방색을 현대적으로 재해석:

```
오방색 원래 의미:
  적(赤) — 주홍/진사, 남쪽, 화(火)
  청(靑) — 남색/군청, 동쪽, 목(木)
  황(黃) — 석간주/황토, 중앙, 토(土)
  백(白) — 호분/분청, 서쪽, 금(金)
  흑(黑) — 먹/암록, 북쪽, 수(水)

  간색(間色): 옥색(翡色), 벽색(碧色), 자색(紫色) 등
```

#### Primary 팔레트 제안

| Token | Light 제안 | Dark 제안 | 근거 |
|-------|-----------|----------|------|
| HanokAccent | `#5B9E8F` (옥색) | `#7FBFB5` (연옥) | 청자 비색, 테마 identity |
| HanokBronze | `#3A3A3A` (유지) | `#C8D5D0` (옥백) | Hero text, 옥색 톤 조화 |
| HanokDusk | `#2B5279` (남색) | `#3D6B8A` (연남) | 단청 청색 계열 |
| HanokDeep | `#1E3A3A` (암청록) | `#152B2B` (심암록) | 기와 어두운 면 |
| HanokMid | `#3A7D6E` (청록) | `#2D6058` (암청록) | 기와 중간톤 |
| HanokMist | `#B8D8CF` (옥백) | `#6B9E91` (연옥) | 한지+옥색 블렌드 |
| HanokSand | `#E8F0EC` (옥분) | `#A8BFB7` (연옥회) | 배경 여백 |

#### 새로운 단청 포인트 컬러 (추가)

| Token | Light | Dark | 용도 |
|-------|-------|------|------|
| HanokCinnabar | `#C83F23` (주홍) | `#E05A3F` | 단청 적색 — accent highlight |
| HanokIndigo | `#2B5279` (남색) | `#4A7BA3` | 단청 청색 — secondary |

> **Note**: `HanokCinnabar`는 Wave 배경에는 사용하지 않고, Glass border shimmer나 crest highlight에 극소량 사용하여 단청의 적색 포인트를 살림.

#### Score 컬러 리뉴얼 (단청 오방색 매핑)

| Score | Light 제안 | Dark 제안 | 단청 매핑 |
|-------|-----------|----------|----------|
| Excellent | `#C83F23` (주홍) | `#E05A3F` | 적(赤) — 가장 강렬, 최상 |
| Good | `#5B9E8F` (옥색) | `#7FBFB5` | 옥(翡) — 균형, 조화 |
| Fair | `#D4A843` (황색) | `#E0B85A` | 황(黃) — 중간, 주의 |
| Tired | `#2B5279` (남색) | `#4A7BA3` | 청(靑) — 침체, 안정 필요 |
| Warning | `#3A3A3A` (묵색) | `#5A5A5A` | 흑(黑) — 경고, 심각 |

#### Metric 컬러 (옥색 기반 조화)

기존 Metric 색상을 옥색 기조에 맞춰 채도/톤 조정. 각 Metric의 식별성은 유지하되 전체적으로 단청 팔레트와 어울리도록 보정.

### 2. 배경 Wave 개선: 바람 흔들림

현재 `linear` drift를 **비대칭 sway**로 교체:

```
현재: phase → phaseTarget (일정 속도 회전)
개선: phase drift + amplitude 미세 변조 (breath)

구체적 방안:
A) HanokEaveShape에 `sway` 파라미터 추가
   - amplitude가 시간에 따라 미세하게 ±10% 변동
   - 각 레이어별 sway 주기를 다르게 (parallax 강화)

B) 기와 crest highlight에 옥색 shimmer 추가
   - 빛이 기와 위를 스치는 느낌
   - 현재 crestColor를 HanokMist → 옥색으로 변경
```

#### 레이어별 바람 표현

| Layer | 현재 drift | 개선 제안 |
|-------|-----------|----------|
| Far (25s) | linear | 미풍 — 가장 느린 sway, amplitude ±5% |
| Mid (20s) | linear | 산들바람 — 중간 sway, amplitude ±8% |
| Near (16s) | linear | 처마 바람 — 가장 큰 sway, amplitude ±12% |

### 3. 애니메이션 세부

**바람 sway 구현 방안:**
- `HanokWaveOverlayView`에 `@State private var breathPhase: CGFloat = 0` 추가
- `breathPhase`를 별도 duration (7~12초)으로 sinusoidal 반복
- `amplitude * (1 + breathIntensity * sin(breathPhase))` 로 실시간 변조
- `reduceMotion` 시 breathPhase 고정 (drift만 유지)

**처마 끝 단청 shimmer:**
- Near 레이어의 crest stroke에 옥색 → 주홍 subtle gradient
- 단청의 "처마 끝 문양" 느낌을 crest highlight로 표현
- 주홍은 crest 전체가 아닌, gradient의 5-10% 포인트로만 사용

## Constraints

- **Asset catalog 규칙**: `Colors/` 하위, `provides-namespace: true`
- **light/dark 동일이면 universal만**: 색상별 확인 필요
- **Dark mode gradient opacity >= 0.06**: visibility 보장
- **기존 3레이어 구조 유지**: Tab/Detail/Sheet 패턴 변경 없음
- **HanokEaveShape path 성능**: `path(in:)` 내 무거운 연산 금지
- **`reduceMotion` 존중**: breath/sway 동적 요소는 접근성 off 가능

## Scope

### MVP (Must-have)

1. **Primary 팔레트 교체**: HanokAccent/Dusk/Deep/Mid/Mist/Sand → 옥색 기반
2. **Score 컬러 교체**: 단청 오방색 매핑
3. **Metric 컬러 조정**: 옥색 기조 harmonization
4. **Wave 레이어 색상 적용**: Deep/Mid/Mist 색상을 새 팔레트로
5. **Crest highlight 색상 교체**: 옥색 shimmer
6. **바람 sway 애니메이션**: breath amplitude 변조
7. **Glass border / SectionGroup 색상 업데이트**: 옥색 기조

### Nice-to-have (Future)

- 단청 문양 패턴 오버레이 (처마 끝 기하학 패턴)
- 계절별 색감 미세 변화 (봄: 연옥, 여름: 진옥, 가을: 황옥, 겨울: 백옥)
- 한지 텍스처 색조를 옥백색으로 tinting
- Wave 레이어 간 미세한 반투명 "안개" 레이어

## Affected Files (예상)

| 파일 | 변경 내용 |
|------|----------|
| `Shared/Resources/Colors.xcassets/Hanok*.colorset` (27개) | 모든 색상값 교체 |
| `HanokWaveBackground.swift` | crest 색상, sway 파라미터 |
| `HanokEaveShape.swift` | sway/breath 지원 (선택) |
| `GlassCard.swift` | hanok case 색상 참조 확인 |
| `SectionGroup.swift` | hanok case 색상 참조 확인 |
| `ProgressRingView.swift` | hanokAccent06 색상 확인 |

## Open Questions

1. ~~배경 디자인 요소~~ → 기와 지붕 곡선 확정
2. ~~애니메이션 종류~~ → 바람 흔들림 확정
3. ~~옥색 방향~~ → 단청 조합 확정
4. ~~변경 범위~~ → 전체 테마 리뉴얼 확정
5. 주홍(cinnabar) 포인트 컬러의 사용 강도는? (shimmer만? 또는 버튼/아이콘에도?)
6. Tab별 Wave 색상 차별화 유지? (현재 tabTrain/tabWellness/tabLife별 색상 존재)

## Next Steps

- [ ] `/plan` 으로 구현 계획 생성 (파일별 변경 상세)
- [ ] 옥색 팔레트 hex값 확정 후 asset catalog 일괄 교체
- [ ] 바람 sway 프로토타입 → Preview에서 검증
