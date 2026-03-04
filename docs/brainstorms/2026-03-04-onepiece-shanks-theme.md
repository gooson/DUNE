---
tags: [theme, design-system, one-piece, shanks, red-hair-pirates]
date: 2026-03-04
category: brainstorm
status: draft
---

# Brainstorm: 원피스 샹크스 빨간머리해적단 테마

## Problem Statement

앱 전체 기본 테마를 원피스 만화의 샹크스/빨간머리해적단(Red Hair Pirates) 컨셉으로 교체한다. 기존 6개 테마 시스템(Desert, Ocean, Forest, Sakura, Arctic, Solar)에 7번째 테마로 추가하되, 앱 전체 기본값으로 설정한다.

핵심 비주얼 레퍼런스: **빨간머리해적단 해적기(두개골 + 교차검 + 빨간 줄무늬)**

## Target Users

- 앱 전체 사용자 (기본 테마로 적용)
- 원피스/샹크스 팬층 어필

## Success Criteria

1. 빨간머리해적단 깃발의 분위기가 앱 전반에 자연스럽게 녹아들 것
2. 기존 테마 시스템과 동일한 구조(prefix 기반 asset dispatch)로 통합
3. 색상 팔레트, 웨이브 배경, 타이포그래피, 아이콘이 일관된 테마 경험 제공
4. 다크/라이트 모드 모두 지원
5. 기존 6개 테마도 선택 가능하게 유지 (기본값만 변경)

## Proposed Approach

### 1. 색상 팔레트 (Color Palette)

빨간머리해적단 깃발 + 샹크스 캐릭터 + 해적 분위기 기반:

| 토큰 | 색상 | 용도 | Hex (예시) |
|------|------|------|-----------|
| ShanksAccent | 진한 크림슨 레드 | 주요 강조색, 버튼, 링크 | #B81C1C |
| ShanksDusk | 깊은 네이비/차콜 | 배경 그라데이션, 보조 | #1A1A2E |
| ShanksBronze | 금장식/골드 | 점수 숫자, 장식 텍스트 | #C9A84C |
| ShanksSand | 낡은 양피지/아이보리 | 보조 텍스트, 장식 | #D4C5A9 |
| ShanksDeep | 해적기 검정 | 카드 배경, 심층 레이어 | #0D0D14 |
| ShanksMid | 짙은 와인 | 중간 레이어, 서브카드 | #4A1528 |
| ShanksSurface | 밝은 스칼렛 | 상단 웨이브, 하이라이트 | #DC3545 |
| ShanksMist | 연한 로즈/핑크 | 미스트 효과, 페이드 | #E8A0A0 |

**Score Colors** (빨간머리해적단 톤):
- Excellent: 골드 (#C9A84C)
- Good: 크림슨 (#B81C1C)
- Fair: 번트 오렌지 (#CC5500)
- Tired: 다크 와인 (#722F37)
- Warning: 차콜 (#2D2D3A)

**Tab Wave Identity**:
- TabTrain: 스칼렛 레드 (전투/훈련)
- TabWellness: 딥 와인 (회복/휴식)
- TabLife: 골드 (보물/일상)

### 2. 웨이브 배경 (Wave Background)

**ShanksWaveBackground** — 해적기 + 바다 + 검기(劍氣) 모티프:

- **Tab Background (3레이어)**:
  - Far layer: 검은 바다 수평선 (ShanksDusk → transparent)
  - Mid layer: 진홍 파도 — 기존 WaveShape 활용, 높은 amplitude/steepness
  - Near layer: 골드 하이라이트 줄기 — 검기/패왕색 표현

- **특수 효과**:
  - 해적기 문양 실루엣 (두개골) — DesertDuneOverlayView 패턴으로 subtle 오버레이
  - 패왕색 패기(覇気) 번개 효과 — Arctic aurora 패턴 변형, 빨간/검정 컬러
  - 골드 입자(파티클) 드리프트 — Sakura petal drift 패턴 변형

- **Detail Background**: 단일 빨간 웨이브 + 골드 크레스트
- **Sheet Background**: ShanksDusk 그라데이션

### 3. 타이포그래피 (Typography)

기존 DS.Typography 시스템(rounded + monospacedDigit) 유지하되:
- **heroScore**: `.bold` weight 유지 — 샹크스의 강렬한 카리스마
- 선택적으로 `.serif` design 검토 (해적 느낌의 고전적 폰트) → **주의**: Dynamic Type 호환성 확인 필요
- 대안: 기존 rounded 유지 + 색상/그라데이션으로 테마감 표현 (safer approach)

### 4. 커스텀 아이콘/일러스트

| 요소 | 설명 | 구현 방식 |
|------|------|----------|
| 해적기 실루엣 | 웨이브 배경 오버레이 | SVG → Shape (Forest silhouette 패턴) |
| 검 모티프 | 섹션 구분선/장식 | SF Symbol 활용 또는 커스텀 Shape |
| 밀짚모자 | 스플래시/빈 상태 일러스트 | Asset catalog SVG |
| 패왕색 번개 | 애니메이션 효과 | Arctic ribbon 패턴 변형 |

## Constraints

### 기술적 제약
- **기존 테마 시스템 구조 준수**: `AppTheme` enum + prefix 기반 asset dispatch
- **xcassets 규칙**: `Colors/` 하위, provides-namespace, light/dark 동일이면 universal
- **Wave Background 아키텍처**: Tab/Detail/Sheet 3단계 dispatch
- **WavePreset에 소비자 없는 case 추가 금지** (기존 4개 preset 유지)
- **DS.Color 직접 수정 최소화**: 테마별 dispatch는 AppTheme+View.swift에서

### 저작권 고려
- 원피스 캐릭터/로고 직접 사용 불가 → 해적기 "영감을 받은" 오리지널 실루엣
- 색감과 분위기로 테마 표현, 공식 아트 사용 금지
- 테마 이름: `shanksRed` 또는 `pirateRed` (직접적 IP 참조 최소화)

### 성능 제약
- Wave background: 120-point pre-computation 패턴 유지
- 파티클 효과: Sakura petal drift 수준 (저전력 모드 대응)
- Arctic LOD 패턴 적용 (reduce motion 대응)

## Edge Cases

- **기존 테마 사용자**: 기본값 변경 시 기존 `desertWarm` 선택한 사용자 설정 보존
  - `resolvedTheme`에서 기존 저장값 존재 시 그대로 유지
  - 새 설치/초기 사용자만 shanks 기본값 적용
- **다크 모드**: 빨간색 계열이 다크 모드에서 과도하게 밝지 않도록 채도 조절
- **접근성**: 빨간-검정 대비 → 색맹 사용자 고려, 충분한 명도 대비 확보
- **watchOS**: Watch 테마도 동기화 필요 (DUNEWatch/DesignSystem.swift 미러링)

## Scope

### MVP (Must-have)
- [ ] AppTheme에 `shanksRed` case 추가
- [ ] 색상 팔레트 정의 (xcassets: Shanks prefix 20+개 컬러셋)
- [ ] AppTheme+View.swift에 shanksRed dispatch 추가
- [ ] ShanksWaveBackground (Tab/Detail/Sheet) 구현
- [ ] ThemePickerSection에 7번째 테마 행 추가
- [ ] 기본 테마를 `shanksRed`로 변경
- [ ] Score/Metric/HRZone/Weather/Tab 색상 전체 매핑
- [ ] watchOS 테마 동기화

### Nice-to-have (Future)
- [ ] 해적기 실루엣 오버레이 (SVG Shape)
- [ ] 패왕색 번개 애니메이션 효과
- [ ] 골드 파티클 드리프트
- [ ] 밀짚모자 빈 상태 일러스트
- [ ] 커스텀 앱 아이콘 (빨간머리 테마)
- [ ] serif 계열 타이포그래피 옵션 검토
- [ ] 날씨 연동 시 폭풍 → 패왕색 강화 연출

## Open Questions

1. **테마 rawValue 네이밍**: `shanksRed` vs `pirateRed` vs `redHair` — IP 리스크와 직관성 균형
2. **기본 테마 변경 전략**: 기존 사용자 migration 필요 여부 (resolvedTheme에서 처리 가능)
3. **해적기 실루엣 저작권**: 오리지널 디자인으로 "해적기 영감" 표현 시 충분한가
4. **타이포그래피**: 기존 rounded 유지 vs serif 도입 — Dynamic Type 호환성 테스트 필요

## 기존 테마 구조 참조

```
AppTheme enum
├── desertWarm  (prefix: 없음, 기본값)
├── oceanCool   (prefix: "Ocean")
├── forestGreen (prefix: "Forest")
├── sakuraCalm  (prefix: "Sakura")
├── arcticDawn  (prefix: "Arctic")
├── solarPop    (prefix: "Solar")
└── shanksRed   (prefix: "Shanks") ← NEW
```

**파일 추가/수정 예상**:

| 파일 | 작업 |
|------|------|
| `Domain/Models/AppTheme.swift` | case 추가 |
| `Presentation/Shared/Extensions/AppTheme+View.swift` | dispatch 추가 |
| `Shared/Resources/Colors.xcassets/Shanks*/` | 20+ 컬러셋 생성 |
| `Presentation/Shared/Components/ShanksWaveBackground.swift` | 신규 |
| `Presentation/Shared/Components/WaveShape.swift` | dispatch 추가 |
| `Presentation/Settings/Components/ThemePickerSection.swift` | 행 추가 |
| `DUNEWatch/DesignSystem.swift` | 테마 색상 미러링 |
| `DUNEWatch/Views/Extensions/AppTheme+WatchView.swift` | dispatch 추가 |

## Next Steps

- [ ] `/plan onepiece-shanks-theme` 으로 구현 계획 생성
