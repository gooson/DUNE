---
tags: [design-system, hanok, theme, dancheong, jade, color, animation]
date: 2026-03-05
category: plan
status: approved
---

# Plan: 한옥 테마 고도화 (단청 리뉴얼)

## 목표

현재 황토/갈색 기반 한옥 테마를 **옥색(翡色) + 단청 오방색** 팔레트로 전면 리뉴얼.
배경 Wave 애니메이션에 바람 sway 효과를 추가하여 한옥의 처마 느낌을 강화.

## 성공 기준

1. 27개 color asset 모두 옥색 기반으로 교체
2. Wave 배경에 breath amplitude 변조 적용
3. Crest highlight가 옥색 shimmer로 표현
4. Light/Dark 모드 모두에서 가독성 유지
5. 빌드 성공 + 기존 테스트 통과

## Implementation Steps

### Step 1: Color Asset 교체 (27개 colorset)

위치: `Shared/Resources/Colors.xcassets/`

#### 1a. Primary Colors (7개)

| Asset | Light 현재→변경 | Dark 현재→변경 |
|-------|----------------|---------------|
| HanokAccent | `#d3a474`→`#5B9E8F` | `#e0b482`→`#7FBFB5` |
| HanokBronze | `#3b3b3b`→`#2A3A38` | `#b8afa3`→`#C8D5D0` |
| HanokDusk | `#8a6913`→`#2B5279` | `#6b5a33`→`#3D6B8A` |
| HanokDeep | `#494133`→`#1E3A3A` | `#332c22`→`#152B2B` |
| HanokMid | `#8a6913`→`#3A7D6E` | `#6b5a33`→`#2D6058` |
| HanokMist | `#dfd6c5`→`#B8D8CF` | `#9e9587`→`#6B9E91` |
| HanokSand | `#f5efe8`→`#E8F0EC` | `#beb7aa`→`#A8BFB7` |

#### 1b. Score Colors (5개) — 단청 오방색

| Asset | Light 현재→변경 | Dark 현재→변경 | 매핑 |
|-------|----------------|---------------|------|
| HanokScoreExcellent | `#c65b39`→`#C83F23` | `#da6c4d`→`#E05A3F` | 赤 주홍 |
| HanokScoreGood | `#d3975a`→`#5B9E8F` | `#e0a86b`→`#7FBFB5` | 翡 옥색 |
| HanokScoreFair | `#6b8a5e`→`#D4A843` | `#7d9f6f`→`#E0B85A` | 黃 황색 |
| HanokScoreTired | `#7a8a9a`→`#2B5279` | `#8e9ead`→`#4A7BA3` | 靑 남색 |
| HanokScoreWarning | `#495468`→`#3A3A3A` | `#5d687a`→`#5A5A5A` | 黑 묵색 |

#### 1c. Metric Colors (7개) — 옥색 기조 harmonization

| Asset | Light 현재→변경 | Dark 현재→변경 | 근거 |
|-------|----------------|---------------|------|
| HanokMetricHRV | `#497a8b`→`#3A7D6E` | `#5b8e9f`→`#5B9E8F` | 옥청록 |
| HanokMetricRHR | `#b85350`→`#C83F23` | `#c96661`→`#E05A3F` | 주홍 (심박) |
| HanokMetricHeartRate | `#c45349`→`#B5432A` | `#d6665c`→`#D05A42` | 적갈 |
| HanokMetricSleep | `#495a7a`→`#2B5279` | `#5d6c8e`→`#4A7BA3` | 남색 (밤) |
| HanokMetricActivity | `#c49539`→`#D4A843` | `#d6a84d`→`#E0B85A` | 황색 (에너지) |
| HanokMetricSteps | `#6b8a5e`→`#4D8B5A` | `#7d9e6f`→`#65A572` | 녹색 (걸음) |
| HanokMetricBody | `#8a8a79`→`#6B8A7E` | `#9e9e8d`→`#82A396` | 옥회 |

#### 1d. Tab Colors (3개)

| Asset | Light 현재→변경 | Dark 현재→변경 |
|-------|----------------|---------------|
| HanokTabTrain | `#c65b39`→`#C83F23` | `#da6c4d`→`#E05A3F` |
| HanokTabWellness | `#497a8b`→`#3A7D6E` | `#5b8e9f`→`#5B9E8F` |
| HanokTabLife | `#8a6913`→`#D4A843` | `#9e7c2c`→`#E0B85A` |

#### 1e. Weather Colors (4개)

| Asset | Light 현재→변경 | Dark 현재→변경 |
|-------|----------------|---------------|
| HanokWeatherRain | 확인 후 옥색 기조 맞춤 조정 | |
| HanokWeatherSnow | 확인 후 조정 | |
| HanokWeatherCloudy | 확인 후 조정 | |
| HanokWeatherNight | 확인 후 조정 | |

#### 1f. Card Background (1개)

| Asset | Light 현재→변경 | Dark 현재→변경 |
|-------|----------------|---------------|
| HanokCardBackground | `#f9f7f3`→`#F2F7F5` | `#242220`→`#1A2422` |

### Step 2: Wave 바람 sway 애니메이션

파일: `HanokWaveBackground.swift`

- `HanokWaveOverlayView`에 `breathIntensity` 파라미터 추가 (0~0.15)
- `@State private var breathPhase: CGFloat = 0` 추가
- breath 애니메이션: sinusoidal, 7~12초 주기
- 실제 amplitude: `amplitude * (1 + breathIntensity * sin(breathPhase))`
- `reduceMotion` 시 breath 비활성화
- 레이어별 breathIntensity: Far(0.05) / Mid(0.08) / Near(0.12)

### Step 3: Crest 옥색 shimmer

파일: `HanokWaveBackground.swift`

- Tab Near 레이어의 `crestColor`를 `theme.hanokMistColor` → `theme.hanokMidColor`로 (옥색 톤)
- crest opacity 약간 증가 (옥색 shimmer 느낌)

### Step 4: 빌드 검증

- `scripts/build-ios.sh` 실행
- 기존 테스트 통과 확인 (`HanokEaveShapeTests`, `AppThemeTests`)

## Affected Files

| 파일 | 변경 유형 |
|------|----------|
| `Shared/Resources/Colors.xcassets/HanokAccent.colorset/Contents.json` | 색상값 교체 |
| `Shared/Resources/Colors.xcassets/HanokBronze.colorset/Contents.json` | 색상값 교체 |
| `Shared/Resources/Colors.xcassets/HanokDusk.colorset/Contents.json` | 색상값 교체 |
| `Shared/Resources/Colors.xcassets/HanokDeep.colorset/Contents.json` | 색상값 교체 |
| `Shared/Resources/Colors.xcassets/HanokMid.colorset/Contents.json` | 색상값 교체 |
| `Shared/Resources/Colors.xcassets/HanokMist.colorset/Contents.json` | 색상값 교체 |
| `Shared/Resources/Colors.xcassets/HanokSand.colorset/Contents.json` | 색상값 교체 |
| `Shared/Resources/Colors.xcassets/HanokScoreExcellent.colorset/Contents.json` | 색상값 교체 |
| `Shared/Resources/Colors.xcassets/HanokScoreGood.colorset/Contents.json` | 색상값 교체 |
| `Shared/Resources/Colors.xcassets/HanokScoreFair.colorset/Contents.json` | 색상값 교체 |
| `Shared/Resources/Colors.xcassets/HanokScoreTired.colorset/Contents.json` | 색상값 교체 |
| `Shared/Resources/Colors.xcassets/HanokScoreWarning.colorset/Contents.json` | 색상값 교체 |
| `Shared/Resources/Colors.xcassets/HanokMetricHRV.colorset/Contents.json` | 색상값 교체 |
| `Shared/Resources/Colors.xcassets/HanokMetricRHR.colorset/Contents.json` | 색상값 교체 |
| `Shared/Resources/Colors.xcassets/HanokMetricHeartRate.colorset/Contents.json` | 색상값 교체 |
| `Shared/Resources/Colors.xcassets/HanokMetricSleep.colorset/Contents.json` | 색상값 교체 |
| `Shared/Resources/Colors.xcassets/HanokMetricActivity.colorset/Contents.json` | 색상값 교체 |
| `Shared/Resources/Colors.xcassets/HanokMetricSteps.colorset/Contents.json` | 색상값 교체 |
| `Shared/Resources/Colors.xcassets/HanokMetricBody.colorset/Contents.json` | 색상값 교체 |
| `Shared/Resources/Colors.xcassets/HanokTabTrain.colorset/Contents.json` | 색상값 교체 |
| `Shared/Resources/Colors.xcassets/HanokTabWellness.colorset/Contents.json` | 색상값 교체 |
| `Shared/Resources/Colors.xcassets/HanokTabLife.colorset/Contents.json` | 색상값 교체 |
| `Shared/Resources/Colors.xcassets/HanokWeatherRain.colorset/Contents.json` | 색상값 교체 |
| `Shared/Resources/Colors.xcassets/HanokWeatherSnow.colorset/Contents.json` | 색상값 교체 |
| `Shared/Resources/Colors.xcassets/HanokWeatherCloudy.colorset/Contents.json` | 색상값 교체 |
| `Shared/Resources/Colors.xcassets/HanokWeatherNight.colorset/Contents.json` | 색상값 교체 |
| `Shared/Resources/Colors.xcassets/HanokCardBackground.colorset/Contents.json` | 색상값 교체 |
| `DUNE/Presentation/Shared/Components/HanokWaveBackground.swift` | breath sway + crest 색상 |

## 변경하지 않는 파일 (색상 참조만, 토큰명 불변)

- `AppTheme+View.swift`: `Color("HanokDeep")` 등 토큰명 유지
- `GlassCard.swift`: `Color("HanokAccent")` 등 토큰명 유지
- `SectionGroup.swift`: `Color("HanokAccent")` 등 토큰명 유지
- `ProgressRingView.swift`: `Color("HanokAccent")` 토큰명 유지
- `HanokEaveShape.swift`: 색상 참조 없음, Shape 로직만

## 위험 요소

- 색상 대비 부족 가능성: Dark 모드에서 옥색 배경 위 텍스트 가독성 → preview에서 확인
- Weather 색상과 신규 팔레트 충돌 가능성 → 조정 필요
