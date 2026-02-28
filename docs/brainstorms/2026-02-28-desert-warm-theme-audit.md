---
tags: [design-system, desert-warm, theme, visual-audit, dark-mode]
date: 2026-02-28
category: brainstorm
status: draft
---

# Brainstorm: Desert Warm 테마 전체 디자인 리뷰 및 개선

## Problem Statement

앱 전체에서 "Desert Warm" 테마의 적용이 불균일함. Hero Cards, Activity Charts 등 핵심 UI는 강하지만, Settings, Watch, Empty States 등은 시스템 기본 스타일에 가까움. 하드코딩된 컬러/opacity가 산재하고, 시스템 컬러(.secondary/.primary)가 100+곳에서 warm tone과 불일치하게 사용됨.

## Target Users

- 앱 사용자 전체 (light + dark mode)
- watchOS 사용자

## Success Criteria

1. 하드코딩 RGB/HSB 컬러 → DS 토큰 전환 완료 (0개 잔존)
2. DS.Color.textPrimary/textSecondary/textTertiary 토큰 생성 + 전면 적용
3. Activity 카테고리 10개 모두 dark mode variant 보유
4. 주요 opacity 사용처 DS.Opacity 토큰화 (186곳 → 토큰 사용)
5. Settings/Watch/Empty States 테마 강화
6. iOS 빌드 + 테스트 통과

## Proposed Approach

### Phase 1: DS 토큰 확장
- `DS.Color.textPrimary` / `textSecondary` / `textTertiary` 추가
- `DS.Opacity` 토큰 확장 (현 5개 → 필요한 만큼)
- Activity 카테고리 dark mode variant 6개 추가

### Phase 2: 하드코딩 제거
- WorkoutShareCard RGB 5곳 → DS 토큰
- FatigueLevel HSB 팔레트 → DS 캐싱 패턴
- 산재한 opacity 하드코딩 → DS.Opacity

### Phase 3: 시스템 컬러 교체
- `.foregroundStyle(.secondary)` → `DS.Color.textSecondary`
- `.foregroundStyle(.primary)` → `DS.Color.textPrimary`
- 100+곳 일괄 교체

### Phase 4: 약점 화면 강화
- Settings: warm icon tint, section header 강화
- Watch: iOS DS 동기화
- Empty States: 추가 warm 장식

### Phase 5: 검증
- iOS 빌드 통과
- Dark/Light mode 시각 점검
- Watch 빌드 통과

## Constraints

- Correction #120: light/dark 동일 색상은 universal만 유지
- Correction #136: 브랜드 컬러에 .accentColor 직접 사용 금지 (예외: ProgressRingView)
- Correction #137: AccentColor dark variant 추가 시 ring gradient 시각 테스트 필수
- Correction #177: DS 색상 토큰은 반드시 xcassets 패턴 사용
- 접근성(a11y): 텍스트 contrast ratio 4.5:1 이상 유지

## Scope

### MVP (이번 작업)
- DS 토큰 확장 (text colors, opacity)
- 하드코딩 컬러 제거
- 시스템 컬러 전면 교체
- Dark mode variant 추가
- Settings/Watch 테마 강화

### Future
- Custom font integration
- 애니메이션 테마 통일
- Accessibility high contrast 모드
- Widget 테마 적용

## Open Questions
- textPrimary/textSecondary의 light/dark mode RGB 값 결정
- opacity 토큰 추가 필요 수준 (현 5개로 충분한지)

## Next Steps
- [ ] /plan 으로 구현 계획 생성
