---
tags: [dashboard, digest, disclosure, compact, card-header]
date: 2026-10-27
category: brainstorm
status: draft
---

# Brainstorm: 오늘의 요약 밀도와 펼침 카드 규칙

## Problem Statement

사용자가 오늘의 요약 카드의 빈 공간과 서로 다른 상세/펼침 버튼 위치를 지적하고 대안을 요청했다. 현재 DailyDigestCard는 24pt 패딩, 20pt 섹션 간격, 별도의 날짜 행과 하단 Full summary DisclosureGroup을 사용한다. 헤더 상세 이동과 모양은 비슷하지만 실제 행동은 카드 내부 펼침이다.

## Target Users

핵심 지표를 빠르게 읽고 필요할 때만 설명을 펼치는 Today 사용자.

## Success Criteria

- 날짜·중복 문구·별도 CTA 영역을 정리해 접힌 카드의 높이를 줄인다.
- 기존 컨디션·변화량·걸음 수·요약 원문과 데이터 유무를 보존한다.
- 위치와 터치 영역은 일관되게 하면서 이동과 펼침의 의미를 구분한다.

## Proposed Approach

| 대안 | 기본 표시 | 펼침/상세 위치 | 장단점 |
|---|---|---|---|
| 헤더 펼침 — 추천 | 제목·날짜 한 행, 두 지표 | 제목 바로 옆 ⌄, 헤더 전체 터치 | 숫자를 유지하며 별도 하단 제어 행을 줄임 |
| 본문 더 보기 | 지표와 한 줄 요약 미리보기 | 내용 아래 `요약 펼치기 ⌄` | 행동이 명시적이며 읽기 흐름에 가까우나 기본 높이가 더 큼 |
| 요약 행 + 상세 이동 | 제목·날짜, 한 줄 지표 | 제목 옆 ›, 별도 상세로 이동 | 가장 간결하나 짧은 원문을 읽기 위해 화면 왕복이 필요 |

## Constraints

현재 요청은 대안 제시다. 네이티브 앱·라우팅·계산·문자열 카탈로그를 변경하지 않는다. 첨부 화면의 10월 26일, 45, 어제 +2, 5,205를 예시로 사용하며 실제 현재 날짜/건강 데이터로 주장하지 않는다. 원문 예시는 제공된 두 지표만 문장으로 옮겼다.

## Edge Cases

데이터 없음에는 펼침 제어를 숨기고 기존 수집 안내를 보존한다. 하나의 지표만 있으면 한 열을 쓰고, 큰 글씨에서는 날짜와 지표를 쌓는다. 긴 요약은 펼친 상태에서 여러 줄로 읽으며 접힌 상태의 필수 숫자는 유지한다. 변화량 0·걸음 0은 결측값으로 취급하지 않는다.

## Scope

승인 시 DailyDigestCard, ConditionExplainerSection, CumulativeStressExplainerSection과 DashboardView 운동 종목 더 보기를 같은 펼침 의미로 정리한다. 기존 CardNavigationHeader의 ›는 화면 이동 전용으로 유지한다.

## Open Questions

사용자는 `본문 더 보기`를 선택하고 해당 요약 방향의 추가 발전을 요청했다. 헤더 펼침은 최초 제안이며 후속 설계는 선택한 본문 더 보기를 기준으로 한다. 세부안은 핵심 먼저·한 문장 먼저·지표 행으로 나누며 [후속 배치 계약](../design/layout-map/digest-read-more-refinement.md)에서 비교한다. 네이티브 적용은 아직 선택 전이다.

## Next Steps

[배치·상호작용 시안](../design/layout-map/digest-disclosure-proposal.html)을 비교한 뒤 선택한 범위만 구현 계획에 연결한다. 현재 앱 변경은 없다.
