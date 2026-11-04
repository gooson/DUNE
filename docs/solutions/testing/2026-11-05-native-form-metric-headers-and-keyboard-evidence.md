---
tags: [swiftui, form, accessibility, keyboard, body-composition, native-evidence]
date: 2026-11-05
category: solution
status: implemented
severity: important
related_files:
  - DUNE/Presentation/BodyComposition/BodyCompositionFormSheet.swift
  - DUNEUITests/Full/WellnessRegressionTests.swift
related_solutions:
  - docs/solutions/testing/2026-10-29-simulator-keyboard-and-visible-form.md
---

# 네이티브 측정 헤더와 키보드 증거 구분

## Problem

공유 신체 기록 Add/Edit Form의 세 측정 헤더에는 기존 지표 아이콘이 없었다. 시각 표현을 보완하면서 네이티브 입력, 번역된 단위, 미래 날짜 제한, 유효성 검사와 create/update 소유권을 보존해야 했다.

첫 iPad 추가 검사는 91.2 입력 후 Save의 hit point를 {-1,-1}로 계산했고 Form이 남았다. 새 PNG와 AX에는 포커스된 화면 키보드와 Save가 보였다. 저장 handler가 실행됐다는 증거는 없으므로 저장 결함이나 키보드 부재로 판단하지 않았다.

## Solution

NavigationStack·Form·입력·focus·키보드 toolbar·오류·Cancel/Save는 유지한다. 작은 `measurementHeader`가 `LocalizedStringKey`와 기존 category를 받아 중립적인 `DS.Color.textSecondary` 글자와 기존 category 색의 SF Symbol을 표시한다. 장식 이미지에만 AX 숨김을 적용한다. 기존 Weight·Body Fat·Muscle Mass 키와 단위를 쓰므로 모델·쿼리·동기화·문자열 카탈로그 변경은 없다.

기존 Add/Edit 검사에 캡처 네 곳을 넣었다. MAX Edit의 기존 입력 순서를 따라 일반 Add도 Save 전에 기존 Done을 누르도록 한 줄을 추가했다. 새 assertion이나 검사 메서드는 추가하지 않고 저장·닫힘·목록 검증을 유지했다.

핵심 다섯 사례가 iPhone·iPad·Duo 접힘/펼침과 접힘 MAX Edit에서 통과했다. 첫 iPad 실패를 따로 보존해 전체 이력은 6회 실행·5회 통과·1회 실패다. 실제 출처는 Xcode 27.2 (27B52)이며, pipeline context의 원래 27.1 표기는 시도 기록을 바꾸지 않고 부가 정정으로 남겼다.

iPad의 Done 탭 자체는 다시 {-1,-1}이었고 직후 키보드도 남았다. 이후 Save와 목록 반영은 성공했지만 키보드 닫힘이나 단정적인 원인 해결을 주장하지 않는다. iPhone과 펼친 Duo에서는 Done 뒤 PNG·AX로 닫힘을 확인했다. 입력 환경과 저장 성공, 개별 탭의 효과는 서로 다른 사실이다.

## Prevention

- 현재 소유 기기의 포커스된 PNG·AX로 화면 키보드를 확인한다. `typeText`만 근거로 삼지 않는다.
- 실패 aggregate와 횟수를 보존하고, 검토한 원인 관련 변화 뒤 같은 논리적 검사만 조건부 재실행한다.
- 탭을 성공으로 설명하기 전에 실제 후속 상태를 확인한다.
- 표현만 바꿀 때 기존 Form과 create/update 소비자를 유지한다.
- 실제 소스·UID·자세·test plan·도구 버전과 캡처를 연결한다. 오래된 이미지는 정체성 참고로 구분한다.
- 같은 핵심 UI 실행의 컴파일을 재사용하며 무관한 전체 빌드나 unit suite를 반복하지 않는다.

## Lessons Learned

작은 네이티브 헤더로 시각적 정체성을 보완할 수 있다. 전체 저장 흐름의 통과가 모든 중간 탭의 성공을 입증하지는 않는다. 기존 규칙으로 충분하므로 .claude 원본을 바꾸지 않았다.
