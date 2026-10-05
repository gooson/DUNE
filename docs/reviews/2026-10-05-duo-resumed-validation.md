---
tags: [iphone-duo, visual-qa, validation]
date: 2026-10-05
category: review
status: in-progress
---

# Duo 최신 main 반영 후 잔여 검증

기준: `origin/main` 96cc5ae7을 bc20673e에서 병합. Xcode 27.1 (27A9269), 전용 iOS 27.1 시뮬레이터 DUNE Duo Visual Audit (`5A2A5D3F-3D53-4326-99DE-47823CA256FA`). 이전 9월 결과는 역사적 증거이며 최신 소스의 최종 통과로 재사용하지 않는다.

## 수행한 검증

| 범위 | 결과 | 증거 |
|---|---|---|
| 앱 및 Duo 전용 테스트 플랜 생성 | Xcode 27.1 표준 앱 빌드 통과 | `/tmp/duo-resume-20261005/app-audit-plan-build.log` |
| 정확한 시뮬레이터 선택 러너 | fixture 계약 29개 통과; 잘못된 기기 대체/복제 없음 | `62ec4dbb`, `scripts/tests/test_ui_test_runner.py` |
| 캡처/ACK/접힘 체크포인트 | fixture 계약 11개 통과; 만료·실패 증거 인정 안 함 | `f26c7f56`, `scripts/tests/test_duo_visual_audit.py` |
| 실제 내부 디스플레이 캡처 | 2853×2007 홈 화면 캡처 성공. 앱 UI 통과를 뜻하지 않음 | `/tmp/duo-resume-20261005/preflight-inner.png` |
| Body 저장 + 최대 AX 템플릿 편집 | 2개 실행, 0개 통과, 2개 실패. 결과 정리 중 Xcode 중단(exit 143); 합격 아님 | `/tmp/duo-resume-20261005/open-maxax-body-template/ui.log.result.json` |

## 미검증/환경 조건

- 현재 Computer Use는 Mac 잠금으로 Device Hub 조작 불가를 반환했다. 잠금 해제 요청을 전달했으며 상태 변화 전에는 반복 호출하지 않는다.
- 부분 접힘·완전 펼침의 실제 힌지 프리셋 UI, 외부 화면, 기본/최대 AX, 회전, 화면 경계와 조작 가능성은 별도 검증한다.
- 운동 입력·완료 상태·타이머, 선택·초안의 접힘 전후 연속성은 정적 자세별 통과로 대체하지 않는다.
- UI 테스트 성공과 원본 이미지 시각 판정은 별도로 기록한다. 최종 full iOS/watch 게이트는 아직 통과하지 않았다.

## 실패 분류와 다음 조치

- 템플릿: 증가 버튼의 실제 식별자는 `template-entry-<UUID>-sets-Increment`이고 레이블은 한국어였다. 영어 `Increment` 레이블 query 오류로 판정. 실제 안정 식별자로 보완했으며 해당 원인의 첫 조건부 재검증이 남았다.
- Body: 최대 AX 내부 화면에서 키보드 닫기와 Fat/Muscle 도달은 성공했으나 내비게이션 Save/Cancel이 모두 사라졌다. 툴바 위치 이동 후 같은 원인이 재현됐으므로 해당 자동 재실행 경로는 중단한다. 고정 하단 Save/Cancel로 구조를 바꾸고, Mac 잠금 해제 후 직접 조작 검증을 남긴다.
- 캡처 013의 `body-form-weight` 값이 `75.88.8`이었다. 입력 교체 헬퍼의 3회 탭/단일 delete가 전체 선택을 보장하지 않았음. iOS XCTest 공개 Command-A 키 이벤트로 변경하고, 비우기와 최종 값이 정확하지 않으면 성공을 반환하지 않게 보완했다.
- 실행 종료 후 Xcode가 SDK build-number 변환 오류와 결과 정리에서 멈췄다. 알려진 이번 PID 8392만 SIGINT, 이후 SIGTERM으로 중단했다. 2개 실제 실패 및 14개 동기화 캡처를 보존했다. 후속 실행에서는 결과 정리 정상 종료 여부도 확인한다.

## 후속 구현

- `9b599975`: 자세·주간 비교 행의 AX 세로 배치, 자세 점수 링을 글자와 함께 확대, 두 자세 pane 및 보고서 하단 landmark 식별자. 픽셀 합격은 후속 캡처에서 별도 판단한다.
- `c73c05ea`: Body Save/Cancel을 Form과 독립된 고정 하단 영역으로 이동. Xcode 27.1 표준 앱 빌드 `/tmp/duo-resume-20261005/app-fixed-footer-and-comparisons.log` 통과. 저장 버튼 소실의 직접 조작 검증은 대기.
- Condition 링도 기존 HeroScoreCard와 같은 내부 원 영역 제약·최소 글자 축소 패턴을 적용했다. 세 자리 점수의 최대 AX 실제 픽셀 확인은 대기.

## 펼친 내부 화면의 남은 경로 실행

`open-maxax-remaining-routes`, 표준 러너, 최대 AX, DuoAudit opt-in. Xcode 종료 65로 실패 게이트이며 결과 파일은 해당 디렉터리 `ui.log.result.json`.

- 실제 passed-case 로그: Workout Insights 및 자세 비교 2개. 집계는 Executed 5 / skipped 1 / failures 3이고 Life setup error가 skipped와 failure 모두에 기록돼 receipt의 산술 passed는 1이다. 서로 겹치는 skipped/failure 때문에 실제 passed-case 2개와 산술 집계를 구분한다.
- 템플릿 이전 Increment 원인은 해소됨: 3세트·9회·90초 조작을 실제 캡처로 확인. 다음 실패는 Command-A가 무게 값을 비우지 못한 것으로 분리. 기존 60이 남아있어 교체를 중단했고 잘못된 저장은 하지 않았다. 두 숫자 폼에 직접 Clear Input/Done 동작 및 3개 언어 문구를 추가했다. 이 새 원인의 조건부 재검증은 대기.
- Insights에 돌아가기/닫기가 없어서 다음 launch가 별도 Insights 창을 복원. Cloud consent와 Life가 This Week 창에서 시작해 목적지에 미도달했다. 창의 고정 Close, 테스트의 운동 복귀 assert 및 fixture launch의 복원 창 닫기를 추가했다. 이 원인의 첫 조건부 재검증은 대기.
- 자세 비교는 실제 Comparison 목적지 및 photos/metrics 두 pane 스크롤 검사가 통과했다. 캡처 044에서 각도 단위가 값에서 분리되어 다음 줄로 떨어지는 잔여 P2를 발견했고 AX metric row/value를 세로 배치로 수정했다. 이 수정의 시각 재검증은 대기.
- 47개 checkpoint 모두 ACK된 이미지·계층을 보존했다. 일부 목적지는 테스트 실패로 미도달이므로 유효한 캡처가 있다는 사실을 목적지 합격으로 승격하지 않는다.

## 입력 교체와 창 복귀 후속 결과

`open-maxax-clear-window-correction`: 5개 실행, 로그상 passed case 2개(템플릿·Insights), skipped 2/failures 3이 겹쳐 receipt 산술 passed 0. 정상 결과 정리에서 다시 SDK build-number `invalidDigitCount`에 멈췄고, 테스트 종료 4분 이상 후 이번 PID 35409만 SIGTERM으로 종료(exit 143). 전체 게이트 실패이며 동일 실행을 다시 시작하지 않았다. 동기화 checkpoint 42개를 보존했다.

- 템플릿은 최대 AX에서 **3세트·9회·65kg·90초 저장 및 재열기 검증 통과**. 원본 [캡처](assets/2026-10-05-duo/template-maxax-persisted.png)의 값과 조작 영역을 직접 검토했다. 상단 Exercises 제목은 스크롤 viewport 경계에 걸려 있으며 입력 행 내부가 잘린 것은 아니다.
- **Insights Close의 기존 pass를 복귀 성공으로 인정하지 않는다.** [닫기 후 계층](assets/2026-10-05-duo/insights-close-two-windows-before.txt)에 Insights와 운동 창이 둘 다 남았다. `controls.exists`는 뒤쪽 창의 존재만 확인했다. 닫기 버튼 소실·운동 화면 hittability·완료 버튼 도달을 함께 요구하도록 테스트를 보완했다.
- 이후 Cloud consent, Life, Posture는 Insights 단일 복원 창에서 시작해 목적지에 미도달했다. 같은 원인의 조건부 재시도에서도 해소되지 않아 자동 경로 중단. primary 세션으로의 명시적 복귀 구조 수정 후, Mac 잠금 해제와 직접 조작에서 원인 해소를 확인해야 재개 가능하다.
- Insights [캡처](assets/2026-10-05-duo/weekly-breakdown-maxax-before.png)에서 운동 아이콘/이름 겹침과 `32%`의 세 줄 분할을 추가 발견했다. 최대 AX에서는 운동 분류를 세로 배치하고 고정 폭 수치 칸을 제거했으며 요약 카드를 한 열로 전환했다. **수정 후 픽셀 검증 대기**.
- 접힘 연속성 테스트는 ± 버튼으로 실제 바꾼 미완료 입력 초안, 완료 요약, 벽시계와 휴식 countdown 연속성, Skip/다음 세트 조작을 구분한다. 기존 다음 세트에 저장된 이전 운동 기본값을 강제로 덮어쓰도록 잘못 요구하지 않는다. host release 후 XCTest 계층을 새로 읽고 내부/외부 디스플레이를 함께 캡처한다. 실제 `closed → partiallyOpen → openFlat` 조작 증거는 아직 없다.

[실행 receipt](assets/2026-10-05-duo/open-maxax-clear-window-result.json)는 실패 상태 그대로 보존했다. 이 receipt는 시각 합격 인증이 아니다. 계정 주간 한도 사용 71%(잔여29%)로 확인했으며 이 작업의 정확한 토큰 수는 제공되지 않았다.

## 창 복귀 구조 수정과 재개 조건

`AppWindowRouter`를 공유 Presentation 컴포넌트에 추가했다. App과 운동 화면이 같은 도우미를 사용하며 Presentation → App 역방향 의존을 만들지 않는다. SwiftUI 기본 group을 `main`으로 지정하고 실제 뷰가 연결된 window scene의 session에 앱 소유 역할/원래 운동 창 ID를 표시한다. 기존 primary는 `openSessions`에서 원래 ID 우선으로 찾아 활성화하며, 없을 때만 새 main을 요청한다. foreground 활성화를 관측한 뒤 현재 Insights session의 정확한 폐기를 요청한다. 중복 요청을 막고 실패를 로그/알림으로 반환해 재시도할 수 있게 한다. 순서 보장을 임의 sleep으로 대체하지 않는다. 기존 nonisolated scene builder를 유지한다.

이 변경의 빌드·실제 UI 결과는 별도로 기록한다. 이전 버전에서 만든 marker 없는 disconnected session은 공용 API로 역할을 식별하지 못하므로 새 main fallback이 생길 수 있다는 업그레이드 한계를 남긴다. 기존 운동의 메모리 상태를 cold launch에서도 복구한다고 주장하지 않는다.

재개 시 필요한 직접 확인:

1. Mac 잠금 해제 후 `DUNE Duo Visual Audit`에서 Insights Close → 실제 primary 활성화와 보조 창 제거, 종료·재실행 후 primary 탐색.
2. 고정 Body Save/Cancel: 최대 AX/키보드/하단 Fat·Muscle에서 실제 탭과 값 저장(88.8) 확인. 자동 경로 재시도 예산 소진 상태 유지.
3. 실제 `closed`, `partiallyOpen`, `openFlat` 각각 기본·최대 AX, 내부·외부 활성 화면, 회전 및 경계 확인. 크기 클래스/가로 방향으로 힌지 상태를 추정하지 않음.
4. 접는 동안 운동 초안·완료 요약·휴식 countdown 연속성 직접 preset release 후 검사.
5. 새 주간 breakdown/Condition score/자세 metric 행 픽셀 검사, consent·Life 보고서 landmark 목적지 재개. 이전 setup failure를 목적지 pass로 간주하지 않음.

동일 실패를 자동 반복하지 않는다. 물리 조작이 가능한 잠금 해제, 수정된 코드에서 직접 원인 해소 확인, 명시적 검증 범위 확정을 재개 조건으로 남긴다.

## 최종 컴파일 및 리뷰 기록

- Xcode 27.1 표준 앱 빌드: `app-final-scene-and-breakdown.log`, `app-final-scene-owner.log` 통과. 리뷰의 조건부 P2(기존 Insights 재사용 시 이전 opener 유지)는 기존 Insights session의 opener를 새 출발 창으로 갱신하고 정확한 session 활성화를 요청하도록 수정했다. 소스 수준 해소이며 실제 여러 창 검증 대기.
- UI 타깃 표준 `build-target.sh --scheme DUNEUITests --platform ios --build-for-testing`: `uitests-final-compile.log` **TEST BUILD SUCCEEDED**. 접힘 테스트와 새 Close assert가 컴파일된 증거이며 실행 통과를 뜻하지 않는다.
- UUID 변수명 `token`에 커밋 훅의 possible-secrets 오탐이 발생했다. 우회 대신 `requestID`로 바꾸고 `app-final-request-id.log` 앱 증분 빌드 통과. 실제 비밀값은 없었다.
- 창 도우미를 공유 Presentation으로 이동한 뒤 프로젝트 재생성과 최종 앱 빌드 결과는 `app-final-presentation-router.log`에 보존한다. 최종 통과 여부를 아래에 추가한다.
- 현재 변경 외 기존 dirty audit 테스트·플랜·9월 문서는 보존했다. 이전 기록의 passed 상태를 최신 전수 검사 완료로 승격하지 않았다. 전체 작업은 아직 미완료다.

최종 앱 표준 빌드(`app-final-presentation-router.log`) **BUILD SUCCEEDED**. 공유 Presentation 이동 및 프로젝트 참조가 포함된 소스의 컴파일 통과이다. UI 실행/전수 픽셀 게이트는 여전히 미통과다.

중간 커밋: `b60218a9` 캡처 refresh/계약, `26d6260a` 큰 글자 통계, `fbec0138` 창 복귀/번역/테스트 플랜. 검증 결과와 원본 증거는 본 문서 및 동명 assets 디렉터리에 보존한다. Mac 잠금 해제 전 실제 preset 조작이나 같은 실패 경로 재실행을 하지 않았다.
