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

2026-11-21에는 자동 선택과 명시적 목적지를 구분했다. PR #1027의 후속 Watch 실행에서 27.0 기기 5대가 모두 사용 불가였고 27.2 기기 5대는 사용할 수 있었다. 기본 실행은 기기 목록과 런타임 정보를 함께 읽고 유효한 후보에서 요청한 모델과 OS를 우선한다. 해당 조합이 없으면 같은 모델의 최신 호환 런타임을 고른다. 직접 지정한 목적지와 생성된 clone은 각각 원래 ID를 검증한다. [당시 Watch 실행](https://github.com/gooson/DUNE/actions/runs/44808746479/job/136539656937)

[실제 재검증](https://github.com/gooson/DUNE/actions/runs/44858729654/job/136706927174)에서 27.0은 검증을 통과한 직후 복제 단계에서 런타임을 잃었다. 수집한 런타임 JSON에는 27.2만 남았다. Watch CI는 러너에 설치된 Xcode 27.2와 watchOS 27.2를 함께 선택하고, clone 명령이 실패하면 비어 있는 ID를 다음 단계로 출력하지 않는다.

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
