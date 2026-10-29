---
topic: l03-habit-template-redesign
date: 2026-10-30
status: approved
confidence: high
---

# L03 습관 템플릿 네이티브 구현

## Context / Requirements

시안을 실제 앱에 구현하고 각 화면을 별도 PR로 분리한다. 이 PR은 L03 하나다. 기존20개 정적 템플릿의 심볼·주기·목표와 prefill→dismiss→onSelect를 유지한다. 큰 컬러 아이콘·시간대 텍스트·전체 제목·구분되는 목표·곡선 장식을 적용한다. iPhone/iPad/Duo만 범위이며 기록이 없어도 템플릿은 선택할 수 있다.

## Research / Approach

Repo·solution 연구2개와 Apple UX 연구1개를 실제 실행했다. 현재2열·한 줄 제목을 개선한다. 기존 DS와 HabitIconCategory.themeColor(for:)를 재사용하므로 별도 공통 기반 PR은 필요하지 않다. docs/solutions/architecture/2026-02-28-detail-score-hero-unification.md, docs/solutions/architecture/2026-03-14-score-detail-unification.md와 Life/큰 글씨 관련 brainstorm/todo/UI 경로를 조사했다. Apple Layout/Accessibility/Buttons 기준으로 큰 글씨 재배치와 버튼 역할을 유지한다. 새 API/외부 의존성은 없다.

## Affected Files / Implementation Steps

1. DUNE/Presentation/Life/HabitTemplateSheet.swift: 너비와 Dynamic Type에 맞는 열 수, 큰 기존 심볼/시간대 텍스트/전체 제목/주기·목표, DS 기반 카드와 전 영역 hit area. 모델과 저장 흐름은 유지한다.
2. DUNEUITests/Full/DuoRemainingRouteTests.swift 또는 인접 Life UI 테스트: 정확한 기존 class/selector 확인 후 카드 식별자·선택·prefill·큰 글씨 검증.
3. L03 전용 layout 문서/테마 보존본·manifest·인덱스와 영향받는 기기별 실제 L03 PNG·출처·맵을 같은 PR에 포함한다.
4. 해결책/단계 결과를 문서화하고 최종 diff를 리뷰한 뒤 PR을 생성한다.

## Testing Strategy

scripts/plan-ui-tests.py --base origin/main 판정과 호출부 조사 후 scripts/build-ios.sh를 실제 실행한다. 표준 UI 실행기와 현재 worktree 소유 기기만 사용하고 한 번에 한 runner를 유지한다. L03 열기/선택/목표 자동 입력·큰 글씨를 확인하고 iPhone/iPad/Duo 접힘·펼침의 영향 화면을 새로 캡처한다. 기존 PNG/브라우저 증거를 네이티브 통과로 대체하지 않는다. 같은 원인은 코드 수정 또는 복구 증거 후 최대1회 재시도한다.

## Risks / Edge Cases

- 긴 한국어/영문 제목과 큰 글씨: 줄임 없이 확장하고 열 수를 줄인다.
- 템플릿의 시간대/주기/목표 의미와 선택 콜백은 바꾸지 않는다.
- 장식은 카드 안에서 잘라 hit area와 스크롤 범위를 확장하지 않는다.
- 실행 환경 차단 시 리뷰/문서는 계속하되 UI·캡처 게이트를 통과시키지 않는다.
- 기존 da96 시안은 보존하며159개 전체 변경을 이 PR에 섞지 않는다.

## Phase Tracking

- 0 Init: completed (clean native worktree, codex branch, origin/main base)
- 1 Plan: completed (plan file + 3 research results)
- 2 Work: completed (4f052fa7, build, iPhone2/iPad1)
- 2.5 UI: in_progress (Duo bootstrap recovery + Mac unlock pending)
- 3 Review: preliminary code review completed; final UI gate pending
- 3.5 Quality: static + iPhone/iPad visual completed; Duo pending
- 4 Resolve: pending
- 5 Compound: prepared (partial-verification solution doc)
- 5.5 Pre-Ship: pending
- 6 Ship: draft PR858 published; merge gate incomplete
