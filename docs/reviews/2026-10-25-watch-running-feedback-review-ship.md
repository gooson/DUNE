# Code Review Report

> Date: 2026-10-25
> Scope: Watch 러닝 거리 우선 화면, 구간·목표 페이스 음성 안내와 설정
> Base: ee38ebe0154af1baee68fe7b865f1f7c7345d3d8 (`origin/main`)
> Branch: `codex/watch-running-feedback`

## Summary

| Priority | Count | Disposition |
|---|---|---|
| P1 | 0 | 없음 |
| P2 | 2 | 모두 Resolved |
| P3 | 4 | 3 Resolved, 성능 권고 1 Open |

2000줄 이상의 전체 변경을 보안·성능·아키텍처·데이터 무결성·단순성 관점에서 parent가 직접 검토했다. Agent-Native는 설정·프롬프트 변경이 없어 생략했다. 기존 Today 커밋과 Live Activity·테마 미커밋 변경은 원래 작업트리에 보존하고, 최신 main 기준 별도 관리 작업트리로 러닝 범위만 분리했다. 최신 Today 및 Activity/Life 변경은 main 동기화로 반영했으며 PR diff에는 러닝 범위만 남긴다.

## Findings

| ID | Priority | Finding | Status · Evidence |
|---|---|---|---|
| data-001 | P2 | 무음 동안 소비한 목표 경고가 다시 활성화되지 않음 | Resolved. 음성 켜기·볼륨 복귀에서 페이스 준비 상태만 재설정한다. 부분 구간을 유지하는 두 인자 회귀가 통과했다. |
| ui-001 | P2 | 40mm 설정의 고정 제목·완료 행이 목록을 압박하고 제목이 잘림 | Resolved. 시스템 제목·확인 도구 막대를 사용하고 짧은 3언어 제목과 한 줄 목표값을 적용했다. 설정 UI 통과와 C17·C18 새 PNG를 확인했다. |
| simp-001 | P3 | 테스트에만 남은 이전 kilometer 이벤트·번역 키 | Resolved. 실제 split 경로로 테스트를 전환하고 미사용 코드·키를 제거했다. |
| simp-002 | P3 | 새 종료 분기의 폐기된 WKExtension API | Resolved. WKApplication으로 교체했고 최종 앱 빌드가 통과했다. |
| ui-002 | P3 | 기본 40mm 거리 화면에서 심박 줄이 하단에 걸림 | Resolved. 큰 km 크기를 유지하고 간격·평균 페이스 레이블을 줄였다. 심박 frame 회귀와 새 C14·C15를 확인했다. |
| perf-001 | P3 | SDK가 메인 스레드의 동기 오디오 활성화에 성능 권고를 보고함 | Open. 실제 UI 정체의 원인으로 관찰되지 않았으나 실기기 계측이 필요하다. 비동기 전환은 stop·새 안내 간 경합 검증을 동반하므로 기계적 수정으로 처리하지 않았다. |

실기기에서 실제 발음·이어폰 경로·음악 복원을 별도로 확인한다. 시뮬레이터의 mock speaker 테스트와 UI 실행을 실제 소리의 증거로 확대하지 않는다.

## Final Review Scope

이전 P1/P2와 이후 변경(설정 Form·접근성·러닝 전용 테스트 진입)을 재검토했다. 구간·페이스·음성 정책의 실제 소스와 단위 테스트는 기존 24건 통과 당시 해시와 동일하다. 새 설정은 기존 검증된 바인딩을 유지하며, native toolbar와 별도 목표값 식별자만 적용한다. 새 HealthKit 권한·저장 모델·WC 메시지는 없다. 미해결 P1/P2는 없다.

SwiftUI 관점에서는 중첩 NavigationStack 없이 기존 Watch 시트 패턴을 따르는지, Apple UX 관점에서는 실제 40mm 표시를, UI 테스트 관점에서는 실제 탭·선택·재실행과 값 보존을 각각 확인했다. 홈의 공통 테스트를 수정하지 않고 이번 러닝 테스트만 실제 Lazy 카드까지 스크롤한다. 선택기는 레이블·값을 함께 읽고 갱신을 기다리며, 빈 AX 값은 표시 레이블로 읽는다. 스위치는 상태값을 확인한 뒤 실제 trailing thumb를 탭한다.

## Apple UX Principles

| Principle | Verdict | Evidence |
|---|---|---|
| Purpose | Conforms | 누적 km가 러닝 기본 페이지의 가장 큰 수치다. |
| Agency | Conforms | 음성·볼륨·간격·목표 안내를 운동 중 조절하고 다시 바꿀 수 있다. |
| Responsibility | Conforms | 로컬 계산·저장과 실제 구간/평균의 명칭을 구분한다. |
| Familiarity | Conforms | 기본 Form·Picker·Toggle·Stepper와 시스템 시트 도구 막대다. |
| Flexibility | Conforms within scope | 작은 Watch에서 세로 스크롤을 허용하고 값·레이블을 노출한다. 최대 글씨·다른 Watch 크기는 이번 실행에 포함하지 않았다. |
| Simplicity | Conforms | 제어에서 설정까지 한 번 진입하고 별도 고정 제목 행을 제거했다. |
| Craft | Conforms within scope | C17·C18 새 캡처에서 제목·목표값 잘림을 해소했다. C14–C18 새 캡처를 확인했다. |
| Delight | Conforms | 짧은 선택적 음성과 반복 안내 제한이 운동을 방해하지 않도록 구성했다. 실기기 오디오는 별도다. |

## Localization

UI는 LocalizedStringKey, 프로그램 음성은 String(localized:)를 사용한다. 새 키 24개의 en/ko/ja와 카탈로그 포맷을 확인했다. helper 레이블 타입·enum rawValue 누출·숫자 단위 포맷도 확인했다. 캡처 테스트는 설정 비교를 위해 en_US와 시스템 기본 글씨로 실행한다.

## Verification

- 단위: 실제 소스·테스트에 연결한 호스트 package에서 3 suite·24 tests 통과. Watch 오디오 어댑터는 제외했다. 초기 영어 숫자 구분 기대값을 수정해 재검증했고 최종 로그를 보존했다.
- 빌드: 최신 main 통합과 최종 Watch 화면 소스를 포함한 표준 앱 빌드가 통과했다.
- 상세 설정: `testRunningFeedbackSettingsPersistAcrossSheetAndRelaunch` 1/1, exit 0. 거리·볼륨·목표 안내·허용 범위의 시트 재열기와 앱 재실행 유지를 확인했다.
- 러닝 화면: 나머지 3 selector가 exit 0으로 통과했다. 이후 심박 줄 개선의 영향 selector 1건만 재검증해 통과했다. 최종 범위는 서로 다른 4건이며 추가 거리 재검증은 1건이다.
- 실제 캡처: C14–C18 신규 PNG·출처를 등록하고 직접 확인했다. C16은 음성 제어를 위해 스크롤한 상태다. 전체 Watch 상태는 68개 중 65개 캡처이며 기존 S08·S11·C12의 미캡처는 이번 범위 밖이다.
- 범위: Watch 관련 4건만 실행한다. 프로젝트 변경은 새 소스 참조이며 iOS 동작을 바꾸지 않았다. 자동 판정기의 full은 미실행이며 targeted를 full 통과로 표시하지 않는다.

## Execution Recovery

초기 저장소 잠금 busy가 실제 획득으로 해소된 뒤에만 재개했다. metadata 자식의 닫힌 FD 환경값 전달은 상위 잠금을 유지하는 로컬 wrapper로 보정했으며 저장소 실행기는 변경하지 않았다. 동일 보정은 deadline을 거쳐 실행되는 registry 정리에도 적용했다.

실패 뒤 SDK의 verbose sysdiagnose 수집이 두 번 정체해 각각 idle deadline으로 종료했다. 남은 소유 실행 프로세스가 없음을 확인한 뒤 해당 수집 경로를 중단했다. 설치된 Xcode의 공식 `-collect-test-diagnostics never` 옵션을 로컬 wrapper에서 test 명령에 적용해 정상 종료·읽을 수 있는 xcresult가 생성됨을 확인했다. XCTest 결과·실패 첨부·실제 화면 캡처는 계속 수집한다.

상세 설정의 120초 한도 초과는 무관한 lazy 목록 구역 대기를 제거해 해결했고 시간 한도는 늘리지 않았다. 실패·변경·재시도 이력은 보존한다. 원래 작업트리의 다른 변경과 기기는 정리 대상에서 제외한다.

## Ship Gate

필수 targeted UI와 실제 캡처를 확인했고 P1/P2는 모두 해결됐다. [검증 receipt와 소스 해시](evidence/2026-10-25-watch-running-feedback/verification.json), [finding 상태](evidence/2026-10-25-watch-running-feedback/findings.json)를 보존한다. PR 생성·원격 merge·소유 기기/작업트리 정리를 진행한다. perf-001은 비동기 오디오 생명주기·실기기 계측을 위한 비차단 후속 항목이다.
