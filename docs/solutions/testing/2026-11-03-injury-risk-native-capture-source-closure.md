---
tags: [swiftui, injury-risk, accessibility, native-capture, source-closure]
category: testing
date: 2026-11-03
status: implemented
severity: important
related_files:
  - DUNE/Presentation/Activity/InjuryRiskDetail/InjuryRiskDetailView.swift
  - DUNEUITests/Full/ActivityExerciseRegressionTests.swift
related_solutions:
  - docs/solutions/architecture/2026-02-20-injury-tracking-review-fixes.md
---

# Solution: 부상 위험 상세의 실제 근거와 기존 캡처 범위 유지

## Problem

기존 상세의 점수, 위험 단계와 기여 요인이 같은 계층에 놓여 핵심 상태를 빠르게 읽기 어려웠다. 개편 중 원래 요인별 아이콘과 기여 막대의 의미를 보존해야 했다. 과거 성공한 iPad 캡처를 최신 버전에서 다시 실행한 결과로 표현하면 실제 검증 범위도 달라진다.

## Solution

`InjuryRiskDetailView`에 제공된 assessment를 그대로 표시하는 전용 불투명 히어로를 적용했다. 실제 단계의 색과 원래 아이콘을 유지하고 점수·단계·안내의 위계를 구분했다. 로컬 링은 단색 arc와 Reduce Motion을 지원하며 다른 점수 화면의 공통 링은 변경하지 않는다. 큰 글씨에서는 점수와 상태, 요인과 기여 수치를 세로로 배치한다.

모든 요인의 원래 순서·아이콘·설명·기여 수치와 권장 행동을 보존한다. 막대는 가장 큰 기여 요인과의 상대 비교이며 점수 비율이나 부상 확률이 아니다. 실제 점수 0에 요인이 없는 상태와 assessment 자체가 없는 상태를 구분한다. 계산식, 모델의 단계 경계, Activity의 데이터 입력과 navigation 소유권은 변경하지 않았다. 실제 입력이 없는 자세 요인을 추가하지 않는다.

현재 CA888 소스에서 iPhone, Duo 접힘·펼침의 같은 직접 경로 검사를 각 1개씩 실행해 3개가 통과했다. 상세 42점, 보통 단계와 +24/+18은 기존 DEBUG route fixture의 값이며 생산 데이터나 의학적 확률이 아니다. Back과 Weekly Report 경로는 같은 통과 selector가 확인한다. Duo의 자세는 실제 각도와 활성 화면, PNG·AX checkpoint를 함께 확인하며 실사용 중 접힘 연속성 검사로 확대하지 않는다. 두 소유 기기는 순서대로 사용하고 증거 보존 뒤 삭제했다.

과거 A20 iPad 일반·dark MAX 2/2는 clean `74a17b94`에서 실행한 기록 그대로 유지한다. 36개 Git object 비교, 다섯 관련 method digest, 20개 표시 문자열 lookup, 여덟 PNG/AX 해시와 실제 캡처의 동일성을 독립 검토했다. 렌더링 관련 입력에 변화가 없다는 범위에서만 재사용하며, 현재 CA888 iPad 실행은 0회다. 변경된 앱 진입·알림 코드 전체가 동일하다고 주장하지 않는다. 최대 글씨의 마지막 권장 행동은 과거 iPad 검사에서 확인했고, 새 좁은 Duo 화면은 보이는 영역과 스크롤 아래 내용을 구분해 기록했다.

[실제 전후 화면과 출처](../../design/full-redesign-map/review/a08-injury-risk-native-2026-11-03/index.html)에 4개 A08 행과 Activity 보드만 반영한다. 검증된 원본 A20 936의 PNG와 AX를 원래 selector·action·device·checkpoint에 연결하며 기존 iPad map-before도 별도로 보존한다. 다른 과거 맵 이미지의 정확한 모델·실행 버전·AX·Duo 자세는 미확인으로 표시한다. 다른 화면·이전 갤러리·Watch는 해시로 보존한다.

## CI와 검증 한계

현재 iOS 빌드와 Watch 단위 CI는 성공했다. iOS 단위 CI 전체는 실제 live AI 평가 두 테스트의 9 assertion 실패로 종료했고 원인은 확정하지 않았다. 같은 실행의 CalculateInjuryRiskUseCase suite는 통과했다. AI 테스트·dataset·서비스·카탈로그·프로젝트 입력은 main573과 동일하고 A08 View에서 새 AI 호출 경로는 없다. 이전 AEDF 실행에서는 두 live AI 평가가 건너뛰어졌으므로 과거 통과로 표현하지 않는다. [실제 CI 실패](https://github.com/gooson/DUNE/actions/runs/41534538396/job/125582924124)를 별도 조사로 기록하고, CI 전체 통과 또는 실패 해결을 주장하지 않는다. 원인 근거 없는 전체 CI 재실행과 무관한 코드 수정은 하지 않았다.

## Prevention

- 실제 점수와 그 요인, 가장 큰 요인과 비교한 상대 막대를 확률로 설명하지 않는다.
- 모든 source factor와 권장 행동, 기존 아이콘과 nil/zero 분기를 유지한다.
- 과거 성공은 원래 리비전과 실행 수를 보존하고 실제로 바뀌지 않은 렌더링 입력만 근거로 재사용한다.
- 공개 PNG와 AX를 정확한 raw manifest 파일·selector·기기·checkpoint에 연결한다. 자체 해시만 맞는 다른 화면을 통과시키지 않는다.
- Duo 각도와 두 display의 활성 상태를 전후 원본 readback 및 해당 실행의 소유 UDID와 대조한다.
- 품질 보고서의 최종 판정과 발견 수를 읽고, 본문의 과거 PASS를 최종 승인으로 오인하지 않는다.

새 `.claude` 규칙은 추가하지 않았으며 원본 설정을 유지한다. View 변경은 필요한 UI selector로 확인하고, 변경하지 않은 계산 코드에 로컬 전체 테스트를 반복하지 않았다.

## Lessons Learned

같은 화면의 과거 렌더링 근거와 현재 진입·복귀 실행은 함께 사용할 수 있지만 서로 다른 주장이다. 실제 native 긍정 결과는 현재 소스 3개와 과거 iPad 2개로 구분한다. 모든 위험 단계, nil/zero 분기와 모든 factor 조합을 실제 기기에서 확인했다는 주장은 하지 않는다. 소스의 기존 분기 보존과 전체 동작 검증을 혼동하지 않는다.
