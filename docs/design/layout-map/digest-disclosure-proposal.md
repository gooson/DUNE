---
tags: [card-navigation, disclosure, design-map]
date: 2026-10-27
category: plan
status: draft
---

# 오늘의 요약·펼침형 카드 대안 · 2026-10-27

후속 선택: 사용자는 **본문 더 보기**를 선택했다. 아래 헤더 펼침은 초기 추천 기록이며 현재 발전 방향은 [본문 더 보기 세부안](digest-read-more-refinement.md)을 따른다.

[세 가지 상호작용 시안](digest-disclosure-proposal.html) · [편집 원본](assets/daily-summary-options-fragment.html) · [브레인스토밍](../../brainstorms/2026-10-27-summary-card-disclosure.md)

**검토 중인 제안이며 네이티브 앱 캡처가 아니다.** 실제 앱은 이 작업에서 변경하지 않았다. 첨부 화면의 날짜와 숫자를 예시로 유지했다.

## 추천 배치

```text
문서  오늘의 요약 ⌄                 10월 26일
컨디션                          걸음 수
45  [어제 +2]                    5,205
```

헤더를 누르면 지표 아래에 원문이 나타나고 ⌄가 ⌃로 바뀐다. 별도 날짜 행, 중복 `오늘 기록`, 하단 `전체 요약` 행을 줄인다. 제안 패딩은 16pt, 지표 간격은 12pt이며 실제 구현 시 Dynamic Type과 번역 폭을 확인한다. 헤더 터치 높이는 최소 44pt를 유지한다.

## 공통 의미

- `제목 ›`: 기존처럼 별도 화면으로 이동한다.
- `제목 ⌄ / ⌃`: 같은 카드 안에서 내용을 펼치고 접는다.
- 제목과 glyph를 가깝게 두고 남은 헤더 너비도 같은 제어 영역으로 사용한다. 두 의미를 같은 아이콘으로 위장하지 않는다.
- 원문이 없거나 펼칠 내용이 없으면 제어와 glyph를 숨긴다. 실제 수치는 접힌 상태에서도 읽을 수 있게 둔다.

현재 DailyDigestCard는 DisclosureGroup, 점수 설명 두 곳은 사용자 정의 오른쪽 chevron 회전, 운동 종목 더 보기는 up/down을 사용한다. 선택 후 화면 이동용 CardNavigationHeader와 별도로 공유 펼침 레이블/스타일을 적용하고 기존 확장 상태와 접근성 ID를 유지하는 방향이 적절하다.

Apple은 [펼침 컨트롤을 내용 가까이에 두고 레이블로 의미를 설명](https://developer.apple.com/design/human-interface-guidelines/disclosure-controls)하고, [중요한 내용을 먼저 표시하면서 관련 정보를 묶는 위계](https://developer.apple.com/design/human-interface-guidelines/layout)를 권한다. 헤더 배치와 up/down의 앱 전체 매핑은 이 앱을 위한 설계 선택이다.

## 대안 비교

본문 더 보기 안은 한 줄 원문을 기본 제공하고 그 아래에서 펼친다. 원문이 중요한 카드에는 적합하지만 별도 제어 행이 남는다. 요약 행 + 상세 이동 안은 접힌 카드가 가장 간결하며 ›를 모든 카드에 적용할 수 있지만 별도 목적지와 뒤로가기가 필요해 현재 짧은 원문에는 비용이 있다.

선택 전에는 앱·카탈로그·실제 화면 인덱스를 변경하거나 시뮬레이터를 실행하지 않는다. 브라우저 시안의 펼침/접기/이동/돌아가기와 줄바꿈만 확인한다. 선택 후 영향 화면 T03 및 점수 설명 상세의 실제 캡처·관련 UI 검증을 정한다.
