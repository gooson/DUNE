---
tags: [theme, design-system, hanok, korean, minimalism, redesign, wave-background, signature]
date: 2026-03-07
category: brainstorm
status: draft
---

# Brainstorm: 한옥 테마 전면 재설계 — 모던 한국 미니멀

## Problem Statement

현재 한옥 테마는 한국 전통 건축을 **너무 직접적으로** 재현하려다 실패했다:
- 경회루 실루엣, 와당 막새, 산 배경 등 figurative 요소가 **관광 엽서** 수준
- jade/slate 색상이 **탁하고 칙칙**하여 건강 앱에 부적합
- 한지 텍스처가 **노이즈**로 보임
- 처마 곡선 wave가 다른 테마와 **차별화 부족**
- 전체적으로 "한국 전통"을 과시하려다 **키치**해짐

목표: 한옥 테마를 앱의 **시그니처 테마**로 격상 — 스크린샷에 넣으면 앱 아이덴티티가 되는 수준.

## Target Users

- 미니멀하고 세련된 UI를 원하는 사용자
- 한국적 감성을 **은근하게** 느끼고 싶은 사용자
- 기본 테마(Desert Warm)보다 더 개성 있는 테마를 원하는 사용자
- 앱 스크린샷/공유 시 "이 앱 뭐야?" 반응을 끌어낼 사용자

## Success Criteria

1. 한국적 요소가 **추상적으로** 녹아들어 "일본풍"이나 "중국풍"과 명확히 구분됨
2. 다른 7개 테마 중 **가장 세련된** 테마라는 평가
3. Light/Dark 모드 모두에서 **깨끗하고 고급스러운** 색감
4. wave 형태가 다른 테마와 **즉시 구분** 가능
5. figurative 요소 **0개** — 실루엣, 아이콘, 패턴 없음

---

## 디자인 컨셉: "여백의 미 (餘白)"

### 핵심 철학 전환

| 기존 (건축 재현) | 신규 (미학 추상화) |
|------------------|-------------------|
| 경회루 실루엣 | **없음** — 여백으로 대체 |
| 와당 막새 장식 | **없음** — 비움이 장식 |
| 산 배경 | **없음** — 그라데이션이 공간감 |
| 한지 텍스처 | **수묵 번짐** — 먹이 물에 퍼지는 농담 |
| 처마 곡선 wave | **달항아리 곡선** — 비대칭 유기적 곡선 |
| 기와 ripple | **없음** — 깨끗한 곡선 |
| jade/slate 색상 | **백자/청자/먹** — 맑고 깊은 톤 |

### 한국 미학 키워드 → UI 매핑

| 미학 개념 | 의미 | UI 적용 |
|-----------|------|---------|
| **여백 (餘白)** | 빈 공간이 곧 아름다움 | 장식 요소 최소화, 깨끗한 배경 |
| **달항아리** | 완벽하지 않은 유기적 곡선 | wave shape의 비대칭 곡률 |
| **백자 유백색** | 순백이 아닌 따뜻한 흰색 | 기본 배경 톤 |
| **수묵 농담** | 먹의 농/담 대비 | 그라데이션, 레이어 투명도 |
| **청자 비색** | 맑고 깊은 옥빛 | accent/score 색상 |
| **옹기 흙빛** | 따뜻한 대지의 색 | warm accent, metric 색상 |

---

## 새 색상 팔레트

### 방향: "깨끗하고 깊은" (Clean & Deep)

기존 jade/slate의 문제: 중간 채도가 탁하게 느껴짐.
해법: **극단의 대비** — 매우 밝거나 매우 어두운 톤 + 하나의 맑은 accent.

### Core Layer Colors

```
Deep  — 먹색 (墨色)
        Light: #1A1A2E  (깊은 남먹)
        Dark:  #0F0F1A  (야먹)
        → 수묵화의 가장 진한 먹

Mid   — 옅은 먹 (淡墨)
        Light: #4A4A5A  (회먹)
        Dark:  #3A3A4E  (어두운 회먹)
        → 먹을 물에 탄 중간 농담

Mist  — 백자 유백 (乳白)
        Light: #F7F3EE  (따뜻한 백)
        Dark:  #2A2A36  (야경 백자)
        → 백자의 따뜻한 흰색, 순백이 아님
```

### Accent & Typography

```
Accent — 청자 비색 (翡色)
         Light: #5BA4A4  (맑은 청록)
         Dark:  #7BC4C0  (밝은 비취)
         → 고려청자의 맑은 옥빛. jade가 아닌 celadon.
         → 기존 jade(탁함) vs 비색(맑음)의 차이가 핵심

Bronze — 옹기 갈색 (甕器)
         Light: #5C4A3A  (어두운 황토)
         Dark:  #D4C4B0  (밝은 황토)
         → 옹기의 따뜻한 흙빛

Sand   — 한지 아이보리 (韓紙)
         Light: #F5EFE6  (한지의 따뜻한 톤)
         Dark:  #C8C0B4  (달빛 아래 한지)
         → 백자보다 약간 더 따뜻한 off-white

Dusk   — 저녁 남색 (暮色)
         Light: #3A4A6A  (해질녘 하늘)
         Dark:  #5A6A8A  (달빛 남색)
         → 수묵화 배경의 깊은 파랑
```

### Score Colors — "먹의 농담에서 옹기의 온기로"

| 등급 | 컨셉 | Light | Dark |
|------|------|-------|------|
| Excellent | 청자의 빛 | #2E9E8E | #4CC4B4 |
| Good | 옹기의 온기 | #C4945A | #DEB87A |
| Fair | 먹의 중간 농담 | #7A8A7A | #9AAA98 |
| Tired | 옅은 먹 | #8A8A9A | #7A7A8C |
| Warning | 고요한 남색 | #5A5A7A | #6A6A88 |

### Metric Colors — "자연 소재 팔레트"

| Metric | 소재 영감 | Light | Dark |
|--------|-----------|-------|------|
| HRV | 비취 (翡翠) | #4A9A8E | #6CC0B4 |
| RHR | 주사 (朱砂) | #C4645A | #E8847A |
| Heart Rate | 진사 (辰砂) | #D45A5A | #F07A7A |
| Sleep | 야먹 (夜墨) | #4A5A7A | #6A7A9A |
| Activity | 황토 (黃土) | #C49A4A | #E0BA6A |
| Steps | 죽녹 (竹綠) | #5A9A6A | #7ABA8A |
| Body | 회석 (灰石) | #8A8A7A | #AAA898 |

---

## 새 Wave 형태: "달항아리 곡선"

### 기존 vs 신규

```
기존 HanokEaveShape:
  - 처마 곡선 (sine + 2nd harmonic uplift)
  - 기와 ripple (고주파 노이즈)
  - 점토 edge variation
  → 복잡하지만 다른 테마 wave와 구분 안 됨

신규 DalhangariWaveShape:
  - 달항아리의 비대칭 유기적 곡선
  - uplift 없음 → 부드럽고 자연스러운 흐름
  - ripple 없음 → 깨끗한 선
  - 대신: 좌우 비대칭 + 불규칙 진폭
  → "완벽하지 않은 아름다움" = 한국 미학의 핵심
```

### 수학적 모델

```
달항아리 곡선의 특성:
1. 기본: sine wave (다른 테마와 동일 기반)
2. 비대칭: sin(x) * (1 + 0.3 * sin(x/3))
   → 좌반부와 우반부의 amplitude가 다름
3. 유기적 변형: 부드러운 3차 harmonic
   → sin(x) + 0.15 * sin(3x + φ)
4. 느린 호흡: phase 변화를 매우 느리게 (30초+)
   → 고요한 움직임

핵심 차별화:
- Desert = 물결 (regular sine)
- Ocean = 파도 (steep, breaking)
- Forest = 나뭇잎 (layered, dense)
- Sakura = 꽃잎 (flutter, light)
- Arctic = 오로라 (wide, smooth)
- Solar = 불꽃 (energetic, sharp)
- Hanok = 달항아리 (asymmetric, organic, slow)
```

### 레이어 구성

```
Tab Background — 3 layers:
  1. Far (깊은 먹): 매우 넓고 느린 곡선, opacity 0.06-0.10
     → 수묵화의 원경 산수
  2. Mid (중간 먹): 달항아리 곡선, opacity 0.15-0.25
     → 핵심 시그니처 곡선
  3. Near (진한 먹): 약간 좁은 곡선, opacity 0.35-0.50
     → 전경의 깊이감

  특수 효과:
  - 수묵 번짐 (ink bleed): 곡선 경계에 blur + gradient
    → 먹이 한지에 스며드는 느낌
  - Crest highlight: 백자 유백색 미세한 빛
    → 달항아리 위의 빛 반사

Detail Background — 2 layers, opacity 60%
Sheet Background — 1 layer, opacity 40%
```

### 삭제할 요소들

| 요소 | 이유 |
|------|------|
| `HanokPavilionSilhouetteShape` | figurative, 키치 |
| `HanokMountainBackdropShape` | figurative, 관광 엽서 |
| `HanokRoofTileSealShape` | 장식 과잉 |
| `HanokRoofSealOverlay` | 장식 과잉 |
| `HanokPavilionLandscapeOverlay` | figurative |
| `HanjiTextureView` (procedural) | 노이즈로 보임 |
| tile ripple params | 불필요한 복잡성 |
| uplift params | eave 컨셉 폐기 |

### 대체/신규 요소

| 요소 | 역할 |
|------|------|
| `DalhangariWaveShape` | 비대칭 유기적 곡선 (신규 Shape) |
| **수묵 번짐 효과** | wave crest에 blur+gradient로 먹 번짐 재현 |
| **여백** | 장식 자리에 아무것도 넣지 않음 |

---

## Gradient

```
heroText:      먹색 → 비색    (깊이에서 맑음으로)
detailScore:   먹색 → 옅은먹  (단색 농담)
sectionAccent: 비색 → 남색    (자연스러운 톤 전환)
cardBackground: 유백 → 투명   (여백으로 사라짐)
```

---

## Tab별 Intensity

| Tab | Scale | 컨셉 |
|-----|-------|------|
| Train | 1.2 | 활동적인 붓놀림 |
| Today | 1.0 | 기본 수묵 |
| Wellness | 0.8 | 고요한 여백 |
| Life | 0.6 | 먼 산수 |

---

## 다른 테마와의 차별화 전략

| 테마 | 정체성 | 한옥과의 차이 |
|------|--------|-------------|
| Desert Warm | 사막의 따뜻함, 부드러운 곡선 | 한옥은 **비대칭** + **먹색 톤** |
| Ocean Cool | 파도의 역동성, 푸른 톤 | 한옥은 **고요함** + **유기적 곡선** |
| Forest Green | 숲의 겹겹이, 초록 톤 | 한옥은 **여백** + **비움** |
| Sakura Calm | 벚꽃의 가벼움, 분홍 톤 | 한옥은 **깊이감** + **먹색** |
| Arctic Dawn | 오로라의 넓음, 차가운 톤 | 한옥은 **따뜻한 백** + **비취 accent** |
| Solar Pop | 태양의 에너지, 뜨거운 톤 | 한옥은 **절제** + **미니멀** |
| Shanks Red | 강렬한 빨강 | 한옥은 **수묵의 농담** |

---

## Constraints

### 기술적
- `HanokEaveShape` → `DalhangariWaveShape`로 교체 (새 Shape)
- 6개 overlay/decorative shape 삭제 → 코드 대폭 간소화
- Color asset 27개 → 전체 재정의 (hex값 변경)
- `AppTheme+View.swift` hanok 색상 매핑 업데이트
- Wave 파라미터 전체 재조정

### 성능
- 오히려 개선: 장식 요소 6개 삭제 → GPU 부담 감소
- 수묵 번짐: blur radius 제한 (3px 이하)
- wave layer 3개 유지 (기존과 동일)

### 디자인
- Dark mode에서 먹색 배경과 앱 배경의 구분 필요
- 비색(celadon) accent가 너무 약하면 건강 데이터 가독성 저하
- Score 5단계 색상 구분 명확성 검증 필요

---

## Edge Cases

- **Dark Mode**: 먹색 deep(#0F0F1A)이 시스템 배경과 너무 유사할 수 있음 → Mist dark를 약간 밝게 조정
- **Accessibility**: 수묵 톤이 저시력 사용자에게 대비 부족할 수 있음 → score 색상에 최소 4.5:1 대비 보장
- **Weather 전환**: 먹색 → 날씨 색상 전환이 자연스러운지 검증
- **iPad**: 넓은 화면에서 달항아리 곡선 비대칭이 어색할 수 있음

---

## Scope

### MVP (Must-have)
- [ ] `DalhangariWaveShape` 신규 Shape 구현 (비대칭 유기적 곡선)
- [ ] 기존 장식 요소 6개 삭제 (Pavilion, Mountain, Seal, Hanji texture 등)
- [ ] Color asset 27개 전체 재정의 (먹/백자/비색 팔레트)
- [ ] `HanokTabWaveBackground` → 달항아리 곡선 + 수묵 번짐 효과
- [ ] `HanokDetailWaveBackground` → 2-layer 간소화
- [ ] `HanokSheetWaveBackground` → 1-layer 최소화
- [ ] `AppTheme+View.swift` 색상 매핑 업데이트
- [ ] Light/Dark 모드 양쪽 검증
- [ ] ThemePickerSection preview 색상 업데이트

### Nice-to-have (Future)
- [ ] 수묵 번짐 효과 고도화 (CIFilter 기반)
- [ ] 계절별 서브테마 (봄=매화, 가을=단풍 → 비색 accent 변조)
- [ ] 달항아리 곡선 기반 전용 앱 아이콘
- [ ] Watch 전용 최적화 (작은 화면에서의 비대칭 곡선 조정)

---

## Open Questions

1. **달항아리 비대칭 정도**: 미묘한 비대칭 vs 뚜렷한 비대칭? → 프로토타입 후 결정
2. **수묵 번짐 구현**: blur만으로 충분? vs 커스텀 gradient mask 필요?
3. **테마 이름 유지?**: "Hanok"을 유지할지, "Ink (수묵)" 또는 "Baekja (백자)" 등으로 변경?
4. **비색 accent 톤**: celadon은 녹색 vs 청록 스펙트럼이 넓음 — 정확한 hue 결정 필요

---

## 참고: 모던 한국 미니멀 레퍼런스

### 디자인 키워드
- 이우환 (Lee Ufan) — 여백과 점/선의 관계
- 윤광조 — 현대 달항아리 재해석
- 아모레퍼시픽 본사 — 한국적 미니멀 건축
- 설화수 패키지 — 모던 한국 럭셔리 색감

### 색감 레퍼런스
- 고려청자 비색: #5BA4A4 계열 (green-teal, 맑고 깊음)
- 조선백자 유백: #F7F3EE (warm ivory, not pure white)
- 먹의 5묘: 농/중/담/청/윤 → gradient 단계

---

## Next Steps

- [ ] `/plan hanok-theme-redesign` 으로 구현 계획 생성
- [ ] DalhangariWaveShape 프로토타입 (수학 모델 검증)
- [ ] 색상 팔레트 시안을 시뮬레이터에서 Light/Dark 검증
- [ ] 기존 HanokWaveBackground.swift에서 삭제할 코드 범위 확인
