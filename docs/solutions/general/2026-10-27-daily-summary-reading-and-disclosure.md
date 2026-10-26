---
tags: [swiftui, daily-digest, disclosure, sentence-boundary, accessibility, native-capture, coredevice, device-ownership]
category: general
date: 2026-10-27
severity: minor
status: implemented
related_files: [DUNE/Presentation/Dashboard/Components/DailyDigestCard.swift, DUNETests/DailyDigestSummaryTextTests.swift, DUNEUITests/Visual/TodayReadingUITests.swift]
related_solutions: [docs/solutions/architecture/2026-10-26-shared-card-navigation-header.md]
---

# Solution: 오늘의 요약을 핵심 지표와 본문 펼침으로 읽기

## Problem

요약 카드의 날짜·수치·중복 보조 문구·떨어진 하단 제어가 넓은 여백 안에 분리돼 읽는 순서가 불명확했다. 상세 이동과 본문 펼침도 비슷한 표시를 사용했다. 사용자는 비교 시안의 1번 `핵심 먼저`를 선택했다.

### Root Cause

24pt 패딩과 별도 날짜 행이 높이를 키웠고, 두 지표의 구획 및 본문 제어의 소속이 약했다. 새로운 해석을 만드는 대신 이미 생성한 요약 원문을 짧게 제시할 표시 경계가 필요했다.

## Solution

| File | Change | Reason |
|---|---|---|
| DailyDigestCard.swift | 16pt 여백, 제목·날짜 한 행, 지표 구분선, 큰 글씨의 세로 배치 | 핵심 지표를 먼저 읽고 원문으로 이어지는 순서 |
| DailyDigestSummaryTextTests.swift | 영·한·일 문장 경계, 소수점, 공백, 단일/빈 요약 | 원문을 보존하며 불필요한 제어 방지 |
| TodayReadingUITests.swift | 일반/AX 펼침·접기·44pt·행 오른쪽 터치·알림 소비자·상단 촬영 | 동작과 실제 배치를 서로 다른 증거로 확인 |
| Localizable.xcstrings | Expand/Collapse summary와 en/ko/ja | 상세 이동과 펼침 의미를 구분 |

`DailyDigestSummaryText`는 표시 가장자리 공백만 정리하고 Foundation `.bySentences`의 첫 경계 구간을 선택한다. 한국어 괄호 뒤 경계가 다음 절까지 포함될 수 있다. 마침표로 직접 나눠 소수점·약어를 손상하지 않으며, 전체 원문은 펼친 상태에서 그대로 교체 표시한다. 단일 구간 또는 빈 원문은 불필요한 Button을 만들지 않는다. 긴 단일 문장은 자연 확장한다. 새 건강 해석·목표 달성률·계산·저장·라우팅은 추가하지 않았다.

실제 Button은 전체 폭과 최소44pt를 사용하고 문구 바로 옆 up/down chevron, 접근성 Expanded/Collapsed 값, Reduce Motion을 지원한다. 다른 화면으로 가는 제목 옆 right chevron과 의미가 다르다. Today T03와 알림 상세 T10은 같은 카드 컴포넌트를 소비한다.

### 검증 결과

표준 범용 Simulator 빌드가 통과했다. 관련 unit13개와 핵심/촬영 UI11개의 기기별 실행이 통과했으며 전체 회귀는 실행하지 않았다. 전용 iPhone·iPad·Duo 외부/내부의 활성 원본25장과 비활성 패널 짝10장을 보존했다. 첫 실패와 원인별 조건부 재검증은 리뷰 기록을 따른다. 사용을 마친 전용 시뮬레이터3대는 삭제했고 등록/미등록0을 확인했다.

### Key Code

```swift
Text(showsFullSummary ? text.full : text.preview)
// The native Button owns a full-width, at-least-44pt hit target.
// Empty and single-segment summaries omit unnecessary disclosure.
```

## Prevention

- SwiftUI 부모 layout에 붙인 접근성 ID가 날짜 등 자식에게 상속될 수 있다. 실패 AX 트리에서 실제 날짜에 header ID가 붙은 것을 확인해 제목 Label로 옮겼다. 제목 Label도 Image/Text가 ID를 공유하므로 촬영 anchor는 명시적인 StaticText를 선택한다.
- `isHittable`은 전체 카드가 viewport 안에 있다는 증거가 아니다. 제목 프레임과 실제 navigation 영역을 대조해 상단을 맞춘다. 펼친 뒤 위쪽으로 돌아올 때 초기 탐색의 swipeUp을 반복하지 않고 signed frame offset으로 방향을 정한다.
- 첫 문장 미리보기는 원문 경계를 재사용한다. 원문 생성기 변경 또는 새로운 언어 지원 시 해당 경계 fixture도 함께 검토한다.
- UI test pass, 정상 runner 종료, native 캡처 성공은 각각 확인한다. 유효 checkpoint PNG가 있어도 teardown이 실패한 실행 전체를 통과로 승격하지 않는다.
- 시뮬레이터 정체는 전역 서비스 강제 종료로 우회하지 않는다. 소유 기기·정확한 실패 의존성을 확인하고 공식 CoreDevice reboot 요청 뒤 실제 readback과 새 native PNG로 정상화를 검증한다. 같은 실패는 원인 해소 근거 후1회만 재검증한다.

## Lessons Learned

작은 카드도 지표 구획·정적 헤더·명시적인 본문 제어를 함께 정리하면 읽는 순서가 분명해진다. 전체 폭 버튼은 글자 옆 화살표와 빈 영역 터치가 함께 동작해야 한다. 접근성 크기는 별도 세로 레이아웃과 여러 viewport의 실제 원본을 대조해야 한다.

기존 교정사항에 안정적인 비상호작용 AX anchor 규칙이 이미 있어 새 전역 규칙은 추가하지 않았다. `.claude/**`는 변경하지 않았다. 관련 별도 TODO는 없었다. [계획](../../plans/2026-10-27-daily-summary-reading.md), [검토·실행 결과](../../reviews/2026-10-27-daily-summary-reading.md), [새 실제 화면과 출처](../../design/full-redesign-map/review/daily-summary-reading-2026-10-27/index.html)에서 범위와 제한을 추적한다.
