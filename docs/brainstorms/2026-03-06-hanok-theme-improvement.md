---
tags: [theme, hanok, korean, materiality, tile, dancheong, hanji]
date: 2026-03-06
category: brainstorm
status: draft
---

# Brainstorm: 한옥 테마 개선

## Problem Statement

현재 한옥 테마는 전체 앱에 적용 가능한 기본 골격은 갖추고 있지만, 실제 인상은 "색만 바뀐 테마"에 가까움. 한옥 특유의 **소재감**과 **형태 언어**가 부족해서 사용자가 첫인상에서 한옥을 즉시 떠올리기 어렵다.

핵심 부족 요소:

- 기와의 청회색, 먹빛, 겹침 리듬이 약함
- 단청의 포인트 컬러가 거의 느껴지지 않음
- 한지 질감 같은 재료감이 없음
- 처마 곡선, 궁전 기와 끝 문양 같은 상징적인 실루엣이 없음

결과적으로 한국적 감성, 프리미엄 무드, 한옥 정체성이 충분히 전달되지 않는다.

## Target Users

- 앱 전체 사용자
- 한눈에 감성적이고 완성도 높은 테마를 기대하는 사용자
- 한국적 분위기와 premium look을 선호하는 사용자

## Success Criteria

1. 테마 진입 첫인상에서 "한옥 같다"는 인지가 바로 생긴다
2. 색감이 단순 earthy tone이 아니라 기와, 단청, 한지 기반으로 읽힌다
3. 전체 앱에서 다른 테마와 동일한 완성도로 일관 적용된다
4. 전통 요소가 들어가도 촌스럽지 않고 고급스럽게 느껴진다
5. subtle animation이 배경 완성도를 높이되 가독성과 사용성을 해치지 않는다

## Proposed Approach

### 1. Palette: 기와 + 단청 + 한지 중심 재설계

- 테마의 base identity를 황토/갈색 중심에서 **기와 청회색 + 먹회색** 중심으로 이동
- 배경과 큰 면적은 저채도, 절제된 톤으로 유지
- accent는 단청 청록, 주홍, 절제된 금빛 계열을 소량만 사용
- 한지의 따뜻한 아이보리 톤을 보조 background와 surface에 적용

추천 방향:

- Base: 청회색, 먹회색, 짙은 목재색
- Surface: 한지 아이보리, 연한 회백색
- Accent: 단청 청록, 단청 주홍, 포인트 황금색

### 2. Graphic Language: 한옥을 즉시 떠올리게 하는 형태 추가

- 배경 상단 또는 hero 영역에 **처마 실루엣** 추가
- 웨이브/곡선 구조를 단순한 abstract shape가 아니라 **기와 겹침 리듬**으로 재해석
- near layer 또는 강조 포인트에 **궁전 기와 끝 문양**을 premium하게 단순화해 적용
- section border, highlight, 장식선 일부에 단청 띠 느낌의 pattern 사용

### 3. Materiality: 평면 색 변경이 아니라 재료감 표현

- detail/sheet/card background에 **한지 texture**를 미세하게 오버레이
- 기와의 유약 표면처럼 보이는 얇은 highlight나 sheen 추가
- 목재색은 중심이 아니라 보조적인 warmth 용도로만 제한
- full illustration보다 silhouette, pattern, texture 위주로 정리해서 과한 장식감 방지

### 4. Motion: 정적인 테마 인상 제거

- 바람이 지나가는 듯한 매우 느린 sway animation
- 기와 상단 highlight가 미세하게 흐르는 shimmer
- 단청 포인트는 움직임보다 정적인 장식 밀도로 존재감 확보
- `Reduce Motion` 환경에서는 정적 상태로 자연스럽게 축소

### 5. App-wide Consistency: 앱 전체에 동일 품질로 확장

- 다른 테마와 동일하게 Tab, Detail, Sheet, 주요 카드에 공통 적용
- 색상 token, background motif, ornament 규칙을 theme 단위 single source로 관리
- chart, ring, glass surface, icon accent까지 palette harmony 점검

## Constraints

- 다른 테마들과 동일한 적용 범위를 유지해야 함
- animation 추가와 custom background 추가는 가능함
- 앱 전체 개선이 목표이므로 특정 화면만 과도하게 차별화하면 안 됨
- 장식 요소가 데이터 가독성과 정보 위계를 침범하면 안 됨
- premium 방향을 유지해야 하므로 과포화 색상과 과한 민속풍 연출은 피해야 함

## Edge Cases

- 사용자가 테마 이름을 몰라도 시각적으로 한국적 정체성을 느껴야 함
- 작은 화면에서도 기와 실루엣과 문양이 노이즈처럼 보이지 않아야 함
- 다크 모드에서도 한지 질감이 탁해지지 않고 기와 색감이 죽지 않아야 함
- 장식이 늘어나도 헬스 데이터의 가독성과 상호작용은 동일하게 유지되어야 함

## Scope

### MVP (Must-have)

- 기와 중심 팔레트로 primary/background 색상 재정의
- 처마 또는 기와 실루엣을 핵심 배경에 반영
- 고급스러운 궁전 기와 끝 문양 추가
- 단청 accent color를 소량 도입해 정체성 강화
- 한지 texture 추가로 소재감 보완
- subtle animation 추가로 정적 인상 제거
- 앱 전체 테마 품질을 동일 수준으로 끌어올림

### Nice-to-have (Future)

- 계절/시간대에 따른 한옥 variation
- 화면별 문양 밀도 자동 조절
- 특정 화면에만 보이는 단청 세부 패턴
- 더 정교한 custom illustration 또는 material shader 표현

## Open Questions

- 궁전 기와 끝 문양을 hero 배경에만 둘지, 주요 카드/section까지 확장할지
- 단청 accent를 ring, icon, CTA까지 확장할지, 장식 포인트로 제한할지
- 한지 texture 강도를 얼마나 줄지: 존재감 위주 vs 거의 느껴지지 않는 premium grain

## Next Steps

- [ ] `/plan 한옥 테마 개선` 으로 구현 계획 생성
- [ ] palette 후보 2-3안을 정의하고 preview 비교
- [ ] 배경 motif 우선순위 확정: 처마 / 기와 / 단청 / 한지
