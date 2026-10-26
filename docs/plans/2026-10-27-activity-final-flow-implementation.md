---
topic: activity-final-flow-implementation
tags: [activity, flow, hero, badges, accessibility]
date: 2026-10-27
category: plan
status: approved
confidence: high
related_solutions: [2026-10-26-shared-card-navigation-header, 2026-10-26-today-compact-density-and-pin-hit-area]
related_brainstorms: [2026-03-29-pr-visual-enhancement]
---

# Implementation Plan: Activity 최종 Flow와 4탭 히어로 제목

## Context

사용자가 반복 검토한 [최종 시안](../design/layout-map/activity-final-proposal.md)을 실제 앱에 적용하고 `/run`으로 검증·리뷰·병합한다. 기반은 origin/main a8dc387d다. 이 채팅이 만든 기존 미커밋 시안/PNG/맵 92개는 이번 기능의 설계 산출물로 포함한다. 다른 작업의 수정은 없다.

## Requirements

- 상태→운동 선택→기록/성취→누적 분석: 준비도, 근육 회복, 훈련 부담, 추천 운동, 최근 운동, 개인 기록, 달성 이력, 최근 7일, 보고서, 꾸준함, 28일 부하, 운동 구성.
- 준비도는 Today Compact의 104pt/7pt 링·외부 READINESS, 100점 척도 근거 가로 막대, 펼치는 기록 추세. 접근성 글씨에서는 외부 점수.
- 근육 지도는 앞/뒤·회복/세트 수와 기존 실제 팔레트 범례를 유지하고 루트 3D 진입 제거. 외부 3D 목적지는 삭제하지 않는다.
- 훈련 부담은 실제 관측 맥락/기간/누락을 설명한다. 관측값을 모두 위험 요인으로 과장하지 않는다.
- 개인 기록·달성·보고서·시간/칼로리·운동 구성은 시안의 시각적 강조를 적용한다. 기존 데이터의 실제 단위·기간·출처를 유지한다.
- 최근 운동은 최신 두 개, 이전 기록 펼침, 작은 분홍 Apple 마크, 유효한 평균 심박, 실제 workoutID 연결된 리본 메달/골드 PR 배지.
- 네 탭 히어로 상단은 CONDITION/READINESS/WELLNESS/HABITS. 설명은 사용자 언어, 상세는 기존 CardNavigationHeader/목적지를 재사용한다.
- 저장 스키마/HealthKit 쿼리/점수 계산은 변경하지 않는다. 빈 기록·누락·Other 범주·회복일을 가짜 데이터로 채우지 않는다.

## Approach

기존 컴포넌트·DS 토큰·팔레트·reward event를 재사용한다. iPad/Duo의 관련 카드 묶음만 두 열, 좁은 폭/접근성에서는 읽기 순서의 한 열로 배치한다. 주간 통계와 보고서는 원천이 달라 합치지 않는다. 실제 최근 운동일 합계와 28일 부하는 제목·기간으로 구분한다. 공식 SwiftUI ViewThatFits/AnyLayout 문서에서 확인한 대체 배치를 사용한다.

### Alternatives

| 접근 | 장점 | 단점 | 판단 |
|---|---|---|---|
| 모든 카드/집계 재작성 | 시안 그대로 고정 가능 | 데이터 중복·회귀 위험 | 제외 |
| 기존 컴포넌트 표현·배치 개선 | 데이터/내비게이션 계약 보존 | 예시 수치와 실제 결과는 다름 | 선택 |

## Affected Files

| 파일/범위 | 변경 |
|---|---|
| ActivityView.swift, ReadinessHeroEvidenceView.swift | Flow 배치·104pt 링·근거/추세·3D 진입 제거 |
| MuscleRecoveryMapView.swift, InjuryRiskCard.swift | 세트 수 명칭·적응형 배치·부담 맥락 |
| PersonalRecordsSection, ConsistencyCard, WorkoutReportCard, ExerciseFrequencySection, TrainingVolumeSummaryCard | 수치·성취·보고서·구성 강조 |
| ExerciseListSection, UnifiedWorkoutRow, ExerciseListItem 및 관련 테스트 | 두 기록/펼침·심박·실제 보상 연결·배지 |
| WellnessHeroCard, LifeView 및 Today 제목 | 상단 영어 대문자·중복 링 캡션 제거 |
| Shared/Resources/Localizable.xcstrings | 새/변경 문구 en/ko/ja와 formatter |
| DUNEUITests/Visual/ActivityFlowUITests.swift | 히어로·범례·순서·경로·상태·실제 캡처 |
| docs/design/layout-map, theme-map, phone-design-map/actual | 시안 보존·실제 캡처와 출처 동기화 |

## Implementation Steps

1. 시안 보존과 브랜치 생성, 최종 계약을 읽고 구현 소유 범위 분리. 설계 산출물 커밋.
2. 루트 Flow/준비도/근육/부담/4탭 제목 구현. 관련 기존 경로 유지.
3. 기록/보고서/꾸준함/부하/구성 표현 구현. 최근 운동 실제 배지·심박 연결 및 의미 있는 매핑 테스트.
4. 문자열 통합·포맷, 표준 빌드, 관련 단위/UI 검증, 영향 기기의 새 캡처와 맵 갱신.
5. diff 기반 5관점 및 SwiftUI/Apple UX/종합 게이트 검토, 발견사항 해결, Compound, PR·원격 병합·소유 시뮬레이터 정리.

## Edge Cases / Risks

| 경우 | 처리 |
|---|---|
| 누락 수면/심박/비교값 | —/생략, 0으로 치환 금지 |
| 기록 없음/접근 제한/기준선 | 상태 설명과 운동 선택 유지 |
| 수동+HealthKit 중복·삭제 | 기존 dedup/tombstone 계약 유지, 실제 ID만 보상 연결 |
| 접근성/긴 번역·작은 폭 | 장식은 고정, 텍스트는 자연 확장·한 열 |
| Other 운동·체중 없는 운동 | 실제 범주 포함, 0kg을 성취로 만들지 않음 |
| 낮은 부담 | 평가 점수와 관측 맥락을 구분, 누락을 안전 보증으로 해석하지 않음 |
| 공유 View 소비자 | 호출부 확인 후 바뀐 소비자의 관련 UI/컴파일 검사 |

## Testing Strategy

- `scripts/build-ios.sh`, `swift scripts/format-xcstrings.swift --check` 실제 실행.
- 보상/행 매핑 변경의 관련 단위 테스트만 표준 test-unit 실행기로 수행.
- `scripts/plan-ui-tests.py --base origin/main` 초기/최종 계획 저장. 공유 표현 때문에 full 분류될 수 있으나 사용자 별도 전체 회귀 요청은 없으므로 adapter 규칙에 따라 영향받는 targeted+smoke만 실행하고 full 미실행을 명시한다.
- ui-test-expert가 seeded Activity/4탭 제목·상세·지도 전환·접근성 테스트를 작성한다. parent만 전용 worktree 기기·표준 runner·deadline으로 실행한다. 동일 원인은 수정 증거 후 최대1회 재시도.
- A01 및 제목이 바뀐 T03/H01/L01의 영향 기기(iPhone/iPad/Duo 접힘/펼침) 새 화면을 저장한다. 기본/어두움·큰 글씨는 변경 위주로 확인한다. Watch/visionOS 전용 화면은 수정하지 않는다.
- 캡처·테스트·시안은 별도 증빙. 실제 화면맵 포털/보드 재생성. 막힌 기기/상태는 이전 PNG를 재사용하지 않고 미검증으로 기록한다.

## Confidence Assessment

높음: 시안과 데이터 계약이 이미 조사되어 있고 main의 공통 헤더 구현을 재사용한다. 실제 기기 HealthKit 권한/실시간 동기화와 전체 플랫폼 회귀는 이 작업의 자동 검증 범위가 아니다.
