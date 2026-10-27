---
tags: [wellness, flow, review, swiftui, accessibility, measured-comparison]
date: 2026-10-28
category: review
status: reviewed
---

# Wellness Flow 최종 리뷰

`main`의 `ebb31e84`에서 시작한 Wellness Flow 구현이다. 앱 소스의 최종 기준은 `6c1d3f77`, 테스트 기준은 `08b320c7`이다. 이후 갤러리·레이아웃·테마 맵과 이 기록만 바뀐다. [계획](../plans/2026-10-28-wellness-flow-implementation.md), [보존 시안](../design/layout-map/wellness-redesign-proposal.md), [새 실제 화면](../design/full-redesign-map/review/wellness-flow-2026-10-28/index.html)을 분리한다.

## Summary

| Priority | 해결 | 현재 미해결 | 판정 |
|---|---:|---:|---|
| P1 | 4 | 0 | 기존 Work/전문 검토 지적 해결, 현재 소스 재확인 |
| P2 | 7 | 0 | 실제 날짜·의미·테마·접근성 보완 확인 |
| P3 | 4 | 3 | 아래 세 가지 시각/미리보기 절충만 유지 |

Work부터 최종 Quality까지의 발견사항을 합친 이력이다. 열린 P1/P2는 없다. 별도의 스냅샷 수집이나 빌드만으로 리뷰를 통과시킨 것은 아니다.

## Five-perspective source review

네이티브 검토 시점의 9,962줄·55파일 브랜치 diff를 수집했고 `review` 스킬의 2,000줄 이상 예외에 따라 주 에이전트가 폴더별로 직접 다섯 관점을 검토했다. 초기 브라우저 시안은 이미 두 차례 Astra 자문을 받았으며, 현재 리뷰는 네이티브 변경과 기존 보존본의 구분을 중심으로 확인했다.

| 관점 | 대상/결과 |
|---|---|
| Security | 새로운 네트워크/인증/저장 쓰기/비밀 경로 없음. simulator·UI 테스트 fixture gate와 유한값/범위 검증 확인. 발견 없음. |
| Performance | 네 항목의 40일 범위 조회를 병렬 수행. bounded metric/chart와 eager 배치, child Query 유지. 대량 데이터 처리·새 누수 경로 없음. |
| Architecture | Wellness 전용 카드와 Foundation 비교 DTO, 기존 query protocol·navigation destination 사용. iOS presentation이며 Watch/Vision UI에 이 파일들이 포함되지 않음. |
| Data integrity | 표시 중인 최신 실측 값/날짜에 비교를 고정. 7일 전 달력일 이하 최신 유효 관측, 실제 이전 날짜, 결측/0/%p/미래값 구분. request guard와 metric/date 일치 방어 유지. 점수 가중치35/30/20/15는 기존 use case와 일치. |
| Simplicity | 사용하지 않는 히어로 입력6개 제거. 공유 VitalCard를 확대 수정하지 않고 feature 범위에 표현 한정. 나머지는 아래 명시적 P3 절충. |

Agent-Native는 `.claude/.codex` 지침·프롬프트 변경이 없어 제외했다. 새/변경 문자열24개 모두 en/ko/ja를 갖추고 `format-xcstrings --check`를 통과했다. View helper는 LocalizedStringKey, 모델/VM 문구는 localized String을 사용한다. 대문자 WELLNESS는 Today/Activity와 맞춘 의도된 브랜드 표기다.

## Specialists

- [SwiftUI](2026-10-28-wellness-flow/quality-swiftui.md): 최종 소스 delta의 P1/P2=0. Query 격리·상태·AX ID·기준선 문구·수면 범위 확인.
- [Apple UX](2026-10-28-wellness-flow/quality-apple.md): 실제 phone/iPad와 큰 글씨·두 열에서 수치/단위/날짜/행동 확인. 긴 문구 줄바꿈은 선택적 P3.
- [Astra 종합 검토](2026-10-28-wellness-flow/quality-astra.md): 손목 온도 의미 누락을 발견해 해결 후 소스·iPad 픽셀 재확인. phone/Ocean/Maximum AX와 Duo 세 viewport 이미지까지 확인, 현재 P1/P2=0, PASS WITH NOTES.
- perf-optimizer는 대량 처리 도입이 없어 별도 실행하지 않았다. 주 에이전트의 성능 관점 검토는 수행했다.

## Findings lifecycle

| ID | Priority | 최종 상태 | 발견사항 | 조치/근거 |
|---|---|---|---|---|
| W01 | P1 | 해결 | Independent records hidden without health summaries | 8085e875; records-only UI route passed |
| W02 | P1 | 해결 | Missing exact target day discarded earlier actual observations | 8085e875; latest at/before target calendar cutoff; unit and no-prior UI passed |
| W03 | P1 | 해결 | Manual body entry unavailable in records-only state | 8ce1b517; dedicated records-only UI passed |
| W04 | P1 | 해결 | Watch summary labeled Today regardless of actual date | 22ea46ae; actual date at source; nonempty Watch native remains unverified |
| W05 | P2 | 해결 | Body sparklines reversed | 8085e875; sorted chronological; unit test passed |
| W06 | P2 | 해결 | Latest posture update identity incomplete | 8085e875; task key includes ID/score/front/side payload |
| W07 | P2 | 해결 | Unmeasurable posture rendered a numeric score | 8085e875; explicit unable-to-measure branches and measured metric count |
| W08 | P2 | 해결 | Watch metrics fixed horizontally at accessibility sizes | 22ea46ae; accessibility VStack; nonempty native not claimed |
| W09 | P2 | 해결 | Forecast score lacked an explicit prediction label | 22ea46ae; Predicted score label and independent detail route |
| W10 | P3 | 해결 | Hero VoiceOver value omitted narrative/date | 8085e875; accessibilityValue includes narrative and evaluation date |
| W11 | P2 | 해결 | Non-Desert ring used the fixed warm palette | b1dbdfda; AppTheme accent/dusk/track; native Ocean passed and Astra inspected |
| R01 | P2 | 해결 | Wrist temperature baseline context missing | 6c1d3f77; localized explicit context; iPad semantic UI and Astra pixels verified; phone final health passed |
| R02 | P3 | 해결 | Unused hero inputs | 6c1d3f77; remove unused properties/call arguments; subsequent UI compiled |
| R03 | P3 | 해결 | Sleep bars saturated above ten hours | 6c1d3f77; scale includes actual sample maximum, retains finite/date filtering |
| R04 | P3 | 해결 | Maximum AX posture heading split a word | b1dbdfda; title-only at accessibility size; fresh AX PNG inspected |
| N01 | P3 | 유지(선택적) | Compact injury memo preview | Accepted existing compact preview; full memo accessible by opening the record; no data loss |
| N02 | P3 | 유지(선택적) | Wide sleep capsules resemble circles | Accepted compact chart styling for this iteration; actual duration/date and corrected scale preserved |
| N03 | P3 | 유지(선택적) | Long labels/dates wrap in nested wide tiles | Accepted two-group density; actual iPad complete tile frames and values are readable; optional typography refinement |

## Validation

- 최종 표준 iOS 빌드: `scripts/build-ios.sh --no-regen` 성공 (실제 최종 로그: `.codex-checks/wellness/ios-final-build.log`).
- 단위19개·2개 suite 통과. `8ce1b517` 이후 ViewModel/비교 DTO/두 단위 테스트 파일이 변경되지 않았음을 `git diff --exit-code`로 확인해 실제 결과를 재사용했다. 이후 View·UI 테스트·번역은 최신 UI 실행에서 다시 컴파일됐다. 오래된 자동 receipt를 새 실행으로 갱신하지 않았다.
- 최종 선택 기기별 testcase57개 통과: phone47, iPad6, Duo 외부2/내부2. class/method별 최종 로그를 기기별로 집계했다. 동일 사례 재실행을 중복 성공 수로 합산하지 않았다. [실행 receipt와 집계](../design/full-redesign-map/review/wellness-flow-2026-10-28/proof/verification.json)를 보존한다.
- 원 phone batch46개는41개 통과/5개 실패. Wellness 세 실패는 스크롤 방향·44pt 부동소수점 오차·변경 전 prediction 식별자를 실제 계층/소스에 맞춰 보정하고 해당 사례만 통과 확인했다. 초기 AX probe 실패의 수정 후1/1 통과와 후속 세 보정3/3을 따로 보존한다.
- Dashboard 알림2개는 `dashboard-morning-briefing-screen`/한국어 ‘좋은 아침’ 오버레이가 남은 실제 실패다. 관련 Today/Notification 소스와 기본 seed 동작은 이번 diff에서 바뀌지 않았다. 범위 밖으로 분리했고 성공으로 계산하지 않았다. main에서 재현한 baseline 실패라고 주장하지 않는다.
- 자동 UI 판정은 공용 리소스/seed/project 경로 때문에 full을 제안한다. 사용자 full 요청이 없어 adapter에 따라 영향 사례와 공통 smoke만 선택했고 full/전체 Watch 회귀는 미실행이다.
- 신규 실제 갤러리66장: phone27/iPad19/Duo외부10/내부10. 원본 SHA256·테스트/앱 소스·UDID·시각·viewport·selector와 host/xcresult 구분을 manifest에 기록했다. 다른 UDID의 과거 H01 PNG를 덮지 않았다. 각 이미지의 이전 소스를 현재 촬영이라고 바꾸지 않았으며, 변경된 손목 기준선 설명은 final health-detail로 교체했다.
- Duo 외부466×678/내부951×669pt. 활성LCD/LCD-1, 전후 display rotation, 실제 AX×scale와 native PNG, ACK와 testcase 결과를 대조했다. 펼침 canonical nativeSize2007×2853과 실제 회전 PNG2853×2007을 구분했다. 현재 CLI에는 힌지각 조회가 없어 actualAngle=null/angleVerified=false를 보존했다. 시스템 multiview chrome은 앱 변경으로 판단하지 않았다.

## Limits and scope

실제 HealthKit 권한·Watch 연결/비어 있지 않은 Watch 행·VoiceOver 순회·한/일 런타임·모든 테마의 모든 상태·수치 대비비·Duo 물리 접힘각/전환은 이 선택 실행의 통과 범위가 아니다. native PNG는 viewport 표본이며 전체 offscreen 상태를 통과시킨 것이 아니다. UI 실행은 전용 registry 기기와 표준 runner/deadline에서 한 번에 하나씩 수행했다. task-local Duo helper ROOT_DIR 누락은 테스트 시작 전1회 실패 후 원인을 고쳐1회 재시도했고, 각도 조회 부재나 화면 잠금만으로 실행 불가라고 처리하지 않았다.

## Map and ship gate

현재 H01 레이아웃·통합 actual 포털·theme study의 실제/시안 구분을 함께 갱신했다. 원본 브라우저 시안과 Compact 대안은 보존했다. 최종 문서 변경 후 앱/단위 소스 동일성을 다시 확인한다. 로컬 primary main의 기존 문자열 수정은 이 작업의 산출물에 포함하거나 reset/stash하지 않는다.

최종 지도/갤러리 문서 delta는 이미지66개 해시, host proof의 패널·회전·AX/PNG 크기 일치, 로컬 링크와 테마 builder 동기화로 재검토했다. 앱 소스는 `6c1d3f77`과 동일하며 이 문서 갱신 때문에 앱 검증을 반복하지 않았다.

[최종 PR 게이트](2026-10-28-wellness-flow/pr-review.md)는 앱/테스트 소스의 동일성과66개 이미지·11개 복사 receipt 해시를 독립 확인했고 P1/P2 차단 사항이 없음을 기록했다. 이후 이 게이트 문서만 추가했다.
