---
tags: [swiftui, morning-briefing, dynamic-type, compact-sheet, toolbar, xctest, native-layout, evidence-provenance]
category: testing
date: 2026-11-02
severity: important
related_files:
  - DUNE/Presentation/Dashboard/MorningBriefingView.swift
  - DUNEUITests/Full/TodaySettingsRegressionTests.swift
  - docs/plans/2026-10-31-t09-morning-briefing-redesign.md
  - docs/design/layout-map/morning-briefing-proposal.md
related_solutions:
  - docs/solutions/general/2026-03-14-morning-briefing-feature.md
---

# Solution: 아침 브리핑의 큰 글씨 배치와 compact sheet 툴바 검증

## Problem

### Symptoms

아침 브리핑 재설계는 일출 히어로와 네 카드 장식을 추가했지만, 네이티브 최대 접근성 글씨 캡처에서 선행 아이콘이 본문 폭을 좁히는 문제가 드러났다. 일반 글씨와 같은 가로 배치를 유지하면 긴 회복·가이드 문장이 지나치게 가늘게 줄바꿈된다.

Duo 접힘 상태의 첫 검증에서는 카드 스크롤 도중 Done이 접근성 트리에서 사라져, viewport 계산의 무조건적인 `done.frame` 읽기가 실패했다. 이 실패는 최종 Done 검증이나 닫기 동작에 도달하기 전에 발생했다. 최초 실패 기록과 이미지·hierarchy는 그대로 보존한다.

### Root Cause

접근성 글씨에도 아이콘과 본문을 같은 HStack에 두어 읽기 폭을 나눴다. 테스트 보조 함수는 스크롤 중에도 sheet 툴바 자식이 항상 존재한다고 가정했다. 실제 기록은 툴바 자식의 사라짐을 보여 주지만 SwiftUI 또는 시스템 내부 원인까지 입증하지는 않는다.

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Dashboard/MorningBriefingView.swift` | 접근성 글씨에서 카드 장식을 숨기고 원래 아이콘과 본문을 세로 배치; 아이콘은 32pt 사용 | 긴 본문의 읽기 폭 확보 |
| 동일 파일 | 일출 히어로, 정적 심벌·능선 장식, 읽기 최대 폭, 제목 header trait | 화면 표현과 제목 탐색 개선 |
| 동일 파일 | 비활성 장면에서 stagger를 종료하고 남은 섹션 즉시 표시 | 화면 생명주기에 맞춘 유한 애니메이션 |
| `DUNEUITests/Full/TodaySettingsRegressionTests.swift` | 툴바 요소 존재 확인 후 frame 읽기, Done 복원 시 최대 여섯 번 content 내부 드래그 | 사라진 AX 요소 조회 예외 방지와 실제 닫기 가능성 확인 |
| 동일 파일 | 두 대상 selector와 opt-in 아침 캡처에 `--ui-dashboard-hour 6` 지정 | 실제 실행 시각과 독립적으로 기존 아침 표시 조건 검증 |
| 레이아웃·테마·실제 화면 맵 | 시안과 네이티브 캡처를 출처와 함께 구분 | 이전 이미지나 시안을 새 실행 증거로 오인하지 않도록 유지 |

### Key Code

```swift
let navigationBottom = navigation.exists ? navigation.frame.maxY : scrollFrame.minY
let doneBottom = done.exists ? done.frame.maxY : scrollFrame.minY
let toolbarBottom = max(navigationBottom, doneBottom)
```

기존 제목 전체 viewport 포함·hittable 조건, 본문 최소 24pt 노출, 가로 경계 조건은 유지한다. Done이 이미 보이고 hittable이면 복원 드래그를 실행하지 않는다. 복원이 필요하면 콘텐츠 viewport 안에서만 최대 여섯 번 드래그한 뒤 Done 존재·창 안 전체 프레임·hittable을 다시 확인한다. 두 테스트 모두 실제 Done 탭을 수행하며 일반 글씨 테스트는 sheet 사라짐도 기다린다.

제품 데이터와 시간 경계는 유지한다. 기존 `LocalDayPeriod`와 `DashboardClock`을 그대로 사용하여 06:00–09:59의 `Good Morning`과 이후 수동 진입의 `Morning Briefing`을 히어로와 compact navigation title에 공유한다. 6시 고정은 해당 UI 시나리오의 launch 인자이며 전역 제품 시계나 아침 외 진입 정책을 바꾸지 않는다. 기존 템플릿·회복/가이드/주간/날씨 순서, 네 원래 아이콘, 날씨 제목·메시지가 모두 있을 때만 표시하는 nil 분기를 보존한다. 새 HealthKit 조회나 허구 측정값은 추가하지 않는다. 주간 장식은 추상 능선이며 측정 그래프가 아니다.

### Validation and source validity

현재 소스 기준은 `7b31cd8e`다. 제품 뷰는 앞선 `2fc`/`fd227` 검증 이후 동일하며, `60dc722f` 이후 변경은 테스트 private helper의 24줄 추가/2줄 삭제다. 다음은 부모가 전달한 실행 근거로, 이 문서 작성 과정에서 재실행하지 않았으며, 아래의 실제 실행 기록과 최종 캡처를 확인했다.

| Evidence | Result and limitation |
|----------|-----------------------|
| iPad `fd227` | 대상 두 테스트 PASS 재사용. 제품 뷰 근거이며 최종 변경 helper로 새로 실행한 결과는 아님 |
| Duo OPEN `31718cae` | 대상 한 테스트 PASS, 엄격 체크포인트 8개 ACK. 승인된 추가 실행 1회 소진, remaining 0 |
| Duo CLOSED 최초 `31718cae` | Done frame 조회에서 FAIL. 최초 실패 보존 |
| Duo CLOSED 수정 후 `94d7a48b` | 대상 한 테스트 PASS, 체크포인트 8개 ACK. 부모가 002/005/006 이미지 확인; Done 복원과 실제 닫기 PASS |
| iPhone `94d7a48b` | 대상 두 selector 2/2 PASS. 기본·dark 최대 접근성 글씨의 실제 캡처를 부모가 확인했다. 94d7a48b의 최종 helper로 실행한 결과다 |
| `60dc722f` CI | build PASS. Watch는 테스트 시작 전 CoreSimulator `host_support` 실패. iOS 2734개/302 suites PASS. 이후 7b31cd8e의 변경은 테스트 helper뿐이며 해당 helper는 새 Phone2·Closed1 실행에서 검증했다. 7b 원격 CI는 별도 상태이며 통과를 앞당겨 주장하지 않음 |
| Source review | 기존 다섯 리뷰 결과 finding 0 재사용, helper 후속 리뷰 finding 0. 새 다섯 agent 실행으로 기록하지 않음 |

두 selector는 `DUNEUITests/TodaySettingsRegressionTests/testMorningBriefingSectionsAndDismissal`과 `DUNEUITests/TodaySettingsRegressionTests/testMorningBriefingAtDarkMaximumAccessibilitySize`다. 전체 회귀나 성능 측정 통과를 주장하지 않는다. 실제 화면 맵의 T09 네 행·이미지와 전후 비교 갤러리 41개 PNG를 설치했다. 출처·해시·로컬 링크·중복 ID와 다른 화면·Watch 보존을 확인했다.

## Prevention

### Checklist Addition

- [ ] 최대 접근성 글씨에서 원본 아이콘이 긴 본문 폭을 좁히지 않는지 새 PNG로 확인한다.
- [ ] 스크롤 중 사라질 수 있는 AX 요소는 존재 확인 후 frame을 읽는다.
- [ ] 툴바 복원은 콘텐츠 내부의 유한 동작으로 제한하고, 최종 존재·전체 프레임·hittable·실제 닫기를 유지한다.
- [ ] 아침 시나리오는 기존 dashboard-hour 인자를 사용하며 제품 시간·데이터 조건을 우회하지 않는다.
- [ ] 제품 소스 증거 재사용과 변경된 테스트 helper의 새 실행 여부를 분리해 기록한다.
- [ ] 실패 원인에 대응한 변화가 있을 때만 제한된 재시도를 수행하고 최초 실패와 예산을 보존한다.
- [ ] 캡처 출처 commit·기기 상태·ACK·육안 확인 여부를 함께 기록한다.

기존 Codex 실행 예산·디자인맵 규칙을 적용한다. `.claude/**` 원본 수정이나 새 전역 규칙은 필요하지 않다.

## Lessons Learned

네이티브 테스트 PASS만으로 긴 글씨의 읽기 폭을 보장할 수 없다. 실제 PNG 검토가 별도 배치 문제를 찾았다. compact sheet의 접근성 트리는 스크롤 중 변할 수 있으므로 테스트는 그 상태 변화를 처리하면서 최종 사용자 동작 검증을 유지해야 한다. 소스가 같은 제품의 기존 실행은 재사용할 수 있지만, 변경된 helper를 실행한 결과처럼 기록하면 안 된다. 시간 조건이 있는 UI는 기존 주입 지점을 이용해 안정화하고 실제 제품 시간 정책을 보존한다.


최종 공개 전 보완: 7b31cd8e 원격 Watch job 125171168382는 xcodegen 설치 단계에서 ghcr.io DNS 해석 실패로 중단되어 0건 실행이다. 60dc의 host_support 실패와 다른 실행 전 환경 실패이며 둘 다 통과로 기록하지 않는다. Watch 소스·테스트·실행기 변경이 없는 화면 PR에서 무관한 네트워크 복구나 Watch 재실행을 추가하지 않았다. 원격 빌드·iOS의 최신 상태는 PR에 별도로 표시한다.
