---
tags: [theme, sakura, dark-mode, readability, premium-ui]
date: 2026-03-03
category: brainstorm
status: draft
---

# Brainstorm: Dark Sakura Mode Polish

## Problem Statement

라이트 모드의 사쿠라 감성은 유지되고 있으나, 다크 모드에서는 배경/카드 레이어가 겹치며 정보 가독성이 떨어지고 전체 인상이 다소 탁하게 느껴진다.  
목표는 벚꽃 정체성을 유지하면서도 더 은은하고 고급스러운 정보 전달감을 확보하는 것이다.

## Target Users

- 운동/건강 데이터를 볼 때 심리적 안정감과 회복 무드를 원하는 사용자
- 야간 환경에서 앱을 자주 보는 사용자
- 기능성뿐 아니라 고급스러운 시각 완성도를 중요하게 여기는 사용자

## Success Criteria

- 다크 모드에서 본문/보조 정보가 이전보다 더 빠르게 식별된다.
- 사쿠라 톤(벚꽃 느낌)은 유지되면서 과한 핑크 안개/혼탁감이 줄어든다.
- 전체 인상이 화려함보다 정제된 프리미엄 무드로 느껴진다.

## Proposed Approach

1. 다크 모드 전용 배경 강도 재조정
- `SakuraWaveBackground`의 dark `visibilityBoost`, haze/petal/branch opacity를 미세 하향
- 카드 뒤 영역에 가벼운 dark veil(스크림)로 콘텐츠 우선순위 강화

2. 사쿠라 카드 레이어 정제
- `GlassCard`, `SectionGroup`의 dark 전용 표면 오버레이를 밝은 톤 중심에서 dusk 보강형으로 재구성
- border/bloom 강도를 낮춰 화려함 대신 고급스러운 선명도 확보

3. 감성 유지 가드레일
- 라이트 모드 값은 유지하고 dark-only 분기만 수정
- 벚꽃 모티프(꽃잎/가지)는 제거하지 않고 강도만 조정

## Constraints

- 벚꽃 정체성은 유지해야 함
- “고급지고 은은한 느낌”을 해치지 않아야 함
- 기술적/시간적 제약은 없음

## Edge Cases

- 데이터 카드가 많은 날에도 배경이 정보를 압도하지 않아야 함
- `Reduce Motion` 활성화 시에도 사쿠라 정체성 유지
- 날씨 오버레이가 활성화된 today 화면에서도 텍스트 식별성 유지

## Scope

### MVP (Must-have)

- 다크 모드 가독성 개선
- 다크 모드 프리미엄 톤 정제
- 사쿠라 디자인 정체성 유지

### Nice-to-have (Future)

- 다크 모드 전용 사쿠라 강도 프리셋(soft/standard)
- High Contrast 접근성 모드용 사쿠라 토큰 분리

## Open Questions

- 대비 개선을 정량화할 최소 기준(예: 본문/보조 텍스트 contrast ratio 기준)을 팀 단위로 고정할지 여부
- 스크린샷 리뷰와 실제 기기(밝기 자동/True Tone) 평가 비중을 어떻게 배분할지 여부

## Next Steps

- [ ] /plan sakura dark mode readability polish
