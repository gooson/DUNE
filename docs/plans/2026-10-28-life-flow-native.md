---
topic: life-flow-native
tags: [life, habits, flow, past-record, native]
date: 2026-10-28
category: plan
status: approved
confidence: high
related_solutions:
  - ../solutions/architecture/2026-03-22-auto-linked-habit-section-routing.md
  - ../solutions/architecture/2026-04-05-habit-archive-management-view.md
  - ../solutions/general/2026-10-26-today-compact-density-and-pin-hit-area.md
---

# Life Flow 네이티브 구현

## Context

사용자가 `/run` 범위를 **시안을 실제 앱 Life 탭에 구현하고 PR 머지**로 선택했다. 기존 [시안 계획](2026-10-28-life-tab-redesign.md)과 [통합 배치 계약](../design/layout-map/life-redesign-proposal.md), [지난 기록 계약](../design/layout-map/habit-past-record-proposal.md)을 구현한다. 앞선 시안/PNG/맵 변경은 이 대화에서 만든 작업 산출물이며 함께 보존한다. 외부 Sites 접근 권한은 변경하지 않는다.

## Requirements / Approach

- 짧은 HABITS 히어로, 104pt 링·큰 남은 수·골드 능선·상태 메달. 아래 이동 버튼 제거.
- 오늘의 실천을 개별 카드로 표현하고 목적 4분류는 표시 전용으로 둔다. 오늘/주간/예정 의미와 수동/자동 분모를 보존한다.
- 완료 목록 접기, 메뉴·±·시간 입력의 44pt 조작, 기록 후 취소. 필터는 히어로 수치를 바꾸지 않는다.
- 기존 로그 삭제 전에 검증한다. 지난 날짜 기록은 습관·날짜·그날 총합을 편집하며 0은 화면에서 기록 해제로 표시하고 동기화용 0 표식을 보존한다. 같은 날 재저장은 대체다. 자동 기록/등록 전/미래 날짜를 제외한다.
- 최근 7일 건수와 28일 패턴을 실제 수동 기록에서 파생한다. 현재 등록 습관 기준임을 표시한다. 기존 90일·주월 비율 상세는 유지한다.
- 자동 운동 목표의 사용자 설정을 먼저 배치하며, 로컬+HealthKit 운동의 출처와 운동 횟수 단위를 명확히 한다.

색만 바꾸는 대안은 조작 문제를 해결하지 못한다. 신규 역사 목표 스키마는 CloudKit 변경이 커 제외한다. 기존 의미를 보존하는 presentation 개편과 날짜별 안전한 로그 대체를 선택한다.

## Affected Files

| 파일 | 변경 |
|---|---|
| LifeView.swift | 순서·필터·완료 접힘·지난 기록/이력 라우트·안전한 저장/취소·자동 순서 |
| LifeViewModel.swift, HabitPastRecordSheet.swift | 날짜/값 검증·총합 대체 준비·폼 |
| HabitRowView.swift, LifeHabitHeroView.swift, HabitPurpose+View.swift | 카드·히어로·표시용 분류 |
| LifeRhythmCard.swift, LifeWeeklyReviewCard.swift | 수동 완료 건수·28일·주간 요약 |
| Shared/Resources/Localizable.xcstrings | en/ko/ja 새 문구 |
| DUNETests/Life*Tests.swift, HabitPurposeTests.swift | 날짜/값/보존/분류 검증 |
| DUNEUITests/Visual/LifeFlowUITests.swift, Full/LifeRegressionTests.swift | 새 동작·기존 CTA 계약 갱신·캡처 |
| docs/design/*, docs/reviews/*, docs/solutions/* | 시안/실제 화면 분리·새 캡처·검증/학습 |

## Implementation Steps

1. VM의 검증된 대체 DTO와 지난 기록 폼을 작성한다. 기존30분→범위 초과 거부 시 기존값 유지, 0·NaN·Inf·자동·날짜 경계를 검증한다.
2. 히어로/카드를 구현하고 루트 순서·4분류·완료 접힘·지난 기록 진입·취소를 연결한다. 기존 등록/편집/보관/반복 동작을 유지한다.
3. 동일한 수동 snapshot을 7일/28일/주간 요약으로 사용하고 기존 상세를 유지한다. 번역·맵을 동기화한다.
4. 빌드·관련 unit·Life UI+공통 smoke를 수행한다. iPhone 기본/다크/최대글씨·iPad·Duo 접힘/펼침의 영향 화면 L01과 새 폼을 전용 기기에서 새 캡처한다. 환경 차단은 미검증으로 기록하고 기존 PNG로 대체하지 않는다.
5. 실제 diff 5관점/전문 UX/UI 검토, 발견사항 해결, Compound, PR 생성/머지를 수행한다.

## Testing Strategy

`scripts/build-ios.sh`, `scripts/test-unit.sh`의 관련 Life/습관 suite, `scripts/plan-ui-tests.py --base main`의 분류와 호출부 분석으로 UI 범위를 결정한다. 전역으로 판정돼도 명시적인 full 요청은 없으므로 Life 관련 selector와 공통 smoke만 실행하고 미실행 full은 구분한다. `scripts/test-ui.sh`·전용 기기·직렬 실행·deadline·동일 원인 조건부 1회 제한을 지킨다. 브라우저 시안 검증은 native 검증을 대신하지 않는다. formatter는 번역 변경 전/후/빌드 후 검사한다.

## Edge Cases / Risks

| 경우/위험 | 대응 |
|---|---|
| 잘못된 수치가 기존 기록을 삭제 | VM에서 대체를 검증/생성한 다음 View에서 mutation |
| 과거 입력으로 오늘 집계 증가 | 선택한 날짜만 대체, 완료 시각과 기록 날짜 분리 |
| 반복 완료·skip/snooze 충돌 | 같은 날짜 수동 로그만 대체, 주기/알림 재계산·취소 |
| 필터0·오늘0·auto-only·보관만 | 상태별 빈 화면, 전체 관리·상단 추가 유지 |
| 역사 비율의 부정확한 분모 | 루트는 건수·현재 습관 기준, 레거시 상세 안내 유지 |
| 최대 글씨·iPad/Duo | 자연 높이·한 열 fallback·전체44pt·실제 캡처 |
| CloudKit/Watch 영향 확대 | 모델 스키마/raw value/Watch UI 변경 없음 |

## Confidence

기존 시안과 소스 조사가 있어 높음. 실제 저장·주기·접근성·기기 렌더링은 아래 실행 결과로만 완료 판정한다. 관련 active TODO는 검색 결과 없으며 새 작업은 이 계획으로 추적한다.

## Execution status · 2026-10-28

구현과 최신 main 통합 후 빌드는 완료했다. 관련113개 unit 통과. UI 재검증7개 중4개 통과·3개 실패 후 수정본62d3c097을 준비했다. 동일 원인 자동 재시도 한도에 따라 추가 실행은 예외 확인 대기다. [초안 PR #854](https://github.com/gooson/DUNE/pull/854), [검증 기록](../reviews/2026-10-28-life-flow/README.md), [부분 실제 화면](../design/full-redesign-map/review/life-flow-2026-10-28/index.html)을 보존한다. UI·추가 기기 캡처·최종 게이트·머지는 완료하지 않았다.
