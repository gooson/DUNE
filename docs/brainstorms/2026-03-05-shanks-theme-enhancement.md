---
tags: [theme, shanks, one-piece, branding, animation, interaction]
date: 2026-03-05
category: brainstorm
status: draft
---

# Brainstorm: 샹크스 테마 고도화 (브랜딩/감성 중심)

## Problem Statement

기존 샹크스 테마를 단순 색상 변경에서 벗어나, 브랜드 감성과 몰입을 강화하는 전면 테마 경험으로 고도화한다.

핵심 요구:
- 붉은머리 해적단 해적 깃발 모티프 추가
- 샹크스 특유의 배경 연출 추가
- 애니메이션/인터랙션/바텀 시트 포함, 전 화면 적용
- 실패 허용 없음(안정성 최우선)

## Target Users

- 전체 사용자
- 원피스를 좋아하는 사용자
- 테마 완성도와 감성 표현을 중요하게 여기는 사용자

## Success Criteria

1. iPhone/iPad 주요 화면 100%에서 샹크스 테마 토큰 적용 (Tab, Detail, Modal, Full Screen, Bottom Sheet)
2. Bottom Sheet의 `collapsed/half/full` 상태 전환에서 시각 깨짐/가독성 이슈 0건
3. 테마 관련 회귀 크래시 0건 및 기존 테마 전환 회귀 0건
4. 접근성 대비(텍스트/배경) 기준 충족, `Reduce Motion` 환경에서도 사용성 유지
5. 리소스 누락/로드 실패 시에도 앱이 안정적으로 fallback 동작

## Proposed Approach

### 1) 해적 깃발 모티프 추가

- 빨간머리 해적단 분위기를 반영한 오리지널 실루엣(저작권 리스크 최소화)
- 적용 위치:
  - 상단 Hero 영역 워터마크
  - 섹션 구분 장식
  - Bottom Sheet grabber 주변 엠블럼
- 인터랙션:
  - 테마 선택 시 깃발 리플(reveal) 애니메이션
  - 중요 액션 완료 시 짧은 하이라이트 펄스

### 2) 샹크스 시그니처 백그라운드

- 컨셉: `Red Hair Horizon`
- 레이어 구성:
  - Base: 딥 네이비-블랙 그라데이션
  - Mid: 크림슨 파도 레이어
  - Overlay: 천 질감(깃발 감성)
  - Accent: 골드 하이라이트/패기(streak) 포인트
- 화면별 변형:
  - Tab: 레이어 4개 전체
  - Detail: 파도 강도 축소 + 대비 우선
  - Bottom Sheet: 저강도 레이어 + 텍스트 가독성 우선

### 3) 전 화면 인터랙션 규칙

- 공통 모션 토큰(시간/커브) 통일
- Bottom Sheet 상태별 표현 차등:
  - `collapsed`: 장식 최소
  - `half`: 배경 표현 중간
  - `full`: 장식 최소 + 가독성 최우선
- 저사양/접근성 환경에서는 자동으로 정적 배경으로 degrade

### 4) 안정성 우선 설계

- fallback 체인: `Shanks -> 기본 테마 토큰`
- 리소스 사전 로드(prewarm) 및 캐시
- 런타임 가드: 누락 리소스 발생 시 안전한 대체 렌더링

### 5) 추가 개선 아이디어

- 테마 첫 적용 시 1회성 cinematic intro
- 목표 달성 시 샹크스 테마 전용 보상 이펙트
- 시간대/날씨 기반 tint 강도 자동 조절
- 사용자별 테마 강도(LOW/MID/HIGH) 설정 슬라이더
- Apple Watch 동기화 변형 테마 확장

## Constraints

- 디자인 시스템 토큰/컴포넌트 규칙 준수
- 기존 `AppTheme` 및 dispatch 구조 유지
- 저작권 제약: 공식 로고/캐릭터 아트 직접 사용 금지, 영감 기반 오리지널 그래픽 사용
- 성능 제약: `Reduce Motion`, 저전력, 저사양 기기에서도 프레임 저하 최소화

## Edge Cases

- 테마 리소스 로드 실패(이미지/컬러셋 누락)
- Bottom Sheet + 내부 스크롤 제스처 충돌
- 다크/라이트 모드 전환 직후 깜빡임
- iPad 멀티태스킹(분할 화면)에서 레이아웃 깨짐
- 접근성 설정(고대비/Reduce Motion/VoiceOver) 동시 활성화

## Scope

### MVP (Must-have)

- [ ] 오리지널 해적 깃발 모티프 컴포넌트 추가
- [ ] 샹크스 백그라운드(Tab/Detail/Bottom Sheet) 구현
- [ ] 핵심 화면 전반 테마 적용 (전 화면 기준 정의 후 100% 반영)
- [ ] Bottom Sheet 상태별 인터랙션/가독성 규칙 적용
- [ ] 실패 대응(fallback + 런타임 가드) 구현
- [ ] 접근성/성능 대응(`Reduce Motion`, 고대비, 저전력) 구현
- [ ] UI 회귀 테스트 및 기본 성능 검증

### Nice-to-have (Future)

- [ ] 테마 1회성 인트로 연출 강화
- [ ] 목표 달성 테마 이펙트 확장
- [ ] 시간대/날씨 적응형 테마
- [ ] 사용자별 테마 강도 커스터마이징
- [ ] Watch 전용 테마 연출 확장

## Open Questions

- 성공 KPI를 어떤 지표로 측정할지(적용률/체류시간/사용자 피드백)
- "전 화면" 범위에 Watch 앱까지 포함할지
- 목표 릴리스 버전/일정
- 저작권 검토 기준(깃발 유사도 허용 범위)

## Next Steps

- [ ] `/plan shanks-theme-enhancement` 으로 구현 계획 생성
