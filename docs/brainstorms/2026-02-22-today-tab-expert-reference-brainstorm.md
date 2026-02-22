---
tags: [today-tab, ux, dashboard, evidence, healthkit, coaching, pinned-metrics]
date: 2026-02-22
category: brainstorm
status: approved
---

# Brainstorm: Today 탭 개선 (전문가 레퍼런스 기반)

## Problem Statement

현재 Today 탭(`DashboardView`)은 데이터 카드 중심 구조라 **"지금 내 상태를 5초 내 판단"**하기 어렵다.

- 강점: 데이터 소스(Health Signals/Activity) 분리, 부분 실패 내성, fallback 데이터 처리
- 한계:
  - 최상단 핵심 메시지(오늘의 readiness/요약)가 약함
  - 변화 해석이 주로 단일 시점 비교에 머무름(장기 baseline 대비 부족)
  - 데이터는 있지만 행동으로 연결되는 "다음 한 가지" 제안이 약함
  - 사용자별 중요 지표 우선순위(핀/개인화)가 없음

## Target Users

- 아침에 빠르게 컨디션 판단하고 싶은 Apple Watch 사용자
- 운동 계획을 조절해야 하는 사용자(오늘 강도 판단 필요)
- 데이터는 보되 복잡한 분석보다 "해석 + 액션"을 원하는 사용자

## Success Criteria

- [ ] 진입 후 5초 내: 오늘 상태(좋음/주의)와 이유 1줄 파악
- [ ] 진입 후 10초 내: 오늘 할 행동 1개 선택 가능(예: 강도 낮춤, 회복 우선)
- [ ] 탭 이탈 없이: 핵심 지표 3~5개 + 추세 + 액션 확인
- [ ] 데이터 누락/지연 시에도 의미 있는 화면 유지(신뢰 라벨 포함)

## Decisions (2026-02-22)

| 항목 | 결정 |
|------|------|
| Today 탭 1순위 목적 | 상태판단 + 습관동기 |
| 성공 지표 | 주간 목표 달성률 |
| 핵심 타깃 | 운동 중심 사용자 |
| 스프린트 범위 | UI + 로직 (데이터 모델 대규모 변경 제외) |
| MVP 필수 | 히어로+코칭, 핀 카드+신선도, baseline 추세 |

## Proposed Approach

### 1) "One Big Thing" 히어로 복원/강화

Today 상단에 단일 핵심 상태 카드를 둔다.

- 표시: `오늘 상태 점수` + `상태 라벨` + `왜 이런지 1줄`
- 근거 지표: HRV, RHR, 수면(있으면), 활동부하
- 세부 근거는 tap 시 확장(Progressive disclosure)

근거:
- Apple Activity는 3개 링으로 하루 상태를 즉시 요약하는 패턴을 사용한다.
- Oura는 Readiness를 단일 점수 + 기여 요인으로 제공해 당일 의사결정을 빠르게 돕는다.
- Nature Medicine 리뷰(2023)는 건강 시각화에서 "명확한 핵심 메시지"와 해석 가능성이 중요하다고 제시한다.
- NN/g Heuristics는 `Visibility of system status`와 `Recognition rather than recall`을 핵심 원칙으로 제시한다.

### 2) 카드 개인화 (Pinned Metrics)

모든 사용자에게 동일 카드 순서를 강제하지 말고, Today 상단 카드 3개를 핀 선택 가능하게 한다.

- 기본 추천(초기값): HRV, RHR, Sleep/Recovery
- 사용자 설정: `Edit Today`에서 top 3 pin
- 미선택 카드는 하단 섹션으로 유지

근거:
- Apple Health Summary는 Pinned 편집을 통해 사용자 우선순위를 반영한다.
- mHealth engagement review(2024)는 참여도 정의가 다양하며, 로그인만으로는 부족하므로 사용자 맥락 기반 설계가 필요함을 지적한다.
- NN/g Heuristics는 `Flexibility and efficiency of use`에서 personalization/customization을 권장한다.

### 3) 추세를 "오늘 vs 어제"에서 "단기 vs 장기 baseline"으로 확장

현재 변화량을 유지하되, 판단 기준을 2축으로 표시한다.

- 축 A: 전일 대비(짧은 변동)
- 축 B: 14일/60일 baseline 대비(개인 정상 범위)
- 표현: `▲/▼ + 상태 점(dot) + 데이터 신선도`

근거:
- Apple Fitness Trends는 90일 vs 365일 비교로 단기 잡음을 줄인다.
- Oura Readiness는 14일 가중 평균 vs 2개월 평균 비교를 명시한다.

### 4) 액션 가능한 코칭(한 줄 처방)

상태 요약 아래에 "오늘의 행동 1개"를 노출한다.

- 예시:
  - Recovery 낮음: "고강도 대신 20-30분 저강도"
  - 수면 부족: "카페인 컷오프 시간 안내"
  - 활동 과부하: "easy day 추천"
- 버튼: `Apply as training hint` (Train 탭 파라미터로 전달)

근거:
- Apple Watch는 하락 트렌드 시 행동 코칭 메시지를 제공한다.
- 피트니스 mHealth 연구(2023)에서 "목표 추적 기능"은 루틴 사용과 강한 상관(OR 5.10), 개인화 부재는 이탈 요인으로 보고됨.

### 5) 데이터 신뢰도/신선도 가시화

값만 보여주지 말고 "이 데이터가 언제 측정됐는지"를 카드 레벨에서 고정 노출한다.

- 라벨: `Today`, `Yesterday`, `3d ago`
- 신선도에 따라 시각적 강도 조절(opacity/secondary tone)
- Historical fallback 사용 시 change 계산 제한(이미 코드 철학과 일치)

근거:
- 대시보드 설계 리뷰들은 human factors를 반영하지 않으면 의사결정 보조 품질이 떨어진다고 지적한다.

### 6) 회고 루프(태그/컨텍스트) 연결

지표 변화 이유를 사용자가 기록하고 다음 주에 회고 가능하게 한다.

- Today quick action: `Tag today` (스트레스, 음주, 수면부족 등)
- 주간 뷰에서 태그와 지표 변화를 함께 표시

근거:
- Oura는 Tags를 통해 습관/환경 요인을 트렌드와 연결해 해석한다.
- Lived Informatics 모델은 추적-해석-행동-중단/재개 루프를 고려한 설계를 권고한다.

## Constraints

- HealthKit 데이터 가용성 편차(특히 아침 early-time missing)
- 의료기기 아님 고지 필요(과도한 진단형 문구 금지)
- 현재 아키텍처 경계 준수 필요
  - Domain 순수성 유지
  - ViewModel에 UI 타입 유입 금지
- iPhone/iPad 공통 레이아웃 안정성 필요

## Edge Cases

- 데이터 전무: 권한 온보딩 + 첫 데이터 생성 가이드
- 일부 데이터만 존재: partial failure 배너 + 남은 데이터로 최소 판단 제공
- 오래된 데이터만 존재: historical 라벨 + 행동 제안 보수적 조정
- 신호 충돌(HRV↑, 수면↓ 등): 단일 점수보다 "불일치" 배지와 보수적 권고

## Scope

### MVP (Must-have)

- Today 히어로(상태 점수 + 1줄 요약 + 1줄 행동)
- 카드 신선도 라벨 표준화(`Today/Yesterday/Nd ago`)
- Top 3 pinned metrics
- 단기/장기 추세 이중 표시(전일 + baseline)

### Nice-to-have (Future)

- 사용자 목표 기반 카드 자동 정렬
- 태그 기반 인사이트(예: late meal ↔ HRV 하락)
- 위젯/Live Activity로 "오늘 상태" 외부 노출
- 추천 행동의 성공률 개인화

## Expert References

1. Apple Support - Health app Summary/Pinned/Highlights/Trend notifications
- https://support.apple.com/en-us/HT203037

2. Apple Watch User Guide - Activity Rings, Trends(90일 vs 365일), coaching
- https://support.apple.com/guide/watch/track-daily-activity-apd3bf6d85a6/watchos

3. Oura Help - Readiness 개념(회복+활동 균형, 단/장기 지표)
- https://support.ouraring.com/hc/en-us/articles/360025589793-How-Your-Readiness-Score-is-Determined

4. Oura Help - Widgets(핵심 점수 glanceable), Tags(맥락 기록)
- https://support.ouraring.com/hc/en-us/articles/11785597429907-Oura-Widgets
- https://support.ouraring.com/hc/pl/articles/360038676993-Using-Tags

5. JMIR (2024) Systematic Review - mHealth engagement 측정/감소 패턴
- https://pubmed.ncbi.nlm.nih.gov/39316431/

6. Public Health Dashboard Scoping Review (2024) - 설계 원칙 5그룹
- https://pubmed.ncbi.nlm.nih.gov/38321469/

7. Patient Safety Dashboard Systematic Review (2021) - human factors 통합 필요
- https://pubmed.ncbi.nlm.nih.gov/34615664/

8. Nat Med (2023) - 건강 정보 시각화 프레임워크
- https://pubmed.ncbi.nlm.nih.gov/37156935/

9. mHealth fitness feature study (2023) - 목표 추적/개인화 영향
- https://pubmed.ncbi.nlm.nih.gov/38938369/

10. Lived Informatics model (2015) - tracking/acting/lapsing/resuming
- https://pubmed.ncbi.nlm.nih.gov/40959606/

11. Nielsen Norman Group (2024 update) - 10 Usability Heuristics
- https://www.nngroup.com/articles/ten-usability-heuristics/

## Next Steps

- [x] Open Questions 답변 수집
- [x] `/plan today-tab-redesign` 구현 계획 작성 완료 (`docs/plans/2026-02-22-today-tab-redesign.md`)
