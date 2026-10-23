---
tags: [swiftui, desert-horizon, design, widgets, live-activity, verification]
date: 2026-10-24
status: blocked-ui-validation
---

# DESERT HORIZON 실제 구현 검증

## 현재 상태

제품 소스 구현은 완료했으며 최종 앱·Widget·Watch 통합 빌드와 영향 단위 테스트58개가 통과했다. **Duo 펼침 Today의 가로 화면 검증이 막혀 `/run` UI 게이트는 실패 상태이며 PR·머지를 진행하지 않았다.** 현재 Mac 잠금 때문에 Device Hub의 실제 표시 회전을 확인할 수 없다. 잠금 해제 후 표시 컨트롤러·물리 방향·실제951×669 viewport를 먼저 맞추고 해당 selector만 확인해야 한다.

## 변경 내용

- 원래 사구 곡선을 유지한 전체 화면 그라데이션과 밝음·어두움 카드 표면.
- Today 알림함 안의 건강 알림·새 소식 필터, 합산 미열람·모두 읽음·기존 상세 이동.
- Activity·Wellness·Life의 상단 기록 진입. 기존 차트·추천 운동·근육 지도·개인 기록·보고서 유지.
- 최근 28일 운동 구성: 근력·유산소·기타, 주별 구성, 주요 부위별 완료 세트 환산, 유산소 종류·시간·거리, 기존 빈도 상세.
- 실제 수면 이력 차트와 주간 습관 보고서의 이번 주·지난 주 비교.
- WidgetKit 크기별 여백과 대비, Rest Live Activity의 시스템 표면·실제 카운트다운.

## 범위와 데이터

DUNE 색·카드 표현은 Desert 테마에 한정한다. 알림 통합과 기록 진입·운동 구성은 모든 테마의 실제 기능이다. 앱에 시안의 임의 건강 점수·기록은 넣지 않았다. 캡처는 명시된 UI 테스트의 mock fixture 데이터이며 실제 앱을 빌드해 렌더링한 결과다.

[실제 화면·변경 전 비교](../design/full-redesign-map/review/desert-horizon-final-2026-10-24/index.html)와 [방향 시안](../design/theme-map/themes/dune-final-four-tab.html)은 구분한다.

## 검증 기록

| 항목 | 현재 결과 | 증거 |
|---|---|---|
| iOS·Widget·Watch 최종 통합 빌드 | 통과, c239a50d 제품 소스. 이후 테스트·문서만 변경 | desert-final-source-build.log |
| 영향 단위 테스트 | 58 통과 / 0 실패 / 0 건너뜀, 7 suites | desert-targeted-unit-retry.xcresult, desert-unit-summary.json |
| iPhone 초기 targeted UI | 10 통과 / 5 실패 / 0 건너뜀 | Test-DUNEUITests-2026.10.24_04-02-34-+0900.xcresult |
| iPhone 수정 후 targeted UI | 6 통과 / 1 내부 컨테이너 검사 실패. 비교율 자식 ID 복구를 새 AX에서 확인 | desert-phone-ui-retry.log |
| Life 내부 컨테이너 검사 조정 | 실제 버튼·현재/이전 비교율 표시 검사 통과 | desert-system-ui.log |
| Watch 운동 시스템 알림 센터 | 진행·일시 정지 개별 테스트 통과, 표준 실행 종료 확인 | desert-system-ui.log |
| iPad | 기존 targeted5 통과, 최종 Today 밝음·어두움1 통과 | desert-ipad-ui.log.result.json, desert-final-toolbar-ipad.log.result.json |
| Duo 접힘·펼침 가로 | 기존 4탭 루트 각1 통과. 최종 접힘 Today1 통과. 최종 펼침 Today는 실제 가로 viewport 조건 실패 | duo-today-closed/runner-result.json, duo-today-open-final/runner-result.json |
| 시스템 Widget·Live Activity | Rest 실제 첫 세트 countdown 및 Watch 진행/일시정지 Notification Center 통과. 위젯3family gallery 메서드 통과. Home live-score timeline 미검증 | desert-system-retry-ui.log, system/capture-index.json |

초기 실패 5개는 새 소식 필터를 영어 문구로 찾던 테스트 3개와 카드 부모의 접근성 식별자가 자식 차트·비교율 식별자를 덮은 2개였다. 화면 합본에서 실제 내용은 표시됐음을 확인했고, containment와 언어 독립적인 세그먼트 선택을 적용했다. 존재 여부만 확인하던 상세 테스트도 스크롤 후 실제 표시 여부를 검증한다. 수정 원인당 한 번만 재검증한다.

전체 회귀는 사용자 요청이 없어 실행하지 않는다. 자동 UI 분류의 full 영향 판정과 실제 targeted 실행은 구분하며, targeted 결과를 전체 통과로 표시하지 않는다.

## 캡처 출처

일반 iPhone 루트 밝음·어두움 8장과 최대 접근성 크기 4장은 3d9ba7e7에서 개별 통과한 ThemeMatrix 메서드의 실제 결과다. 전체 초기 번들이 통과했다는 증거는 아니다. Before 이미지는 이전 구현 참고용이며 새 구현의 증거가 아니다. 기기·커밋·테스트·시각은 갤러리의 capture-index.json에 기록한다.

## 실행 격리

원래 e1e6 작업 트리에 독립 작업의 변경이 시작되어, 커밋된 디자인 53fd5c2d에서 관리 워크트리 desert-horizon-final-validation과 브랜치 codex/desert-horizon-final-ship을 만들었다. 다른 작업의 파일과 시뮬레이터는 보존한다. 모든 런타임 검증은 단일 표준 실행기·저장소 잠금·현재 작업 트리 소유 기기를 사용한다.

기존 registry subprocess의 잠금 FD 환경 상속 문제는 저장소 실행기를 수정하지 않고 task-local 환경 shim으로 격리했다. 바깥 실행기는 실제 잠금을 계속 보유한다. 이 수정은 제품 변경에 포함하지 않는다.

## Proof Ledger

| Phase | 상태 | 증빙 |
|---|---|---|
| 0 Init | completed | 관리 작업 트리·codex 분기 격리, 원본 작업 보존 |
| 1 Plan | completed | 실제 계획서·레이아웃/데이터/목적지 계약 |
| 2 Work | completed | 구현 커밋·통합 빌드·58개 단위 테스트 |
| 2.5 UI Test | failed | Duo 펼침 Today의 실제 가로 viewport 조건 실패, Mac 잠금으로 GUI 확인 차단 |
| 3 Review | skipped | UI 게이트 실패. 사전 5관점 소스 검토·최종 source reviewer 증거는 보존 |
| 3.5 Quality | skipped | 정식 게이트 미진입. SwiftUI·Apple UX·UI test·app-quality 사전 검토/수정은 보존 |
| 4 Resolve | skipped | UI 게이트 해결 후 현재 diff 기준으로 진행 |
| 5 Compound | skipped | UI 게이트 실패. 해결된 항목의 초안만 보존 |
| 5.5 Pre-Ship | skipped | UI 게이트 실패. 구현과 현재 기록은 원격 분기에 보존 |
| 6 Ship | skipped | UI 게이트 실패로 PR·머지 미실행 |


### 최신 main 통합

원격 main의 Today 시작 로딩 수정(#834)과 Watch 운동 Live Activity(#833)를 823f0179에서 통합했다. 유일한 충돌은 실제 화면맵 링크였으며 양쪽 링크를 보존했다. 새 Watch 운동 액티비티에도 기존 named warm surface/ink/accent와 민감 정보 표시를 적용했다. 기존 WLA01 PNG는 이 색상 변경의 증거로 재사용하지 않는다.

Rest 시스템 테스트의 첫 실패는 완료 버튼이 별도 고정 영역에 있는데 ScrollView 내부에 있어야 한다고 무조건 검사한 테스트 조건이었다. 기존 정상 플로우처럼 버튼이 hittable하지 않을 때만 스크롤하도록 원인 수정 후 한 번 확인한다.

## 요청한 정보의 보존 대조

아래는 소스·배치 계약 대조이며, 모든 스크롤 상태를 새로 촬영했다는 뜻은 아니다.

| 요청 | 실제 반영·보존 |
|---|---|
| 기존 비대칭 곡선·전체 배경 | 기존 주파수·skew 유지, 420pt 채움의 하단 fade와 화면 전체 gradient |
| 탭 아이콘·Today 알림/설정 | 기존 네 탭 SF Symbols 유지, Today bell/settings와 합산 미열람 |
| 근육 지도·범례·회복/볼륨 | 기존 앞/뒤 지도·모드 선택·범례 보존 |
| 이번 주 운동 | WeeklyStatsGrid의 볼륨·칼로리·시간·활동일과 기간 비교 보존 |
| 추천 운동 | 검색·환경·장비·추천 루틴·템플릿·운동 제외·전체 목록 동작 보존 |
| 주간 보고서·개인 기록 | WorkoutReportCard와 PersonalRecordsSection의 실제 정보·상세 경로 보존 |
| 표현 변경 | Consistency/Workout Consistency의 한국어는 운동 페이스, 일본어는 運動ペース |
| 운동 구성 | 같은 28일 merged summary에서 건수·주별 비율·완료 세트 환산·유산소 세부·빈도 |
| Wellness 그래프 | 기존 VitalCard/Sparkline·수면 흐름 보존, Today 회복 카드에 실제 이력 막대 추가 |
| Life 보고서 | 기존 상세 경로와 이번/지난 주 비교율·완료 수·좋은/개선 습관 요약 |
| 상단 기록 진입 | 세 기록 탭의 toolbar + 유지, 중복 CTA 제거 |
| 위젯·액티비티 | 기존 Widget family·데이터 provider·타이머·미러링 상태 보존, 표면·대비·레이아웃 수정 |

## 후속 캡처 검사와 원인별 수정

- Duo 루트 테스트는 링과 경로를 통과했지만 실제 합본에서 Today의 두 toolbar item이 하나의 긴 시스템 glass 표면으로 합쳐져 내용을 가렸다. AX도 설정 y176, 알림 y612로 분리된 것을 보여 주었다. 두 action을 하나의 toolbar item 안의 작은 그룹으로 묶고 영향받는 Today만 밝음·어두움/접힘·펼침으로 재확인한다. 기존 4탭 통과를 시각 검사 통과로 바꾸지 않았다.
- 위젯 native gallery의 내부 custom ID는 OS에서 노출되지 않는다. 실제 host의 localized title·family value를 사용한다. 세 family는 시스템 gallery에서 렌더링·크기를 확인했다. 이후 Home 설치 검사는 transient bound-index query 실패를 stable firstMatch로 수정했다.
- 위젯 메서드의 초기 super setup은 본문의 seeded 재실행보다 앞서 empty fixture를 열어 navigation unavailable로 건너뛰었다. 클래스의 최초 launchConfiguration부터 seeded fixture를 적용했다.
- 수면 chart 전체가 tab bar 위에 있어야 한다는 검사는 큰 swipe가 그래프를 지나칠 수 있었다. 실제 navigation/tab/scroll frame에서 유효 viewport를 구하고, 겹친 거리만큼 작은 방향 drag를 적용한다. 이는 테스트의 가시성 검사 수정이며 제품 데이터를 바꾸지 않는다.

### Widget Home 범위 판정

Home 설치 후 host를 찾지 못한 실패 PNG에는 두 개의 실제 DUNE 위젯이 `Open DUNE` 빈 상태로 표시돼 있었다. 이를 점수 timeline 성공이나 렌더링 실패로 단정하지 않는다. 새 세 family 디자인의 원래 검증 범위는 시스템 gallery의 실제 extension 렌더링이며 세 크기에서 모두 확인했다. Home live-score 확인은 이 디자인 변경의 요구 밖으로 추가됐던 검사여서 family regression에서 분리하고 **미검증**으로 남긴다. 테스트 통과를 위해 가짜 점수 데이터를 provider에 넣지 않았다. 후속 검증은 실제 App Group score가 준비된 환경에서 Home timeline을 별도로 확인해야 한다.

최종 source build는 c239a50d 앱·Widget·Watch 소스로 성공했다. 이후 a4077925는 테스트 helper의 미사용 Home 조회만 제거하며 앱 소스 차이는 없다. 전체 worktree fingerprint 도구가 이를 stale로 표시하는 것은 해당 빌드가 실패했다는 뜻이 아니다. `git diff c239a50d HEAD -- DUNE DUNEWidget Shared`가 비어 있음을 확인해 제품 소스 증거를 재사용한다.

Today toolbar 추가 회귀의 첫 실행은 iPhone에서도 native AX label child가 36pt인 것을 44pt hit target과 동일시해 실패했다. 명시적인 44pt SwiftUI label은 보존하고, 테스트는 native child 보존·hittable·같은 행·compact group·실제 window 포함을 확인한다. 최초 Duo의 y176/y612 분리와 긴 glass 문제는 여전히 실패하는 조건이다. 원인 수정 후 이 selector만 한 번 확인하며 표준 DesignCapture plan으로 불필요한 SDK 진단 수집을 제외한다.

Duo Today의 초기 상단 회귀는 접힘에서는 정상 통과했다. 펼침 메서드도 toolbar geometry 자체는 통과했지만 수집기의 native PNG·AX viewport 조건이 세로669×951을 발견하여 가로 증거로 채택하지 않았다. 최초 preflight의 landscape readback만으로 앱 재실행 이후까지 보장하지 않는다. 펼침 selector는 각 재실행 후 기존 ORIENT host handshake로 물리 방향을 설정하고, fresh AX951×669 및 native2853×2007을 확인하도록 보강했다. 이전 합본의 펼침 이미지는 최종 증거가 아니다.

## Duo 표시 회전 차단의 최종 증거

새 테스트 전부터 물리 방향과 표시 컨트롤러가 서로 달랐다. devicectl physical landscapeLeft·lock=false였지만 displays currentOrientation=rot0, native2007×2853, AX669×951이었다. 기존 성공한 가로 실행은 display rot90, native2853×2007, AX951×669였다. `XCUIDevice.shared.orientation` 호출과 device orientation 변경 로그도 확인했지만 interface orientation은 바뀌지 않았다. 공식 `devicectl orientation set`을 별도로 적용한 한 번의 진단에서도 display rot0가 유지됐다. 앱·scene·지원 방향 설정 변경이 원인이라는 근거는 없다.

같은 경로를 추가 반복하지 않는다. CUA는 `The Mac is locked and automatic unlock could not unlock it`을 반환했다. Mac 잠금 해제 후 Device Hub에서 표시 회전을 확인하는 것이 재개 조건이다. 새 가로 캡처를 얻기 전에는 기존 가림 PNG를 최종 Today 이미지로 표시하지 않는다. 전체 UI/watch 회귀, Home live-score, DUNE Score 선택형 family의 실제 host, Island, Watch small, 실제 페어링/잠금 개인정보 상태는 미검증이다.

## 사전 검토와 범위

- Security·Performance·Architecture·Data Integrity·Simplicity의 준비 소스 검토에는 열린 P1/P2/P3가 없다. 2,000줄 초과 diff는 폴더별 직접 검토했고, 기존 전문가 검토 후 수정분을 최종 source reviewer가 대조했다. 정식 Phase3 통과를 뜻하지 않는다. Agent-Native는 .claude/.codex 지침 변경이 없어 제외했다.
- SwiftUI·Apple UX·UI test expert·app-quality·PR reviewer의 소스/레이아웃 검토와 수정 증거는 보존했다. 대량 데이터 optimizer는 28일 범위/공유 query로 제한돼 별도 실행하지 않았다. Duo 표시 방향은 추가 Astra 진단에서도 물리 방향과 compositor의 불일치가 확인됐고 세부 원인은 미확정이다.
- 새 문자열25개는 en/ko/ja가 모두 있고 catalog format check가 통과했다. 보조 글자/card 대비는 밝음6.69:1·어두움8.74:1, Widget accent/surface는 밝음5.26:1·어두움9.52:1이다.
- 변경 Unit 파일: ActivityViewModelTests, ExerciseMixServiceTests, ExerciseMixDetailViewModelTests, WhatsNewStoreTests. 실행은 기존 Widget·Dune 관련 suite를 포함한7suite/58개다.
- 대표 UI 파일: ThemeMatrixUITests, DashboardSmokeTests의 capture cases, ActivityExerciseRegressionTests, NotificationRoutingRegressionTests, TodaySettingsRegressionTests, WatchWorkoutLiveActivityUITests. 전체 목록은 git diff에서 확인한다.
- 현재 완료할 활성 TODO는 발견되지 않았다. 기존 done092–095를 다시 처리하지 않고, 이 DUNE 작업으로 전역8테마 개편 계획을 done으로 바꾸지 않았다.
- 명시적인 전체 회귀 요청이 없어 iOS/watch full UI는 실행하지 않았다. 이미 확인한 데이터·레이아웃과 다른 상태를 일괄 통과 처리하지 않는다. 최종 toolbar 이후 Today 최대 AX는 별도 재캡처하지 않았으며 이전 body AX 캡처의 출처를 그대로 보존했다.

## 변경 확인 가이드

| 화면 | 확인 경로·결과 |
|---|---|
| Today | 상단 bell → 전체/건강/새 소식 → 출시 상세, 모두 읽음 뒤 합산 배지 갱신. 아래 회복/수면 카드에서 실제7일 이력 확인 |
| Activity | 상단+기록 진입, 기존 근육 지도·회복/볼륨·추천·개인 기록·보고서 확인. 운동 구성 → 주별/부위별 완료 세트/유산소/전체 빈도 |
| Wellness·Life | 상단+기록·템플릿 진입, 기존 그래프와 Life 주간 보고서의 이번/지난 주 비교 확인 |
| Widget·Live Activity | 실제 gallery의 Today3family 여백 확인. 운동 첫 세트 완료 → Rest Notification Center, Watch fixture의 진행·일시정지 카드 확인 |
| 내부 변경 | 28일 query를 training load와 공유하고 source failure를 표시한다. 기존 저장 스키마·실제 운동 데이터를 바꾸지 않는다 |

사전 조건은 건강 데이터 권한/기록 또는 명시된 seeded fixture이며, 실제 Watch 연동 확인에는 페어링된 Watch가 필요하다. Duo 펼침 Today는 Mac 잠금 해제와 Device Hub 표시 회전 확인 뒤 검증한다.
