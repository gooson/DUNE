---
tags: [today, digest, accessibility, review, validation]
date: 2026-10-27
category: review
status: reviewed
---

# 오늘의 요약 · 핵심 먼저 검토

## Review

`codex/daily-summary-reading`, base `origin/main`, native 검토 HEAD `4f09dff3`. 시안·생성 HTML을 포함한 텍스트 diff가 3,461줄 이상이어서 review 스킬의 2,000줄 이상 예외에 따라 주 에이전트가 폴더별로 직접 5관점을 수행했다. 생성 HTML은 앞선 시안 단계에서 편집 원본과의 일치·브라우저 동작을 확인한 자료이며 앱 캡처와 구분한다. `.claude`/`.codex` 지침 변경은 없어 Agent-Native는 제외했다.

| 관점 | 결과 |
|---|---|
| Security | 새 네트워크·권한·저장 동작 없음. 시안과 seeded 건강 수치를 실 사용자 기록으로 표시하지 않음 |
| Performance | 첫 문장 탐색은 첫 경계에서 중단. 짧은 표시용 문자열·고정 개수 지표, 쿼리/비동기 처리 변경 없음 |
| Architecture | Presentation 문자열 값과 View 상태로 한정. Today와 T10 알림 요약의 공유 소비 유지 |
| Data integrity | 원본 지표와 요약 계산 보존. 표시 경계 공백만 trim, 소수점/한국어/일본어 문장 경계 검증. 긴 단일 문장은 숨기지 않음 |
| Simplicity | 단일 카드와 작은 표시 값 타입. 중복 날짜/기록 문구를 정리하고 불필요한 단일 문장 제어 제거 |
| Localization | Expand summary/Collapse summary 및 기존 Expanded/Collapsed에 en/ko/ja 확인. 오래된 미참조 키 제거, 카탈로그 형식 검사 통과 |

읽기 전용 검토 시 새 소스 문제는 P1=0/P2=0/P3=0이었다. 당시 산출물 품질 P3 1건: T03 UI 캡처가 아래 본문과 제어를 보여 주지만 헤더·수치 상단이 viewport 밖에 있어 별도의 상단 캡처를 보완한다. T10 공유 카드 캡처에서는 제목·날짜·두 지표·구분선·제어를 한 화면에서 확인했다. 이 보완은 앱 코드의 추가 변경이 아니다.

## Work 품질 검토와 수정

- `swift-ui-expert`: 코드상 레이아웃·44pt Button·상태·소비자에서 발견 없음.
- `apple-ux-expert`: 변화량 caption 색 대비 P2, 영어 Read summary 의미 P3를 발견. `.primary`와 Expand summary로 바꾼 후 두 건 Resolved 확인.
- UI 실패: 최초 3개 중 알림 요약 1개 통과, Today 2개는 날짜 식별자 누락으로 실패. 실패 트리에서 날짜가 `dashboard-digest-header`를 상속한 것을 확인해 ID를 부모 layout 대신 제목 Label에 붙였다. 기대값 변경 없이 실패한 두 selector를 1회 재실행해 2/2 통과.

## 검증

- 표준 iOS Simulator 빌드 통과. 최초 빌드도 성공했지만 실행 중 프로젝트 등록 변경으로 pipeline 증거가 무효화돼, 등록 완료 뒤 `--no-regen`으로 한 번 재확인했다.
- DUNETests의 관련 두 suite: 실제 Swift Testing **13개 통과**, xcresult summary Passed/totalTestCount=13. 기존 로그 요약기는 XCTest의 0개를 읽었으므로 이 작업은 실제 Swift Testing 및 결과 번들 수를 기준으로 한다.
- Today 일반·접근성 글씨: 수정 후 **2/2 통과·정상 종료**. 원문 펼침, 미리보기 제거, 접기 복원, 변화하는 접근성 상태, 44pt 이상과 오른쪽 빈 영역 터치 검사.
- T10 알림 요약: 최초 실행에서 **1개 통과**. 이후 변경은 공통 헤더·날짜 AX 식별자 분리이며, 원문/지표/라우팅 동작에는 영향이 없어 통과 결과의 해당 범위만 재사용한다.
- 전용 iPhone은 `3712F209-B644-45C4-9726-44D5BF835B0B`. 사용자가 병행 검증을 명시적으로 승인한 뒤 worktree 잠금·독립 기기/DerivedData/로그를 사용했다. 다른 실행은 조작하지 않았다.
- 일반/AX 실제 캡처와 T10 캡처는 성공 selector 원본에서 추출했다. 캡처와 테스트 통과는 별도 증거이며 화면 일부만 보이는 캡처는 전체 카드 완료로 과장하지 않는다.

## Resolve와 최종 범위

- capture-001 **Resolved**: 별도 촬영 selector가 실제 제목 StaticText의 frame을 기준으로 상단을 맞춘다. 처음 장식 Image 선택 오류는 텍스트 기준 변경 후 상단 촬영 성공으로 해소됐다. 이후 새로 도달한 펼침 후 복귀 단계의 일방향 탐색을 제거해 마지막 최대 글씨 selector1/1 통과했다. 두 원인을 하나의 실패로 숨기거나 성공한 일반/알림 검사를 반복하지 않았다. 원인별 근거와 로그를 갤러리 proof에 보존했다.
- 종합 app-quality-gate는 P1=0/P2=0, 기존 캡처 구도 P3만 확인했다. 고정 개수 지표·짧은 표시 문자열이라 대량 처리 perf-optimizer는 해당 없음이다.
- iPhone 촬영 첫3건은 일반·알림2건 통과/최대 글씨1건 실패였다. 최종 최대 글씨 촬영1건은 보정 후 통과했다. 최신 알림 검사가 다시 통과했으므로 이전 AX-only 전의 알림 결과에만 의존하지 않는다. 해당 최신 알림 PNG는 스크롤된 상단이며 전체 공유 카드 배치는 T03 및 iPad/Duo 외부 T10 원본에서 확인했다.
- iPad Today·알림2/2, Duo 외부 Today·알림2/2가 통과·정상 종료했다. [실제 화면25장·비활성 짝10장·출처](../design/full-redesign-map/review/daily-summary-reading-2026-10-27/index.html)에 보존했다.
- capture-002 **Resolved**: Duo 내부 첫 실행은 teardown 직전 simctl display enumerate8초 초과로 중단됐다. 소유 xcodebuild/test-ui 종료를 확인했고, native screenshot8초 및 simctl list15초 초과 상태에서는 UI를 재시도하지 않았다. 공식 CoreDevice 경로로 전용 Duo만 재부팅한 뒤 실제 조회·PNG 생성1.51초, 정확한 내부 포트 열거·PNG 생성1.16초를 확인했다. 완료된 전용 iPhone·iPad를 종료한 후 미완료 두 selector를1회 재실행해 **2/2 통과·정상 종료**했다. 갤러리는 최종 내부 T03/T10 성공 원본으로 갱신하고 첫 실패와 복구 근거를 보존했다. 수치 힌지 각도·물리 회전은 검증하지 않았다.
- 최종 테스트 수정은 촬영 helper에 한정된다. 기존 핵심 selector·앱·문자열 helper·생성기 입력은 유지해 관련 unit13개와 핵심 UI2개의 해당 성공 범위를 재사용한다. git diff 기반 재검토에서 Security/Performance/Architecture/Data/Simplicity/L10N의 새 P1/P2는 없었다. 전체 회귀·어두움·다른 테마·iPad/Duo 최대 글씨·실기기 VoiceOver는 실행하지 않았다. Watch는 이 카드를 소비하지 않는다.

최종 표준 빌드 첫 실행은 컴파일 후 actool 단계에서360초 제한으로 중단됐고 같은 시점 simctl도 정체됐다. 원인 회복 근거 없이 빌드를 반복하지 않았다. 전용 Duo의 공식 재부팅·실제 native IO 정상화와 이후 UI2/2 정상 종료로 의존성을 확인했다. 빌드 재개·Compound·Ship는 후속 증거로 추가한다.


최종 범용 Simulator 표준 빌드는 실제 복구 후1회 재개해 **BUILD SUCCEEDED**로 정상 종료했다. 최종 build receipt는 수정하지 않은 전체 source fingerprint에서 valid를 확인했다. 이후 변경은 아래 문서 정리뿐이라 앱/테스트 실행 증거를 재사용한다. 최종 빌드에는 이전부터 존재한 Text 연결 사용 중단 경고가 있으며 SessionSummaryView·CardioMachineLevelHistoryView의 origin/main 대비 diff가 없음을 확인했다. 형식 검사·git diff --check와 사진35장의 SHA-256도 통과했다.

최종 PR 사전 검토의 P1=0/P2=0, P3 1건(과거 T10 인덱스의 현재 미검증 문구)은 **Resolved**다. 과거 사진의 출처를 유지하면서 별도 전용 Duo의2026-10-27 최신 검증과 새 갤러리를 안내하도록 metadata를 정정하고 통합 포털을 재생성했다. 현재 Open findings는 P1=0/P2=0/P3=0이다. 사용자 요청에 따라 검사가 끝난 전용 기기3대를 표준 소유권 cleanup으로 삭제했고 기록0·미등록0을 확인했다.


Compound: [최종 구현과 예방책](../solutions/general/2026-10-27-daily-summary-reading-and-disclosure.md)에 정리했다. 기존 active correction의 안정적 AX anchor 규칙을 재사용하고 새로운 .claude 규칙은 만들지 않았다. 관련 별도 TODO는 없었다.
