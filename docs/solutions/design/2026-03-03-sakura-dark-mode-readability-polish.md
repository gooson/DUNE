---
tags: [theme, sakura, dark-mode, readability, premium-ui, glasscard]
category: design
date: 2026-03-03
severity: important
related_files:
  - DUNE/Presentation/Shared/Components/SakuraWaveBackground.swift
  - DUNE/Presentation/Shared/Components/GlassCard.swift
  - DUNE/Presentation/Shared/Components/SectionGroup.swift
related_solutions:
  - docs/solutions/general/2026-03-03-sakura-wave-real-expression.md
  - docs/solutions/design/2026-03-02-sakura-calm-theme.md
---

# Solution: Sakura Dark Mode Readability Polish

## Problem

Sakura 테마의 다크 모드에서 배경 레이어와 카드 tint가 누적되면서 콘텐츠 레이어 분리가 약해졌다.  
벚꽃 정체성은 충분했지만, 정보 전달 관점에서는 텍스트/보조 지표의 즉시 식별성이 떨어지고 화면이 다소 탁하게 느껴졌다.

### Symptoms

- Today 탭 다크 모드에서 배경 존재감이 카드 콘텐츠보다 앞에 보임
- Hero/Standard/Inline 카드의 밝은 오버레이가 중첩되어 정보 밀도 높은 구간에서 가독성 저하
- SectionGroup 경계/표면 강도가 다소 화려해 “은은한 고급감”보다 장식감이 우세

### Root Cause

- `SakuraWaveBackground`의 dark `visibilityBoost`와 레이어 opacities가 강하게 설정됨
- `GlassCard`/`SectionGroup`의 dark 사쿠라 오버레이가 밝은 ivory/petal 비중 중심으로 구성됨
- foreground 분리용 dark veil이 없어 배경/정보 계층 대비가 약함

## Solution

다크 모드에서만 강도를 재조정해 배경을 한 단계 뒤로 보내고, 카드 표면은 depth 중심으로 정제했다.  
라이트 모드 값은 유지해 기존 사쿠라 감성을 보존했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `SakuraWaveBackground.swift` | dark `visibilityBoost`, haze/petal/branch/drift opacity 하향 + theme.cardBackground 기반 veil 추가 | 배경 존재감 유지 + 정보 우선순위 강화 |
| `GlassCard.swift` | dark 사쿠라 `hero/standard/inline` surface 밝기 하향, `dusk` depth 추가, border/bloom 강도 하향 | 고급스럽고 정돈된 카드 계층감 확보 |
| `SectionGroup.swift` | dark 사쿠라 surface/top bloom/border 강도 하향, border width 완화 | 섹션 컨테이너 장식 과밀 완화 및 가독성 개선 |

### Verification

- `xcodebuild -project DUNE/DUNE.xcodeproj -scheme DUNE -destination 'generic/platform=iOS Simulator' build -quiet` 통과
- `xcodebuild -project DUNE/DUNE.xcodeproj -scheme DUNETests -destination 'generic/platform=iOS Simulator' build-for-testing -quiet` 통과

## Prevention

### Checklist

- [ ] 다크 모드 테마 강화 시 `visibilityBoost` 증가만으로 해결하지 않고 foreground 분리(veil)도 함께 검토
- [ ] 카드 표면 tint 조정 시 밝은 톤(ivory/petal)과 depth 톤(dusk) 균형을 먼저 맞춘 뒤 border 강도 조정
- [ ] 라이트/다크를 동시에 바꾸기보다 dark-only 분기 우선 수정으로 회귀 범위 최소화

### Rule Addition (if applicable)

- 신규 룰 파일 추가는 불필요. 기존 `design-system`/`documentation-standards` 규칙 범위에서 관리 가능.
