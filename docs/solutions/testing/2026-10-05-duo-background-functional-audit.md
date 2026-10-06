---
tags: [duo, xctest, accessibility, scene, mock-data]
category: testing
date: 2026-10-05
severity: important
related_files:
  - DUNE/App/DUNEApp.swift
  - DUNE/Presentation/Exercise/WorkoutSessionView.swift
  - DUNE/Presentation/Shared/CloudSyncConsentView.swift
  - DUNE/Presentation/Posture/PostureHistoryView.swift
  - DUNEUITests/DUNEUITests-DuoFunctional.xctestplan
  - DUNEUITests/Helpers/UITestHelpers.swift
related_solutions:
  - architecture/2026-09-26-duo-layout-and-presentation-ownership.md
---

# Solution: Duo 잠금 상태의 기능 검사와 원본 시각 판정을 분리

## Problem

Mac 잠금으로 Device Hub의 실제 접힘 preset 조작이 막힌 것을 모든 UI 자동화가 불가능한 것으로 잘못 해석했다. 별도 Insights scene 복원은 primary-only 목업 초기화를 건너뛰어 실제 HealthKit 오류를 일으켰다. 큰 글자 입력란/Compare Selected가 viewport 위쪽에 있어도 helper가 아래로만 스크롤했고, 동의 버튼 식별자는 composite 화면 식별자에 덮였다.

## Solution

- 공유 scene 진입 전에 고급 목업을 한 번 초기화하고 준비된 뒤 내용을 표시한다.
- phone의 Workout Insights는 같은 scene의 시트를 사용한다. 닫기 버튼 소실과 운동 컨트롤 hittability를 검사해 배경 창의 존재를 복귀 성공으로 오해하지 않는다.
- `DUNEUITests-DuoFunctional`은 native XCTest PNG/계층을 남기되 host ACK/FOLD 대기는 활성화하지 않는다. Xcode 27.1에서 잠금 상태의 기능 실행이 가능했다.
- 입력/자세 helper는 target과 올바른 scroll container의 frame을 비교해 방향을 고른다.
- composite 화면 식별자는 스크롤 본문에, action 식별자는 Button 자체에 붙인다. `.safeAreaInset`의 형제 action들이 화면 ID를 물려받지 않도록 한다.
- AX에서는 차트 메뉴/제목·습관 이름/완료율·자세 날짜/메모를 세로로 배치하고 점수 링도 글자와 함께 확대한다.

## Verification

[실행과 원본 판정](../../reviews/2026-10-05-duo-resumed-validation.md)에 실패 receipt를 유지했다. 독립 Body 1/1, 운동 입력/휴식 및 통계 복귀 2/2, Life 보고서, 동의/자세 비교의 조건부 재검증 2/2가 통과했다. 잘못 지정한 클래스명 두 개는 xcodebuild exit 0에도 missing-selector 게이트에서 실패 처리했다.

기능 성공과 픽셀 성공은 별개다. 통과한 차트에서 첫 요일 잘림을 추가 발견했고, 마지막 anchor 후보는 빌드만 통과하여 시각 확인을 남겼다. native inactive inner 이미지나 landscape orientation을 실제 partiallyOpen/openFlat 증거로 사용하지 않는다. 실제 접힘/회전/전환 중 상태 보존 및 전체 최종 UI 게이트는 아직 미완료다.

## Prevention

- 테스트 메서드의 파일명과 선언 클래스명을 구분하고 실행 receipt의 요청 selector 누락을 확인한다.
- 잠금 상태의 XCTest와 GUI preset 조작 가능 여부를 각각 판정한다.
- 재사용 성공은 해당 선택 범위에만 적용한다. 본문/하단 action의 ID는 실제 AX 계층에서 확인한다.
- 스크롤 viewport 경계, 실제 행 내부 clipping, 단어 분절을 원본 이미지에서 구분한다.
- 공유 simulator mutex를 우회하지 않고, 대기만 한 프로세스 종료와 실제 테스트 실패를 구분한다.

## Lessons Learned

고급 목업을 제공하는 것만으로 충분하지 않으며 복원되는 모든 scene이 초기화 gate를 거쳐야 한다. UI 기능 검사는 잠긴 Mac에서도 실행할 수 있었지만, 실제 접힘 전환과 전수 시각 판정은 별도 증거가 필요했다.

## 2026-10-06 후속 검증

[최신 main 병합 기록](../../reviews/2026-10-06-duo-main-sync-validation.md)에서 알림 운동 상세와 운동 통계 복귀가 통과했고, Personal Records의 제한된 scroll budget을 최대 AX 콘텐츠 길이에 맞게 늘린 뒤 해당 상세까지 78.509초에 통과했다. 전체 suite의 budget이나 공통 helper를 무조건 늘리지 않았다.

Duo에서는 화면 밖 `Compare Selected`도 hittable로 판단됐고, full swipe가 짧은 View All 버튼을 오가며 지나칠 수 있었다. viewport 안의 실제 tap point도 확인해야 한다. 짧은 위치 보정 drag는 후속 후보이며 실행 통과 전이다.

실제 Book/Open/Closed에서 입력 초안은 유지됐지만 결합된 fold case는 실패했다. 실제 전환 후 XCTest의 idle 대기가 오래 걸려 이미 시작된 휴식이 만료될 수 있다. opt-in 입력/휴식 case를 분리하고 휴식 case에만 기존 세트의 긴 휴식 값을 seed하는 후보를 준비했다. 아직 runtime 성공은 아니다. 타이머 중 fold 전환을 assertion 없이 성공으로 보고하지 않는다. native PNG의 실제 크기는 port default 크기가 담긴 파일명 대신 header로 확인한다.
