---
tags: [recommendation, workout-template, sequence-mining, time-window, personalization]
category: architecture
date: 2026-03-07
severity: important
related_files:
  - docs/solutions/architecture/2026-03-04-life-tab-auto-workout-card-ux-ui.md
related_solutions:
  - docs/solutions/architecture/sleep-deficit-personal-average.md
  - docs/solutions/architecture/2026-02-17-wellness-tab-consolidation.md
---

# Solution: 일정 시간 내 연속 운동 패턴 기반 템플릿 추천 시스템

## Problem

운동 로그가 누적되어도 사용자가 반복 루틴을 재사용하기 어렵다. 특히 특정 시간대(예: 평일 아침 30분)에서 자주 수행한 연속 운동 조합이 있어도 수동으로 템플릿을 다시 구성해야 한다.

### Symptoms

- 같은 시간대에 반복 수행한 루틴이 로그에만 남고 재사용 가능한 형태로 승격되지 않는다.
- 템플릿 생성 진입 비용(운동 선택/순서 구성/시간 조절)이 높아 재사용률이 떨어진다.
- 앱은 단일 운동 추천은 가능해도 “연속 시퀀스” 추천 근거를 제시하지 못한다.

### Root Cause

- 현재 모델은 운동 단건 중심 저장/표시에 최적화되어 있고, “세션 내 연속 시퀀스”를 별도 엔티티로 추출하지 않는다.
- 시간 윈도우(예: 30분/45분)와 운동 간 간격(gap threshold)을 반영한 패턴 집계가 없다.
- 반복성, 최근성, 완료율을 결합한 점수화 규칙이 없어 추천 우선순위가 불명확하다.

## Solution

운동 로그를 “시간 윈도우 기반 세션”으로 재구성한 뒤, 반복 시퀀스를 템플릿 후보로 승격하는 추천 파이프라인을 설계한다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `docs/solutions/architecture/2026-03-07-windowed-workout-template-recommendation-system.md` | 추천 시스템 설계 문서 추가 | 연속 운동 템플릿 추천을 구현 가능한 단위로 명세화하기 위해 |

### Key Design

```text
1) 로그 정렬: 하루 단위로 운동 이벤트를 시작 시각 기준 정렬
2) 세션화: 인접 운동 간 간격 <= gapThreshold(예: 10분)이면 동일 세션으로 묶음
3) 시퀀스 정규화: 운동명/강도/순서를 canonical form으로 변환
4) 후보 집계: 최근 N주(예: 4~8주)에서 동일/유사 시퀀스 빈도 집계
5) 점수화: score = 0.5*frequency + 0.3*recency + 0.2*completionRate
6) 추천: 상위 K개(예: 3개) 템플릿 제안 + 근거 문구 제공
```

#### Data Modeling (MVP)

- `WorkoutEvent`: 기존 로그 원천 데이터
- `WorkoutSession`: 시간 윈도우 내 연속 이벤트 그룹
- `TemplateCandidate`: 정규화 시퀀스 + 통계(빈도/최근성/완료율)
- `RecommendedTemplate`: 사용자에게 노출되는 최종 카드(제목, 예상시간, 근거)

#### Similarity Rule (MVP)

- 완전 일치 우선
- 불완전 일치 허용: “운동 구성 겹침 비율 >= 70%”면 같은 후보군으로 병합
- 순서 편차는 1단계 swap까지 허용(옵션)

#### UX Contract

- 추천 카드 예시: `평일 아침 하체+코어 30분`
- 근거 표기: `최근 6주간 5회 반복, 평균 28분 소요`
- 원탭 시작 + 시작 전 미세 조정(운동 추가/삭제/순서 변경)

#### API Sketch

- `GET /templates/recommend?window=30m&lookback=42d`
- `POST /templates/{id}/apply`
- `POST /templates/{id}/feedback` (dismiss, started, completed)

## Prevention

### Checklist Addition

- [ ] 추천 기능은 “단건 운동”과 “연속 시퀀스”를 분리해 저장/집계한다.
- [ ] 추천 근거(반복 횟수, 평균 소요, 최근 수행일)를 UI에 항상 노출한다.
- [ ] MVP 단계에서는 복잡한 ML 이전에 규칙 기반 점수화를 먼저 검증한다.
- [ ] 유사 시퀀스 병합 임계치(예: 70%)는 A/B 테스트로 보정한다.

### Rule Addition (if applicable)

신규 규칙 파일 추가는 보류한다. 먼저 MVP 운영 지표(추천 클릭률, 시작률, 완료율, 재사용률)로 설계 유효성을 검증한다.

## Lessons Learned

운동 추천의 실사용 가치는 “무엇을 할지”보다 “언제/어떤 순서로 자주 했는지”에서 크게 올라간다. 따라서 시간 맥락 기반 시퀀스 추출과 설명 가능한 점수화가 템플릿 추천의 초기 성공 조건이다.
