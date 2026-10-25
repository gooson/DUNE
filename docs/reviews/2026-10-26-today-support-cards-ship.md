---
tags: [today, design, ship, validation]
date: 2026-10-26
category: review
status: reviewed
---

# Today 진행·브리핑 카드 최종 Ship

## 최종 범위

Today의 진행 목표 타일과 날씨·코칭 브리핑에 보조 표면, 제목, 목표·제안 구분을 적용한다. 기존 main의 시간대 정책은 유지한다. 진행은 22–06시, 브리핑은 17–06시에 숨긴다. 회복·수면 카드는 최신 main 구현을 그대로 사용하며 수면 단계 타임라인을 다시 도입하지 않는다.

main `7555b4bc`를 반영했다. `RecoverySleepCard.swift`는 origin/main과 바이트 단위로 동일하다. 원래 브랜치의 수면 단계 조회·단위 테스트 코드는 `2c1380d4`와 동일함을 diff로 확인했다. 당시 4/4 기록은 역사적 결과이며 이번 실행의 새 단위 테스트 통과 건수로 계산하지 않는다.

## 기존 finding 재조정

| 항목 | 현재 분류 | 근거 |
|---|---|---|
| 수면 지표·단계 동시 게시 | Resolved | `2c1380d4` 수정 유지. 관련 VM·단위 테스트 소스 동일 |
| 수면 단계 범례·Hours 단위 | Stale after fix | 수면 카드 전체를 최신 main 버전으로 채택. 현재 diff에 없음 |
| 회복 카드 전체 포함·작은 드래그 정체 P2 | Stale after fix | 실패했던 수면 카드 구현·식별자·해당 검사 경로 제거. 원래 실패 로그는 그대로 보존 |
| 병합 후 삭제된 수면 ID를 요구하는 테스트 P2 | Resolved | 현재 변경인 진행·브리핑의 배치·문구·전체 viewport·필수 제안 검사로 정렬. 기존 main의 수면 검사는 TodayReadingUITests에 유지 |
| 예전 수면 PNG의 현행 증거 표시 P2 | Resolved | 2026-10-24 갤러리·README·인덱스에 과거 보존본임을 명시. 촬영 당시 revision과 실패 기록 유지 |
| 진행률 번역 추출 키 | Resolved | 숫자 percent FormatStyle을 접근성 값에 사용. 새 문구 번역 키 불필요 |

기존 공통 알림 허브 두 실패는 자동 아침 브리핑 시트에 가려진 기준 코드 이슈다. 해당 화면·동작은 이번 diff에서 수정하지 않으며 이번 Ship의 기능 검사를 대신하지도 않는다.

## 최종 소스 검토

pr-reviewer가 현재 main 대비 diff와 후속 테스트·진행률 delta를 읽기 전용으로 검토했다. 남은 제품 코드 P1/P2는 0, 수정된 테스트 delta의 P1/P2는 0이다. 진행·브리핑의 실제 runtime 검사는 아래 실행 결과로 별도 판단한다.

## 실행 결과

진행·브리핑 밝음/어두움 및 최대 글씨 검사 2개를 전용 iPhone 18 Pro에서 실행해 2개 통과·0개 실패·0개 skip을 확인했다. 앱과 UI test target 컴파일도 성공했다. 새 원본 PNG6장을 [갤러리](../design/full-redesign-map/review/today-progress-brief-2026-10-26/index.html)에 보존하고 통합 포털을 갱신했다. 여백·겹침·잘림을 육안 확인했다. 로그와 receipt는 `.codex-checks/today-ship-iphone.log` 및 `.result.json`에 둔다. 전용 UDID는 `03BF6AD6-EE4D-40D2-87D2-33D31090F6DF`다.

전체 회귀·iPad·Duo 신규 검사는 이번 Ship에서 실행하지 않았다. 앞선 대화에서 사용자가 기존 미완료 검사에 대해 “패스하고 다음 단계”를 지시했으며, 이번에는 현재 main 병합 후 남은 두 카드의 관련 iPhone 검사만 수행한다. 전용 iPhone 결과를 다른 기기의 완료 증거로 확대하지 않는다. Watch는 이 화면을 공유하지 않는다.

카탈로그 포맷 검사·Swift 구문 검사·git diff 공백 검사가 통과했다. 이후 변경은 증거 문서·갤러리·포털뿐이다. 커밋 훅의 앱 재빌드는 같은 제품/테스트 소스의 UI build-for-testing 성공과 중복되어 환경 변수로 생략하며, 나머지 훅은 그대로 실행한다.

최종 증거 delta 재검토에서 PNG6개의 해시·앱/테스트 소스5개의 해시·현재 포털 연결을 확인했다. 두 P2는 Resolved이며 새 P1/P2는 없다.
