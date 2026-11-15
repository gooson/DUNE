---
tags: [watchos, simulator, preflight, unit-runner, ci]
date: 2026-11-14
category: general
status: reviewed
related_files:
  - scripts/lib/watch-simulator-preflight.py
  - scripts/test-unit.sh
  - scripts/tests/test_watch_simulator_preflight.py
---

# Watch unit runner 사전 검증

## Problem

CI가 기기 목록에 남아 있지만 runtime bundle이 없는 Watch simulator를 선택했다.
clone 실패 이후 빈 destination ID가 출력되어 boot/test 단계까지 진행됐다.

## Solution

Watch unit 경로에서 clone 전과 boot 전 각각 simulator ID, 기기 가용성,
watchOS runtime 가용성 및 bundle 경로를 검증한다. name/OS 지정도 명확한
단일 기기로 해석하고 ID로 정규화한다. 조회 실패/timeout/모호한 선택은
즉시 실패한다. runtime 설치, 기기 삭제 또는 자동 복구는 하지 않는다.
iOS 실행 경로와 정상 boot retry 정책은 그대로 둔다.

2026-11-15 최신 runner에 통합하면서 `--build-before-boot`의 컴파일 후 부팅과
별도 live Xcode readiness 검사를 유지했다. source/clone 사전검증은 두 실행
방식에서 모두 부팅보다 먼저 수행한다.

## Prevention

기기 선택·clone·부팅 순서 변경 시 source 실패와 clone 후 실패에서 다음 단계가
실행되지 않는지 검사한다. 정상 경로뿐 아니라 `--build-before-boot`의 초기
부팅 생략도 fixture에 포함한다. 변경 경로는 CI workflow에 함께 등록한다.

## 검증 범위

fixture로 유효한 ID/name, 누락 runtime/bundle, 비가용 기기, 잘못된 ID,
query 실패/timeout, clone 이전 실패 시 boot/test 미실행을 검사했다.
최신 통합본은 preflight·unit runner·readiness 계약 43개 통과와 shell 구문,
dry-run argv, 설치 runtime의 읽기 전용 검증을 확인했다.
실제 GitHub runner에서 Watch unit test 성공 여부는 이 로컬 검증에 포함되지 않는다.
유효한 destination으로 boot한 뒤 발생하는 nil native architecture/exit 65는
별개 문제이며 이 preflight로 해결됐다고 간주하지 않는다.

## Lessons Learned

runtime 목록에 남은 기기 ID와 실제 사용 가능한 runtime bundle은 별도로
확인해야 한다. 중간 작업 폴더의 수정은 최종 PR에 반영됐는지 파일 단위로
대조하고, 검증된 최종 실행 순서를 보존하면서 통합한다.
