---
tags: [activity, flow, swiftui, accessibility, localization, native-capture]
date: 2026-10-27
category: review
status: reviewed
---

# Activity 최종 Flow 리뷰

기준: `origin/main fefd3581` → `codex/activity-final-flow 0bdc1860`. 최신 main의 Today 일일 요약 개선을 통합했다. [실제 화면 한판](../design/full-redesign-map/review/activity-flow-2026-10-27/overview.png) · [81개 원본과 출처](../design/full-redesign-map/review/activity-flow-2026-10-27/index.html) · [구현 계획](../plans/2026-10-27-activity-final-flow-implementation.md).

## Summary

| 열린 항목 | P1 | P2 | P3 |
|---|---:|---:|---:|
| 최종 소스 재확인 | 0 | 0 | 0 |

비이미지 diff 29,594줄이므로 `/review`의 2,000줄 이상 예외에 따라 주 에이전트가 폴더별 5관점을 직접 검토했다. 별도로 SwiftUI·Apple UX·app-quality-gate 에이전트가 실제 실행됐으며 수정 후 delta와 새 PR 수치 PNG까지 확인했다. UI 테스트 작성은 ui-test-expert가 수행했다. 최종 PR 리뷰는 별도 read-only reviewer가 기존 findings와 이후 변경을 확인한다.

## 관점별 결과

| 관점 | 확인한 경계와 결과 |
|---|---|
| Security | 새 네트워크·인증·저장·건강정보 로깅 없음. 평균 심박은 finite 및20…300 범위 확인 뒤 Int 변환. 디자인 자료는 seeded 데이터. 열린 문제 없음. |
| Performance | 최근 목록2+3개, reward history 공급 범위 내 ID 매칭, 정적 배지 gradient 재사용. buildContent는 body당 한 번 계산. 새 대량 처리·쿼리 없음. |
| Architecture | 기존 CardNavigationHeader·typed destination 유지. 새 NavigationStack·HealthKit 쿼리·스키마 없음. ActivityMetricsLayout는 반복된6개 적응형 배치의 공통 수정. |
| Data integrity | 보상을 날짜/종목이 아닌 raw/manual-/연결 HealthKit ID로 매칭. 집계 서비스 변경 없음. 구성 분모는 운동 기록 항목, 근육 비율은 완료 세트. 최근 운동일 합계와28일 effort/HR load 구분. 누락 수면/준비도/회복을 가짜0·안전으로 표시하지 않음. |
| Simplicity | 기존 뷰/팔레트/서비스 재사용, 루트 읽기 순서만 추출. 지도3D 루트 바로가기만 제거하고 외부 목적지는 유지. 불필요한 router/persistence 없음. |
| Agent-Native | `.claude/**`, `.codex/**` 변경이 없어 해당 없음. |

공유 소비자도 확인했다. CompactConditionRing의 기본 AXID는 Today 계약을 유지한다. UnifiedWorkoutRow의 `.full` 소비자는 ExerciseView이며 유효 심박·접근성 설명을 공통 사용하고 골드 배지는 compact에 적용한다. Presentation 변경은 iOS 대상이다. Watch는 별도 카탈로그, visionOS/Widget은 공유 문자열 리소스만 소비한다. 해당 전용 화면 변경이나 런타임 통과를 주장하지 않는다.

## 해결된 findings

| 우선순위 | 문제 | 최종 해결과 증거 |
|---|---|---|
| P1 | ViewThatFits 안 조건부 EmptyView가 접근성 크기의6개 지표 그룹을 숨김 | AX 분기를 밖으로 옮긴 ActivityMetricsLayout. 최대 글씨 기능 검사에서 보고서/시간/칼로리/구성 실제 양수 프레임과 도달성 확인. |
| P2 | 준비도 누락 원인 단정 | 사용할 수 없는 준비도는 중립 안내로 표시. |
| P2 | 운동 구성을 세션 수로 설명 | 기록 항목 분모로 코드·번역·맵 정정. ExerciseMixService 원천 집계 유지. |
| P2 | Wellness 빈 상태 제목 누락 | 빈 카드에도 WELLNESS 표시. |
| P2 | Life 제목과 설명의 AX 수평 충돌 | AX에서 세로 배치. |
| P2 | 모든 부위가 noData인데 회복됨으로 표시 | 관측 상태만 필터링, 수면 finite·positive 조건. |
| P2 | DisclosureGroup 상위 AXID가 추세 그래프 ID를 덮음 |44pt Button과 조건부 형제 trend. 저장 이력·부족 이력 관련2개 통과. |
| P2 | 두 열 개인 기록 카드의 숫자 잘림 | 숫자 전체 폭, 단위/48pt sparkline 별도 줄·최소44pt target. 새 iPad8개 값과 iPhone 최대 글씨 값 확인. |
| P3 | 달성 미리보기 개수 불일치 | 최근3개로 계약 일치, 긴 텍스트 자연 줄바꿈. |

기존 PR 내부 sparkline NavigationLink 및 지도 캐시 count 관찰 방식은 이번에 도입한 코드가 아니므로 별도 구조 개편으로 넓히지 않았다. 마지막 앱 수정은 `a0e8cbbc`; 이후는 UI 검사·문서와 main 통합이다.

## Localization

변경/추가33개 카탈로그 항목 모두 en/ko/ja를 확인했다. helper 제목은 LocalizedStringKey, 모델/보상 문자열은 기존 localized displayName, 동적 숫자는 formatter를 사용한다. CONDITION/READINESS/WELLNESS/HABITS는 사용자가 요청한 브랜드 고정 영어이며 설명은 번역한다. Shared와 Watch catalog formatter 검사를 수행한다. 실시간 locale 전환·모든 언어 화면을 자동 검증한 것은 아니다.

## 실행 증거와 제한

| 실행 | 실제 결과 | 해석 |
|---|---|---|
| 최초 iPhone 선택 UI |43개 중38통과·5실패 | 준비도 이력2개는 수정 후 통과. 알림함2개·기존 Today 차트 selector1개 실패 보존. |
| 사용자 허용 복구 실행 |7/7통과 | 순서·기본/다크/최대 글씨 수집·네 제목·준비도 이력2개. |
| iPad |6/6통과, 수치 수정 뒤 최종1/1통과 | 실제 PNG에서8개 기록값이 모두 보임. |
| 최종 iPhone 기본/다크 사진 수집 |각1개 통과 | 실제 원본 보존. |
| 최대 글씨 전체 사진 수집 |실패 exit65 |19개 PNG와 본문 검사 뒤300초 teardown 제한 초과. 이미지에도 실패 상태를 명시. 통과 수에 포함하지 않음. |
| 최대 글씨 개인 기록 기능 검사 |1/1통과74.678초 | 숫자 프레임 전체가 가용 viewport 안에 들어옴. |
| 최대 글씨 지표 기능 검사 |1/1통과136.958초 | 보고서 볼륨·시간·칼로리·근력/유산소 비율이 도달 가능하고 실제 크기 존재. |
| Duo 외부/내부 |각1/1통과245.985/238.111초 | Flow·네 제목·104/104/135/135pt AX 링 크기. 활성 패널 readback·새 AX·양쪽 PNG. |
| 관련 단위 |8/8,2개 suite 통과 | ID 매칭·유효 심박·운동 구성. |
| iOS 표준 빌드 |통과 | 최종 소스/문서 동결 뒤 최신 main 통합 상태 빌드와 관련 검사를 다시 실행할 예정이며 자동 receipt는 별도로 남긴다. |

알림함 실패 관련 DashboardSmokeTests/NotificationHubView/DashboardView/ContentView는 최초 기준 main에서 변경하지 않았다. Today 히어로 변경은 제목 스타일/AXID이며 기존 차트 selector를 만들지 않는다. 이 소스 대조는 실패의 런타임 baseline 증명이 아니며, 해당3개와 전체 smoke/full을 통과 처리하지 않는다. 별도 범위의 결함을 이 변경으로 확대 수정하지 않았다.

최초 수정 후 AX 응답 지연 실행은 중단됐다. 재시도 제한을 사용자에게 설명했고 “안쓰는거 다 정리하고 해”라는 명시적 허용 뒤 소유 잔여 실행기/819MiB 재생성 캐시/유휴 기기를 정리했다. 실패 로그와 시도 메타데이터를 보존했다. 이름만 바꾼 무제한 재시도를 하지 않는다. 선택적 사진 수집의600초 예산 선언은 재실행 통과의 증거가 아니다.

## 실제 화면맵과 main 통합

A01과 제목 변경 T03/H01/L01의 새 원본81개, 기기·커밋·체크포인트·시각·해시를 보존했다. 한판 PNG는8개 원본의 축소 비교보드이고 원본을 대체하지 않는다. T03 캡처는 제목/회복 범위이며 main의 새 DailyDigest 본문은 화면 밖이다. 기존 PNG를 새 DailyDigest의 증거로 표시하지 않는다. [main의 일일 요약 실제 맵](../design/full-redesign-map/review/daily-summary-reading-2026-10-27/index.html)을 별도로 유지한다. seeded 보고서의5,400분은 기존 ActivityViewModel fixture 값이며 실제 생성기의 durationMinutes 집계를 변환한 수치가 아니다.

Duo viewport는 외부466×678pt·내부951×669pt. 공개 테스트 helper의 setter 뒤 공식 displays에서 활성 LCD/LCD-1을 확인했다. 실제 힌지 조회는 불가하므로 actualAngle=null/angleVerified=false. 물리 각도·회전·입력 연속성·모든 window 상태를 통과했다고 주장하지 않는다.

## Verification guide

Activity에서 준비도 세 막대와 이력 펼침, 근육 회복/세트 범례, 최근2개와 이전 기록, 작은 Apple/심박/실제 달성 배지를 확인한다. 개인 기록 헤더 오른쪽 끝으로 상세에 진입하고 숫자가 잘리지 않는지 확인한다. 하단에서 보고서 볼륨·월 목표·최근 운동일 시간/칼로리·28일 부하·운동 구성 분모를 비교한다. 최대 글씨는 한 열, iPad/Duo 넓은 폭은 관련 카드 묶음으로 표시한다.

전체 UI·모든 테마/언어·실기기 HealthKit 권한/실시간 동기화·Watch/visionOS 런타임은 이번 검증 범위가 아니다. 최종 frozen 상태의 표준 실행 receipt와 PR URL은 PR 본문 및 `/run` 최종 결과에서 제공한다.
