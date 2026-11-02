---
tags: [swiftui, weekly-report, accessibility, native-capture, duration-minutes, muscle-volume]
category: solution
date: 2026-11-03
status: implemented
severity: minor
related_files:
  - DUNE/Presentation/Activity/WorkoutReportDetail/WorkoutReportDetailView.swift
  - DUNEUITests/Full/ActivityExerciseRegressionTests.swift
related_solutions:
  - docs/solutions/general/2026-03-22-weekly-report-healthkit-data-gap.md
---

# Solution: 주간 운동 리포트의 값과 단위를 유지한 적응형 상세 화면

> 대상 앱·검사 소스는 `0d789a1ea11e777f663f52aad44a760684e27acc`, 기준 main은 `97ff66f2d1df59e1a88a6284504ba95b3a1609c7`이다. 구현·핵심 네이티브 검증·실제 비교 맵 반영을 완료했다. GitHub 머지는 별도 Ship 단계에서 확인한다.

## Problem

### Symptoms

기존 주간 리포트는 고정 열과 좁은 근육 행 때문에 큰 글자와 좁은 화면에서 값·요약·하이라이트의 가독성을 확인하기 어려웠다. 화면 개편에서는 실제 리포트의 조건부 항목과 단위, 원래 뒤로 가기 경로를 유지하면서 여러 기기의 실제 표시를 증명해야 했다.

### Root Cause

화면은 보고서가 제공하는 값으로만 구성되며 별도의 기간 선택기나 리포트 재계산 기능이 없다. 시각적 정렬을 위해 모델 의미를 바꾸거나 테스트 fixture의 숫자를 추측해 환산하면 기존 데이터 계약과 달라진다. 특히 `totalDuration`은 분 단위 합계이고 DEBUG fixture는 `5_400`을 직접 제공한다. 기존 화면과 변경 화면의 표시는 `5400 min`이며 90분으로 변환할 근거가 없다.

## Solution

### Changes Made

| File | Change | Reason |
|---|---|---|
| `WorkoutReportDetailView.swift` | 불투명 hero, 적응형 통계, 요약·하이라이트와 실제 최댓값 기준 상대 근육 막대를 구성한다. 총 볼륨과 시간 glyph에 각각 `scalemass`, `timer`를 사용하고 근육 행의 기존 `stat.muscleGroup.iconName`을 앞에 배치한다. | 원래 데이터와 조건을 유지하며 화면 크기와 글자 크기에 맞춘다. |
| `ActivityExerciseRegressionTests.swift` | 기존 A08 위험 경로와 뒤로 가기를 유지하고 A09 fixture 값, 내용, 최대 접근성 크기와 실제 뒤로 가기를 검증한다. | 두 경로의 공유 테스트와 실제 화면 계약을 함께 보호한다. |

리포트 모델·formatter·use case·Activity ViewModel의 계산은 변경하지 않는다. 기간과 날짜는 제공된 보고서를 따르고, nil 및 빈 요약·하이라이트·근육 데이터의 기존 분기를 유지한다. 상대 막대는 실제 근육 값의 최댓값과 0 방어를 사용하며 임의의 백분율을 생성하지 않는다. 새 기간 제어 또는 AI 호출을 추가하지 않는다.

### 검증 및 출처

| 범위 | 현재 근거 |
|---|---|
| 소스 | 다섯 소스 리뷰에서 P1/P2/P3 발견 없음. 이 결과는 런타임 품질을 대신하지 않는다. |
| iPad mini A20, `0d789a1e` | 일반 + dark 최대 접근성 글자 2/2 통과. 일반 hero/하단과 MAX 5개 상태의 PNG와 AX를 대조한 최종 품질 검토가 있다. |
| Phone, `0d789a1e` | 일반 경로 1/1 통과. hero와 하단 캡처 및 AX가 대응한다. |
| Duo Closed, `0d789a1e` | 일반 경로 1/1 통과, 9/9 ACK, 전후 0°/LCD. 실제 host PNG와 manifest AX를 대조했다. |
| Duo Open, `0d789a1e` | 일반 경로 1/1 통과, 9/9 ACK, 전후 180°/LCD-1. 활성 host 이미지와 manifest AX를 대조했다. |
| 이전 화면 | clean `936b87b4` 원본 A20 report-link PNG와 AX는 동일 checkpoint 및 통과 selector에 묶인 별도 before다. 다른 세 맵의 개별 과거 기기·버전·AX·Duo 자세는 미확인이다. `58ac` iPad 2/2는 아이콘 변경 전 역사적 결과다. |
| CI | CI Build 성공. iOS unit job `125608087094`의 테스트 단계는 취소로 표시되며 결과 업로드 중이다. 전체 unit 통과를 주장하지 않는다. Watch job `125608087511`, run `41541957500`은 테스트 전 destination ID 누락으로 exit 64이며 실행 수는 미확인이다. 이 변경에는 Watch 코드와 runner 수정이 없다. 별도 전체 재실행을 하지 않았다. |

현재 소스의 다섯 케이스 5/5와 일반 hero 4쌍, 하단 4쌍, iPad MAX 5쌍 총 13개 PNG/AX에 대한 독립 네이티브 품질 검토는 PASS WITH NOTES, P1/P2/P3 0이다. 소유 기기 세 대는 모두 삭제되어 registry는 비어 있다. 갤러리는 298파일·126 PNG로 stage되었고 inventory SHA-256은 `49a20c82faeb0182f190374772c282920efaa0dc1ec7086a123bc8c05f06e04d`다. 갤러리 설치는 실제 exit 0으로 완료했다. 18개 소스와 19개 출력의 고정 값 및 네 A09 행·활동 보드만 반영하고 다른 행·Watch·기존 갤러리 보존을 설치기에서 확인했다.

## Prevention

### Checklist Addition

- [ ] 보고서 모델과 생산 집계의 단위를 확인하고 fixture 원문을 그 단위 그대로 표시한다.
- [ ] 실제 selector와 capture action, device, checkpoint UUID, timestamp, 원본 PNG 및 AX를 함께 대조한다.
- [ ] 기존 이미지의 기기·버전·AX가 확인되지 않으면 맵 before에 그 제한을 표시하고, 현재 after나 다른 기기 증거로 전용하지 않는다.
- [ ] Duo는 원본 양쪽 display/angle readback, 해당 기기 식별자, collector와 ACK 및 활성 화면을 검증한다. Xcode의 `modelName`이 `iPhone`이어도 원본 `iPhone19,4`와 `com.apple.iphone-duo-9`가 해당 Duo인지 함께 확인한다.
- [ ] 현재 소스의 성공 기록과 이전 소스의 기록을 따로 세고 최종 CI 및 설치 결과를 확인 후 기록한다.

### Rule Addition

일반화할 규칙의 필요성은 최종 검토 때 판단한다. 현재 `.claude` 또는 전역 규칙 변경을 제안하지 않는다.

## Lessons Learned

- `5400 min`은 테스트 fixture의 비현실성 여부와 무관하게 원래 분 단위 계약이다. UI 개편 중 조용한 단위 변환은 기능 변경이 된다.
- 같은 화면의 각 캡처는 실제 checkpoint/AX/device 결합으로 증명한다. 펼친 화면, live VoiceOver, 다른 기간이나 nil 상태는 별도 근거 없이 확장 해석하지 않는다.
- `58ac`의 이전 iPad 성공은 유용한 이력이지만 아이콘이 달라진 `0d`의 실행 결과가 아니다. 일시 실패 또는 미완료 CI의 원인과 결과도 실제 확인 전 추정하지 않는다.

## 실제 비교 자료

[네 기기 원본·개편 비교](../../design/full-redesign-map/review/a09-weekly-report-native-2026-11-03/index.html)에 출처와 범위를 함께 기록했다. 캡처 13쌍과 전체 증거 298파일·126 PNG는 현재 소스와 원본 기록에 결합되어 있다. 추가 공통 규칙이나 `.claude` 수정은 필요하지 않다.
