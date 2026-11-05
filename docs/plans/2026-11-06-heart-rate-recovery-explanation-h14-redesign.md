---
tags: [detail-redesign, h14, health-tools]
date: 2026-11-06
category: plan
status: approved
---

# H14 · 심박 회복 설명

[공통 구현·검증 계획](2026-11-06-detail-redesign-health-tools-batch02.md)의 해당 화면 범위를 수행한다. [배치 계약](../design/layout-map/heart-rate-recovery-explanation-h14.html)과 [테마 시안](../design/theme-map/themes/dune-heart-rate-recovery-explanation-h14.html)을 먼저 맞춘다.

영향 App은 `DUNE/Presentation/Shared/Extensions/HeartRateRecovery+View.swift`이며 T17은 `DUNE/App/ContentView.swift`의 DEBUG UI fixture도 포함한다. 기존 동작·데이터·아이콘·문구·상태·닫기/저장 의미를 보존한다. 구현·리뷰·해결 문서·actual map은 화면별 PR로 분리한다.

정상 네 프로필 selector: `DUNEUITests/ActivityExerciseRegressionTests/testVisualAuditHeartRateRecoveryExplanation`. 접힌 Duo MAX 추가 selector: `DUNEUITests/ActivityExerciseRegressionTests/testHeartRateRecoveryExplanationAtMaximumAccessibilitySize`. 실행·native 결과와 실패 기록은 통합 후보의 실제 source closure와 연결하고 해당 PR HEAD에서 새로 실행했다고 바꾸어 적지 않는다.

위험: sheet/inspector 좁은 폭, MAX 본문·아이콘 자연 높이, List 가상화, 실제 seed, 키보드와 내비게이션. 원인별 기록과 점유 예산을 유지하고 필요한 경로만 검증한다. 아직 앱 빌드·UI 실행·새 실제 캡처·PR 완료 증거는 없다.

## 실제 캡처의 최소 터치 영역 보정

원래 44pt 프레임이 초기 medium 시트의 시스템 축소에서 실제 42.4pt로 관측됐다. 소스 프레임을 48pt로 조정하고 초기 정상 viewport에서 실제 AX 폭·높이 44pt 이상을 확인한다. 이 변경 뒤 H14 정상 검사와 fresh PNG/AX가 다시 필요하며 이전 H14 native 결과를 완료로 재사용하지 않는다.
