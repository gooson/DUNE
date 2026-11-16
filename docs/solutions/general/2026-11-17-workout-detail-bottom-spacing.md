---
tags: [swiftui, workout-detail, bottom-padding, tab-bar, accessibility, ui-testing]
category: general
date: 2026-11-17
status: implemented
severity: minor
related_files: [DUNE/Presentation/Exercise/HealthKitWorkoutDetailView.swift, DUNEUITests/Full/WorkoutZoneDetailUITests.swift]
related_solutions: [2026-11-04-watch-summary-bottom-spacing]
---

# 운동 상세의 마지막 카드와 하단 탭 바 간격

## Problem

달리기 상세(W28)를 맨 아래까지 스크롤했을 때 마지막 심박수 구간 카드가 시스템의 떠 있는 탭 바에 붙어 보였다. 콘텐츠 VStack에는 가로 padding만 있었다.

## Solution

`HealthKitWorkoutDetailView`의 콘텐츠 VStack에 `.padding(.bottom, DS.Spacing.xxl)`을 추가했다. 프로젝트의 24pt 토큰이며 시스템 safe area에 추가되는 콘텐츠 끝 간격이다. 구간·날씨가 조건부로 표시되어도 스택 끝에 같은 간격이 생긴다. 탭 바 높이나 기기 크기를 하드코딩하지 않는다. modifier의 edge/길이는 [Apple padding 문서](https://developer.apple.com/documentation/swiftui/view/padding(_:_:))를 확인했다.

정확한 카드 frame을 검사하기 위해 심박 구간과 날씨 카드를 `accessibilityElement(children: .contain)`으로 그룹화했다. 이전 구간 카드의 root identifier는 내부 출처·각 구간 identifier까지 덮고 있었으며, 실제 AX에서 모든 자식이 `healthkit-workout-zones-section`으로 보였다. 그룹화 후 기존 출처·구간 검사도 통과했다.

## Verification

- Xcode 27.2 / iOS 27.2 / 전용 iPhone 18 Pro: 알림 운동 상세 push에서 일반 글씨·접근성 XXXL 선택 UI **2/2 통과**, skip 0. 앱/테스트 컴파일 포함.
- 전용 iPad mini: 같은 경로 일반 글씨 선택 UI **1/1 통과**, skip 0. 상단 탭 바인 경우 하단 탭 비교를 강제하지 않았다.
- iPhone 실제 AX: 일반 Weather 카드 `y=670, height=97`, MAX `y=379.7, height=387.3`; 탭 바 `minY=791`. 두 경우 모두 **24pt** 간격을 확인했다.
- [새 원본 PNG·AX·기기·소스 해시·receipt](../../design/phone-design-map/actual/workout-bottom-spacing-2026-11-17/index.html)를 직접 열어 검토했다. 카탈로그 포맷·manual extraction 검사와 diff 검사를 통과했다.
- 비즈니스 로직 변화가 없어 단위 테스트는 추가하지 않았다. 전체 회귀는 실행하지 않았다.

### 초기 실패와 범위 수정

최초 클래스 실행은 새 검사 2건 통과·기존 출처 검사 1건 실패였다. AX를 확인하니 새 검사는 카드 제목의 frame을 측정했고, 운동 전체 목록 시트 안에 있어 탭 바가 실제로 보이지 않았다. 이 결과를 최종 간격 증거로 사용하지 않았다.

contain 그룹 추가 후 기존 출처 검사가 **52.235초에 통과**했다. 뒤이어 Activity 최근 목록에 없는 advanced fixture를 탐색하는 경로를 소스 리뷰로 발견해 그 실행을 중단했다(exit 75). 실패·중단 이력은 `.codex-checks/pipeline/` 및 `.codex-checks/workout-bottom-logs/`에 보존한다. 동일 오류를 이름만 바꿔 반복하지 않고, 이미 존재하는 알림 workout push와 그 fixture의 마지막 Weather 카드를 검증하는 계약으로 변경했다.

최종 두 검사는 실제 Weather 카드 OtherElement, scroll 끝의 안정된 frame, 화면과의 교차, iPhone의 보이고 조작 가능한 하단 탭 바, 최소 12pt 간격을 확인한다. 최종 앱·테스트 SHA-256은 캡처 manifest에 보존했다. 이후 문서·캡처만 추가됐으며 코드 해시를 재확인한다.

### Limits

알림 fixture에는 심박 샘플이 없어 Weather가 마지막이다. **날씨 없이 마지막 심박 구간 카드가 오는 원래 사진의 변형은 새 native 탭 바 캡처로 직접 검증하지 않았다.** 동일 스택 끝 padding을 적용하는 소스 구조와 기존 구간 표시 검사로 보완하며, 이 한계는 P3로 기록한다. Duo 접힘·펼침, iPad 최대 글씨, 어두운 모드는 이번에 재캡처하지 않았다. Watch/visionOS 화면은 변경 소비자가 아니다. 최대 글씨 Weather의 기존 어색한 줄바꿈은 별도 문제로 유지한다. 실제 HealthKit 조회·실사용자 데이터는 검증하지 않았다.

## Prevention

스크롤 끝 여백을 검사할 때는 실제 마지막 카드의 전체 frame과 보이는 고정 제어를 비교한다. 아래 presenter의 AX 탭 바만 존재하는 시트를 통과 증거로 사용하지 않는다. 컨테이너 ID가 자식에게 전파되는지도 실제 AX로 확인한다. 이번 한정된 수정에는 새로운 전역 규칙이나 CLAUDE.md 교정 항목을 추가하지 않았다.

## Lessons Learned

요소 존재와 잘못 선택한 제목 frame만으로 간격 검사가 통과할 수 있다. 화면 진입 경로·마지막 섹션·실제 PNG를 함께 확인해야 레이아웃 회귀 검사가 의미를 갖는다.
