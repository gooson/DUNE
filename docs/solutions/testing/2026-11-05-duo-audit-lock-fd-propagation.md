---
tags: [duo, visual-audit, pass-fds, simulator-lock, subprocess]
date: 2026-11-05
category: solution
status: implemented
---

# Duo 관찰자에서 하위 프로세스로 잠금 FD 전달

## Problem

P06/H07 큰 글씨 검사에서 자세 상세에 진입한 뒤 첫 접힘 명령이 `Hinge 0 failed (1): [Errno 9] Bad file descriptor`로 중단됐다. 표준 소유권 wrapper는 `DUNE_SIM_TEST_LOCK_FD`와 repository 범위에서 추가되는 `DUNE_SIM_TEST_WORKTREE_LOCK_FD`를 실제 열린 파일 descriptor와 함께 상속한다. Python 관찰자의 hinge `subprocess.run`에는 `pass_fds`가 없어 환경 변수만 살아남고 descriptor는 자식에서 닫혔다. 검증 실행기 `Popen`도 기존에는 첫 번째 FD만 보존했다.

첫 이력 진입 실패와 두 번째 관찰자 중단은 별개로 보존했다. 두 번째 SDK bundle에는 `Info.plist`가 없어 완료 사례 수를 읽을 수 없다. 이를 통과나 정상 종료된 테스트 실패로 꾸미지 않고 host-aborted로 기록했다.

## Solution

`scripts/duo-visual-audit.py`의 `inherited_lock_fds()`가 설정된 두 환경 변수의 FD를 수집한다. 정수·열린 사용자 소유 일반 파일을 확인하고 중복은 제거한다. 잘못된 설정이나 primary 없이 남은 secondary는 자식 실행 전에 실패한다. 잠금이 설정되지 않은 기존 수동 관찰자 모드는 빈 튜플을 사용한다. 반환값을 hinge set/get과 검증 실행기 `Popen`의 `pass_fds`로 전달한다.

이 유효성 확인이 실제 잠금 소유권을 인증하지는 않는다. 기존 `simulator-test-lock.py --verify`와 기기 소유권 wrapper는 그대로 유지한다. 앱·fixture·접힘 각도·시간 제한·실패 횟수·자동 재시도 한도는 바꾸지 않았다. orientation 명령 경로는 이번 수정 범위 밖이다.

## 검증과 제한

`python3 -B -m unittest scripts.tests.test_duo_visual_audit scripts.tests.test-simulator-test-lock`의 계약 테스트 49건이 통과했다. 실제 임시 hinge 자식 프로세스가 두 FD에 `fstat`을 수행하고 set/get readback을 마친다. 기존 캡처 acknowledgement·기한·종료 처리 및 잠금 계약도 확인한다. 독립 리뷰로 추가한 `CaptureContracts.test_worktree_scope_inherits_single_primary_lock_fd` 1건도 별도 통과했다. 같은 본문을 재실행하지 않아 총 50개 사례를 한 번씩 확인했다.

앱이나 시뮬레이터를 실행한 검증은 아니다. 수정된 도구로 실제 0°·90°·180° 접힘을 완료했는지는 원래 P06/H07 검사의 새 증거로 별도 판단해야 한다. 기존 실패 기록이나 불완전한 SDK를 새 네이티브 성공으로 재분류하지 않는다.

## Prevention

- 환경 변수에 FD 번호를 전달하는 wrapper를 호출할 때는 `exec`·`Popen`·`run`마다 descriptor 생존 경계를 확인한다.
- repository/worktree 두 범위와 단일 FD·중복·미설정·닫힌 FD를 함께 검사한다.
- subprocess mock 인자 확인에 더해 실제 임시 자식에서 열린 FD를 읽는 계약 테스트를 유지한다.
- 관찰자가 중단되면 raw host 로그와 불완전한 SDK를 보존하고 종료된 사례 수와 구분한다.

## Lessons Learned

환경 변수 상속과 descriptor 상속은 별개의 계약이다. 같은 셸에서 성공한 소유권 검증도 Python 자식을 한 단계 더 거치면 실패할 수 있다. 기능 검사 도중 발견된 실행 도구 문제는 별도 도구 변경으로 분리하고, 그 단위 테스트를 실제 앱 UI 검증의 대체 근거로 사용하지 않는다.
