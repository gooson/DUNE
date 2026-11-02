---
tags: [design, layout, notification, detail, T12]
date: 2026-10-31
category: plan
status: native-source-implemented-pending-runtime-validation
---

# T12 알림 메시지 상세 배치

[보존한 브라우저 제안](../theme-map/themes/dune-notification-message-detail.html) · [알림함 배치](notification-inbox-proposal.md) · [실제 화면 맵](../phone-design-map/actual/index.html)

## 승인 시안과 실제 데이터

승인된 상세 갤러리 소스는 Git 스냅샷 `786c2c3cb8dab80ccb0f5db0414c23f0ae5e4894`의 `docs/design/detail-redesign-map/data/dashboard.json` (blob `1aa8044fc53db55e07899dd161be4b788c4bc5b3`) T12 레코드다. `data/visual-emphasis.json` (blob `6013c46b5683430059960ad0d77b854ccc40dfde`)은 T12를 `retain-focused-layout`으로 분류한다. 갤러리의 요약 수치·시간·행·`오늘 보기`는 설명용 fixture이며 실제 T12 뷰 입력이나 동작에 없으므로 네이티브에 옮기지 않는다. 제목·본문과 뒤로 가기라는 핵심 구조, DUNE 시각 언어를 적용한다.

## 실제 데이터와 화면 경계

T12는 알림함이 저장된 `NotificationInboxItem`을 연 뒤 전달하는 `title`과 `body` 두 문자열만 받는다. 메시지 본문은 여러 줄과 긴 문장을 포함할 수 있다. 수신 시각, 심각도, 분류, 읽음 건수, 목적지, 확신도는 T12 뷰의 입력이 아니므로 새 시각 요소나 문구로 만들지 않는다. UI 테스트의 “Message Route Fixture”는 진입 확인용 예시이며 실제 알림 문구가 아니다.

| 순서 | 네이티브 배치 | 원천·행동 |
|---|---|---|
| 시스템 상단 | 기존 `Notification` 내비게이션 제목과 시스템 뒤로 가기 | Today 탭 안의 알림함으로 돌아간다. |
| 제목 히어로 | 기존 알림 계열 SF Symbol, 원문 제목, 테마별 불투명 어두운 `ScoreHeroPalette.surface` 표면 | 금빛/테마 강조 심볼과 밝은 `palette.ink` 제목을 사용한다. 문자열 전체를 표시하며 문장을 다시 쓰지 않는다. |
| 본문 카드 | 원문 본문을 왼쪽 정렬로 한 열에 표시 | 줄바꿈을 보존하고 스크롤·텍스트 선택을 제공한다. |

## 기기와 접근성

- iPhone·Duo 접힘은 화면의 한 열을 사용한다. iPad·Duo 펼침은 화면 전체에 문장을 길게 펼치지 않고 약 680pt 읽기 폭을 가운데에 둔다.
- 큰 글씨에서는 히어로 심볼을 함께 키우고 제목·본문 높이를 고정하지 않고 자연스럽게 늘린다. 가로 타일이나 둘로 나뉜 본문은 쓰지 않는다.
- 색과 아이콘 없이도 제목·본문을 읽을 수 있어야 한다. VoiceOver는 장식 아이콘을 건너뛰고 저장된 문자열을 순서대로 읽는다.
- 본문이 비어 있더라도 다른 사실이나 조작을 꾸며 채우지 않는다. 화면 자체의 스크롤과 시스템 뒤로 가기는 유지한다.

## 시안과 실제 화면

연결한 HTML은 내용 위계와 폭을 검토하기 위한 설명용 브라우저 제안이다. 실제 앱의 T12 증거는 `phone-design-map/actual`의 새 iPhone·iPad·Duo 접힘·펼침 캡처로 별도 갱신해야 한다. 현재 보존된 기존 PNG는 이 변경의 검증 자료가 아니다.
