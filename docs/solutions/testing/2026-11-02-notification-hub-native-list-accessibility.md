---
tags: [swiftui, notification-inbox, native-list, dynamic-type, accessibility, xctest, virtualization, segmented-control, source-closure, retry-budget]
category: testing
date: 2026-11-02
severity: important
related_files:
  - DUNE/Presentation/Dashboard/NotificationHubView.swift
  - DUNEUITests/Smoke/DashboardSmokeTests.swift
  - DUNEUITests/Full/TodaySettingsRegressionTests.swift
  - docs/plans/2026-10-31-t11-notification-hub-redesign.md
related_solutions:
  - docs/solutions/architecture/2026-03-03-notification-inbox-routing.md
  - docs/solutions/architecture/2026-03-08-notification-root-push-from-current-screen.md
---

# Solution: 알림함의 큰 글씨 읽기 폭과 가상화된 List 요소 검증

## Problem

### Symptoms

알림함의 읽지 않은 상태를 강조하고 아이콘이 앞에 오는 건강·업데이트 행을 유지하면서 최대 접근성 글씨의 읽기 폭을 확보해야 했다. 제목·상대 시각·읽지 않음 표시와 긴 본문이 같은 좁은 가로 열을 경쟁하면 줄바꿈이 많아지고 상태·행·동작의 위계가 흐려진다.

최초 Phone MAX 검사에서는 네이티브 segmented Picker의 접근성 프레임 높이 약 31.3pt에 44pt 조건을 적용해 실패했다. 같은 실행의 별도 빈 상태 검사는 기본 한국어 환경에서 영어 Health 레이블을 찾아 실패했다. 조건부 재시도에서는 빈 상태 검사가 통과했지만, MAX 검사가 스크롤 밖으로 가상화된 필터의 frame을 직접 읽다가 snapshot 조회에 실패했다. 이 두 실행과 실제 실패 원인을 그대로 보존했다.

### Root Cause

네이티브 컨트롤의 AX 프레임이 물리적인 터치 영역을 모두 나타낸다고 가정했다. custom 버튼의 최소 타깃 검사와 시스템 segmented control의 표시·선택·조작 검사를 구분하지 않았다. 또한 SwiftUI List가 화면 밖 요소를 접근성 트리에서 제거할 수 있는데도 존재 여부와 무관하게 frame을 읽었다.

큰 글씨의 콘텐츠는 List의 실제 제안 폭과 가용 viewport 안에서 자연스럽게 높이가 늘어나야 한다. 아이콘·제목 헤더의 선행 여백을 본문 전체에도 적용하면 본문 읽기 폭이 불필요하게 줄어든다. 제목 전체가 보이는 조건과 긴 본문의 일부를 읽고 스크롤할 수 있는 조건도 서로 다르다.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `NotificationHubView.swift` T11 구간 | 읽지 않은 상태를 큰 글씨로 표현하고 접근성 크기에서 아이콘·상태·Read All을 세로 배치 | 상태와 주요 동작의 읽기 위계 확보 |
| 동일 구간 | 건강 행의 아이콘·제목·시각과 본문을 다른 세로 영역으로 구성 | 본문이 헤더 아이콘 열을 벗어나 카드 폭을 사용하도록 배치 |
| 동일 구간 | 최대 글씨에서 제목·시각을 세로 배치하고 본문 lineLimit을 해제 | 긴 제목과 본문이 intrinsic 높이로 성장하도록 허용 |
| 동일 구간 | 업데이트 제목·버전과 전체 intro를 분리하고 Unread 텍스트 사용 | 원래 payload와 상태를 보존하면서 색 점 하나에 의존하지 않도록 표현 |
| `DashboardSmokeTests.swift` | 존재 확인 뒤 frame 읽기, 없는 요소는 의미에 맞는 방향으로 유한 스크롤 | 가상화된 List 요소의 snapshot 조회 실패 처리 |
| 동일 파일 | custom 버튼 44pt와 native Picker의 표시·선택 조건을 구분 | 잘못된 AX 프레임 가정 제거, 실제 사용자 조작 검증 유지 |
| `TodaySettingsRegressionTests.swift` | 빈 상태 검사에서 Health를 고정된 두 번째 세그먼트로 선택하고 실제 선택·빈 상태 확인 | 기본 언어 차이를 처리하면서 기능 assertion 유지 |

네이티브 List·segmented Picker·swipe read/unread/delete·Read All·설정·삭제 확인과 실제 목적지는 유지한다. 읽지 않은 수는 기존 combinedUnreadCount만 사용한다. 새 측정값·차트·필터별 추정 개수나 저장소 쓰기를 추가하지 않는다. bell/badge, gearshape, ellipsis, sparkles, 각 insight와 목적지 힌트의 원래 심벌을 보존한다.

### Key Code

```swift
if element.exists {
    let frame = element.frame
    // 가로 경계와 제목/컨트롤의 전체 표시 또는 본문의 읽을 수 있는 부분 확인
    // 표시된 요소의 실제 위치에 따라 다음 스크롤 방향 결정
} else {
    switch missingDirection {
    case .towardTop: movingUp = false
    case .towardBottom: movingUp = true
    }
}
```

helper는 최대 열 번 반복한다. front List와 창의 교집합에서 내비게이션·하단 탭 영역을 제외한 viewport 안으로 드래그를 제한한다. 없는 요소를 성공으로 처리하지 않는다. 제목·컨트롤은 전체 프레임과 hittable을 확인하고, 긴 본문은 가로 경계와 최소 24pt의 읽을 수 있는 부분을 확인한다. 필터는 위쪽, 건강·업데이트 내용은 아래쪽이라는 의미를 호출부에서 전달한다.

Settings·Read All의 custom 타깃에는 기존 44pt 높이 assertion을 유지한다. 네이티브 segmented Picker에는 가려지지 않은 viewport·가로 경계·세 세그먼트 존재·hittable과 실제 Health/News 선택 및 내용 검증을 적용한다. 31.3pt AX 높이를 근거로 시스템 컨트롤의 물리 터치 영역이 44pt인지 인증하거나 반대로 제품 결함으로 단정하지 않는다.

### Source closure and shared-file boundary

공개 소스는 `bfed37ab`의 T11과 최신 main의 실제 병합이다. 검증 소스 `ae2598a6`에는 아직 다음 PR의 T12/T13도 있으므로 `NotificationHubView.swift` 전체 일치를 주장하지 않는다. `private struct NotificationMessageDetailView` 앞의 T11 prefix만 비교했고 관련 MAX method와 helper도 별도로 일치시켰다. 공개 main의 T12/T13 tail은 그대로 유지한다. 공유 파일 전체를 validation 버전으로 덮어써 다음 작업을 조기에 포함하지 않는다.

### Validation and execution history

소스 log/diff, 실제 실행 결과와 원본 캡처를 함께 기록한다. 유효한 동일 범위 통과 결과는 재사용하고, 새 검사는 미확인 상태에 한정했다.

| Evidence | Result and limitation |
|----------|-----------------------|
| 최초 `t11-ui-hub`, `730b39b4` | 4개 중 2 PASS/2 FAIL. MAX native segment AX44pt 가정과 빈 상태의 영어 Health 조회 실패 보존 |
| 조건부 재시도 `b6ac0790` | 2개 중 1 PASS/1 FAIL. 빈 상태는 통과, MAX는 offscreen 가상화 필터 frame 조회 실패. 기존 자동 재시도 소진 |
| 원래 raw check | `check-9c602a5f40860c2606f9cf4c.json`에 두 실패 실행의 명령·결과·로그 해시 보존. 과거 null ID 기록을 새 실패나 0회로 바꾸지 않고 복구 출처를 구분 |
| 정상 Phone `7be65148` | `testNotificationHubControlsTransitionToEmptyState` 1/1 PASS. 동일 T11 prefix·관련 method 근거로 재사용하며 MAX 통과나 새 전체 트리 실행으로 표시하지 않음 |
| 승인된 추가 Phone MAX `ae2598a6` | 원래 `DUNEUITests/DashboardSmokeTests/testNotificationHubSummaryAtMaximumAccessibilitySize` 1/1 PASS. 별도 승인 1회 consumed1/remaining0, 원래 두 실패 기록 유지 |
| Phone MAX 실제 PNG | 부모가 5개 원본을 확인했고 독립 reviewer가 같은 원본에서 SwiftUI·Apple UX·UI-test 세 관점을 적용하여 finding0. 세 관점은 한 reviewer이며 세 agent 실행이 아님 |
| iPad `ae2598a6` | 기존 controls 메서드 1/1 PASS. 실제 Pro 13 원본에서 All/읽음 처리/메뉴/삭제 확인/확인 후 All/Health 빈 상태 확인. 과거 mini 전후 비교는 모델·viewport 차이를 명시 |
| Duo `ae2598a6` | 같은 전용 기기에서 접힘·펼침 controls 각 1/1 PASS. 각각 엄격 ACK7, 실행 전후 0° LCD 및 180° LCD-1 확인. 정상 글씨의 상태 전환 검사이며 Duo MAX 전체 검사가 아님 |
| 공개 `bfed37ab` CI | 앱 빌드 PASS, iOS Swift Testing 2,734개/302 suite 및 XCTest 12개 PASS, Watch 213개/29 suite PASS. 최종 문서 변경 이후 앱을 다시 실행한 것으로 표시하지 않음 |

Phone MAX 실제 상태는 요약/필터, 건강 제목·본문, 업데이트 제목·intro다. 서로 다른 스크롤 위치의 이미지는 한 화면에 모두 보이는 상태로 해석하지 않는다. 본문을 드러내려고 제목이 내비게이션 위로 이동한 것은 스크롤 결과로 기록한다. 실제 메서드 통과는 Settings/menu/back/swipe와 모든 저장 상태를 검증한 전체 회귀가 아니다.

승인된 one-shot guard는 원래 두 실패 record 해시와 정확한 selector를 확인하고, 전용 소스·기기·잠금을 검증한 뒤 dispatch 전에 consumption marker와 ledger를 보수적으로 저장한다. 실패나 중단이 발생해도 승인을 환불하거나 반복하지 않는다. 새 proxy 기록은 승인 예외의 출처이며 원래 실패 ID를 지우거나 이름을 바꾸어 재시도 횟수를 초기화하는 수단이 아니다.

원래 `ui-retry-remediation.json`의 pending/remaining 값은 두 번째 실제 실패보다 앞선 문서다. 현재 예산은 실제 실패 receipt와 명시적 승인 ledger/소진 marker를 함께 읽어 판단한다. 오래된 pending 텍스트를 최신 성공·남은 승인으로 해석하지 않는다.

## Prevention

### Checklist Addition

- [ ] 네이티브 List의 제목·본문을 실제 가용 폭과 최대 글씨에서 확인한다. 본문을 아이콘 헤더의 좁은 열에 가두지 않는다.
- [ ] AX 요소는 존재를 확인한 뒤 frame을 읽고, 가상화로 없으면 의미에 맞는 방향으로 유한 탐색한다.
- [ ] 탐색 종료 뒤 실제 viewport·hittable·선택 결과·내용 assertion을 유지한다.
- [ ] custom 타깃과 native segmented AX 프레임을 구분한다. 임의의 시스템 프레임 수치를 제품 터치 영역으로 단정하지 않는다.
- [ ] 언어 의존 레이블을 쓰는 검사는 언어를 고정하거나 안정적인 구조·식별자로 선택한 뒤 실제 상태 변화를 확인한다.
- [ ] 공유 파일에서는 해당 화면 구간과 관련 메서드를 비교하고 다음 PR의 tail을 함께 복사하지 않는다.
- [ ] 이전 실패·원래 ID·소진된 자동 재시도와 사용자가 승인한 단일 예외를 별도 출처로 보존한다.
- [ ] screenshot 성공, helper 소스 일치, 실제 selector 통과, 육안 관찰을 서로 다른 증거로 기록한다.

### Rule Addition (proposal only)

기존 Codex의 가상화 요소·핵심 검증·재시도·소스 보존 규칙으로 처리할 수 있다. 필요하면 향후 `.codex` 실행 어댑터에 “공유 파일은 화면 구간 단위로 증거 일치”와 “AX frame 조회 전 exists 확인” 예시를 보강하는 것을 제안한다. 이 문서 작업에서 `.claude/**`, 공통 규칙, 교정사항 또는 다른 화면 TODO를 수정하지 않았다.

## Lessons Learned

테스트가 시스템 컨트롤의 표현 방식을 잘못 가정하면 실제 기능보다 잘못된 프레임 조건이 실패 원인이 된다. 조건을 제거하는 데서 끝내지 않고 가려지지 않은 표시·실제 선택·읽을 수 있는 내용으로 원래 사용자 동작을 검증해야 한다. List의 가상화는 요소가 없다는 결과와 제품 콘텐츠가 없다는 결과를 구분하게 만든다. 소스 구간의 일치, 과거 통과의 재사용, 새 실제 실행과 예외 승인의 소비를 각각 기록하면 반복 실행 없이도 검증의 범위와 한계를 유지할 수 있다.
