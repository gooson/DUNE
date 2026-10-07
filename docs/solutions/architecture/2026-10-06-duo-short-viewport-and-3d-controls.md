---
tags: [iphone-duo, dynamic-type, clipping, workout, realitykit, adaptive-layout, menu, animation]
category: architecture
date: 2026-10-06
severity: important
status: implemented
related_files:
  - DUNE/Presentation/Exercise/WorkoutSessionView.swift
  - DUNE/Presentation/Activity/MuscleMap/MuscleMap3DView.swift
  - DUNE/Presentation/Activity/Components/WeeklyStatsGrid.swift
  - DUNE/Presentation/Activity/Components/MuscleDetailPopover.swift
  - DUNE/Presentation/Wellness/MetricComparisonView.swift
related_solutions:
  - docs/solutions/testing/2026-10-06-duo-background-motion-verification.md
---

# Solution: Duo 최대 글자 크기의 짧은 운동 화면과 3D 모델 가림

## Problem

실제 Closed landscape/maxAX에서 운동 입력 전체 표시 조건이 실패했다. Window는 678×466, controls는 662×122이고 KG TextField는 높이 99.7pt였다. 고정 progress header와 Complete Set footer가 본문 높이를 소비해 작은 scroll 여유만 남았다. Native/AX 원본은 [감사 보고서](../../reviews/2026-10-06-duo-cli-fold-validation.md)에 보존했다.

같은 감사에서 최대 AX weekly 지표의 고정 두 열과 값/단위/변화율 수평 배치가 숫자 ellipsis·변화율 세로 분절을 만들었다. 근육 상세도 고정 두 열을 유지했다. 3D는 모델이 로드됐지만 큰 summary overlay가 아래쪽 신체를 덮었다. ARView 접근성 존재만 확인하는 검사는 이 가림을 검출하지 못한다.

Book portrait/maxAX에서 system 기간 메뉴도 왼쪽 밖(x=-76.8pt)에 열려 월 선택이 실패했다. 메뉴 수정 후 native에서는 navigation title ellipsis도 확인했다. 휴식 case의 반복 60초 animation idle 대기는 매초 1초짜리 ring animation 갱신과 함께 관찰됐다.

## Solution

- WorkoutSessionView는 전체 가용 높이 700pt 미만과 accessibility text size가 함께 성립할 때 progress header와 Complete Set을 controls ScrollView 안에 배치한다. Closed portrait에서는 휴식 종료 후 고정 footer가 다시 나타나 본문이 334pt로 줄었고, 두 입력의 합친 높이 377pt를 수용하지 못했다. 현재 세트 action은 이전 기록보다 먼저 배치한다. 기존 binding/완료/초안/휴식 로직은 유지한다. 일반 크기와 충분한 높이에서는 고정 header/footer 및 두 열 overview 정책을 유지한다.
- WeeklyStatsGrid/MuscleDetailPopover는 AX 크기에서 한 열로 전환하고 값/단위/변화율·header를 세로 배치한다. 근육 icon frame은 ScaledMetric으로 실제 glyph 크기를 수용한다.
- MuscleMap3DView의 AX 크기는 모델과 controls를 별도 영역으로 표시한다. 넓은 화면은 옆 열, 좁은 화면은 위 viewer와 아래 scroll controls다. AnyLayout으로 배치가 바뀌어도 viewer subtree의 identity를 유지한다. 기본 크기의 immersive overlay는 유지한다.
- MetricComparisonView는 최대 AX에서 기간을 본문 내 세로 button 목록으로 표시하고 제목도 줄바꿈 가능한 본문 Text로 배치한다. period binding 및 두 metric의 날짜 갱신은 유지한다.
- 최대 AX weight/reps의 휴식 종료 뒤 paired input 영역의 위쪽으로 animation 없이 자동 이동한다. 입력 binding과 timer deadline·Skip 로직은 유지한다. Closed portrait의 강화된 단독 UI 검사는 175.391초, 1/1 passed, exit 0으로 즉시 두 입력 전체 표시를 확인했다. 실제 접힘은 275.743초, 높이 조건이 바뀌는 Book 회전은 156.163초로 각각 1/1 passed, exit 0이다.
- 테스트는 full input/countdown frame, 값 보존, 실제 기기 방향 readback 및 viewer/controls 불교차·mode 도달성을 확인한다. Regular 너비의 근육 tap은 옆 열 상세 선택이므로 명시적인 3D 버튼으로 진입한다.

Closed/maxAX 회전 재검증은 1/1 passed, exit 0, 173.237초다. Book/portrait maxAX 3D는 83.255초로 통과했고 native에서 모델 전체와 분리된 controls를 확인했다. Open/portrait maxAX 3D도 90.136초 exit 0이며 전체 모델/controls를 확인했다. 전체 제목과 기간 버튼은 최종 source로 세 자세에서 통과했고, 네 주간 지표와 +1,450% 변화율도 실제 native로 확인했다. 0.25초 ring 실험은 단독 smoke가 통과했으나 fold idle 대기가 재발하고 600초 초과로 실패해 원래 1초로 되돌렸다. 이 실험을 최종 해결책으로 제시하지 않는다. 최종 자동 scroll과 가용 높이 수정으로 실제 90°→180°→0° 휴식 검사가 275.743초, 1/1 passed, exit 0으로 whole countdown·완료 세트·Skip·다음 kg/reps 전체 frame·Done까지 통과했다. 다른 조건 및 SDK cleanup 종료는 보고서의 개별 receipt로 판단한다. 이 문서는 현재 브랜치의 수정안을 기록하며 main에 merged됐다고 주장하지 않는다.

## Prevention

- 기기 이름/화면 폭만 확인하지 말고 실제 hinge·물리 방향·가용 높이·AX 크기를 함께 기록한다.
- ScrollView 존재만으로 가시성을 판정하지 않는다. 입력/숫자의 전체 frame과 실제 native를 확인한다.
- 스크롤 경계에 있는 내용과 고정 요소가 가리는 내용을 구분한다.
- 3D 렌더링 성공과 overlay 가림 해결을 구분한다. Viewer/controls 교차 및 아래 controls 도달성을 검사한다.
- 테스트 실패 뒤 다음 group이 이전 방향을 상속하지 않도록 시작 자세를 독립 검증한다.
- 개별 testcase 통과와 SDK result cleanup 정상 종료를 분리한다. Cleanup timeout을 전체 실행 exit 0으로 바꾸지 않는다.

## Lessons Learned

최대 AX에서는 넓은 Duo도 큰 정보 패널 때문에 본문 가용 영역이 크게 줄어든다. 폰트만 축소하거나 existence assertion만 늘리지 말고 고정/scroll 영역과 overlay 구조를 실제 viewport로 검증한다. 이미 확보한 성공을 모든 155 route의 런타임 합격으로 확장하지 않는다.
