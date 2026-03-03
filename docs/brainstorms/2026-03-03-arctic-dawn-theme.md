---
tags: [theme, arctic-dawn, glacier, aurora, wellness, watch-parity]
date: 2026-03-03
category: brainstorm
status: draft
---

# Brainstorm: Arctic Dawn Theme (Glacier + Aurora)

## Problem Statement

현재 테마(Desert/Ocean/Forest/Sakura)는 각각 개성이 있으나, 일반 웰니스 사용자를 위한
"차분하지만 차별화된 감성" 관점에서 빙하/오로라 계열 무드는 아직 부재하다.
기존 자연 테마와 겹치지 않으면서도 회복감, 맑음, 프리미엄 무드를 전달하는 신규 테마가 필요하다.

## Target Users

- 일반 웰니스 사용자
- 강한 자극보다 정서적 안정감과 시각적 차별화를 원하는 사용자

사용자 핵심 니즈:
- 기존 테마와 즉시 구분되는 첫인상
- 과하지 않고 오래 봐도 편안한 화면
- iOS와 watchOS에서 동일한 테마 정체성

## Success Criteria

- 테마 선택 직후 Desert/Ocean/Forest/Sakura와 명확히 다른 "빙하+오로라" 분위기가 인지된다.
- Today/Activity/Wellness/Life 핵심 화면과 카드가 Arctic Dawn 톤으로 일관되게 보인다.
- 라이트/다크 모드 모두에서 텍스트 가독성과 정보 우선순위가 유지된다.
- watchOS에서도 경량화된 동일 시각 언어가 적용되어 플랫폼 간 이질감이 없다.

## Proposed Approach

### 1. 시각 컨셉 정의 (차별화 축 고정)

- 키워드: glacier clarity, aurora veil, cold calm, breathable space
- 핵심 모티프:
- 얇은 오로라 리본 레이어 (저속 이동)
- 빙하 안개/서리 느낌의 소프트 그라데이션
- 실버-아이스 하이라이트로 정보 영역 분리
- Desert의 warm grain, Ocean의 파도 강조, Forest의 실루엣, Sakura의 floral 감성을 재사용하지 않고
  Arctic 전용 형태 언어를 사용

### 2. 전체 UI 토큰 전면 적용 (사용자 요청 범위: 전부)

- 색상 토큰:
- accent, score, metric, tab, weather, card, separator, surface까지 Arctic prefix 토큰 세트 정의
- 컴포넌트:
- Hero/Standard/Inline card, 차트, 링, 배지, 버튼 강조색을 Arctic 팔레트로 동기화
- 배경:
- Tab/Detail/Sheet 배경을 공통 Arctic Dawn 배경 시스템으로 통일

### 3. 배경/모션 설계

- 레이어 구성 예시:
- Back: glacier fog gradient (정적 중심)
- Mid: aurora ribbon bands (저속 수평/대각 drift)
- Front: fine frost highlight (콘텐츠 프레임 보강)
- 모션 원칙:
- 눈에 띄는 "퍼포먼스형" 애니메이션 대신, 저빈도·저진폭으로 안정감 유지
- 컨텐츠 가독성 우선, 배경 존재감은 2순위

### 4. iOS + watchOS 동시 적용

- 시각 언어는 동일하게 유지
- watchOS는 레이어 수/샘플링/애니메이션 빈도를 줄인 경량 버전 적용
- `AppTheme` 공용 매핑 규칙에 맞춰 iOS/watch 동시 반영 누락 방지

### 5. 품질 검증 포인트

- 테마 전환 직후 배경 모션 정지/깜빡임 회귀 없음
- 다크 모드에서 카드/텍스트 대비 확보
- watch에서 성능 저하 없이 무드 유지

## Constraints

- 필수 제약:
- watchOS 동시 적용 필요
- 명시적으로 요구되지 않은 제약:
- 색약 대응 특화 튜닝 없음
- Reduce Motion 특화 분기 없음
- 단, 기본 접근성/가독성 품질은 유지

## Edge Cases

- 다크 모드에서 오로라/안개 레이어가 과해져 정보 레이어를 침범하는 경우
- 밝은 모드에서 냉색 팔레트가 "밋밋함"으로 인지되어 테마 차별성이 약해지는 경우
- iOS에서는 풍부하지만 watch에서는 지나치게 단순해 정체성이 약해지는 경우
- 테마 전환 직후 백그라운드 애니메이션 초기화 타이밍 불일치

## Scope

### MVP (Must-have)

- Arctic Dawn 신규 테마 추가 (AppTheme + iOS/watch 공통 매핑)
- Arctic 전용 토큰 세트 전체 정의 (accent/score/metric/tab/weather/card/surface)
- Tab/Detail/Sheet 배경의 Arctic 전용 비주얼 구현
- 핵심 컴포넌트(카드/차트/링/배지)의 Arctic 톤 전면 반영
- 라이트/다크 모드 가독성 검증
- watchOS 경량 버전 동시 구현

### Nice-to-have (Future)

- 오로라 강도 프리셋(Soft/Standard)
- 계절/시간대 기반 오로라 색온도 미세 변화
- 테마 미리보기 인터랙션 고도화

## Open Questions

- 오로라 표현 강도: "거의 안 보이는 고급스러움" vs "첫눈에 보이는 차별성" 중 기본값 결정
- 카드 톤: 아이시 글래스 느낌을 어디까지 허용할지(가독성/정보밀도 균형)
- watch 경량화 기준: 레이어 축소 우선 vs 모션 축소 우선

## Next Steps

- [ ] `/plan arctic dawn theme` 으로 구현 계획 생성
