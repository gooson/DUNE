---
tags: [watchos, ci, simulator, destination, unit-runner, environment-overrides]
category: testing
date: 2026-11-02
severity: important
related_files:
  - scripts/test-unit.sh
  - scripts/tests/test_unit_test_runner.py
  - scripts/tests/test_ui_test_runner.py
related_solutions:
  - 2026-10-30-unit-test-selection.md
  - 2026-03-03-ios-build-destination-fallback-hardening.md
---

# CI 기기 이미지에 맞게 Watch unit runner 기본값 유지

## 문제 (Problem)

상세 화면 PR 품질 검증이 Watch 테스트를 실행하기 전에 실패했다. 실패한 job은 `Apple Watch Series 11 (46mm),OS=27.0`을 요청했지만, 호환 destination 목록과 수집된 기기 목록에는 Series 12, SE 3, Ultra 4가 있고 Series 11은 없었다. Xcode는 Watch assertion 실패가 아니라 사용할 수 없는 destination 오류로 종료됐다.

runner에는 이미 사용 가능한 기기를 고르는 dynamic resolver와 27+ runtime 하한이 있다. 이전 로그에는 선택 시점의 조회 출력이나 외부 override 맥락이 남아 있지 않다. 기본값의 기기를 사용할 수 없었다는 점은 확인됐지만, 이전 resolver 호출 이후에도 이름 기반 destination이 남은 정확한 원인은 나중에 얻은 기기 목록 snapshot만으로 증명되지 않는다.

## 해결 (Solution)

Watch 기본 name만 Series 11 (46mm)에서 Series 12 (46mm)로 변경한다. 기존 resolver와 다음 우선순위는 유지한다.

1. 명시적 `DAILVE_WATCH_DESTINATION`.
2. `DUNE_WATCH_SIM_NAME`과 `DUNE_WATCH_SIM_OS` 선호값.
3. runner 기본값. 실제 실행에서는 기존 호환 runtime fallback을 적용한다.

workflow YAML에 기본값을 중복 선언하거나, 소유권·clone·preboot 정책을 바꾸거나, shell 기본값을 검증하기 위해 로컬 Watch simulator를 추가하지 않는다.

기존 fake inventory 테스트에는 제거된 MODE 분기를 가리키는 별도의 오래된 추출 경계가 있었다. unit resolver 추출 구간을 뒤따르는 `preboot_from_destination()` 선언에서 끝내도록 수정한다. Series 11/26.x fixture는 유지한다. 새 기본값과의 단순 일치가 아니라 호환되는 Series 12/27.x fallback 선택을 검증하기 때문이다.

Watch-only dry-run contract 세 개를 추가해 기본값, 명시적 name/OS, 전체 destination의 우선순위를 확인한다. subprocess 환경을 복사하고 관련 Watch override 키 세 개만 제거한 뒤 테스트별 override를 적용한다. 부모 환경을 변경하거나 무관한 설정을 제거하지 않는다.

## 검증

`bash -n`, Python AST parsing, diff 검사를 통과했다. 대상 `UnitRunnerTests`와 `SimulatorVersionFloorTests` 클래스는 표준 pipeline에서 **24개 테스트**를 통과했다. 이 테스트는 dry-run 명령이나 fake binary와 임시 기기 목록을 사용한다. native Watch/앱 테스트를 실행하지 않으며, 특정 원격 runner에 기기가 있음을 증명하지 않는다.

보안, 성능, 아키텍처, 데이터 무결성, 단순성의 독립적인 정적 리뷰 다섯 개에서 새 문제가 발견되지 않았다. scripts/tests/documentation만 바뀌므로 앱 UI, localization, schema 검사는 적용 대상이 아니다. 실제 원격 Watch 실행은 수정이 대기 중인 PR에 반영된 뒤 수행할 별도 소비자 검증으로 남아 있다. 로컬 fake suite로 원격 성공을 추론하지 않는다.

## 예방 (Prevention)

- Xcode가 일치하는 destination이 없다고 보고하면 앱 코드를 바꾸기 전에 환경 선택 실패와 앱/테스트 실패를 구분한다.
- 기본값을 갱신할 때 명시적 destination override를 보존한다.
- 없거나 오래된 선호 기기로 fallback을 검증한다. 모든 fixture를 기본값으로 바꾸면 fallback 사례가 사라진다.
- 함수 추출 fixture를 실제 shell 경계와 일치시킨다.
- 다음 CI job에서도 사용할 수 없는 이름 기반 destination을 요청하면, 추측에 따른 selector 변경을 추가하기 전에 resolver 선택 시점의 기기 목록과 override 맥락을 수집한다.
- 로컬 simulator 소유권과 원격 CI 검증을 구분한다. shell contract 테스트에는 native simulator가 필요하지 않다.

## 배운 점

일반적인 fallback이 이미 있어도 한 줄의 기본값 변경이 적절한 수정일 수 있다. 근거에는 확인된 실패와 아직 불확실한 환경 경로를 정확히 구분해 적어야 한다.
