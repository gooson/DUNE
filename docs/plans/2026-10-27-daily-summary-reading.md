---
topic: daily-summary-reading
date: 2026-10-27
status: approved
confidence: high
related_solutions: [docs/solutions/architecture/2026-10-26-shared-card-navigation-header.md, docs/solutions/general/2026-10-26-today-compact-density-and-pin-hit-area.md]
related_brainstorms: [docs/brainstorms/2026-10-27-summary-card-disclosure.md]
---

# Implementation Plan: 오늘의 요약 · 핵심 먼저

## Context

사용자가 본문 더 보기 방향의 첫 번째 세부안 `핵심 먼저`를 선택하고 `/run` 전체 실행을 요청했다. 별도 날짜·중복 보조 문구·하단의 떨어진 제어를 정리하고 수치→짧은 원문 미리보기→같은 카드 펼침의 흐름으로 구현한다. 장기 스트레스 시안과 다른 설명 카드의 전면 변경은 이번 범위가 아니다.

## Requirements

- 16pt 패딩, 같은 행의 제목·날짜, 두 지표 사이 얇은 구분선, 34pt 계열 시스템 수치. 접근성 글씨에서는 날짜·지표를 세로로 쌓는다.
- `Recorded today` 중복 행을 없애고 어제 대비 변화는 기존 부호/서식과 의미를 보존한다.
- 원문의 첫 문장을 미리보기로 표시하며 더 보기/접기로 원문을 같은 위치에서 전환한다. 새로운 건강 해석을 만들지 않는다.
- Foundation 문장 경계를 사용해 소수점·한국어·일본어를 보존한다. 단일 문장·빈 원문이면 불필요한 펼침 버튼을 숨긴다. 단일 긴 문장은 잘라 숨기지 않고 자연 확장한다.
- 실제 버튼은 44pt 이상, chevron은 레이블 바로 옆, 행의 빈 영역도 터치 가능. 기존 식별자와 알림 상세의 공유 소비를 보존한다.
- 영·한·일 번역과 카탈로그 정렬을 유지한다. 계산·HealthKit·라우팅 변경은 없다.

## Approach

DailyDigestCard의 표시만 재배치하고 작은 presentation 문자열 값 타입으로 미리보기/원문/추가 본문 유무를 정한다. 현재 앱의 원문을 우선하므로 시안의 예시 해석 문장을 하드코딩하지 않는다. 요약 제어는 네이티브 Button과 명시적인 펼침 상태를 사용하며 본문 밖의 상세 이동용 `›`와 구분한다.

| Alternative | Decision |
|---|---|
| 헤더 펼침 | 사용자가 본문 더 보기·핵심 먼저를 선택해 제외 |
| 원문을 단순 두 줄로 자르기 | 짧은/긴 단일 문장에서 접근 불가능한 텍스트를 만들 수 있어 제외 |
| 새 해석 생성 | 데이터/AI 생성 범위 확장을 피하고 기존 원문 첫 문장 사용 |

## Affected Files

| File | Change |
|---|---|
| DailyDigestCard.swift | 제목·날짜·지표·구분선·미리보기·44pt 펼침 제어 |
| DUNETests/DailyDigestSummaryTextTests.swift | 문장 경계·소수점·공백·단일/빈 요약 테스트 |
| DUNEUITests/Visual/TodayReadingUITests.swift | 첫 문장→전체→접기, 전체 행 터치, 큰 글씨·알림 소비자·캡처 |
| Shared/Resources/Localizable.xcstrings | 새 펼침/접기 및 접근성 상태 번역 |
| DUNE/DUNE.xcodeproj/project.pbxproj | 표준 프로젝트 재생성으로 새 테스트 등록 |
| docs/design/layout-map 및 실제 화면맵 | 승인안·새 앱 캡처·검증 범위 연결 |

## Implementation Steps

1. 기존 시안과 배치 계약의 선택 상태를 기록하고 문자열 미리보기와 카드 배치를 구현한다. 검증: 구문·번역·관련 유닛 테스트.
2. UI 전문 에이전트가 기존 seeded 테스트를 갱신한다. 검증: Today 일반/접근성 글씨의 펼침·접기 및 알림 상세 공유 카드.
3. 전용 iPhone으로 표준 빌드와 관련 UI만 실행한다. 동일 실패는 원인 해소 근거가 있을 때만 1회 재시도한다.
4. T03 및 알림 요약 소비자, 영향을 받는 iPad·Duo viewport를 새로 촬영해 실제 화면맵에 연결한다. 미촬영 상태는 이유를 명시한다.
5. 읽기 전용 Review·Quality → Resolve → Compound → 최종 PR 검토 → 원격 빌드 확인·merge·소유 기기/브랜치 정리.

## Edge Cases

| Case | Handling |
|---|---|
| 기록 없음 | 기존 수집 안내 유지, 요약 제어 숨김 |
| 지표 하나/0걸음/변화 0 | 한 열, 0걸음 유효, 불필요한 변화 0 보조 문구 숨김 |
| 빈 요약/단일 문장 | 빈 본문 또는 불필요한 제어를 숨김 |
| 긴 단일 문장/큰 글씨 | 잘라 숨기지 않고 세로 확장 |
| 소수점·한/일 문장 | Foundation 문장 경계와 원문 보존 테스트 |
| 알림 경로 | 같은 DailyDigestCard 사용, 중복 지표나 새 목적지 추가 없음 |

## Testing Strategy

작은 문자열 처리 로직에 Swift Testing 테스트를 추가한다. iOS 표준 빌드 후 관련 유닛 suite와 Today 요약 UI selector를 실행하고 정상 종료·실행 건수를 확인한다. 단일 selector가 여러 변형을 반복해 정체됐던 과거 이력이 있어 새 UI는 필요 시 독립 selector로 나눈다. 전체 회귀는 요청되지 않아 실행하지 않고 미검증으로 기록한다. 실제 PNG와 테스트 assertion을 별도로 검토한다.

## Risks

첫 문장이 원문의 해석을 바꾸거나 버튼이 긴 원문을 숨기는 위험은 원문 기반 문장 경계와 단일 문장 자연 확장으로 막는다. SwiftUI 컨테이너 식별자가 버튼을 덮는 문제는 실제 Button ID·44pt frame·오른쪽 빈 영역 터치로 확인한다. 알림 소비자와 iPad/Duo 배치 누락은 호출부 및 영향 화면 목록에 포함한다.

## Confidence Assessment

High. 선택한 시안과 재사용 소비자가 명확하고 데이터 계산을 바꾸지 않는다. UI 환경의 실제 실행·캡처는 결과를 확인한 뒤에만 완료로 처리한다.
