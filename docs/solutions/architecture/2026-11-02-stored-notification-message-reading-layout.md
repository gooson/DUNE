---
tags: [swiftui, notification, stored-payload, reading-width, dynamic-type, duo, native-navigation, source-closure]
category: architecture
date: 2026-11-02
severity: minor
related_files:
  - DUNE/Presentation/Dashboard/NotificationHubView.swift
  - DUNEUITests/Full/DesignMapAdditionalRoutesTests.swift
related_solutions:
  - docs/solutions/testing/2026-11-02-daily-report-native-disclosure-and-navigation.md
  - docs/solutions/testing/2026-11-02-notification-hub-native-list-accessibility.md
---

# Solution: 저장된 알림 메시지를 가독성 있는 상세 화면으로 표현하기

## 2026-11-14 후속 · 저장된 체성분 값 강조

### Problem

큰 종·제목 영역 아래 작은 두 줄 본문으로 체성분 알림을 표시해 실제 측정값이 잘 드러나지 않았다. 최대 접근성 글씨에서는 장식 아이콘이 제목 폭을 차지해 단어가 나뉘었다.

### Solution

알림함 목적지는 기존 ID·제목·본문과 함께 실제 저장 시각·유형을 전달한다. 제목 영역을 줄이고 체성분 본문 전체가 측정 문장일 때 원래 이름·값·단위·순서를 카드로 표시한다. `NotificationMessageContent`는 최대 세 줄의 콜론과 숫자·단위·괄호 변화량 형식만 분리하고 수치 자체를 변환하지 않는다. 빈 줄·다른 설명·해석 불가능한 값이 섞이면 전체 원문을 표시한다. 기본 두 열과 접근성 한 열을 사용하며, 접근성 글씨에서는 장식 아이콘을 생략한다.

### Prevention

분리 로직은 한국어·일본어 레이블, 소수 쉼표, CRLF, 체중 변화량, 빈 값과 혼합 문장을 단위 테스트로 확인한다. 실제 `Text` 날짜는 기기의 24시간 표시 설정도 반영하므로 영어 UI 테스트는 12·24시간 표시를 모두 허용하며 저장된 시각 자체를 검증한다. 최대 글씨의 제목 폭과 실제 PNG를 함께 확인한다.

### Lessons Learned

알림 본문을 나눌 때 일부 줄만 남기지 않는다. 수치 표현을 분리하는 일과 건강 수치를 해석하는 일의 경계를 유지한다. 테스트 통과 뒤에도 실제 캡처에서 장식 요소가 제목·측정값을 밀어내는지 확인한다. 후속 기기별 실행·캡처 범위는 [구현 계획](../../plans/2026-11-14-notification-detail-reading.md)에서 추적한다.

아래는 첫 개편 당시의 기록이다.

## Problem

T12 목적지가 받는 데이터는 저장된 제목과 본문 두 문자열뿐이다. 시안의 측정값·날짜·상태·행동 버튼을 그대로 추가하면 실제 payload에 없는 사실이나 이동 기능을 표시하게 된다. 기존 단일 카드에서는 제목과 내용의 위계도 약했다. 넓은 iPad·Duo에서 화면 전체 폭을 본문에 쓰면 읽기 길이가 과도하게 늘어날 수 있다.

공유 파일에는 T11 알림함과 T13 목적지 오류 화면도 있다. 검증용 통합 후보 전체를 복사하면 다음 화면 변경까지 현재 PR에 섞인다. Duo의 네이티브 뒤로 버튼은 NavigationBar 바깥 레일에 있을 수 있으므로 기존 navbar-only 테스트 조회도 그대로 재사용할 수 없다.

## Solution

### Changes Made

| 범위 | 변경 | 보존한 동작 |
|---|---|---|
| T12 private view | 기존 ScoreHeroPalette로 제목 히어로, StandardCard로 본문 분리 | 저장된 제목·본문의 정확한 내용과 줄바꿈 |
| 넓은 화면 | 세로 읽기 열을 최대 680pt로 제한하고 중앙 정렬 | 좁은 화면의 가용 폭, 자연스러운 세로 스크롤 |
| 접근성 | 고정 텍스트 높이·lineLimit 없이 제목과 본문 성장, 본문 선택 가능 | Dynamic Type와 전체 본문 접근 |
| 기존 normal UI 검사 | 검증된 detail에 capture checkpoint, 알려진 native BackButton을 우선 조회하고 navbar fallback 유지 | 정확한 payload assertion·실제 back tap·hub-return assertion |

```swift
let railBack = app.buttons["BackButton"].firstMatch
let backButton = railBack.exists && railBack.isHittable
    ? railBack : app.navigationBars.buttons.firstMatch
XCTAssertTrue(backButton.waitForExistence(timeout: 5))
XCTAssertTrue(backButton.isHittable)
backButton.auditTap()
// 실제 알림함 복귀 assertion 유지
```

테스트는 원래 Phone 경로를 유지하면서 확인된 Duo 레일 컨트롤도 찾는다. 목적지 화면이 이미 나타났다는 assertion을 back 성공으로 대신하지 않는다. 앱의 내비게이션·저장소·모델·payload에는 새 로직을 추가하지 않았다. 제안 시안의 예시 데이터는 실제 앱 사실로 사용하지 않았다.

### Source and evidence boundaries

공개 소스0862f70f는 기존583dcaf1의 T12 구현을 최신 main에 통합했다. T11 prefix는 main과 같고 T13 tail도 main 그대로다. 검증 후보3fac15d4에는 미래 화면들이 있어 전체 파일/트리 일치를 주장하지 않는다. T12 구간, payload/store 소비, 관련 메서드와 helper를 별도로 비교했다.

기존 clean583 Phone normal+dark/MAX 2/2 PASS는 정확히 같은 T12 앱 소스와 변경 없는 MAX helper의 검증으로 재사용한다. normal 메서드의 새 paused checkpoint 및 back 조회·wait·hittable 조건은 과거 실행에 있었다고 주장하지 않는다. 새 iPad normal 1/1 PASS는 이 작은 테스트 변경도 실제 컴파일·실행했으며 payload와 back 복귀를 확인했다. 과거 iPad 원본은 old UI1f7 baseline이므로 개편 통과로 표시하지 않는다.

Duo 접힘·펼침도 같은3fac15d4의 기존 normal 메서드 각 1/1 PASS다. 실행 전후 SDK 0° LCD 및 180° LCD-1, 각각 엄격 ACK7을 확인했다. 부모는 각005 검증된 상세 원본에서 제목·본문을 확인했고, 실제 back 뒤006/007은 알림함 복귀 증거로 구분했다. 원래 Phone history와 다른 화면의 승인 예산은 유지한다. 추가 Phone/full UI/local Watch 실행은 수행하지 않는다.

## Prevention

- 실제 목적지가 소비하는 필드부터 확인하고, 시안의 예시 사실·상태·행동을 앱 데이터로 추정하지 않는다.
- 메시지 읽기 열은 넓은 기기에서 폭을 제한하고, 최대 글씨에서는 고정 높이 대신 세로 성장을 허용한다.
- 공유 파일은 해당 화면 구간만 비교·통합한다. 다음 PR의 tail을 통째로 복사하지 않는다.
- 알려진 플랫폼 내비게이션 조회 차이는 첫 실행 전에 기존 AX 근거로 반영하고, 실제 back/복귀 검증은 유지한다.
- 새 상세 캡처와 알림함·설정·post-back 캡처를 구분한다. iPad mini/Pro13, 과거 날짜·언어·Duo 미확인 각도 차이를 동일 조건처럼 표현하지 않는다.
- 원본 PNG·pose·실패 기록과 현재 출판 상태를 분리한다. 출판 완료 때 오래된 assembly pending 문구만 갱신한다.

새 공통 규칙은 제안하지 않는다. 기존 디자인·테스트·소스 보존 규칙을 적용한 사례이며 `.claude/**` 원본을 변경하지 않는다.

## Lessons Learned

풍부한 시각 표현은 새 사실을 추가하지 않아도 가능하다. 저장된 문자열을 제목 히어로와 적절한 읽기 폭으로 구성하면 실제 데이터 범위 안에서 위계와 가독성을 높일 수 있다. 소스와 상태의 일치 범위를 명시하면 기존 통과를 재사용하면서 넓은 기기·네이티브 back처럼 빠진 확인에만 실행을 집중할 수 있다.
