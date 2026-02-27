---
tags: [watch, watchos, ux, design, illustration, template, exercise-selection, design-system]
date: 2026-02-27
category: brainstorm
status: draft
---

# Brainstorm: Apple Watch UX 전면 리뉴얼

## Problem Statement

현재 Watch 앱의 UX가 **텍스트 중심의 리스트**로 구성되어 시각적 매력과 직관성이 부족함:

| # | 문제 | 심각도 | 현재 상태 |
|---|------|--------|----------|
| 1 | 운동 선택이 텍스트 리스트 | High | 이름+sets×reps만 표시. 어떤 운동인지 시각적 식별 어려움 |
| 2 | 템플릿 카드 정보 빈약 | High | 이름+"N exercises"만 표시. 내용 파악에 탭 필요 |
| 3 | iOS 앱 디자인과 불일치 | Medium | iOS는 warm tone+wave+muscle map, Watch는 기본 시스템 UI |
| 4 | 세트 입력 정보 과밀 | Medium | 작은 화면에 무게/랩/±버튼/HR 동시 노출 |
| 5 | 커스텀 비주얼 에셋 부재 | High | SF Symbol만 사용. 경쟁 앱 대비 시각적 차별성 없음 |

**핵심**: 운동 선택 시 "이 운동이 뭔지" 한눈에 알 수 있는 시각적 단서가 없고, 앱 전체가 generic watchOS 리스트처럼 보임.

## Target Users

- 헬스장에서 Watch만 착용하고 운동하는 사용자
- 루틴(템플릿) 기반으로 운동하는 중급 이상 사용자
- iOS 앱과 동일한 브랜드 경험을 기대하는 사용자
- 운동 종류를 시각적으로 빠르게 식별하고 싶은 사용자

## Success Criteria

1. **운동 선택 시 이미지/아이콘으로 즉각 식별 가능** (텍스트 읽기 없이 탐색)
2. **템플릿 카드에 운동 아이콘 미리보기 + 예상 시간/세트 수 인라인 표시**
3. **iOS DS (warm tone, wave background, desert palette)와 시각적 일관성 확보**
4. **운동 중 땀 상태에서도 미스탭 없는 큰 터치 타겟 유지** (최소 44pt)
5. **앱 전체 화면에서 브랜드 아이덴티티 느낌** (generic watchOS ≠ Dailve Watch)

## Reference Analysis

### Apple Workout App (watchOS 26)
- 운동 타입별 **컬러 코딩 + SF Symbol** 대형 타일 (1열)
- watchOS 26에서 4-corner 버튼으로 개편되었으나 사용자 불만 (작은 타겟)
- **교훈**: 큰 타일 1열이 Watch에서 가장 안전한 패턴

### Strong / Hevy / Fitbod
- 모두 **세로 스크롤 리스트** 사용 (Grid 없음)
- 행 레이아웃: 아이콘(좌) + 이름(중) + 부가 정보(우/아래)
- **iPhone은 설정, Watch는 실행** 분업 패턴
- 단일 탭 → 즉시 시작이 표준 인터랙션

### watchOS HIG 핵심
- 터치 타겟 최소 44×44pt
- CarouselListStyle: 중앙 항목 확대 효과 (운동 선택에 적합)
- 다크 배경 전용, 밝고 채도 낮은 색상
- 2-3초 내 인터랙션 완료가 목표
- Liquid Glass (watchOS 26): 반투명 소재, 뚜렷한 형태 필요

## Decisions

| 질문 | 결정 | 근거 |
|------|------|------|
| 운동 아이콘 스타일 | **커스텀 일러스트/아이콘** | SF Symbol은 운동별 구분 약함. 덤벨/바벨/머신 등 맞춤 에셋 |
| 선택 레이아웃 | **1열 큰 타일 리스트** | 44pt+ 터치 타겟 보장. watchOS 표준 패턴. 땀 상태 고려 |
| 템플릿 카드 | **아이콘 미리보기 + 메타 정보** | 이름만으로 부족. 운동 아이콘 3개 + 세트 수 + 예상 시간 |
| DS 통일 | **iOS DS 토큰 완전 적용** | wave background, desert palette, warm glow 일관성 |
| MVP 범위 | **Watch UX 전면 리뉴얼** | 운동 선택 + 템플릿 + 세트 입력 + DS 전체 개편 |

## Proposed Design

### 1. 운동 선택 UI 재설계

**현재**:
```
┌──────────────────────┐
│ Popular               │
│ ├─ Bench Press  3×10  │  ← 텍스트만, 시각적 구분 없음
│ ├─ Squat       4×8   │
│ ├─ Deadlift    3×5   │
│ Recent               │
│ ├─ Lat Pulldown 3×12 │
└──────────────────────┘
```

**제안**:
```
┌──────────────────────┐
│ ★ Popular            │
│ ┌──────────────────┐ │
│ │ 🏋 Bench Press   │ │  ← 커스텀 아이콘 + 큰 타일
│ │    3×10 · 80kg   │ │     최근 무게 인라인 표시
│ └──────────────────┘ │
│ ┌──────────────────┐ │
│ │ 🦵 Squat         │ │  ← 근육 부위별 컬러 틴트
│ │    4×8 · 100kg   │ │
│ └──────────────────┘ │
│ ┌──────────────────┐ │
│ │ 💪 Deadlift      │ │
│ │    3×5 · 120kg   │ │
│ └──────────────────┘ │
└──────────────────────┘
```

**디자인 요소**:
- **타일 높이**: ~60pt (터치 타겟 여유)
- **좌측 아이콘**: 36×36pt 커스텀 일러스트 (장비 기반: 덤벨/바벨/케이블/머신/바디웨이트)
- **우측 상단**: 운동 이름 (headline)
- **우측 하단**: sets×reps · 최근 무게 (caption, secondary)
- **배경**: DS.Color.warmGlow.opacity(DS.Opacity.subtle) 라운드 카드
- **근육 부위 컬러 틴트**: 가슴=warm, 등=cool, 하체=earth 등 카테고리별 accent

### 2. 운동 아이콘 체계

**분류 기준**: 장비(Equipment) 기반 + 근육 부위 컬러

| 장비 카테고리 | 아이콘 | 적용 운동 예시 |
|-------------|--------|--------------|
| Barbell | 바벨 일러스트 | Bench Press, Squat, Deadlift, OHP |
| Dumbbell | 덤벨 일러스트 | DB Curl, DB Fly, DB Row |
| Cable/Machine | 케이블 머신 | Lat Pulldown, Cable Fly, Leg Press |
| Bodyweight | 사람 실루엣 | Pull-up, Push-up, Dip |
| Cardio | 달리는 사람 | Running, Cycling, Rowing |
| Kettlebell | 케틀벨 | KB Swing, Goblet Squat |
| Band | 밴드 | Band Pull-apart, Banded Squat |
| Smith Machine | 스미스 머신 | Smith Squat, Smith Press |

**에셋 요구사항**:
- 포맷: SVG → Asset Catalog (watchOS용 단일 스케일)
- 크기: 36×36pt (Watch), iOS에서는 48×48pt 재활용 가능
- 스타일: 라인 아트 + desert palette 단색 채움 (warm tone 일관성)
- 다크 배경 최적화: 밝은 선 + 반투명 채움

### 3. 템플릿 카드 재설계

**현재**:
```
┌──────────────────────┐
│ Push Day        ▶    │  ← 이름만 표시
│ 4 exercises          │
└──────────────────────┘
```

**제안**:
```
┌──────────────────────┐
│ Push Day             │
│ 🏋 🏋 💪 🏋          │  ← 운동 아이콘 미리보기 (최대 4개)
│ 4 exercises · ~45min │  ← 세트 수 + 예상 시간
│ ▬▬▬▬▬▬▬░░░ Last 3d  │  ← 마지막 수행일 + 진행 바
└──────────────────────┘
```

**디자인 요소**:
- **아이콘 행**: 포함 운동의 장비 아이콘 최대 4개 (초과 시 `+N`)
- **메타 정보**: 총 운동 수 · 예상 소요 시간 (전회 기록 기반)
- **최근 수행**: "Last 3d ago" 또는 "Today" + mini progress bar
- **카드 배경**: warm gradient (DS.Gradient 토큰)
- **라운드 코너**: 18pt (watchOS 표준)

### 4. 세트 입력 UX 개선

**현재 문제**: 무게/랩/±버튼이 작은 화면에 과밀 배치

**제안**:
- **주요 표시**: 무게 (대형 폰트, monospacedDigit) + 랩 수
- **입력 방식**: Digital Crown = 무게 조절 (2.5kg 단위)
- **±버튼**: 랩 수만 (무게는 크라운에 위임)
- **Complete 버튼**: 화면 하단 전체 너비, DS.Color.positive
- **HR 표시**: 우상단 작은 뱃지 (heartRate 토큰 컬러)
- **진행률**: 상단 dot indicator (완료=filled, 남음=outline)

### 5. DS 통일 적용 범위

| 영역 | 현재 | 제안 |
|------|------|------|
| 배경 | 기본 검정 | WaveBackground (amplitude 축소) |
| Accent | warmGlow 부분 적용 | 전체 CTA/progress에 warmGlow |
| 카드 | 시스템 기본 행 | DS rounded card (18pt corner, gradient fill) |
| 타이포 | 시스템 기본 | monospacedDigit(숫자), rounded(대형) |
| 색상 | 일부 토큰 | 전체 metric color 토큰 적용 |
| 애니메이션 | 기본 transition | .contentTransition(.numericText()), wave drift |

## Constraints

### 기술적 제약
- watchOS 화면: 46mm 기준 ~208×248pt (실 가용 영역 더 작음)
- 터치 타겟 최소 44×44pt → 2열 Grid 시 열 당 ~90pt (가능하나 빠듯)
- Digital Crown 점유: 스크롤 vs 값 입력 충돌 → 시트 분리로 해결
- 에셋 크기: Watch 앱 번들 50MB 제한 고려 → SVG→rasterize 또는 최소 에셋
- WatchConnectivity: 아이콘은 번들에 포함, 동기화 불필요

### 리소스 제약
- 커스텀 일러스트 8-10종 제작 필요 (장비 카테고리별)
- iOS DS 토큰과 Watch DS 토큰 동기화 작업 (Correction #138)
- 기존 View 전면 수정 → regression 테스트 범위 넓음

## Edge Cases

| 시나리오 | 대응 |
|---------|------|
| 운동 라이브러리 미동기화 | fallback 기본 아이콘 (generic dumbbell) |
| 장비 카테고리 매핑 없는 운동 | `equipment == nil` → bodyweight 아이콘 |
| 템플릿 0개 (신규 사용자) | Quick Start만 표시, "iPhone에서 템플릿 생성" 안내 |
| 예상 시간 계산 불가 (첫 수행) | "~" 대신 세트 수만 표시 |
| 긴 운동 이름 (2줄 이상) | `.lineLimit(1)` + truncation. 전체 이름은 탭 후 확인 |
| 아이콘 미지원 장비 | generic 아이콘 + 텍스트 레이블 fallback |

## Scope

### MVP (Must-have)
- [ ] 운동 선택 1열 타일 리스트 (아이콘 + 이름 + 최근 기록)
- [ ] 장비 기반 커스텀 아이콘 8종 (Barbell/Dumbbell/Cable/Bodyweight/Cardio/Kettlebell/Band/Machine)
- [ ] 템플릿 카드 디자인 강화 (아이콘 미리보기 + 메타 정보)
- [ ] WaveBackground 전체 적용
- [ ] DS 색상 토큰 완전 적용 (warm tone 일관성)
- [ ] 세트 입력 정보 계층화 (무게 강조, HR 축소)
- [ ] 기존 기능 유지 (Quick Start, 템플릿, 세트 기록, Rest Timer)

### Nice-to-have (Future)
- [ ] CarouselListStyle 적용 (중앙 항목 확대)
- [ ] Liquid Glass 소재 적용 (watchOS 26)
- [ ] 근육 부위별 컬러 틴트 (Muscle Map 연동)
- [ ] 운동 애니메이션 GIF/Lottie (운동 동작 미리보기)
- [ ] Smart Stack 연동 (시간/장소 기반 루틴 추천)
- [ ] 운동 중 Workout Buddy 스타일 동기부여 메시지
- [ ] 템플릿 Watch 단독 편집 (순서 변경, 세트 수 조절)
- [ ] iPad/iPhone 미러링 디스플레이 (Live Activity)

## 기존 에셋 현황 조사 결과

### Equipment SVG (25종, iOS Asset Catalog)

**위치**: `DUNE/Resources/Assets.xcassets/Equipment/`

| 카테고리 | 에셋 | 퀄리티 | Watch 재활용 | 비고 |
|---------|------|--------|-------------|------|
| **Free Weights** | | | | |
| | barbell | B+ | O | 바+플레이트+칼라 인식 가능 |
| | dumbbell | B | O | 단순하나 명확 |
| | kettlebell | B+ | O | 핸들+벨 형태 잘 표현 |
| | ez-bar | ? | 확인필요 | |
| | trap-bar | ? | 확인필요 | |
| **Machines** | | | | |
| | cable-machine | A- | O | 타워+도르래+케이블+웨이트 스택 |
| | leg-press 등 9종 | ? | 확인필요 | |
| **Bodyweight** | | | | |
| | bodyweight | C+ | 교체 권장 | 기하학적 인체, 조악함 |
| | pull-up-bar | ? | 확인필요 | |
| | dip-station | ? | 확인필요 | |
| **Small Equipment** | | | | |
| | band, trx 등 | ? | 확인필요 | |

**SVG 스타일 특성**:
- 64×64 viewBox, 단색 검정(`#000000`) fill
- 기하학적 도형 기반 (rect, circle, ellipse, path)
- 디테일 없음 — 라인 아트 수준, 그라데이션/셰이딩 없음
- **프로그래머가 그린 수준** — 작은 사이즈(48px)에서는 OK, 큰 타일에서는 부족

### Equipment enum & 매핑 (완비)

- `Equipment.swift`: 24 cases 정의
- `Equipment+View.swift`: `displayName`, `localizedDisplayName`, `iconName`(SF Symbol), `svgAssetName` 모두 매핑
- **ExerciseDefinition에 equipment 필드 존재** → 운동별 장비 매핑 이미 완료

### Watch 앱 현황

- `WatchExerciseInfo` DTO에 equipment 필드 **미포함** — 추가 필요
- Watch Asset Catalog에 Equipment SVG **미포함** — iOS에서 복사 또는 공유 필요

### 결론: AI 생성 + 선별 재활용

| 접근 | 대상 | 이유 |
|------|------|------|
| **AI 재생성** | bodyweight, other, 머신 계열 | 현재 품질 부족. 큰 타일에서 시각적 임팩트 필요 |
| **선별 재활용** | barbell, dumbbell, kettlebell, cable-machine | 형태 인식 가능. 컬러/스타일만 warm tone으로 조정 |
| **스타일 통일** | 전체 25종 | 선/채움/컬러를 DS desert palette에 맞춤. 일관성 최우선 |

## Resolved Questions

| # | 질문 | 답변 |
|---|------|------|
| 1 | 아이콘 에셋 제작 방식 | **AI 생성** (선별적 기존 에셋 재활용) |
| 2 | 장비 매핑 데이터 | **이미 완비** — Equipment enum 24종 + ExerciseDefinition.equipment |
| 3 | 기존 SVG 재활용 | **퀄리티별 판단** — 인식 가능한 것은 유지, 조악한 것은 교체 |

## 아이콘 스타일 가이드

### 스타일: 2px Stroke Line Art + Warm Sand 단색

업계 표준 분석 결과, 프리미엄 피트니스 앱(Strong, Hevy, Fitbod)은 일관되게 **2px stroke 라인 아트**를 사용.
3D, 그라데이션, 글래스모피즘은 쇠퇴 중. 미니멀 라인 아트가 고급스러움의 핵심.

**스타일 규격**:
- Stroke: 2px 균일, rounded terminals (둥근 끝)
- 단색: `DS.Color.warmGlow` 계열 (#E8C287)
- 배경: 투명 (다크 배경 위 렌더)
- 디테일: 5개 이하 시각 요소 (Watch 작은 화면 고려)
- 그리드: 64×64 viewBox (현재 SVG와 동일)

**상태별 컬러 체계**:

| 상태 | 컬러 | 토큰 | Hex (참고) |
|------|------|------|-----------|
| Default | Warm Sand | `DS.Color.warmGlow` | #E8C287 |
| Active/Selected | Amber Glow | 신규 토큰 | #F0A050 |
| Muted/Inactive | Weathered Bronze | 신규 토큰 | #8B7355 |
| Disabled | Dusk Stone | 신규 토큰 | #5C4A3A |

### 생성 도구: Recraft V4

| 장점 | 상세 |
|------|------|
| 네이티브 SVG | AI 도구 중 유일. Xcode Asset Catalog 즉시 적용 |
| hex 컬러 고정 | DS 토큰 입력 → 전체 세트 동일 팔레트 |
| style preset | 25종 배치 생성 시 일관성 보장 |
| 비용 | ~$2 (25종 전체) |

**프롬프트 패턴**:
```
Flat line icon of [equipment name],
2px stroke weight, rounded corners,
single color #E8C287 on transparent background,
minimal detail, 64x64px, fitness app icon set style
```

**워크플로우**: Recraft SVG 생성 → 퀄리티 확인 → Asset Catalog 교체 → iOS/Watch 공유

### watchOS 고려사항

- OLED에서 warm sand는 채도 +10% 부스트 권장 (Watch 전용 variant)
- 인앱 아이콘은 라인 아트, 앱 아이콘은 filled/solid (Apple 가이드라인)
- Liquid Glass 소재와의 공존: 뚜렷한 형태(bold shapes) 필수

## Open Questions

1. **Watch에서 아이콘 전달 방식**: Watch Asset Catalog에 직접 포함 vs iOS에서 WatchConnectivity로 전송
2. **CarouselListStyle**: 실기기 퍼포먼스 테스트 필요 (항목 20개+ 시)
3. **아이콘 크기 최적화**: 36pt vs 40pt vs 44pt — 실기기 테스트로 결정

## Next Steps

- [ ] `/plan watch-ux-renewal` 로 구현 계획 생성
- [ ] AI 아이콘 생성 도구 결정 + 스타일 가이드 수립
- [ ] 기존 25종 SVG 전수 퀄리티 평가 (재활용/교체 분류)
- [ ] WatchExerciseInfo DTO에 equipment 필드 추가 설계

## 관련 문서

- `docs/brainstorms/2026-02-18-watch-design-overhaul.md` — Watch 디자인 전면 수정 (퀵스타트/크라운/정보과밀)
- `docs/brainstorms/2026-02-18-watch-first-workout-ux.md` — Watch-First Workout UX (독립 운동 흐름)
- `docs/brainstorms/2026-02-23-equipment-svg-images.md` — 장비 SVG 이미지 (소스 조사, 에셋 교체 계획)
