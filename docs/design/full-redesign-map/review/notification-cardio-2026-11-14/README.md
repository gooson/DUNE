---
tags: [notification, T12, watch, cardio, actual-capture]
date: 2026-11-14
category: plan
status: partial-verification
---

# 알림 상세와 Watch 유산소 실제 화면

[원본 PNG 갤러리](index.html)와 [출처·SHA256](manifest.json)을 함께 본다. 이미지 편집이나 합성을 거치지 않은 XCTest 원본을 복사했다.

## 알림 상세 T12

- 문장 분리 단위 테스트 5개가 통과했다. 다국어 레이블·소수 쉼표·CRLF·빈 줄·혼합 문장·일반 유형의 원문 대체를 확인한다.
- 최종 iPhone 검사 3개가 통과했다. 체성분 기본, 체성분 다크 최대 글씨, 일반 본문 다크 최대 글씨다. 일반 본문의 기본 검사는 앞선 실행에서 개별 통과했으며 기본 분기의 표시 동작은 동일하다.
- iPad 기본 검사 1개가 통과했다. 실제 저장 시각·두 값·읽기 폭·뒤로 복귀를 확인했다.
- iPhone의 실제 iOS T12 소스는 `63022ff33`과 같다. 커밋 전 working diff에서 실행한 캡처임을 구분한다. iPad는 같은 커밋의 iOS 소스다. Watch 소스의 별도 변경까지 전체 트리 동등성을 주장하지 않는다.
- 첫 실행의 24시간 시각 기대값 불일치와 첫 접근성 캡처의 좁은 제목은 실패·과거 근거로 보존했다. 날짜 표시 설정을 반영한 테스트 보정과 장식 아이콘 생략 뒤 최종 검사를 통과했다.

- Duo 접힘 검사 1개가 통과했다. 전후 활성 LCD와 7개 checkpoint ACK, 실제 뒤로 복귀를 확인했다. checkpoint005의 원본 PNG·AX만 완료 화면으로 출판했다.
- Duo 펼침은 검토된 setter의 성공 응답 뒤에도 LCD가 active, LCD-1이 inactive로 남아 UI 실행 전에 중단했다. 현재 `devicectl device`/`simulate`/`settings`와 `simctl ui` 도움말에 힌지 설정 경로가 없고, 과거 `device motion hinge-angle -d` 조회도 지원되지 않는다. 기기 허브 CUA 접근은 실제 Mac 잠금으로 차단됐다. 이 조합의 펼침 T12는 미갱신이며, 활성 LCD-1 readback을 확보한 뒤 해당 한 검사를 재개해야 한다. 숫자 각도를 측정했다고 기록하지 않는다.

기계 생성 UI receipt와 Duo readback은 [proofs](proofs/iphone-result.json)에 보존했다. 영어 fixture·기본 테마 범위이며 모든 언어·테마·글씨 조합의 통과로 확장하지 않는다.

## Watch C01·C02

시간 우선 유산소의 심박·현재 존·가변 구간 막대를 합쳤다. 칼로리는 상단에 두고 레벨 또는 거리·페이스/속도를 한 줄로 정리해 공간을 확보했다. 심박 미수신은 기존 `Zone --`와 비활성 막대로 표현한다.

40mm의 이전 두 실행에서는 존 막대가 하단 페이지 점과 겹쳤다. 마지막 레벨·거리 행의 한 줄 보정은 Swift 구문 검사와 앱·UI 테스트 컴파일을 통과했고 최종 native 검증은 자동 재시도 한도에 따라 사용자 예외 승인을 기다린다. 이 상태를 UI 게이트 통과나 C01·C02 새 완료 캡처로 표시하지 않는다. 기존 C05–C07은 별도 보조 상세 페이지여서 이번 변경 화면 ID에 포함하지 않는다.

마지막 소스의 `DUNEWatchUITests` 표준 `build-for-testing`이 통과했다. [컴파일 결과 발췌](proofs/watch-build-excerpt.txt)를 보존했다. 최종 40mm UI 검증은 승인 대기다.

## 원본 보존

로컬 실행 로그·receipt·xcresult와 초기 실패 PNG는 `.codex-checks/notification-cardio/evidence/` 및 worktree 전용 DerivedData의 원본 Test 로그에서 보존한다. 이 갤러리는 검증한 화면만 출판한다. Watch의 보정 전 실패 PNG를 최종 모습으로 복사하지 않는다.
