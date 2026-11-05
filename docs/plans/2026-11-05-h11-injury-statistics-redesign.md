---
tags: [injury, statistics, hero, batch01]
date: 2026-11-05
category: plan
status: approved
confidence: high
---

# H11 부상 통계 구현 계획

## Context / Requirements

기록 건수·활성 건수를 히어로로 강조하고 회복일·부위 빈도·운동량 비교의 위계를 정리한다. 서비스 통계·반올림·단위·원래 빈 섹션 조건은 유지한다. 의료 점수나 새 추정값은 만들지 않는다.

## Affected Files

| File | Change |
|---|---|
| `DUNE/Presentation/Injury/InjuryStatisticsView.swift` | Overview HeroCard·선행 기호·회복 보조 타일·축 글씨 대비·AX |
| `DUNEUITests/Full/WellnessRegressionTests.swift` | 원래 통계 진입 검사를 실제 값/차트/뒤로 확인으로 보강, MAX 핵심 필드 |
| H11 layout/theme/index/README/manifest | 구현 전 기준 보존 |
| actual map H11·검증 갤러리 | 새 실제 PNG/AX와 명시한 범위로 갱신 |

## Implementation Steps

1. 기존 `InjuryStatisticsService` 결과·volumeComparisons·빈 데이터 분기를 확인한다.
2. 전용 layout/theme 맵을 먼저 보존한다. 실제 Total/Active를 HeroCard로, 원래 평균/최장 회복일은 보조 타일로 둔다. 큰 글씨에서는 기존 AnyLayout 세로 전환을 유지한다.
3. 빈도 가로 막대와 Before/During/After 원래 비교 계산은 유지한다. 축 텍스트는 보조 텍스트 색으로 보완한다.
4. H10/H12/H13과 같은 빌드·기기 준비를 공유하되 H11의 실제 값·그래프·돌아가기와 MAX는 각각 검사한다.
5. 독립 리뷰·실제 캡처·문서 후 H11 PR을 분리한다.

## Testing Strategy / Risks

기존 opt-in injury fixture의 실제 총수/활성수/완료 회복일/두 부위 빈도를 확인한다. 일반 네 프로필 + Duo 접힘 MAX가 대상이며 정확한 selector와 1200초 예산은 통합 후보 고정 후 기록한다. 서비스·도메인 로직 미변경으로 새 unit/full 회귀는 추가하지 않는다. 빈 데이터는 원래 섹션 생략/nil 회복 — 처리 코드 보존을 리뷰한다. 같은 통합 실행의 다른 화면 결과를 H11 결과로 대신하지 않는다.
