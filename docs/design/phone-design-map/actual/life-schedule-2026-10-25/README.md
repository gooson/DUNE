---
tags: [life, habits, schedule, actual-capture, iphone, ipad, duo]
date: 2026-10-25
category: design
status: approved
---

# L01 습관 일정 분리 실제 캡처

[갤러리](index.html) · [원본 출처와 hash](manifest.json) · [검증 기록](../../../../reviews/2026-10-25-today-habit-schedule.md)

PNG 25장은 정상 종료한 xcresult의 원본이다. 기기별 4개 일정 viewport는 주간·7일 주기를 실제 폼에서 추가한 뒤 Today 3 / Weekly 1 / Upcoming 1과 오늘 1/3을 확인한다. 일반 iPhone/iPad/Duo 내부에는 기존 히어로의 밝음·어두움·최대 접근성 글씨 3장씩을 추가했다. 일정 검사는 en_US, 히어로 검사는 기기 locale이다. 모든 그룹의 큰 글씨·모든 테마/방향/언어를 검증했다는 뜻은 아니다.

일반 iPhone 묶음은 38 수행·36 통과·알림 2 실패다. 그 안의 Life 16개는 모두 통과했다. Duo 외부 1/1, iPad 2/2, Duo 내부 2/2, iPad 전체 Upcoming 캡처 보정 1/1이 통과했다. 세부 실패·제외 근거는 리뷰 문서에 보존했다.

Duo의 내부 LCD-1은 전환 후 공식 readback과 테스트 전후 readback, 새 native PNG/AX/window로 확인했다. 현재 Xcode에는 기존 motion 조회 명령이 없어 실제 수치 각도를 보증하지 않는다. 숫자 180은 검토한 도구에 전달한 요청값이다. 전용 기기 이외의 Simulator나 GUI는 조작하지 않았다.

`manifest.json`의 각 항목에는 개별 테스트·시각·revision·UDID와 PNG/짝 AX hash가 있다. 원본 AX와 xcresult는 기록된 로컬 작업 경로에 보존했다. 재실행은 `scripts/test-ui.sh --no-regen --test-plan DUNEUITests-DesignCapture --simulator-udid <소유 기기> --only-testing DUNEUITests/LifeRegressionTests/testWeeklyAndFutureRecurringHabitsStayOutsideTodayProgress`를 사용한다. 미확인 기기나 공용 `booted`를 사용하지 않는다.
