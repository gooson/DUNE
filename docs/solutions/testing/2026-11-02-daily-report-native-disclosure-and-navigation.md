---
tags: [swiftui, daily-digest, notification-routing, dynamic-type, progressive-disclosure, sf-symbols, xctest, native-navigation, evidence-provenance]
category: testing
date: 2026-11-02
severity: important
related_files:
  - DUNE/Presentation/Dashboard/DailyDigestNotificationView.swift
  - DUNEUITests/Visual/TodayReadingUITests.swift
  - DUNEUITests/Full/NotificationRoutingRegressionTests.swift
  - Shared/Resources/Localizable.xcstrings
related_solutions: []
---

# Solution: 오늘의 리포트 구성과 네이티브 뒤로가기 검증

## Problem

### Symptoms

알림으로 여는 일일 요약을 날짜 표지와 컨디션·활동·수면·하루 돌아보기 카드로 구성하면서 기존 데이터와 전체 요약, 펼침/접힘 동작을 보존해야 했다. 최대 접근성 글씨에서는 운동 라벨과 내용이 가로 폭을 경쟁하고 긴 문단은 여러 viewport를 차지한다.

재설계 중 기존 펼침/접힘 chevron이 빠진 P2가 발견되어 복원했다. Duo CLOSED 최초 실행은 제품 리포트 진입 후 `NavigationBar` 하위로만 조회한 뒤로가기 버튼을 찾지 못했다. 실제 네이티브 back 버튼은 AX 트리의 별도 rail에 있었다.

### Root Cause

표현 재구성 시 기존 SF Symbol도 사용자에게 동작을 알려 주는 계약임을 함께 확인해야 한다. 테스트가 네이티브 버튼의 AX 부모를 하나의 구조로 가정해 기기별 navigation 표현 차이를 처리하지 못했다. 버튼 조회 실패를 제품 뒤로가기 실패로 단정하거나 탭/복귀 assertion을 제거하면 원래 동작 보존을 검증할 수 없다.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DailyDigestNotificationView.swift` | 날짜·문서 표지와 조건부 컨디션/활동/수면/서술 카드, 읽기 폭 제한 | 알림 리포트의 정보 구조 명확화 |
| 동일 파일 | 기존 원문을 `DailyDigestSummaryText`의 preview/full로 표시 | 요약 재작성 없이 원문과 disclosure 보존 |
| 동일 파일 | expand/collapse 문구 옆 down/up chevron 복원, 장식 AX 숨김 | 기존 시각적 동작 단서 보존과 중복 낭독 방지 |
| 동일 파일 | 최대 접근성 글씨에 운동 라벨/본문 세로 배치, trailing 장식 숨김 | 읽기 폭 확보와 자연스러운 줄바꿈 |
| `TodayReadingUITests.swift` | 정상 disclosure와 dark/max-text viewport·44pt·실제 탭 확인 | 존재 여부를 넘어 읽기와 조작 가능성 확인 |
| `NotificationRoutingRegressionTests.swift` | 네이티브 rail BackButton 우선, 없거나 unhittable이면 navigation bar 후보 사용 | AX 부모 차이를 수용하며 실제 back과 Today 복귀 유지 |
| `Localizable.xcstrings` | 리포트 제목과 하루 돌아보기의 en/ko/ja 수동 키 | 새 화면 역할에 맞는 언어별 문구 |

### Key Code

```swift
let navigationBack = app.navigationBars.buttons.element(boundBy: 0)
let railBack = app.buttons["BackButton"].firstMatch
let backButton = railBack.exists && railBack.isHittable ? railBack : navigationBack
XCTAssertTrue(backButton.waitForExistence(timeout: 5) && backButton.isHittable,
              "Summary should have a reachable native back button")
backButton.tap()
```

이후 기존 Today 알림 toolbar의 복귀 assertion도 유지한다. 테스트 전용 조회 수정이며 제품 toolbar나 navigation 구조를 바꾸지 않는다. disclosure는 원래 전체 문자열을 보존하고 preview에 뒤따르는 내용을 숨겼다가 다시 보여 준다. 버튼의 localized label·expanded/collapsed value·안정적인 식별자, 전체 폭의 최소 44pt hit 영역을 유지하고 Reduce Motion에서는 전환 애니메이션을 사용하지 않는다.

보고서 수치는 이미 로드한 digest scalar를 표시하며 새 조회·AI 요청·수치 추정을 추가하지 않는다. 기존 문서·수면·펼침/접힘 아이콘과 원문을 보존하고, 컨디션·활동·서술 카드에는 유형별 심벌을 더한다. 고정된 네 섹션 구성이라 데이터 크기에 비례하는 새 렌더 루프나 반복 작업도 만들지 않는다.

### Validation and source validity

아래는 부모가 전달한 실행 상태와 이 reviewer가 읽은 기존 PNG/manifest/source를 구분한 기록이다. 문서 작성 과정에서 실행하지 않았다.

| Evidence | Result and limit |
|----------|------------------|
| Public `27d12c40` | `fd888` 제품 + routing test 7줄 조회 수정 |
| Validation `ae2598a6` | `f9c956e1` 제품 + 같은 routing 조회 수정 |
| iPad `f9c956e1` | 기존 report method 한 개 PASS. 제품과 TodayReading method 불변이므로 재사용; 새 routing helper 실행 결과는 아님 |
| Phone `f9c956e1` | report method 한 개 PASS, 다섯 named PNG 검토. 정상 collapsed는 스크롤 후 상태로 표지는 offscreen |
| Older Phone 증거 | dbea4ef0의 route+report 2/2 통과 및 최초 d369 그룹에서 통과한 deferred-readiness 항목을 각각 소스 일치 근거로 재사용한다. 최종 query patch의 새 실행으로 표기하지 않음 |
| Duo CLOSED 최초 `f9c956e1` | native back AX 조회 실패 보존. 제품 back 실패나 스크린샷 수집 실패로 바꾸어 기록하지 않음 |
| Duo CLOSED 수정 후 | ae2598a6에서 1/1 PASS. 엄격 체크포인트 2개와 전후 0° LCD, 실제 native back 탭·Today 복귀를 확인했다. 최초 실패는 보존했다. |
| Duo OPEN report | ae2598a6에서 1/1 PASS. 정상/펼친 원문/dark 최대 글씨와 엄격 ACK 7개, 전후 180° LCD-1을 확인했다. |
| Source review | chevron P2 해결 후 기존 독립 다섯 리뷰 finding0, native-query 후속 finding0. 새 다섯 agent 실행 주장 없음 |
| CI `fd888` | build PASS/iOS 2,734개/302 suites PASS. Watch는 destination ID를 찾지 못해 테스트 전 exit64; `/private/tmp/pr882-watch-fd888.log`. Watch PASS나 T09의 다른 인프라 실패와 혼동하지 않음 |

보고서 selector는 `DUNEUITests/TodayReadingUITests/testNotificationDigestReportPreservesDataAndDisclosure`다. 전체 회귀·모든 크기 클래스·VoiceOver 실기·성능 측정 통과는 주장하지 않는다.

실제 갤러리 경로는 `docs/design/full-redesign-map/review/t10-daily-report-native-2026-11-02/`다. 정식 맵의 T10 네 행·이미지와 관련 갤러리·보드·포털·비교 페이지에 설치하고 다른 화면·Watch의 원본을 보존했다. Phone 정상 스크롤 상태와 초기 표지를 구분하고, iPad 이전/이후 모델이 다르면 모델·viewport 차이를 명시한다. 각 이미지의 실제 commit·기기·상태·출처를 보존한다.

## Prevention

### Checklist Addition

- [ ] 기존 아이콘·chevron·label·AX value를 표현 변경 전후에 비교한다.
- [ ] 전체 요약은 생성 원문을 유지하고 preview/full의 prefix 및 길이를 함께 검증한다.
- [ ] 큰 글씨 문단은 전체 한 화면 포함 대신 가로 폭·읽을 수 있는 부분·스크롤 가능성을 확인한다.
- [ ] 조작 버튼은 viewport 안 전체 포함·hittable·최소 44pt와 실제 탭 결과를 확인한다.
- [ ] 네이티브 AX rail과 NavigationBar의 부모 차이를 확인하고 최종 복귀 assertion을 보존한다.
- [ ] 변경된 테스트 query와 불변 제품/별도 method의 증거 재사용을 구분한다.
- [ ] 이전 실패·조건부 재시도·pending·실행 예산을 그대로 기록한다.
- [ ] 이미지 툴 표시만으로 transient 렌더링 결함을 주장하지 않는다. 원본 재확인과 필요한 픽셀 비교로 검증한다.
- [ ] 다른 모델의 이전/이후 캡처 및 스크롤/초기 상태를 같은 조건처럼 표시하지 않는다.

기존 실행 예산·실제 디자인맵·문자열 카탈로그 규칙을 적용한다. `.claude/**` 원본이나 새 전역 규칙 수정은 필요하지 않다.

## Lessons Learned

정보 구조를 바꾸어도 원문·실제 값·아이콘·동작 단서는 함께 보존해야 한다. 네이티브 UI 테스트는 기기별 AX 부모 차이를 수용하되 실제 탭과 복귀 조건은 유지해야 한다. 큰 글씨의 긴 본문은 viewport를 넘는 것이 자연스러우므로 줄바꿈·가로 경계·부분 가독성과 조작 가능성을 각각 검증한다. 소스가 같은 제품 증거는 재사용할 수 있지만 최종 테스트 patch의 새 실행 결과로 바꾸어 서술해서는 안 된다. Pending 실행과 CI는 실제 receipt를 확인할 때까지 pending으로 남긴다.
