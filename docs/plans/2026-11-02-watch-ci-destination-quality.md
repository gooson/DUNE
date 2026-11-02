---
topic: watch-ci-destination-quality
date: 2026-11-02
status: approved
confidence: high
---

# 현재 CI 이미지에 맞게 Watch unit runner 기본값 복구

## 문제와 근거

#878과 #879를 포함해 품질 검증이 대기 중인 상세 화면 PR은 Apple Watch Series 11 (46mm), watchOS 27.0을 요청하고, Watch 테스트를 실행하기 전에 사용할 수 없는 destination 오류로 실패한다. 기존 실패 CI 로그와 기기 목록에는 Series 12 (46mm), Series 12 (42mm), SE 3, Ultra 4가 있고 Series 11은 없다. 이는 실행 환경의 실패이며, 앱 assertion 실패가 확인된 것은 아니다.

읽기 전용 조사에서는 `scripts/test-unit.sh`, `.github/workflows/test-unit.yml`, runner 테스트 모듈 두 개, 기존 simulator/runtime 계획·해결책·TODO를 확인했다. 관련 선행 해결책은 unit-test selection contract, simulator preflight pipefail 처리, CI destination fallback 보강이다. 기존 unit resolver는 이미 27+ 하한을 적용해 사용 가능한 호환 runtime을 선택한다. 이전 로그에는 조회 전 실패 경로가 남아 있지 않으므로, 새 selector 알고리즘이 필요하다거나 기본값 변경으로 모든 fallback 실패의 원인을 진단했다고 주장하지 않는다.

## 범위와 구현 단계

1. `scripts/test-unit.sh`에서 `DUNE_WATCH_SIM_NAME`의 기본값만 Series 11 (46mm)에서 Series 12 (46mm)로 변경한다.
2. 명시적인 전체 destination의 우선순위, name/OS 선호값, 기존 dynamic resolver, worktree 소유권, preboot, suite 선택, 실패 보고는 유지한다. workflow에 기본값을 중복 선언하지 않는다.
3. 기존 `SimulatorVersionFloorTests`의 unit 함수 추출 경계를 수정한다. 이전 MODE 분기 표식은 더 이상 없으며, 뒤따르는 `preboot_from_destination()` 선언이 실제 경계다. fallback 검증을 위해 기존 Series 11/26.x fixture는 유지한다.
4. `scripts/tests/test_unit_test_runner.py`에 격리된 fake/dry-run contract 세 개를 추가한다. Watch 기본 name/OS, 명시적 name/OS, 둘보다 우선하는 전체 destination을 확인한다. 테스트 helper에서는 관련된 ambient Watch override만 제거한 뒤 테스트별 값을 적용한다.
5. 표준 pipeline에서 shell 구문, diff 검사, 대상 fake-only unittest 클래스 두 개를 실행한다. 이 scripts-only 변경에는 native Watch simulator, 앱 build, 무관한 전체 suite가 필요하지 않다.
6. 작은 diff를 독립적으로 리뷰하고, 발견사항을 해결하고, 한계를 문서화한 뒤 별도 tooling PR로 ship한다. 수정이 영향받는 브랜치에 반영된 다음 실제 원격 Watch job을 검증한다. 로컬 fake 결과는 원격 native 성공의 근거가 아니다.

## 영향받는 파일

| 파일 | 변경 내용 |
|------|-----------|
| `scripts/test-unit.sh` | Watch 기본 기기를 Series 12 (46mm)로 변경 |
| `scripts/tests/test_unit_test_runner.py` | Watch 기본값과 override 우선순위 contract 추가 |
| `scripts/tests/test_ui_test_runner.py` | 기존 resolver 함수 추출 경계 수정 |
| `docs/plans/2026-11-02-watch-ci-destination-quality.md` | 범위, 근거, 검증 계약 기록 |
| `docs/solutions/testing/2026-11-02-watch-ci-destination-default.md` | 해결책과 검증 한계 기록 |

## 검증 계약

`scripts/codex-pipeline.py` 아래에서 `bash -n scripts/test-unit.sh`, `git diff --check`, 실행 시간을 제한한 `python3 -B -m unittest scripts.tests.test_unit_test_runner.UnitRunnerTests scripts.tests.test_ui_test_runner.SimulatorVersionFloorTests`를 실행한다. 실제 양수 실행 건수를 확인한다. 모든 subprocess는 dry run 또는 fake tool을 사용한다. 로컬 simulator를 만들거나 native 앱/Watch 실행으로 범위를 넓히지 않는다.

## 위험과 대안

새 selector 전체를 하드코딩하거나 workflow 환경값을 추가하면 기존 정책을 중복하고 명시적 override를 가릴 수 있어 채택하지 않는다. 이전 fixture를 모두 새 기본값으로 바꾸면 fallback 검증이 사라지므로 유지한다. 기본값은 다시 오래될 수 있지만 기존 dynamic 27+ fallback은 남아 있다. 다음 원격 job에서도 사용할 수 없는 이름 기반 destination이 출력되면, 문제가 완전히 해결됐다고 주장하기 전에 선택 시점의 기기 목록과 override 맥락을 수집한다. 자격 증명, 환경값, 공유 hook 설정은 변경하지 않는다.
