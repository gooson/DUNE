---
tags: [iphone-duo, swiftui, arrangement-view, accessibility, live-activity, camera, multi-window]
category: architecture
date: 2026-09-20
severity: important
related_files:
  - DUNE/Presentation/Shared/Components/AdaptivePaneView.swift
  - DUNE/Presentation/Exercise/WorkoutSessionView.swift
  - DUNE/Presentation/Exercise/WorkoutRestActivity.swift
  - DUNE/Presentation/Posture/PostureAssessmentViewModel.swift
  - DUNE/App/DUNEApp.swift
related_solutions: []
---

# iPhone Duo 적응형 화면과 상태 연속성

## Problem

넓은 화면에서 Life 빈 습관 영역이 불필요하게 늘어났고, 요약과 상세를 동시에 보기 어려웠다. 새로운 폼팩터에 화면 폭만으로 분기를 추가하면 입력 상태를 다시 생성하거나, 접힘으로 줄어든 영역에 입력과 완료 버튼이 겹칠 수 있었다.

### Symptoms

- 빈 Life 화면이 0%와 0/0을 크게 표시했다.
- Duo 운동 UI 테스트에서 무게 증가 탭 뒤 세트가 완료되고 반복 횟수 입력이 사라졌다.
- 일부 `.secondaryAction` 항목은 Duo의 실제 접근성 트리에 메뉴와 함께 나타나지 않았다.
- 카메라 전환 이후 취소된 작업이 새 화면의 촬영 상태를 바꿀 수 있었다.
- 종료 중인 Live Activity를 화면 재등장 시 다시 연결할 수 있었다.

### Root Cause

빈 상태에도 높이 채우기 정책을 적용했고, 적응형 pane 내부의 safe-area footer와 스크롤 터치 영역을 충분히 분리하지 않았다. 터치 현상의 SDK 내부 원인은 확정하지 않았다. 스크롤/완료 버튼을 명시적인 형제 레이아웃으로 분리하고 clipping을 적용한 뒤 동일 UI 테스트가 통과했다. 비동기 작업의 수명과 화면의 수명을 동일하게 취급한 것도 상태 경합의 원인이었다.

## Solution

| 영역 | 변경 | 이유 |
|---|---|---|
| Life | 내용 크기에 맞는 시작 카드, 일간 습관/주간 운동 집계 구분 | 빈 데이터의 의미와 다음 행동을 명확히 표시 |
| AdaptivePaneView | SDK 모듈 버전과 OS availability로 ArrangementView 보호, 기존 SDK는 AnyLayout | Duo의 시스템 배치와 일반 기기 호환성 유지 |
| 운동 | 이전 기록과 입력을 안정적인 두 pane에 배치, 스크롤과 완료 버튼 분리, 좁은 창의 키보드 공간 확보 | 입력 상태와 터치 대상 보존 |
| 휴식 | 종료 시각 기준 계산, 초안 복원, ActivityKit countdown | 앱 비활성화 후에도 남은 시간을 재계산 |
| Live Activity | 종료 예정 ID 제외 및 active/stale 상태만 재연결 | 종료/재등장 경합 방지 |
| 운동 목록 | 선택 ID를 최신 목록에 연결한 inspector, 삭제 시 선택 해제, 행 전체 contentShape | 목록과 상세의 데이터/터치 일치 |
| Today/Life | inspector로 요약·목록과 상세 병치, 고정된 닫기 행동 | 상세를 확인한 뒤 문맥 유지 |
| 비교 | 같은 날짜 범위, 독립된 단위/축; 수면 누락을 0분 측정으로 표시하지 않음 | 잘못된 데이터 해석 방지 |
| 주간 계획 | 날짜별 템플릿 배정, 버튼과 drag/drop 병행, 기기 내 저장 명시 | 접근 가능한 계획 편집 |
| 카메라 | generation 검사, 취소와 오류 구분, 완료 결과 유지, 가용한 경우에만 외부 안내 | 전환 중 오래된 작업의 결과 차단 |
| 분석 창 | 읽기 전용 WindowGroup, 공유 ModelContainer, 권한 준비 조건, 기록/활성화/날짜/갱신 신호 반영 | 새 분석 창에서 중복 기록 세션을 시작하지 않음 |
| 배경 | 부분 접힘 상태에서만 장식 채도 전환, Reduce Motion 존중 | 기능 배치와 독립된 표현 |

### Key Code

```swift
VStack(spacing: 0) {
    ScrollView { inputOrRestContent }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .contentShape(Rectangle())
    completionAction
}
```

SDK 보호에는 Swift 컴파일러 버전만 사용하지 않는다. 설치된 SwiftUI 모듈 버전과 런타임 availability를 모두 확인한다. `.accessibilityIdentifier`를 컨테이너에 부여할 때는 `.accessibilityElement(children: .contain)`으로 자식 버튼 식별자를 보존한다.

## Prevention

- plain 버튼으로 바꾸는 목록 행은 Spacer를 포함한 전체 영역에 `contentShape(Rectangle())`를 지정한다.
- 버튼 존재뿐 아니라 hittable 상태와 **행동 직후의 상태**를 검증한다. 무게 증가가 세트를 완료하지 않는지 확인한다.
- Duo의 내부 화면을 명시하여 캡처한다. 기본 screenshot 대상은 비활성 외부 화면일 수 있다.
- 도구 막대는 선언만으로 노출을 가정하지 않고 실제 접근성 트리에서 확인한다.
- 초안, 선택, 타이머 상태를 보유하는 ViewModel의 identity를 레이아웃 분기로 교체하지 않는다.
- AsyncStream을 추가 창에서 경쟁 소비하지 않는다. 분석 창에는 별도의 broadcast 갱신 신호를 제공한다.
- 카메라 취소 완료는 해당 generation에서만 화면 상태를 변경한다.
- 비교 차트는 단위와 날짜 범위를 표시하고, 누락 값을 실제 측정값처럼 그리지 않는다.

## Validation and Limits

구체적인 빌드·테스트 결과는 `docs/plans/2026-09-20-iphone-duo-experience.md`의 Validation Ledger에 기록한다. 시뮬레이터의 UI 테스트 통과를 물리적 접힘, 카메라 품질, 외부 화면 가독성 또는 배터리 검증으로 간주하지 않는다. 설치된 SDK의 모듈 버전 guard는 SDK 업데이트 시 재확인해야 한다.

## Lessons Learned

적응형 화면에서는 화면 크기보다 상태 수명과 명확한 터치 영역이 먼저다. 시스템 배치에 맡기더라도, 기능 진입·닫기·저장 같은 핵심 행동은 실제 표시 상태와 함께 검증해야 한다. 읽기 전용 분석 창과 기록 창의 역할을 나누면 기존 기록 모델을 재사용하면서 추가 창에서의 중복 입력 위험을 줄일 수 있다.
