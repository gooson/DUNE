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

40mm 이전 두 실행의 하단 겹침을 보존하고, 사용자가 승인한 추가1회에서 러닝 시간 우선·계단6존·계단 심박 미수신3개 검사가 모두 통과했다(실패0·skip0). 새 C01·C02 원본 PNG를 별도 최종 리뷰어와 주 에이전트가 확인했고 막대와 페이지 표시점 사이 간격을 확인했다. 레벨·거리/페이스·심박·존·칼로리가 첫 화면에 보인다. [기계 생성 실행 결과](proofs/watch-approved-result.json)를 보존했다.

기본 글씨의 Apple Watch SE3 40mm·watchOS27.2 범위다. C02 캡처는 한국어, C01은 러닝 명칭과 존이 영어다. 큰 글씨·Always-On·VoiceOver와 모든 언어·테마 조합은 검증하지 않았다. 심박 미수신 테스트는 통과했지만 별도 PNG를 저장하지 않았다. C05–C07은 별도 보조 페이지로 갱신 대상이 아니다. 이전 C01·C02 PNG는 `assets/watch-before-C01.png`, `assets/watch-before-C02.png`에 역사적 화면으로 보존했다.

## 원본 보존

로컬 실행 로그·receipt·초기 실패 PNG와 내보낸 첨부 원본은 `.codex-checks/notification-cardio/evidence/`에 보존한다. 남아 있는 xcresult 원본 3개는 `.codex-checks/notification-cardio/original-xcresults/`로 원자 이동해 보관했다. 소유 시뮬레이터 4개와 완료된 빌드 캐시를 정리했으며 소유권·보관 기록은 `.codex-checks/notification-cardio/cache-cleanup.json`에 있다. 최종 Watch 실행의 xcresult와 로그도 함께 보존한다. 갤러리의 새 완료 캡처는 T12 8장과 Watch2장이다.
