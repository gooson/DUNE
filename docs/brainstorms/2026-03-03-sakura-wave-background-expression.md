---
tags: [theme, sakura, wave-background, premium, recovery, dark-mode]
date: 2026-03-03
category: brainstorm
status: draft
---

# Brainstorm: Sakura WaveBackground Real Expression

## Problem Statement

현재 Sakura 테마는 색상 외에는 벚꽃 고유성이 약하고, 일부 표현이 Forest 테마 재활용처럼 보여 차별성이 부족하다.  
카드 레벨에서도 사쿠라 톤 강조가 약해 프리미엄한 회복(Recovery) 무드 전달이 충분하지 않다.

## Target Users

- 회복 중심 사용자 (컨디션 관리, 휴식/웰니스 중시)
- 사쿠라 테마 선택 시 기능성뿐 아니라 감성 품질과 프리미엄 비주얼을 기대하는 사용자

사용자 핵심 니즈:
- “실제 벚꽃 느낌”이 명확하게 보일 것
- 과하지 않고 고급스러운 톤일 것
- 다크모드에서도 무드/가독성이 유지될 것

## Success Criteria

- 첫 인상에서 Desert/Ocean/Forest와 즉시 구분되는 “사쿠라 배경”으로 인지된다.
- WaveBackground에 벚꽃 고유 요소(꽃잎/가지/부드러운 봄빛 레이어)가 실제로 보인다.
- 카드/강조 컴포넌트가 사쿠라 톤을 적극 반영해 테마 통일감이 높다.
- 다크모드에서도 벚꽃 레이어가 묻히지 않고 안정적으로 식별된다.

## Proposed Approach

1. 사쿠라 전용 모티프 재정의
- Forest 계열 실루엣 재사용을 중단하고, 사쿠라 전용 Shape/Layer 언어로 재구성
- 핵심 모티프:
  - 꽃잎 군집 능선(petal ridge)
  - 가지/잔가지 실루엣(얇은 브러시 스트로크)
  - 봄 안개(아이보리 보카시) + 부드러운 빛 번짐

2. WaveBackground의 “실제 사쿠라화”
- Tab/Detail/Sheet 공통으로 사쿠라 레이어를 유지하되 강도만 다르게 구성
- 레이어 구조 예시:
  - Back: 아이보리 haze + 보카시
  - Mid: 핑크 petal field
  - Front: 딥그린 branch/leaf anchor
  - Accent: 저속 drift petals (Reduce Motion 대응 가능)

3. 카드/표면 시각 강화
- Hero/Standard/Inline card border와 separator에 사쿠라 전용 그라데이션 강도 상향
- 카드 배경 톤을 사쿠라 아이보리/핑크 기반으로 미세 조정해 “테마가 카드까지 살아있게” 개선
- 상태 컬러(Score/Metric)도 사쿠라 톤 컨텍스트에 맞춘 채도/명도 재조정

4. 다크모드 가독성 전용 튜닝
- 사쿠라 밝은톤이 다크 배경에서 죽지 않도록 라이트 레이어 최소 opacity 상향
- branch/leaf 레이어 대비를 강화해 깊이 유지
- 라이트/다크 각각 별도 토큰 튜닝으로 동일 무드 유지

5. watchOS 경량화 분리 전략
- 시각 언어는 동일하되 레이어 수/샘플 수/파티클 수를 축소
- watch는 정적 + 저빈도 drift 중심으로 배터리 친화적 표현 유지

## Constraints

- 성능 제약: 명시적 제약 없음 (단, 제품 품질 관점에서 불필요한 과연산은 지양)
- 플랫폼 제약:
  - iOS: 풀 표현 허용
  - watchOS: 경량화 허용
- 디자인 제약:
  - 프리미엄 감성 유지
  - Forest 재활용 인상 제거

## Edge Cases

- 다크모드:
  - 밝은 petal/ivory 레이어가 사라지지 않도록 대비 보호 필요
- 접근성(Reduce Motion):
  - 파티클/드리프트 비활성 시에도 “사쿠라” 인지가 유지되어야 함
- 테마 전환 직후:
  - 애니메이션 정지/깜빡임 없이 자연스럽게 전환되어야 함
- 저사양/Watch:
  - 경량화 상태에서도 핵심 모티프(벚꽃성)가 유지되어야 함

## Scope

### MVP (Must-have)

- Sakura 전용 WaveBackground 시각 언어 전면 교체 (Tab/Detail/Sheet)
- 카드 레벨 사쿠라 강조(gradient/border/surface) 강화
- 다크모드 별도 튜닝
- iOS + watchOS 동시 반영 (watch는 경량화 버전)

### Nice-to-have (Future)

- 계절감 기반 사쿠라 변형(만개/흩날림 강도 프리셋)
- 미세 파티클 품질 옵션 (배터리/성능 프로파일 연동)
- 사용자 커스터마이징(사쿠라 강도 슬라이더)

## Open Questions

- “실제 벚꽃 느낌”의 리얼리즘 레벨을 어디까지 올릴지 (미니멀 vs 일러스트 풍)
- 카드 강조 강도 상향 시 정보 가독성과의 균형 기준
- Reduce Motion에서 petals를 완전 제거할지, 저빈도 이동만 유지할지

## Next Steps

- [ ] `/plan sakura wave background real expression` 으로 구현 계획 생성
