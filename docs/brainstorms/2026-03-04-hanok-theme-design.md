---
tags: [theme, design-system, hanok, korean, culture, wave-background, health]
date: 2026-03-04
category: brainstorm
status: draft
---

# Brainstorm: 한옥 (Hanok) 테마 + 기존 테마 보완

## Problem Statement

DUNE 앱은 현재 6개 테마를 제공하지만:
1. **Arctic Dawn**과 **Solar Pop**은 탭 배경만 있고 Detail/Sheet 배경이 미구현
2. 문화/지역 기반 테마가 없어 차별화된 미학적 경험이 부족
3. 헬스/피트니스 앱으로서 테마가 건강 컨셉과 약하게 연결됨

한옥 테마를 통해 한국 전통 건축의 아름다움을 헬스 메트릭과 강하게 연결하고,
기존 미완성 테마(Arctic/Solar)의 Detail/Sheet 배경을 보완한다.

## Target Users

- 한국 문화에 관심 있는 사용자 (국내외)
- 차분하고 정갈한 UI를 선호하는 사용자
- 기존 Desert/Ocean 등 자연 테마와 다른 인공미 + 자연 조화를 원하는 사용자

## Success Criteria

1. 한옥 테마가 기존 6개 테마와 동일한 완성도로 구현됨 (Tab + Detail + Sheet 배경)
2. Score/Metric 색상이 한국 전통 색상(오방색 기반)과 자연스럽게 매핑됨
3. Arctic Dawn/Solar Pop의 Detail/Sheet 배경이 보완됨
4. ThemePickerSection에서 자연스럽게 선택 가능

---

## 한옥 테마 컨셉: "기(氣)의 흐름"

### 핵심 메타포

한옥의 핵심 철학은 **자연과 조화**. 마루, 대청, 처마의 곡선은 바람과 빛의 흐름을 따른다.
헬스 앱에서 이를 **기(氣)의 흐름**으로 해석:

| 한옥 요소 | 건강 메타포 | UI 매핑 |
|-----------|------------|---------|
| 처마 곡선 | 컨디션의 리듬 | 웨이브 배경 형태 |
| 온돌의 온기 | 신체 온기/활력 | Score Excellent~Good 색상 |
| 대청마루의 바람 | 회복/휴식 | Score Fair~Warning 색상 |
| 단청 문양 | 건강의 균형(오방색) | Metric 카테고리 색상 |
| 창호지 | 맑은 마음/명상 | 카드 배경 텍스처 |
| 기와 | 보호/안정 | 내비게이션/헤더 |

### 색상 팔레트 (오방색 기반)

한국 전통 오방색(오행)을 헬스 메트릭에 매핑:

| 오방색 | 한국명 | Hex (제안) | 오행 | 건강 매핑 |
|--------|--------|-----------|------|-----------|
| 적(赤) | 붉은색 | #C4544A | 화(火) | Heart Rate, 활력 |
| 청(靑) | 푸른색 | #4A7B8C | 목(木) | HRV, 성장/회복 |
| 황(黃) | 노란색 | #D4A574 | 토(土) | Accent, 중심/균형 |
| 백(白) | 흰색   | #F5F0E8 | 금(金) | 배경, 정결/호흡 |
| 흑(黑) | 검은색 | #3C3C3C | 수(水) | 텍스트, 깊이/수면 |

#### 기본 색상 토큰

```
Accent (warmGlow 대응):  단청 주황  #D4A574  — 온돌의 온기
Bronze (bronze 대응):    먹색       #3C3C3C  — 서예 먹의 깊이
Dusk (dusk 대응):        소목색     #8B6914  — 나무의 따뜻함
Sand (sand 대응):        한지백     #F5F0E8  — 창호지의 맑음
```

#### Score 색상 (컨디션 = 기의 흐름)

| 등급 | 한옥 해석 | 색상 제안 |
|------|-----------|----------|
| Excellent | 온돌의 충만한 온기 | 진한 단청 주홍 #C75B3A |
| Good | 아침 햇살 드는 대청 | 따뜻한 황토 #D4985A |
| Fair | 처마 그늘의 쉼 | 소나무 초록 #6B8B5E |
| Tired | 저녁 안개의 고요 | 청회색 #7B8B9A |
| Warning | 새벽 찬 기운 | 먹빛 남색 #4A5568 |

#### Metric 색상 (오행 기반)

| Metric | 오행 | 색상 |
|--------|------|------|
| HRV | 목(木) — 성장, 유연 | 청록 #4A7B8C |
| RHR | 화(火) — 심장, 열 | 적갈 #B85450 |
| Heart Rate | 화(火) — 심박 | 주홍 #C4544A |
| Sleep | 수(水) — 고요, 깊이 | 남색 #4A5A7B |
| Activity | 토(土) — 에너지 | 황토 #C4963A |
| Steps | 목(木) — 이동, 성장 | 연두 #6B8B5E |
| Body | 금(金) — 체질, 뼈 | 은회 #8B8B7A |

### 웨이브 배경: 처마 곡선과 기와 물결

#### Tab Background — "기와 물결 (瓦紋)"

```
구성 요소:
1. 기와 레이어 (최하단): 기와 지붕의 부드러운 곡선 반복
   - amplitude: 0.06, frequency: 2.0
   - 기와의 반원 패턴을 연상시키는 부드러운 물결

2. 처마 레이어 (중간): 한옥 처마의 우아한 곡선
   - amplitude: 0.04, frequency: 1.2
   - 느리고 우아한 drift (20초 주기)
   - 처마 끝 곡선의 미묘한 상승감

3. 바람 레이어 (최상단): 대청마루를 지나는 바람
   - amplitude: 0.02, frequency: 3.0
   - 매우 미세한 흔들림, 투명도 높음

특수 효과:
- 창호지 텍스처: 한지의 미세한 섬유질 느낌 (pre-rendered UIImage)
- 기와 하이라이트: 기와 마루의 빛 반사 (crest highlight 활용)
```

#### Detail Background — "한지 물결 (韓紙紋)"

```
- 단일 레이어: 부드러운 한지 위 물결
- amplitude: 0.03 (Tab의 50%)
- opacity: 0.08 (절제된 표현)
- 한지 그레인 텍스처 오버레이
```

#### Sheet Background — "온돌 숨결 (溫突紋)"

```
- 단일 레이어: 온돌의 미세한 열기 흐름
- amplitude: 0.02 (가장 미묘)
- opacity: 0.06 (최소한의 존재감)
- 따뜻한 색조의 그라데이션
```

### 그라데이션

```
heroText:     소목색 → 단청 주황  (나무에서 단청으로)
detailScore:  소목색 → 청회색     (따뜻함에서 고요로)
sectionAccent: 단청 주황 → 청회색  (활력에서 안정으로)
cardBackground: 한지백 → 투명     (자연스러운 페이드)
```

### Weather 연결 (Today Tab)

| 날씨 | 한옥 해석 | 색상 |
|------|-----------|------|
| Clear | 맑은 대청마루 햇살 | 따뜻한 황토 |
| Rain | 처마 위 빗소리 | 청회색 |
| Snow | 기와 위 첫눈 | 순백 + 먹빛 |
| Cloudy | 안개 낀 한옥마을 | 연회색 |
| Night | 달빛 아래 고요 | 남색 + 먹 |

---

## 기존 테마 보완 계획

### Arctic Dawn — Detail/Sheet 배경 추가

현재 상태: Tab 배경만 구현 (오로라 레이어 + 서리 하이라이트)

#### Detail Background — "극지 서리 (Frost)"
```
- 단일 오로라 레이어 (amplitude 축소, opacity 70%)
- 서리 결정 텍스처 (미세한 패턴)
- 차가운 그라데이션: 딥블루 → 투명
```

#### Sheet Background — "빙하 숨결 (Glacier)"
```
- 최소한의 오로라 잔향
- 서리 하이라이트만 유지
- opacity: 0.06
```

### Solar Pop — Detail/Sheet 배경 추가

현재 상태: Tab 배경만 구현 (불씨/코어/글로우 레이어)

#### Detail Background — "태양 잔열 (Afterglow)"
```
- 단일 글로우 레이어 (amplitude 50%)
- 따뜻한 그라데이션: 앰버 → 투명
- 미세한 열기 시머
```

#### Sheet Background — "태양 숨결 (Solar Breath)"
```
- 최소한의 코어 글로우
- opacity: 0.06
- 부드러운 라디얼 그라데이션
```

---

## Constraints

### 기술적 제약
- 기존 `AppTheme` enum에 `.hanok` case 추가 → 모든 switch 구문 업데이트 필요
- Asset Catalog에 `Hanok` prefix로 ~35개 colorset 추가 필요
- Wave Shape는 기존 `WaveShape` 재활용 가능 (처마 곡선은 sine 변형)
- Watch DS 동기화 필요 (별도 DesignSystem.swift)

### 성능 제약
- 한지 텍스처: pre-rendered UIImage (Shape.path 내 생성 금지)
- 기와 패턴: static 배열 캐싱
- Wave 레이어 3개 이내 유지 (Ocean 테마 기준)

### 디자인 제약
- Dark mode에서 배경 gradient opacity >= 0.06 유지
- Light/Dark 동일 색상이면 universal만
- Score 색상 5단계 명확한 구분 필수 (접근성)

---

## Edge Cases

- **Accessibility**: 고대비 모드에서 단청 색상의 가독성 검증 필요
- **Dark Mode**: 한지 배경(밝은)이 다크 모드에서 역전 — 별도 다크 팔레트 필수
- **Dynamic Type**: 한옥 테마 특유의 넓은 여백이 큰 글자에서 레이아웃 깨짐 가능
- **Weather 전환**: 한옥 색상 → 날씨 색상 전환 시 atmosphereTransition 자연스러운지 검증
- **Watch**: 작은 화면에서 한지 텍스처가 인식 불가할 수 있음 → Watch에서는 텍스처 생략

---

## Scope

### MVP (Must-have)
- [ ] `AppTheme.hanok` enum case 추가
- [ ] Hanok 색상 팔레트 정의 (Asset Catalog ~35개 colorset)
- [ ] `AppTheme+View.swift`에 Hanok 색상 매핑
- [ ] `HanokTabWaveBackground` — 기와 물결 + 처마 곡선 + 바람
- [ ] `HanokDetailWaveBackground` — 한지 물결
- [ ] `HanokSheetWaveBackground` — 온돌 숨결
- [ ] ThemePickerSection에 Hanok 테마 추가
- [ ] Light/Dark 양쪽 colorset 정의
- [ ] Arctic Dawn Detail/Sheet 배경 추가
- [ ] Solar Pop Detail/Sheet 배경 추가

### Nice-to-have (Future)
- [ ] 한지 섬유 텍스처 (pre-rendered UIImage)
- [ ] 기와 하이라이트 (crest highlight 변형)
- [ ] 계절별 한옥 변형 (봄 매화, 가을 단풍 — 서브테마)
- [ ] Watch 전용 한옥 테마 최적화
- [ ] 한옥 테마 전용 앱 아이콘

---

## Open Questions

1. **한지 텍스처 구현 방식**: CIFilter vs pre-rendered image vs 노이즈 셰이더?
2. **기와 곡선의 수학적 모델**: sine 변형 vs 커스텀 bezier?
3. **오방색 채도**: 전통 원색 유지 vs 현대적 톤다운?
4. **UserDefaults 마이그레이션**: 기존 사용자의 theme 키에 새 case 추가 시 backward compatibility

---

## Next Steps

- [ ] `/plan hanok-theme` 으로 구현 계획 생성
- [ ] Asset Catalog 색상 시안 확정
- [ ] 웨이브 배경 프로토타입 (WaveShape 커스텀 여부 결정)
- [ ] Arctic/Solar Detail/Sheet 배경은 한옥 테마와 병렬로 구현 가능
