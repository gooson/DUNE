---
tags: [settings, swiftui, navigation, theme-preview, accessibility, dynamic-type]
date: 2026-11-21
category: architecture
status: implemented
severity: important
related_files: [DUNE/Presentation/Settings/SettingsView.swift, DUNE/Presentation/Settings/Components/ThemePickerSection.swift, DUNEUITests/Smoke/SettingsSmokeTests.swift]
related_solutions: [2026-11-19-artist-theme-native-rollout]
---

# 설정 허브에서 메뉴 위치와 테마 선택 보존하기

## Problem

설정의 단일 Form에서 테마가 운동·알림 항목 24개 아래에 있었다. 개인정보를 열려면 테마 원화 9장도 지나야 했다. 검색과 갤러리라는 두 진입점을 만들자 같은 테마를 적용해도 돌아갈 화면이 서로 달라질 수 있었다.

## Solution

- 설정 홈에 현재 테마와 범주별 진입점을 둔다. 좁은 화면에서는 기존 탐색 스택에 상세 화면을 열고, 넓은 화면에서는 왼쪽 목록을 유지한 채 오른쪽 내용을 교체한다. 설정값을 읽고 저장하는 로직은 각 상세 화면이 재사용한다.
- 검색 항목은 안정적인 ID와 목적지를 가진다. 검색어는 결과를 표시하는 쪽에서 보관하므로 상세에서 뒤로 가면 이전 검색 결과가 다시 보인다.
- 후보 테마와 미리보기 밝기는 미리보기 화면에만 전달한다. 적용 버튼에서 저장 테마를 변경한 뒤 갤러리를 열고, 뒤로 버튼은 이전 화면으로 돌아간다. 미리보기 예시는 고정된 값을 사용한다.
- 갤러리에서는 SwiftUI Button 자체에 테마 이름·식별자·선택 상태를 지정한다. Button 바깥에 별도 접근성 요소를 만들었을 때 XCTest에는 이름만 있는 버튼과 식별자만 있는 Other가 따로 노출됐다.

## Prevention

갤러리에서 미리보기 취소와 적용을 모두 확인하고 검색에서 연 미리보기에도 같은 적용 검사를 수행한다. 테스트는 스크롤 대상을 갤러리로 한정하고, 테마를 고른 뒤 같은 버튼의 선택 상태와 앱 아이콘 팔레트를 확인한다.

## Lessons Learned

메뉴 개수가 같아도 첫 화면에서 지나야 하는 행의 수는 배치에 따라 달라진다. 이 변경에서는 기존 설정을 모두 유지하면서 테마를 한 번에 열고, 테마 수가 늘어나도 개인정보 메뉴가 같은 자리에 있도록 했다.

[승인 시안](../../design/layout-map/settings-hub/index.html) · [네이티브 화면](../../design/phone-design-map/actual/settings-hub-2026-11-21/index.html)
