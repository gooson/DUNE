---
tags: [theme, arctic-dawn, aurora, performance, swiftui, ios, watchos]
date: 2026-03-04
category: brainstorm
status: draft
---

# Brainstorm: Arctic Aurora Performance (Quality-Preserved)

## Problem Statement

Arctic Dawn(오로라) 테마는 시각 품질은 높지만, 배경 레이어 수와 동시 애니메이션 수가 많아
일부 화면/기기에서 프레임 안정성과 배터리 효율 저하 위험이 있다.
핵심 목표는 "현재 퀄리티 인상은 유지"하면서 렌더링 비용을 줄이는 것이다.

## Target Users

- Arctic Dawn 테마를 선호하는 기존 사용자
- iOS/Watch에서 테마 일관성을 기대하는 사용자
- 구형/저전력 상태에서도 부드러운 체감을 원하는 사용자

사용자 핵심 니즈:
- 오로라 무드는 그대로 유지
- 스크롤/전환/탭 이동 시 끊김 최소화
- 배터리 소모 체감 완화

## Success Criteria

- 시각 품질 유지:
- Arctic Dawn 핵심 모티프(오로라 커튼, 리본, 엣지 글로우) 인지력 유지
- 기존 스냅샷 대비 주요 레이아웃/색감 회귀 없음

- 성능 개선:
- Tab/Detail/Sheet 진입 후 초기 3초 프레임 드랍 빈도 감소
- 백그라운드 레이어 렌더링 시간(상대값) 유의미 감소
- watchOS에서 동일 무드 대비 애니메이션 비용 감소

- 접근성/안정성 유지:
- Reduce Motion/저전력 모드에서 일관된 degrade 전략 동작
- 테마 전환 시 애니메이션 겹침/재시작 아티팩트 없음

## Proposed Approach

### 1) Quality Lock 먼저 정의 (비주얼 후퇴 방지)

- Arctic Dawn 기준 스냅샷 골든(라이트/다크, Tab/Detail/Sheet, iOS/watch) 고정
- "절대 유지 요소"를 명시:
- 상단 오로라 커튼 존재감
- 중단 리본 레이어 깊이감
- 하단 엣지 글로우 하이라이트
- 변경 후에도 위 3요소가 동시에 인지되는지 체크리스트화

### 2) 병목 구간 계측을 먼저 추가

- `ArcticTabWaveBackground`, `ArcticDetailWaveBackground`, `ArcticSheetWaveBackground` 렌더 구간 측정
- `ArcticAuroraCurtainOverlayView`, `ArcticAuroraMicroDetailOverlayView`, `ArcticAuroraEdgeTextureOverlayView` 비용 분리 측정
- 개선 전/후 동일 시나리오 비교(테마 전환, 탭 왕복, 시트 열기)

### 3) "보이는 결과 동일" 중심의 비용 절감

- 다중 독립 애니메이션 루프 정리:
- 현재 레이어별 `phase` 애니메이션을 공용 타임베이스로 통합해 상태 업데이트 수 축소

- 미세 디테일 레이어 축소/대체:
- `ArcticAuroraMicroDetailOverlayView`의 다량 `Capsule`/`Circle` 반복 렌더를
  밀도 기반 LOD(Level of Detail)로 분기
- 고비용 구간은 Canvas/텍스처화(또는 seed 수 축소)로 시각 인상은 유지하고 draw call 감축

- Blur + Blend 중첩 최적화:
- 동일 영역의 반복 `blur` + `blendMode(.screen/.plusLighter)` 조합 수를 줄이고,
  핵심 레이어만 하이라이트 유지
- 거의 체감이 없는 후방 글로우는 정적 gradient로 대체

- Shape 샘플링/마스크 비용 조정:
- `ArcticRibbonShape`, `ArcticAuroraCurtainShape` sample count를 고정값 1개가 아닌
  컨텍스트별(화면 타입/기기 상태) 가변 전략으로 적용

### 4) 품질 유지형 적응형 렌더링

- 조건 기반 품질 단계 도입:
- `normal`: 현재 시각 품질 유지
- `conserve`: 저전력/워치/백그라운드 복귀 직후에 미세 레이어 강도 축소

- 단계 전환 원칙:
- 색/구도는 유지하고 "디테일 밀도와 모션 진폭"만 축소
- 사용자에게 테마가 달라졌다는 인상은 주지 않음

### 5) watchOS 전용 비용 캡

- watch 배경은 이미 경량화되어 있지만, Arctic 전용 커튼/글로우 레이어가 여전히 상대적으로 무거움
- watch에서는
- 커튼 개수 축소
- 하이라이트/필라멘트 라인 수 축소
- 필요 시 마이크로 디테일 레이어 비활성
- 대신 색상 그라데이션 대비로 동일 무드 유지

### 6) 회귀 방지

- 테마 스냅샷 테스트 케이스에 Arctic 강도별(기본/저전력) 캡처 추가
- 성능 체크 스모크 시나리오를 CI 또는 로컬 체크리스트로 고정
- 신규 테마/레이어 추가 시 "레이어 예산" 규칙 문서화

## Constraints

- 비주얼 제약: 오로라 정체성(커튼/리본/엣지 글로우) 유지 필수
- 플랫폼 제약: iOS + watchOS 동시 품질 기준 필요
- 접근성 제약: Reduce Motion에서 표현 약화는 가능하나 테마 인지성은 유지
- 리소스 제약: 대규모 아트 에셋 추가 없이 코드 중심 최적화 우선

## Edge Cases

- 테마 전환 직후: 애니메이션 루프 중복 시작으로 phase 불일치 발생 가능
- 저전력 모드 on/off: 품질 단계 전환 시 깜빡임/색온도 급변 가능
- watch 저휘도(AOD) 상태: 디테일이 사라져 오로라 인지가 약해질 가능성
- 다크 모드: 블러/블렌드 축소 시 배경이 평면적으로 보일 가능성

## Scope

### MVP (Must-have)

- Arctic 배경 계측 포인트 추가 + 개선 전/후 비교
- 공용 타임베이스 도입(애니메이션 루프 통합)
- 마이크로 디테일 레이어 LOD 적용
- watch 전용 비용 캡(커튼/필라멘트/글로우 단계 축소)
- Arctic 스냅샷 회귀 체크 보강

### Nice-to-have (Future)

- 기기 성능 등급 기반 자동 품질 튜닝
- 사용자 설정의 "배경 효과 강도" 옵션
- 오로라 디테일 프리렌더 캐시(초기 로드 최적화)

## Open Questions

- 성능 목표 기준: "프레임 안정성"과 "배터리" 중 우선순위는 무엇인지
- 퀄리티 고정 기준: 절대 타협 불가 레이어(예: 커튼 vs 글로우) 우선순위
- 품질 단계 전환 허용 범위: 사용자가 알아채지 못할 수준의 디테일 축소 한계
- watch에서 허용 가능한 단순화 수준

## Next Steps

- [ ] `/plan arctic aurora performance preserve quality` 으로 구현 계획 생성
