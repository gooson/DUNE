---
tags: [audit, localization, performance, review]
date: 2026-03-15
category: plan
status: approved
---

# Plan: 2026-03-15 일일 머지 감사

## 요약

오늘 머지된 15개 PR (#527-#541)의 코드/문서 179개 파일 변경 내역을 6개 관점에서 감사하여 발견된 이슈를 수정.

## 발견된 이슈

### P1 (Critical) — 0건

없음.

### P2 (Important) — 2건

| # | 파일 | 이슈 | 유형 |
|---|------|------|------|
| 1 | `PostureResultView.swift:145-147` | ternary in `Text()` → `String` init 사용 → 번역 미적용 | Localization Leak |
| 2 | `CompoundWorkoutSetupView.swift:64-66` | ternary in `Text()` → `String` init 사용 → 번역 미적용 | Localization Leak |

### P3 (Minor) — 1건

| # | 파일 | 이슈 | 유형 |
|---|------|------|------|
| 1 | `DotLineChartView.swift:189-196` | `yDomain` computed property가 body 렌더마다 2×O(N) min/max 수행 | Performance |

## 수정 계획

### Step 1: PostureResultView ternary → 분리 Text

ternary 대신 `if-else`로 `Text()`를 분기하여 `LocalizedStringKey` init이 동작하도록.

### Step 2: CompoundWorkoutSetupView ternary → 분리 Text

동일 패턴 수정.

### Step 3: DotLineChartView yDomain 캐싱

`@State private var cachedYDomain` 추가, `.onChange(of: data.count)`에서 무효화.

## 영향 파일

| 파일 | 변경 내용 |
|------|----------|
| `DUNE/Presentation/Posture/PostureResultView.swift` | ternary → if-else |
| `DUNE/Presentation/Exercise/Components/CompoundWorkoutSetupView.swift` | ternary → if-else |
| `DUNE/Presentation/Shared/Charts/DotLineChartView.swift` | yDomain 캐싱 |

## 테스트 전략

- 빌드 검증: `scripts/build-ios.sh`
- 번역 확인: ternary 제거 후 `LocalizedStringKey` init이 사용됨을 코드로 확인 (런타임 검증은 시뮬레이터 필요)

## 리스크

- 낮음. 순수 Presentation 레벨 수정으로 데이터/로직 변경 없음
