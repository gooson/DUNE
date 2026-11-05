---
tags: [detail-redesign, health-tools, targeted-ui, validation-reuse]
date: 2026-11-06
category: plan
status: approved
confidence: medium
---

# H14·T17·T18 건강 도구 묶음 구현과 검증

## 범위와 선행 근거

사용자가 관련 화면을 묶어 구현·검증하고 화면별 PR을 유지하도록 승인했다. Batch01 머지 main을 기준으로 private 패치의 원본 SHA를 다시 비교한 후 적용한다. 별도 검증 원본을 보존하며 통합 실행을 각 PR HEAD 실행으로 바꾸어 적지 않는다.

기존 HeartRateRecoveryRow의 두 소비자(ExerciseSessionDetailView, HealthKitWorkoutDetailView), ContentView의 dashboardInspector, DashboardView의 PinnedMetricsEditor sheet를 조사했다. 관련 해결책은 HRR₁ 설명/범위(2026-03-12), Today 고정 지표 터치 영역과 실제 seed2개(2026-10-26), Batch01의 intrinsic SF symbol 높이·MAX 본문 양끝 검증을 참조한다. 기존 완료 todo 030·105·062와 건강 데이터 Q&A/SwiftData 관련 brainstorm은 동작 배경이며 새 구현 완료 증거가 아니다.

## 화면별 변경

- H14: 기존 설명·측정 문단과 Good/Normal/Low 범위·색 점·SF Symbol·detent를 보존한다. 히어로·아이콘·Close를 강조하고 MAX에서 제목을 독립된 전체 폭 행으로 배치한다.
- T17: 기존 ViewModel·서비스·기기 지원 조건·프롬프트 순서·Send·Browse·Done·reset을 보존한다. 히어로·추천 질문·사용 불가 안내를 강조하며 메시지가 생기면 히어로도 메시지 스크롤 안에서 움직이게 한다. DEBUG와 --uitesting 및 전용 fixture 인자가 모두 있는 실행에만 고정 응답 서비스를 주입해 두 실제 UI 분기를 확인한다. 실제 기기 지원·AI 응답 검증으로 표현하지 않는다.
- T18: 기존 List·아이콘·선택 순서·6개 제한·Cancel 폐기·Done 저장을 보존한다. 선택된 항목만 장식으로 표시한 히어로와 intrinsic 높이의 아이콘 배지를 쓴다. 초기 UI seed는 HRV/RHR 2개이며 운영 fallback3개로 가정하지 않는다.

## 영향 파일과 분리

| 화면 | App | UI |
|---|---|---|
| H14 | Presentation/Shared/Extensions/HeartRateRecovery+View.swift | ActivityExerciseRegressionTests |
| T17 | Presentation/Dashboard/HealthDataQASheet.swift, App/ContentView.swift의 테스트 전용 생성 경로 | DesignMapAdditionalRoutesTests |
| T18 | Presentation/Dashboard/Components/PinnedMetricsEditorView.swift | TodaySettingsRegressionTests |

각 화면의 layout/theme 맵과 manifest/README/index를 앱보다 먼저 맞추고, fresh 실제 PNG/AX와 actual-map 해당 행만 갱신한다. 원본 .claude 설정·공통 runner·Domain/HealthKit 계산·저장 스키마는 수정하지 않는다. 화면별 구현/리뷰/Compound/PR 커밋을 분리하고 마지막 PR에 실제 통합 검증 커밋 ancestry를 보존한다.

## 핵심 검증 계약

private UI CONTRACT의 정확한 여섯 메서드를 최종 SHA와 함께 실행 전에 고정한다. 일반 iPhone/iPad/Duo 접힘/펼침 각각 정상 3메서드, 접힌 Duo에서 MAX 3메서드를 추가해 15개 메서드·프로필 조합을 확인한다. T17의 지원/미지원 화면은 별도 상태이며 각각 확인한다. 한 상태 성공을 다른 상태에 대입하지 않는다.

H14는 전체 원본 문단의 읽을 수 있는 양끝·3개 범위·Close와 운동 상세 복귀, T17은 고정 서비스의 prompt/send/disabled draft/fallback·두 Browse 경로·Done·MAX composer, T18은 초기2개/6개 제한/선택 해제 가능/Cancel 폐기/Done 지속과 MAX 선택 preview·footer를 확인한다. 모든 목록 행은 현재 viewport에 드러낸 뒤 상태를 확인해 가상화된 요소를 오판하지 않는다.

한 번에 소유 시뮬레이터 1개와 runner 1개만 쓴다. 표준 pipeline+test-ui, jobs2, index OFF, 병렬테스트 OFF, targeted 1200초, case 기본300초를 적용한다. 예상 합계가 초과하면 실행 전 normal/MAX를 같은 소유 기기에서 나누고 빌드 캐시를 재사용한다. 전체 unit/full UI 회귀를 추가하지 않는다. 실제 변경 분기와 필요 UI만 검사하고 같은 컴파일을 phase마다 반복하지 않는다. 문자열 카탈로그는 빌드 전후 표준 포맷/수동 추출 검사를 한다.

## 리뷰·실패·완료 기준

공통 코드·fixtures·호출부와 각 화면을 독립 관점으로 검토한다. 과거 실패와 시도 횟수는 보존하며 원인 수정 근거가 있는 최소 검사만 재실행한다. live PNG/AX의 겹침·잘림·아이콘·MAX·복귀가 확인되어야 native 완료다. 시안·모의 응답·SDK·시각 검토·GitHub CI·머지를 구분한다. Dark·VoiceOver·물리 기기·실제 Foundation Models·전체 회귀를 실행하지 않았다면 그 범위를 완료로 표현하지 않는다.

H14/T17/T18 각각 source closure와 새 실제 캡처, 리뷰의 미해결 P1/P2 없음, 해결 문서, 화면별 PR 정상 머지가 완료 기준이다. 머지 수만 남은 원래 화면 수에서 뺀다. 검증 원본과 기록은 보존하고 재사용할 캐시는 유지하며 완료된 소유 리소스만 정리한다.

## 통합 검증 결과

기본 15개 메서드·프로필과 T18 한국어 iPad 1개를 실제 SDK와 새 PNG/AX로 확인했다. 초기 실패와 수정 후 재시도는 별도 원본으로 보존했다. 화면별 PR과 실제 맵 발행은 각각 분리하며 마지막 T18 PR에서 검증 통합 소스의 ancestry를 보존한다. 통합 실행을 각 최종 PR HEAD 실행으로 바꾸어 표기하지 않는다.

## 화면별 발행 상태

H14는 PR #929에서 정상 머지했다. T17의 PR #930과 T18은 통합 SDK 결과의 출처를 그대로 유지하며 화면별로 발행한다. T18 브랜치는 검증 통합 커밋 `1ae4fb4c333c0bd8890e91c3fac9d9c355511f3e`를 조상으로 보존하고, 먼저 발행한 H14·T17 실제 맵과 문서를 병합했다. GitHub CI와 최종 머지 결과는 각 PR의 실제 상태로 판단한다.
