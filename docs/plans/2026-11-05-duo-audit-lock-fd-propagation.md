---
tags: [duo, tooling, simulator-lock, file-descriptor]
date: 2026-11-05
category: plan
status: implemented
---

# Duo 캡처 하위 프로세스의 검증 잠금 전달

## 배경과 범위

P06/H07 큰 글씨 검사는 이력 진입 수정 뒤 저장된 자세 상세에 도달했지만 첫 `FOLD:closed`에서 소유권을 검증하는 hinge CLI가 `Bad file descriptor`로 중단됐다. 관찰자의 `subprocess.run`은 잠금 FD 환경 변수를 물려주면서 실제 FD를 닫고 있었다. 앱·테스트 데이터·타임아웃을 바꾸지 않고 관찰자에서 검증 실행기와 hinge 하위 프로세스로 두 종류의 잠금 FD를 전달한다. 기존 소유권 검증은 하위 표준 도구에 남긴다.

## Affected Files

| 파일 | 변경 |
| --- | --- |
| `scripts/duo-visual-audit.py` | 설정된 repository/worktree 잠금 FD의 유효성을 확인하고 필요한 하위 프로세스에만 전달 |
| `scripts/tests/test_duo_visual_audit.py` | 실제 자식 프로세스 FD 전달, 양쪽 잠금, 중복·미설정·잘못된 값 경계 검사 |
| `docs/solutions/testing/2026-11-05-duo-audit-lock-fd-propagation.md` | 원인·한정 검증·후속 실제 접힘 검증을 구분해 기록 |

## Implementation Steps

1. 기존 `simulator-test-lock.py`의 두 환경 변수와 observer의 자식 호출을 확인한다. 실패한 두 실행과 불완전한 SDK 결과는 보존한다.
2. main 기준 별도 도구 브랜치에 최소 수정과 관련 Python 계약 테스트를 구현한다. 잠금 파일·기기 소유권 검사, 검사별 예산, 재시도 한도와 기존 실패 기록은 바꾸지 않는다.
3. 해당 observer/lock 계약 테스트를 표준 pipeline으로 한 번 수행하고 독립 리뷰를 받는다. 앱 코드가 없으므로 앱 빌드·네이티브 검사를 이 도구 PR에 추가하지 않는다.
4. 일반 merge로 병합한 뒤 원래 기능 브랜치에 반영한다. 실제 접힘 동작은 기존 P06/H07의 동일 검사·소유 기기에서 별도로 검증하며 도구 단위 테스트를 실제 UI 통과로 표시하지 않는다.

## 검증 전략과 위험

정상 설정에서는 두 열린 FD가 실제 자식에서도 `fstat` 가능한지 검사한다. 중복 FD는 한 번만 전달하고, 설정되지 않으면 빈 튜플로 유지한다. 잘못된 값이나 닫힌 FD는 자식 실행 전에 오류로 처리한다. 이미 열린 FD라는 사실만으로 잠금 파일의 소유를 인증하지 않으며 기존 하위 검증기는 그대로 유지한다. 외부 기기·공용 서비스·SDK 설치를 건드리지 않는다. 표준 observer의 종료 처리와 시간 제한은 기존 회귀 테스트로 확인한다. orientation 경로 등 현재 오류와 관계없는 개선은 분리한다.

## 결과

기존 observer/lock 계약 49건과 독립 리뷰 후 추가한 단일 FD 경계 1건이 각각 통과했다. 앱·시뮬레이터 실행은 수행하지 않았고 실제 접힘 검증은 원래 기능 작업의 남은 게이트다. 소유권 검사·시간 제한·이전 두 실패 기록은 유지했다.
