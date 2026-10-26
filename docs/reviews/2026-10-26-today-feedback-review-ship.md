---
date: 2026-10-26
category: review
tags: [today, review-ship, data-retention, verification-gate]
status: blocked-before-pr
---

# Code Review Report · Today 피드백 수정

> Scope: `origin/main`(`0cb55721`) 대비 커밋·staged·unstaged·관련 untracked 전체. 최초 커밋 차이는 없으며 모든 변경은 이 대화의 Today 작업에 속한다. detached HEAD에서 `codex/today-feedback-repair`를 만들었다.

## Summary

| Priority | Count | Status |
|----------|-------|--------|
| P1 | 0 | 새 critical 없음 |
| P2 | 3 | 데이터 버그1 해결, 필수 검증2 Open |
| P3 | 0 | 새 발견사항 없음 |

전체 텍스트가 약2,800줄이므로 review skill의 큰 diff 예외를 적용해 parent가 Security·Performance·Architecture·Data Integrity·Simplicity를 폴더별 직접 검토했다. 별도 app-quality-gate는 SwiftUI·Apple UX·UI 검증 관점으로 읽기 전용 검토와 Resolve delta 재검토를 수행했다. Agent-Native는 agent/prompt/adapter 변경이 없어 생략했다.

## P1 Findings

없음.

## P2 Findings

### [Data Integrity] data-001 · 부분 성공 날짜와 전체 갱신 시각 혼용

- **File**: `DUNE/Presentation/Dashboard/DashboardViewModel.swift:64`
- **Issue**: 전체 소스 성공 때만 바뀌는 `lastUpdated`가 전날이면 오늘 부분 성공을 표시한 뒤의 다음 오류에서도 해당 값을 제거했다.
- **Status**: **Resolved**. 보존 기준을 private `lastHealthDataLoadedAt`로 분리하고 실제 새 지표가 반환됐을 때만 갱신한다. 표시용 전체 갱신 시각은 유지한다. 보존 값을 합치기 전에 새 지표 존재를 계산한다.
- **Validation**: Dashboard37건 중36건 최초 통과. 새 회귀1건은 snapshot 실패 플래그가 실제 mock 조회 실패를 만들지 못해 timestamp 기대가 실패했다. 운동 mock이 실제로 throw하도록 수정하고 `errorMessage`로 부분 실패를 확인한 뒤 한정 선택자가0개를 실행한 시도는 성공 증거에서 제외했다. 결과 번들의 정확한 Swift Testing 식별자(괄호 포함)로 해당1건만 실제 재검증해 통과했다. 날짜 변경은 주입한 시계로 검증한다.

### [App Quality] quality-001 · X 패딩 터치 미검증

- **File**: `DUNEUITests/Visual/TodayCompactUITests.swift:58`
- **Issue**: 이전 실행 두 건은 탭 전에 실패했다. 최종 독립 식별자와44×44 프레임은 실제 계층에서 확인했지만 패딩 클릭 성공은 없다.
- **Status**: **Open**. 사용자가 추가 X 실행을 명시적으로 거절했으므로 재실행하지 않았다. 이 선택을 검사 통과나 출시 게이트 면제로 해석하지 않는다.
- **Resume**: 실제 터치 검증을 허용하거나 이 게이트의 출시 제외를 사용자가 명시적으로 결정해야 한다.

### [App Quality] quality-002 · Duo 펼침 T03 검증 실패

- **File**: `docs/design/full-redesign-map/review/today-repair-2026-10-26/duo-open-ui-result.json`
- **Issue**: `dashboard-stress-details` activation point invalid로0/1 실패했고 앱 PNG는 검은 화면이었다. LCD-1 활성 확인만으로 앱 표시·터치 성공을 증명하지 못한다. 실패 계층의 앱 창은951×669, 디스플레이 캡처는2006×2852로 방향/좌표 경로도 불일치했다.
- **Status**: **Open**. 새 근거 없이 같은 테스트를 반복하지 않았다. `.claude/**`, 테스트 실행기, 무관한 앱 코드를 수정하지 않았다.
- **Resume**: 디스플레이/창 방향과 캡처 경로를 정합시킨 뒤 유효한 새 PNG·해당 selector 통과가 필요하다.

## 관점별 검토

- Security: 새 권한·네트워크·저장 스키마·외부 입력 없음. 캡처는 mock 데이터이며 비밀 정보 추가 없음.
- Performance: 기존 HRV/RHR 입력을 재사용하고 시간별 계산을 detached task에서 수행한다. 새 HealthKit 조회·body 내 서비스 호출 없음.
- Architecture: 루트 navigation 소유권 유지, metric inspector 제거와 기존 Q&A inspector 구분. 공유 차트 기본값 유지. 두 VM의 같은 계산 helper를 재사용한다.
- Data Integrity: 오류/정상 빈 결과·날짜 변경·부분 성공을 구분한다. 보존 점수를 새 측정으로 저장하지 않는다. data-001 해결을 재검토했다.
- Simplicity: 기존 지원 카드·순수 계산 재사용, 새로운 범용 framework 없음.
- Localization: 새4키 en/ko/ja와 positional placeholders 확인. 삭제된 Analysis details의 소비자 없음. 새 rawValue는 접근성 ID에만 사용한다. 날짜는 locale format style 사용.

## 검증·재사용 범위

- 표준 `build-target.sh`의 앱·테스트 build-for-testing 성공.
- Dashboard37개 고유 검사 성공 증거(36+보정 후1), 변경되지 않은 컨디션 상세16개의 이전 성공을 재사용했다. 최초 실패·재검증 summary는 갤러리에 함께 보존했다.
- formatter `--check`, `git diff --check`, 캡처21장 SHA-256, 포털 링크·생성기 구문 확인.
- 이전 일반 상태의 폰·iPad·Duo 접힘 T03 캡처는 유지한다. Resolve delta는 데이터 보존 메타데이터와 회귀 fixture이며 정상 화면 배치는 바꾸지 않았다. 이 재사용으로 X·Duo 펼침·부분 실패 UI를 검증했다고 주장하지 않는다.

## Ship 상태

`review-ship` Step4는 미해결 P1/P2 또는 실패/불가한 필수 검증이 있으면 Ship 전에 중단하도록 요구한다. 두 검증 게이트가 Open이므로 PR 생성·push·원격 머지·브랜치/워크트리/시뮬레이터 정리는 수행하지 않았다. 원격 main의 동기화와 GitHub 인증은 확인했다. 로컬 브랜치와 전용 시뮬레이터3개를 보존한다.

[Finding 상태 JSON](2026-10-26-today-feedback-review-ship.json) · [실제 화면·검증 제한](../design/full-redesign-map/review/today-repair-2026-10-26/index.html)
