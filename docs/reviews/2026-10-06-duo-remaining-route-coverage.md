---
tags: [iphone-duo, visual-qa, coverage, remaining-routes]
date: 2026-10-06
category: review
status: completed
---

# Duo 잔여 화면 검증

2026-10-06 시작, 10-07 후속 검증. UI 동작, 전체 접근성 frame, 원본 native 픽셀 검토를 구분했다. 인벤토리의 155개는 진입 선언 수이며 고유 화면·검증 조합의 분모가 아니다. 이 숫자로 완료율을 계산하지 않는다.

## 백그라운드 실행과 기존 증거

Xcode 27.1과 DUNE Duo Visual Audit를 사용했다. GUI focus·창·메뉴·키보드 조작은 하지 않았다. 전용 Duo `5A2A5D3F-3D53-4326-99DE-47823CA256FA`/iOS27.1과 전용 iPhone `515C9267-8B31-4FDE-9EC2-1F4A5CC0D07B`/iOS27.0만 CLI/XCTest 대상으로 지정했다. 사용자 iPad `EE45BC41-3EC5-45DD-9585-9A84FDEDFCB3`는 변경 대상에서 제외했다. 공통 simulator lock으로 실행을 직렬화하고 다른 작업의 runner를 종료하지 않았다. 공통 종료 fallback도 포괄적인 `booted` 대신 유효한 runner UDID만 사용하도록 수정했으며 기기 격리 host 계약 14/14가 통과했다.

[앞선 CLI 검증](2026-10-06-duo-cli-fold-validation.md)의 운동 입력·휴식·회전, 3D, Body 편집·저장, 비교 제목·기간, 주간 수치 결과는 해당 변경 범위에서 재사용한다. 이번 표는 그 결과를 다른 화면의 성공으로 확대하지 않는다. 최종 `scripts/build-ios.sh --no-regen` generic Simulator 빌드 exit0과 UI 테스트의 Xcode27.1 컴파일을 확인했으며 전체 unit/watch/full UI suite를 이번 결과로 대체하지 않는다.

## 최종 수정별 결과

아래 최대 AX는 accessibility-extra-extra-extra-large이다. 각 phase의 원본 실행 로그·checkpoint·AX·선택 native PNG는 `assets/2026-10-06-duo-remaining/<phase>/`에 있다. 시간은 실제 testcase 시간이며 runner cleanup과 구분한다.

| 검사 / 수정 | 실제 조건 | 결과 및 native 판정 |
|---|---|---|
| Settings·습관 관리·히트맵 | Book/maxAX | 기존 3/3 동작 통과; 히트맵 별도79.601초 통과 |
| 습관 Archive→Restore→관리 종료→root | Book/maxAX | `book-max-life-restore-fixed` 1/1,114.938초,exit0 |
| Life starter template 생성·저장 | Book/maxAX | `book-max-life-restore-template-fixed` 해당 testcase105.533초 통과; 이 batch의 다른 실패와 구분 |
| Life33%·제목·Weekly/Monthly 선택 | Closed/Book/Open,maxAX | `life-max-chart-title-query-fixed` 1/1,219.407초,exit0. 세 상태의 전체33%/제목 및 Closed의0–100%축/날짜 native 통과 |
| Life 안쪽 하단 축 | Book/Open,maxAX | `life-inner-lower-axes-complete` 1/1,109.675초,exit0. 네 뷰포트의0%·Weekly양끝A16/O4·Monthly M/J/J/A/S/O 전체 native 통과 |
| Posture 상세86/100·ring | Closed/Book/Open,maxAX,synthetic | `posture-max-score-all-poses` 1/1,140.204초,exit0. native 전체 수치·stroke 간격 통과 |
| Posture symmetry | Closed/Book/Open,maxAX,synthetic | `posture-max-symmetry-all-poses` 1/1,291.310초,exit0.18개 native 수치·부호·단위·좌우 읽기 배치 통과 |
| Injury 상세 편집·통계 | Book/maxAX |51.864초/53.250초 동작 통과 |
| Injury severity 아이콘 간격 | Book/maxAX | `book-max-injury-icon-width-fixed` 1/1,66.114초,exit0. 실제 편집005에서16.7pt 간격으로 겹침 해소 |
| Weather 낮 시간 fixture | Book/maxAX | `book-max-weather-daytime-fixed` 1/1,39.097초,exit0. DEBUG/uitesting에서만12시 사용 |
| Morning Briefing 아이콘 | Book/maxAX | `book-max-briefing-icon-width-fixed` 1/1,75.469초,exit0.002–008 섹션 제목·아이콘 겹침 해소 |
| Stress 수치와 전체 설명 | Closed/Book/Open,maxAX | `stress-max-contributor-details-fixed` 1/1,294.930초,exit0.18개 native 수치·전체 설명·아이콘 간격 통과 |
| 공통 ScoreComposition 소비자 | Book/maxAX |Readiness97.809초·Wellness78.417초 동작/수치 통과; Stress는 위 결과; Condition은 populated100점 fixture로71.900초/1건/exit0,100/100·70%/30% native 통과 |
| Readiness 공통SubScore3그래프 | Book/maxAX | `book-max-readiness-subscore-complete` 1/1,112.239초,exit0. 제목/평균·전체plot·Y3눈금·양끝날짜 native 통과 |
| Wellness 공통SubScore3그래프 | Closed/maxAX | `closed-max-wellness-subscore-reveal-fixed` 1/1,116.784초,exit0. 세 그래프 native 통과 |
| Condition 공통SubScore2그래프 | Closed/maxAX,populated fixture | `closed-max-condition-subscore-reveal-fixed` 1/1,105.403초,exit0. 두 그래프 native 통과 |
| Cardio 저장·상세 하단 | Book/maxAX | `book-max-activity-remaining` 해당200.604초 testcase 통과. 전체제목·Save·48.4ml/kg/min·Steps/Cadence 빈값 native 통과 |
| PR timeline·rewards·history | Book/maxAX | 기존103.744초 동작/하단 native 통과. 후속 `book-max-pr-endpoint-axis-clearance` 1/1,103.838초,exit0. 확대된1'50"와 인접3'20" Y눈금 겹침 해소 |
| 일반 iPhone 입력 초안 회전 | iPhone18Pro/iOS27.0,기본L | `phone-default-capture-handshake-fixed` 1/1,137.723초,exit0. portrait→landscape→portrait,kg/reps전체frame·62.5/11 유지·17개 host capture 확인. 최대 AX의 이전94.480초 testcase 통과는 별도 재사용 |
| 운동 완료·share미리보기·닫기·요약 유지·목록 복귀 | Book/maxAX | `book-max-share-system-close-scoped` 1/1,218.467초,exit0. 실제header.closeButton으로 system popup 종료; recipient 선택·발송 없음. 복귀native delta 검토 통과. 이후 단수문구1set 교정은 별도 최종컴파일 검사로 확인 |
| 사용자 운동 근육 칩·템플릿 생성/편집/첫 운동 | maxAX | `book-max-template-session-identity-fixed` testcase1/1,258.100초 통과. SDK cleanup60초 초과로 wrapper1/-15, 최종UI receipt없음은 별도 기록. Book의 전체한줄chip native 통과. `custom-muscle-max-all-poses-viewport-fixed` 1/1,249.517초,skip0,exit0. Closed/Open/Book wholechip·Cancel복귀 및 세native검토 통과 |

## 원인과 교정

고정 크기의 ring·숫자 열·아이콘 열·차트 높이가 확대된 글자와 맞지 않았다. Life/Posture ring과 Injury/Briefing/Stress 아이콘 폭은 해당 글자 스타일에 맞춰 확대했다. AX composition과 symmetry는 제목·가중치·값을 독립된 행에 배치했다. Stress 설명의 두 줄 제한은 AX에서 해제했다.

Life chart 제목/기간 선택과 SubScore 제목/평균은 AX에서 세로로 배치했다. plot 높이와 축 끝값 여유를 확보하고 clipping은 plot에 한정했다. PR의 불투명 끝점 캡슐은 x를 plot 경계에 맞춰 Y눈금 침범을 방지했다. 사용자 운동 근육 칩은 AX에서 한 열로 배치하고 최소44pt 높이를 확보했다. 일반 크기의 기존 adaptive90 grid는 유지한다.

운동 완료 버튼은 입력 focus 중 keyboard 위 footer에 둔다. 테스트의 offscreen `isHittable` 조회는 전체 frame 노출 뒤 수행한다. lazy Form 행은 실제 scroll/window 교차 영역 안에 드러낸 뒤 선택한다. 큰 swipe로 그래프를 왕복해 지나치던 검사는 작은 방향 drag로 교정했다. viewport보다 큰 차트는 제목과 하단 축을 별도 캡처하며 내부 잘림과 정상 스크롤 경계를 구분한다.

DEBUG test fixture는 조건 점수 detail이 nil인 기본mock과 별개로100점/가중치를 채운다. Weather/Briefing 진입은 테스트 clock/lastBriefingDate 조건을 고정했다. 일반 폰의 host-only capture는 FOLD opt-in과 분리해 XCUIDevice 회전을 유지한다.

## 원본 실패 보존과 제한

원본 실패는 삭제하지 않았다. 실패 cause별 source/helper/fixture 수정 후 해당 selector만 재실행했다. 원본에는 33% 비대화형hit-test, 부모ID상속, lazyAddExercise/Shoulders, 실제KO운동이름, Other타입 sharecaption, 숨은presenter Close, 큰swipe왕복, 늦은시간Today, inactive display capture timeout과 SDK cleanup watchdog가 포함된다. Template255.315초 실행은 실제첫세션에 도달했지만 대문자 `EXERCISE 1 OF 2` 가정으로 실패했으며 전체pass로 집계하지 않았다. 실제 정확한 session ID/label을 기준으로 수정했다.

일부 SDK cleanup60초 초과에서는 testcase 결과는 있지만 runner가 중단되어 최종UI receipt가 없다. [증거 인덱스](assets/2026-10-06-duo-remaining/evidence-index.json)는 testcase·runner·receipt 유무를 별개로 기록한다. unknown이나 누락을0건 성공으로 처리하지 않는다. 모든 원본 PNG는 수정 없이 로컬에 보존하고 SHA256/크기를 인덱스에 기록한다. 대용량 PNG 전체는 Git에 추가하지 않으며 검증 receipt와 전문가 기록을 커밋한다.

실제 이전OS의 persisted scene/session upgrade fixture, 실기기camera/live feed, VoiceOver 실제음성, 모든font/pose/empty/long-data/theme 조합은 이 보고서의 통과 범위에 포함되지 않는다. available runtime에는18.6/27.0/27.1이 있어 이전OS upgrade 미검증을 runtime 부재로 설명하지 않는다. 원래155개 진입 선언을 전부 실행한 것으로 주장하지 않는다.

## 보존과 기록

[재발 방지 해결 기록](../solutions/testing/2026-10-06-duo-background-isolation-and-numeric-evidence.md)과 Codex UI-test memory에 교정을 남긴다. 로컬 커밋은 수정 단위별로 나눴고 정상hook을 유지했다. 중복 hook compile만 기존 빌드 증거로 생략하며 보안검사를 우회하지 않았다. 사용자 baseline5파일의 patch SHA256은 `d6624fe5e115264dd5b3cc467be94a1af47b88772377a48b873ce3f96b82f476`, 기존MuscleMap 잔여24+/9-도 보존했다. 원래dirty파일과 이전날짜 untracked 문서를 자동stage하지 않는다. 확인된 잔여 소프트웨어 수정·선택 gate·native검토를 완료했다. 전체 조건 매트릭스 및 위 실기기/업그레이드 fixture 제한은 유지한다.

최종 근육 칩 검사 전 첫 짧은 실행124.814초는 임의80pt 하단 여백 때문에 실제보이는 AddExercise를 실패 처리했다. 실제nav-bar아래/Form하단12pt 기준으로 교정한 뒤 위249.517초 gate가 통과했다. 이미 통과한258.100초 템플릿 전체 경로는 반복하지 않았다.

검사 종료 후 전용 Duo의0도/portrait/large readback과 전용iPhone Shutdown을 확인했다. [복원 결과](assets/2026-10-06-duo-remaining/final-device-restore.json). 사용자iPad 변경 명령은 실행하지 않았다.

[최종 품질 검토](assets/2026-10-06-duo-remaining/reviews/final-app-quality-review.md)는 선택된 변경 범위의 기존P1/P2를 해소된 것으로 판정했다. 위 실기기·전체조건·SDK정리 제한은 유지하며, 단수 문구는 수정 후 native재검증이 아니라 source검토/최종컴파일 결과다.
