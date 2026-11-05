---
tags: [injury, detail, hero, dynamic-type, batch01]
date: 2026-11-05
category: plan
status: done
updated: 2026-11-06
confidence: high
---

# H10 부상 상세 구현 계획

## Context / Requirements

기존 부위·심각도·상태·기간·메모가 비슷한 크기로 보여 위계가 약하다. 기존 기능·아이콘을 유지하며 큰 기간과 부위, 원래 심각도 기호를 HeroCard로 강조한다. 기간은 히어로에서 한 번, 날짜 세 항목은 Timeline에 둔다. 계산과 기록 수정 동작은 바꾸지 않는다.

## Affected Files

| File | Change |
|---|---|
| `DUNE/Presentation/Injury/InjuryHistoryView.swift` | private InjuryDetailView만 변경; H09 목록과 모델은 유지 |
| `DUNEUITests/Full/WellnessRegressionTests.swift` | 기존 row→detail→Edit→Save 유지, 상세 필드와 회복 기록 MAX 보강 |
| layout/theme H10 HTML과 index/manifest/README | 구현 전 배치와 표현 기준 |
| 실제 디자인맵 H10와 별도 갤러리 | 새 네 프로필의 실제 이미지·AX로만 갱신 |

## Implementation Steps

1. H09 실제 데이터/아이콘과 H10 날짜·메모·callback을 대조한다. 기존 nil-record unavailable와 활성 기록의 회복·편집·Form Save를 유지한다.
2. 전용 layout/theme 기준을 먼저 기록한다. HeroCard에 부위·좌우·심각도 아이콘·명칭·상태·원래 localized duration을 두고 설명을 보존한다. Timeline/Memo 헤더와 날짜 행에는 의미에 맞는 SF Symbol을 둔다.
3. Light 전경은 기존 색을 검은색 45%와 혼합하고 Dark는 원래 색을 쓴다. 공통 DS/도메인/문자열 카탈로그는 바꾸지 않는다. 최대 글씨는 날짜 행을 세로 배치한다.
4. 첫 묶음 H10/H11/H12/H13이 고정된 뒤 기기별로 한 표준 실행에 selector를 모은다. 별도 build-only나 unit/full 회귀를 추가하지 않는다.
5. 실제 PNG/AX와 전문가 리뷰로 필드 잘림·대비·편집 복귀를 확인하고 실제 맵·문서·화면 PR을 마무리한다.

## Testing Strategy

일반 iPhone·iPad·Duo 접힘·펼침에서 기존 normal 상세/Edit/Save 검사, Duo 접힘 MAX에서는 이미 머지한 opt-in fixture의 회복 Shoulder 기록 상세 필드·날짜·메모·뒤로를 확인한다. HeroCard 전체 동시 노출이 아니라 각 필드 전체가 스크롤로 접근 가능한지 확인한다. H08 Add 경로는 보류 상태를 유지한다. 테스트는 UI 소스 작성 담당이 기존 selector를 보강하며 최종 명령/예산은 묶음 고정 후 기록한다. 초기 UI 예산 1200초, 한 소유 기기·실행만 사용한다.

## Risks / Edge Cases

- 메모 없음은 기존 No memo, 기록이 사라지면 기존 unavailable를 유지한다.
- 날짜/기간을 새 계산으로 바꾸지 않으며 durationDays의 기존 경계를 유지한다.
- 통합 tip의 결과를 별도 PR에 연결할 때 관련 App/fixture/UI 내용과 의존성의 동일성을 확인한다.
- UI 변경이므로 SwiftUI·Apple UX·데이터/성능/구조 리뷰와 실제 캡처는 구현 후 필요하다. 현재 계획/브라우저 시안은 검증 증거가 아니다.

## 검증 결과

관련 기기·상태의 SDK와 독립 PNG/AX 검토를 완료했다. [실제 화면·원본 출처](../design/full-redesign-map/review/h10-injury-detail-native-2026-11-06/index.html)의 실행 소스와 범위를 따른다. PR·머지는 GitHub 기록으로 확인한다.
