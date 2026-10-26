---
date: 2026-10-26
category: review
tags: [today, foreground, healthkit, navigation, layout, hit-testing]
status: reviewed-with-coverage-limits
---

# Today 실제 피드백 수정

사용자 화면에서 확인한 범위는 T03 컨디션 근거 배치, 어제·인사이트·루틴의 다른 카드 외형, 브리핑·수면·스트레스의 과도한 행동 행, 작은 X 터치 영역, 지표 inspector 모달 및 빈 모달 상태, 복귀 후 컨디션·수면 소실, 컨디션 요약·상세 그래프 불일치다.

## 검증 계약

- 데이터: 조회 실패 전후 컨디션 49, 수면 443분, 어제 운동 2건 보존. 정상 빈 응답은 제거하고 전날 값은 오늘 값으로 유지하지 않는다.
- 내비게이션: 지표 상세 push → 백그라운드/복귀 → 뒤로 → 재진입 → 전체 데이터 경로.
- 터치: X 글리프 바깥의 44×44pt 내부 패딩을 눌러 실제 인사이트가 제거되는지 확인.
- 배치: 기본·큰 글씨에서 제목 옆 상세 행동, 스트레스 근거 기본 표시, 공통 지원 카드 표면을 새 PNG로 확인.
- 영향: iPhone·iPad·Duo 접힘/펼침 T03 및 Today에서 여는 지표 상세. Watch는 이번 Today 전용 View를 소비하지 않는다. 전체 앱 테스트나 모든 테마 검증으로 확대하지 않는다.

## 실행 중

전용 iPhone: `F8DF973B-A068-4A71-B91A-6134E77A7556`, worktree 소유권 등록 확인. 앱 빌드는 표준 `scripts/build-ios.sh` 사용. 새 캡처와 실제 통과 결과가 생기기 전까지 기존 디자인맵 이미지를 수정 완료 증거로 사용하지 않는다.

실제 기기의 HealthKit 오류 로그는 제공되지 않았으므로 복귀 실패 원인은 코드 경로와 회귀 fixture로 검증하며 특정 OS 오류 코드가 발생했다고 단정하지 않는다.

## 현재 증거

- 첫 generic build는 컴파일 도중 공유 차트 initializer 변경이 겹쳐 undefined symbol로 실패했다. 소스 동결 후 표준 `build-target.sh --scheme DUNETests --platform ios --build-for-testing`로 앱·테스트 빌드를 다시 완료했다. 이 실패는 앱 동작 실패로 분류하지 않는다.
- 표준 unit runner는 selector를 지원하지 않아 전체 실행 대신 표준 빌드 결과에 `test-without-building`을 사용했다. 저장소 실행 잠금·전용 기기·900초 deadline을 유지했고 실행기 소스는 수정하지 않았다. DashboardViewModelTests·ConditionScoreDetailViewModelTests **52/52 통과**, exit0, `/private/tmp/today-repair-unit.xcresult`, `/private/tmp/today-repair-unit-summary.json`.
- 요약은 상세와 같은 HRV 측정 시간별 계산 및 저장 점수/current 점수 병합을 사용한다. Today 그래프만 면 채움을 제거하고 실제 관측 시각 범위를 표시한다. 다른 sparkline consumer의 기본값은 유지한다.
- 위 단위 검증 뒤 추가한 앱 delta는 요약 그래프 접근성 ID 한 줄이며, UI 검사에서 컴파일한다.

## UI 실행 이력

- 최초 9건: 5통과·4실패. 최대 글씨 컨디션 상세, 기본 카드 헤더 배치, 수면 밝음·어두움·최대 글씨, 지표 상세 background/back/reopen, 브리핑 밝음·어두움 통과.
- 실패 selector 4건만 수정 후 재검증: 수면 상세 진입, 스트레스 근거 밝음·어두움·최대 글씨, 스트레스 상세 진입 3건 통과. X 검사는 두 번째 실패를 보존하고 자동 실행을 중단했다.
- 실제 XCTest hierarchy에서 `dashboard-smart-insights-section`과 `dashboard-stress-contributions`가 자식 식별자를 덮는 것을 확인했다. 각 부모를 접근성 container로 명시한다. 인사이트의 첫 실패를 단순 seed 부재로 추정했던 판단은 실제 계층 증거로 교정했다.
- 인사이트 테스트는 52점과 launch 전용 빈 dismissal 배열을 사용해 재실행 가능하게 했다. production dismiss 저장 상태는 변경하지 않는다. X의 추가 실행은 저장소 재시도 제한에 따라 사용자 허용을 요청했다.
- 기본/AX 수면·스트레스 및 상세 경로의 기존 성공은 유지한다. 이후 앱 delta는 인사이트/루틴 접근성 container와 Today 그래프 왼쪽 domain이며 최종 캡처 검사에서 컴파일한다.

## 최종 폰 보완

49점 표본의 T03 헤더·브리핑·수면·스트레스 정보 배치 검사 **1/1 통과**, exit0. 새 PNG에서 요약 그래프가 첫 관측 시점부터 표시되는 것을 확인했다. 원본은 `/private/tmp/today-repair-final-attachments/manifest.json`이다. 동일 최종 빌드의 접근성 계층에서 `dashboard-insight-dismiss-training-fair-normal` 버튼 ID와 44×44pt 프레임도 확인했다. 실제 X 패딩 터치는 추가 실행 승인 대기이며 계층 존재를 클릭 통과로 보고하지 않는다.

## iPad·Duo

iPad 전용 기기 `1A8F0D5D-922E-4184-A890-BED0C7AA908E`에서 최종 T03 정보 카드 검사1/1 통과. 원본4장과 receipt를 갤러리에 보존했다.

Duo 전용 기기는 `2227C2BF-E074-4D6C-A87C-FED6578FD933`. 검토된 hinge source `7acb090dd7d28fb0aea8e1907211ceff15aa450e`의 setter 이후 공식 displays readback에서 외부 LCD만 active를 확인했다. 현재 devicectl에는 `device motion` 하위 명령이 없어 기존 `hinge get`의 수치 각도 조회는 실패했다. 숫자0°/180°로 인증하지 않고 활성 디스플레이·새 PNG·실제 viewport를 별도로 대조한다. 원인 변화 없이 해당 get을 반복하지 않는다.

사용자가 추가 X 실행을 하지 않고 수정 결과만 정리하도록 선택했다. X 재실행은 하지 않는다. 최종 프레임·식별자 확인과 실제 패딩 클릭 통과를 구분한다.

## 최종 상태

- 표준 앱·테스트 build-for-testing 성공, 관련 단위52/52 통과.
- 관련 UI9개 고유 selector 중8개에서 성공 증거를 확보했다. 최초5건과 실패 후 수정3건의 성공을 재사용한다. 최종49점 T03 배치는 폰·iPad·Duo 외부에서 각각1/1 통과했다. 전체 회귀나 모든 기기/언어/상태 조합의 통과가 아니다.
- X는44×44pt contentShape 및 부모 container 수정 완료. 최종 계층에서 개별 버튼 ID와 프레임을 확인했다. 실제 패딩 클릭 검사는 두 실패를 보존하고, 사용자 선택에 따라 추가 실행하지 않았다.
- Duo 내부는 전환 지연 후 LCD-1 활성 상태를 전후로 확인했다. stress-details hittability가 Activation point invalid로 실패했고 추출된 앱 PNG는 검은 화면이었다. 해당 PNG는 실패 진단으로만 보존하고 실제 화면 갤러리에서 제외했다. 이 실행의 근본 원인은 미확정이다. 전체 펼침 배치를 통과로 표시하지 않는다.
- 새 실제 갤러리에는 유효 PNG21장을 해시와 함께 보존했다. 초기 단계의 유효 캡처와 최종49점 캡처를 출처로 구분하고, 테스트가 실패한 실행의 캡처는 capture-only로 표시한다.
- T06 상세는 폰 수면 표본을 직접 확인했다. 다른 지표·iPad/Duo T06과 운영 루틴의 새 캡처는 없다. 기존 PNG를 새 수정 증거로 바꾸지 않았다.
- [새 실제 화면](../design/full-redesign-map/review/today-repair-2026-10-26/index.html)과 [재발 방지 기록](../solutions/general/2026-10-26-today-foreground-and-detail-navigation.md)을 저장했다. 통합 포털과 포털 생성기의 링크, 상태 계약, T06 내비게이션 인벤토리도 갱신했다. `.claude/**` 원본·테마 방향 시안은 변경하지 않았다.
