---
tags: [detail-redesign, t17, health-tools]
date: 2026-11-06
category: plan
status: approved
---

# T17 · 건강 Q&A

[공통 구현·검증 계획](2026-11-06-detail-redesign-health-tools-batch02.md)의 해당 화면 범위를 수행한다. [배치 계약](../design/layout-map/today-health-qa-t17.html)과 [테마 시안](../design/theme-map/themes/dune-today-health-qa-t17.html)을 먼저 맞춘다.

영향 App은 `DUNE/Presentation/Dashboard/HealthDataQASheet.swift`이며 T17은 `DUNE/App/ContentView.swift`의 DEBUG UI fixture도 포함한다. 기존 동작·데이터·아이콘·문구·상태·닫기/저장 의미를 보존한다. 구현·리뷰·해결 문서·actual map은 화면별 PR로 분리한다.

정상 네 프로필 selector: `DUNEUITests/DesignMapAdditionalRoutesTests/testHealthDataQAOpensFromToday`. 접힌 Duo MAX 추가 selector: `DUNEUITests/DesignMapAdditionalRoutesTests/testHealthDataQAAtMaximumAccessibilitySize`. 실행·native 결과와 실패 기록은 통합 후보의 실제 source closure와 연결하고 해당 PR HEAD에서 새로 실행했다고 바꾸어 적지 않는다.

위험: sheet/inspector 좁은 폭, MAX 본문·아이콘 자연 높이, List 가상화, 실제 seed, 키보드와 내비게이션. 원인별 기록과 점유 예산을 유지하고 필요한 경로만 검증한다. 아직 앱 빌드·UI 실행·새 실제 캡처·PR 완료 증거는 없다.

## 실제 캡처에서 발견한 표현 수정

지원 불가 badge에서 sparkles.slash가 표시되지 않아 원래 의미를 유지하는 sparkles·nosign 시스템 심벌을 합성한다. 같은 계획된 UI 메서드에서 UIKit UIImage 리소스 해상도 단위 assertion도 수행한다. Fallback answer는 secondary 텍스트색으로 대비를 높인다. 서비스·문구·흐름은 그대로이며 T17 정상 검사와 fresh PNG/AX를 갱신한다.
