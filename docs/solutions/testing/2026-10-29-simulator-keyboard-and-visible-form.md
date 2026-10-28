---
tags: [simulator, keyboard, xcuitest, life, hit-testing]
category: testing
date: 2026-10-29
severity: important
status: verified-phone-scope
related_files:
  - DUNEUITests/Helpers/UITestHelpers.swift
  - .codex/skill-compat.md
  - .codex/ui-execution.md
  - .codex/agent-memory/ui-test-expert.md
related_solutions: []
---

# Solution: 소프트웨어 키보드 확인과 화면 밖 AX 키 제외

## Problem

Life 주간·예정 회귀 검사가 새 습관 메뉴에서 입력 폼으로 진행하지 못했다. 사용자가 하드웨어 키보드 연결 상태를 지적하고 소프트웨어 키보드 활성화를 직접 확인했다. 복구 후 재개에서는 폼 표시·필드 포커스·Weekly Swim 입력값이 확인돼 이전 실패 지점이 해소됐다.

### Symptoms

이후 테스트 helper가 Return 키를 탭하면서 kAXErrorFailure를 발생시켰다. 해당 키의 AX frame은 y1087–1141이었고 402×874pt 창 바깥이었다. XCTest는 hit point -1,-1을 보고했다.

### Root Cause

`dismissKeyboardIfPresent`가 키보드/툴바 버튼의 존재만 확인했다. 키보드가 실제로 보이지 않는 시점에도 AX 노드가 남을 수 있으므로, 존재만으로 누를 수 있는 버튼이라고 판단할 수 없었다. 이어 기존 폼 스크롤 helper가 CollectionView를 고려하지 않고 화면 밖10pt ScrollView를 선택하는 문제가 확인됐다. 반복 시작 안내문 검사는 조건 선택 후 화면 아래에 있는 문구를 그대로 조회하고 있었다. 메뉴 미진입과 화면 밖 Return 탭을 같은 실패 원인으로 합치지 않는다.

## Solution

### Changes Made

| File | Change | Reason |
|---|---|---|
| UITestHelpers.swift | 키보드·툴바 후보에 exists와 isHittable 적용, 보이는 CollectionView·Table·ScrollView 중 폼 선택 | 화면 밖 잔여 AX 노드에 탭/스와이프를 보내지 않음 |
| LifeRegressionTests.swift | 반복 시작 안내문을 스크롤로 드러낸 뒤 같은 문구 검증 | 선택 의미와 이후 분모·그룹 소속 assertion 유지 |
| .codex/skill-compat.md, ui-execution.md | 입력 UI 검사 전 소프트웨어 키보드 확인 | 사용자 확인을 환경 복구 근거로 인정하고 설정부터 분리 |
| .codex/agent-memory/ui-test-expert.md | 사용자 교정과 확인 근거 보존 | 이후 실행에서 같은 환경 점검 누락 방지 |

### Key Code

```swift
keyboardButtons.first(where: { $0.exists && $0.isHittable })
```

## Verification

- e2838920: 키보드 guard의 targeted UI build-for-testing 성공. 다음 실행에서 Return 탭 실패는 없어졌고 폼 컨테이너의 별도 실패를 확인했다.
- 1982ebe0: 폼 helper 수정 후 등록·주간 설정·편집 소비자3개 통과. 반복 안내문은 화면 밖 조회로 실패해 원본 PNG로 위치를 확인했다.
- c80b5f1e: 원래 주간/예정 회귀 검사1/1 통과, 표준 runner exit0. 두 습관 생성, 오늘1/3 분모 유지, Today/Weekly/Upcoming 소속 assertion을 끝까지 확인했다.
- 전체 Life 선택 실행의 최신 결과는26개 통과·옵트인 시각 감사3개 skip이며 full suite 통과를 뜻하지 않는다. 로그·receipt·이전 실패는 [검증 기록](../../reviews/2026-10-28-life-flow/README.md)에 보존한다. iPad/Duo의 기기 캡처는 별도로 진행한다.

## Prevention

- 전용 UDID의 키보드 상태를 확인하고, 사용자 직접 확인과 자동 검사 결과를 구분한다.
- 입력 성공 후 키보드 닫기 실패가 발생하면 키의 AX frame·hittability를 먼저 읽는다.
- 상태 변경만으로 이전 testcase를 통과 처리하지 않는다. 실패 지점별 원인과 재시도 이력을 보존한다.

### Checklist Addition

- [ ] 하드웨어 키보드 연결/소프트웨어 키보드 활성화의 확인 근거를 기록했는가?
- [ ] 키보드 키와 툴바 버튼이 실제로 눌릴 수 있는 상태인가?

### Rule Addition

Claude 원본은 유지하고 Codex adapter의 UI 테스트 규칙에 반영했다.

## Lessons Learned

사용자가 직접 확인한 환경 복구를 반영해 실행을 이어가야 한다. 메뉴, 입력, 키보드 닫기, 저장을 단계별로 확인하면 실제로 해소된 원인과 새로 발견한 테스트 helper 오류를 구분할 수 있다.
