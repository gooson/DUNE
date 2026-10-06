---
tags: [iphone-duo, xcode-27-1, simulator, hinge, physical-orientation, cli, xctest, visual-audit]
category: testing
date: 2026-10-06
severity: important
status: reviewed
related_files: [scripts/duo-visual-audit.py, scripts/tests/test_duo_visual_audit.py, DUNEUITests/Helpers/UITestHelpers.swift, .codex/agent-memory/ui-test-expert.md]
related_solutions: []
---

# Solution: Duo 물리 전환의 백그라운드 제어와 실제 상태 검증

## Problem

Mac GUI 조작이 막혔다는 이유로 Duo Book/Open 전환 검증 전체를 대기시켰다. `simctl`에 hinge setter가 없다는 사실은 다른 CLI 제어 경로가 없다는 근거가 아니었다. 공식 orientation setter도 성공 JSON을 반환했지만 실제 후속 조회는 portrait였다.

### Symptoms

- 수동 checkpoint가 deadline 만료 또는 전환 실패 뒤 잘못 release돼 실제 자세 증거가 없는 PNG가 생성됐다.
- 단순 orientation setter 성공과 앱 viewport 변화를 혼동할 위험이 있었다.

### Root Cause

GUI 제약, 물리 이벤트 전달, 상태 readback, 앱 viewport 변화, 기능 검사 통과를 각각 확인하지 않았다. 검토한 Duo driver는 legacy orientation 이벤트 대신 vendor-defined `orientation-picker-control`을 사용한다. 이는 테스트용 비공개 simulator 경로이며 앱 API가 아니다.

## Solution

`3a49f100`의 호스트는 `DAILVE_DUO_HINGE_CLI`와 선택적 `DAILVE_DUO_ORIENTATION_CLI`를 사용한다. 둘 모두 명시적 UDID와 저장소 simulator lock 아래에서 설정한다. hinge는 목표 각도 ±1°의 유한값, orientation은 공식 devicectl get의 정확한 방향 일치를 요구한다. 이후 fresh XCTest AX와 내부/외부 native PNG를 수집한 뒤 ACK한다. 실패/timeout에는 ACK하지 않는다. 외부 lock FD는 child runner에도 상속한다.

### Changes Made

| File | Change | Reason |
|---|---|---|
| scripts/duo-visual-audit.py | FOLD/ORIENT driver, 실제 readback, receipt, lock FD 전달 | GUI 조작 없이 검증하고 잘못된 성공 방지 |
| scripts/tests/test_duo_visual_audit.py | 성공/불일치/timeout/dispatch 실패/paired capture 계약 | 실패 checkpoint release 방지 |
| DUNEUITests/Helpers/UITestHelpers.swift | 물리 전환 뒤 fresh AX handshake | 이전 자세의 snapshot을 증거로 사용하지 않음 |
| .codex/agent-memory/ui-test-expert.md / AGENTS.md | 검증된 source pin과 상태 판정 기준 | 다음 작업에서 같은 대기 판단 반복 방지 |

### 재현 가능한 준비

검토한 source revision은 hinge `7acb090dd7d28fb0aea8e1907211ceff15aa450e`, serve-sim `c60d583747b88a15616eeecec56f287ef5759769`다. 다음 세션에서는 작업별 임시 디렉터리에 repository를 받고 해당 revision을 checkout한 뒤 source를 확인한다. 전역 설치는 필요 없다.

- hinge 실행 파일: `bin/hinge`. `XDG_CACHE_HOME`을 작업별 임시 디렉터리로 설정한다.
- 회전 helper: serve-sim의 `packages/serve-sim/Sources/SimDuoHID/main.m`. 같은 디렉터리의 검토한 `build.sh`를 `DEVELOPER_DIR=/Users/shanks/Downloads/Xcode27.1.app/Contents/Developer`, `SERVE_SIM_ARCH=arm64`로 실행하고 출력 경로를 임시 디렉터리로 지정한다.
- helper는 `xcrun simctl spawn <명시적 UDID> <helper 절대 경로>`로 실행한다. stdin 한 줄의 `orientation 1`은 physical portrait, `orientation 3`은 physical landscapeLeft, `orientation 4`는 physical landscapeRight다. enum은 UI landscape convention과 CoreDevice physical convention이 반대라는 원본 구현을 기준으로 한다.
- 이번 임시 wrapper는 orientation token을 enum으로 바꿔 전달하고 reply `OK` 및 process exit 0을 확인한다. setter 뒤 호스트가 다시 `xcrun devicectl device orientation get --device <UDID> --timeout 10 --json-output -`를 호출한다.
- 원본 helper의 `OK`는 dispatch ACK다. 앱 회전·초안 보존 완료를 의미하지 않는다. 방향 불일치에서는 캡처와 checkpoint ACK를 수행하지 않는다.

앱에는 private HID code를 포함하지 않는다. 다음 SDK에서도 같은 경로가 유효하다고 가정하지 말고 제한된 실제 readback probe부터 수행한다.

## SDK 정리 감시

`scripts/duo-visual-audit.py`는 stdout을 별도 reader로 읽고 테스트 allowance 초과/Selected tests 종료 뒤 SDK cleanup이 60초 이상 정체하면 자신의 isolated runner group을 종료한다. 다음 testcase 시작은 감시를 해제한다. 결과는 `runner-result.json`에 기록한다. 29개 계약은 정상 완료, EOF 정체, 다음 case 보호, descendant pipe 해제 및 다른 runner 생존을 확인한다. 기능 timeout 자체의 원인 해결과는 구분한다.

## Prevention

- 기기를 이름이나 `booted`로 선택하지 않는다.
- GUI 잠금만으로 모든 백그라운드 UI 검사가 불가능하다고 결론 내리지 않는다.
- setter JSON, 실제 물리 상태, 활성 화면, 앱 viewport, 기능 assertion을 별도로 기록한다.
- paired PNG의 실제 header 크기를 읽는다. 파일명 또는 한 화면 크기만으로 Book/Open을 분류하지 않는다.
- 기존 실패 evidence를 보존하고 동일 실패를 이름만 바꿔 반복하지 않는다.
- native PNG를 직접 확인한다. 29개 호스트 계약 테스트는 앱 시각 QA 전체 성공을 증명하지 않는다.

## Lessons Learned

접힘의 실제 기본/최대 AX 입력·휴식 검사가 각각 2 passed / exit 0을 기록했고 물리 방향 probe도 portrait→landscapeLeft→portrait readback을 통과했다. 최종 countdown 전체 표시, 실제 앱 회전, 다른 화면, 이전 OS scene session 복원은 각각의 후속 receipt로 판단한다. [실행 근거와 잔여 범위](../../reviews/2026-10-06-duo-cli-fold-validation.md)를 최신 상태로 유지한다. 이 해결책은 CLI 제어·검증 원칙에 한정하며 전체 Duo 감사 완료 보고서가 아니다.
