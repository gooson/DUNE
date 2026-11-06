---
tags: [review-ship, watchos, live-activity, indoor-place, healthkit]
date: 2026-11-06
category: solution
status: reviewed
---

# 12:30 예약 Review → Resolve → Ship

## 범위와 격리

사용자가 2026-11-06 12:30 KST의 일회성 review-ship을 명시적으로 요청했다. Live Activity 여백, 승인된 Watch 러닝 V2 현재 존, 실내 유산소 장소 핀만 대상으로 삼았다. 원본 `cleanup-chat-ownership/Health`의 아이콘·Watch 요약 dirty 변경은 수정하거나 stage/stash/reset하지 않았다. `origin/main`의 `6b5befdf2447eaabef0e37cbe92bc4d468d77834` 위에 `codex/workout-surface-spacing-zones-place`를 격리했다. 공유 문서는 이번 항목·링크·C14/C15/C20/C21 기록만 구조적으로 옮기고 생성본을 다시 만들었다. 최신 main 번역을 보존하고 `Workout location` 항목만 추가하여 카탈로그 충돌을 해결했다.

## Review findings

Security·Performance·Architecture·Data Integrity·Simplicity를 별도 에이전트로 read-only 리뷰했다. Agent-Native는 지침/agent 변경이 없어 제외했다. 주 에이전트가 L10N 키·보간·레이블 타입·en/ko/ja 번역과 카탈로그 상태를 별도로 확인했다. 발견사항을 보고한 후 별도 Resolve에서 수정했다.

| ID | 우선순위 | 발견사항 | 처분 |
|---|---|---|---|
| data-001 | P2 | 선택적 route 조회 실패가 이미 읽은 유효한 장소를 버림 | 코드 수정. 취소·장소 없는 오류는 전달하고 장소가 있으면 지도 핀을 보존. 35건의 관련 unit 검증 통과. |
| data-002 | P2 | optional addMetadata await가 finishWorkout 앞에서 무기한 대기 | 코드 수정. endCollection 전에 첫 1초 budget 내 callback gate로 제한하고 지연 callback을 무시. 35건의 관련 unit 검증 통과. |
| perf-001 | P2 | 실내 핀 수집에도 실외 best accuracy 연속 GPS 사용 | 코드 수정. coarse 단발 요청·100m 이내·최초30초 deadline, 명시적 재개 시에만 새 요청 허용. 35건의 관련 unit 검증 통과. |
| simple-001 | P3 | 소비자가 사라진 route-only protocol/wrapper | 제거. 관련 target 컴파일 통과. |

P1은 0건이다. 초기 보안 제안은 실제 WhenInUse 권한·실내 장소 용도 설명·비공개 HealthKit 저장·사용자의 자동 장소 계약 확인 후 철회됐다. 초기 아키텍처 제안도 생성 호출부를 확인한 결과 imported Watch 기록의 저장된 nil 장소가 명시적 사용자 제거 결정임을 확인해 철회됐다. 이들은 현재 차단 finding으로 남기지 않는다.

## Resolve 이후 최종 검토

별도 PR reviewer/app-quality-gate가 전체 앱 변경과 새 metadata helper·테스트·프로젝트 target 포함 여부를 재확인했다. 앞선 4건은 현재 소스에서 해결됐고 새 P1/P2/P3는 없었다. 진행 중 검사를 통과로 간주하지 않았다. 원본 구현의 21 unit/7 UI·네이티브8장 기록은 초기 근거로 보존하며 최신 main 통합과 이번 복구 로직은 필요한 selector만 새로 실행한다.

## 검증·Ship

iOS unit 10건(`WorkoutLocationTests`), Watch unit 25건(`WorkoutRouteRecorderTests` 17 + `WorkoutPlaceMetadataWriteTests` 8), 일반 iPhone UI 4건, 40mm Watch UI 3건, 카탈로그 계약 11건이 새로 통과했다. UI는 모두 runner exit 0·요청 selector 누락 0·skip 0이며, 통과한 결과 번들에서 실제 PNG 8장을 다시 추출해 갤러리·출처·SHA-256을 갱신했다. 여백은 카드 본체 기준 위 20pt·아래 20.0–20.3pt다. 카탈로그 format/manual, theme-map check, diff whitespace도 통과했다. 원격 PR/merge는 이 검증 이후 실행하며 실제 결과는 채팅과 로컬 실행 기록에 남긴다. 전체 회귀는 요청하지 않아 실행하지 않는다. 실기기 GPS와 Watch→HealthKit→iPhone 전달은 계속 미검증이다.

### 검증 중 발견한 실행·fixture 문제

새 성공 route fixture의 첫 segment 표시가 빠져 1건 실패했다. 올바른 첫 segment로 수정한 후 해당 suite 10건과 Watch 두 suite 25건이 정상 종료했다. 메서드 selector를 시도한 실행은 0건이어서 통과로 인정하지 않았고, 실제 실행이 확인된 suite selector로 바로잡았다. 카탈로그 계약 11건도 새로 통과했다.

기본 이름 iPhone17로 선택된 unit clone의 실제 type은 iPhone-Duo였다. 그 기기에서 지도 2건은 통과했고 Live Activity 2건은 원격 Widget 접근성 서버(kAXErrorServerNotFound) 때문에 실패했다. 새 PNG에는 두 카드가 정상 렌더링되어 있었다. 앱 코드는 변경하지 않고 실제 type iPhone18Pro를 확인한 전용 clone에서 같은 4개 selector를 한 번 재검증했고, 실제 4건 실행·4건 통과·skip 0·runner exit 0을 확인했다. 실패한 Duo 결과를 정상 iPhone 통과 증거로 쓰지 않는다.

Watch 3개 testcase 통과 후, 기기 목록에서 이미 없어진 Watch에 대한 `simctl diagnose`가 결과 정리를 지연했다. 사용자 정리 요청에 따라 해당 실행의 소유 PID만 종료했고 기존 xcodebuild·runner가 exit 0으로 정상 종료한 뒤 3/3 receipt를 확인했다. 이번 실행의 idle iPhone 2개를 순서대로 shutdown/delete/재조회했고, Watch 2개는 이미 없음으로 확인했다. 다른 작업의 기기는 조작하지 않았다.

## Ship 직전 main 통합

검증 중 main이 `5815bba6ec7e7c9f4c170fc7b7299e75b2a98080`으로 갱신돼 feature에 통합했다. 코드 변경은 Life 히트맵·주간 리포트와 해당 UI 테스트뿐이며, 앞서 통과한 운동 코드·카탈로그·핵심 테스트 소스 해시는 동일하다. 공유 README·실제 포털·테마 manifest의 문서 충돌은 양쪽 링크와 기록을 보존해 해결하고 테마 index를 다시 생성했다(10테마·67시안). 통합 컴파일은 기기를 만들지 않는 generic iOS Simulator build로 확인했고 exit 0으로 통과했다. 같은 운동 UI·unit 검사는 반복하지 않는다.

통합 후 독립 최종 리뷰에서도 새 P1/P2/P3는 없었다. 코드·문서 충돌이 모두 해소됐으며, 초기 작업 공간에서 이번 캡처에 사용한 Watch도 별도로 삭제 확인했다. 원래 작업 공간의 소스 69개 SHA-256은 예약 격리 이후 변하지 않았다. 향후 전용 기기는 검증이 끝나는 순서대로 정리하며 여러 idle 기기를 누적하지 않는다.
