---
tags: [ios, swiftui, alternate-app-icons, app-theme, launch-screen, accessibility-identifier]
category: general
date: 2026-11-16
severity: minor
related_files:
  - DUNE/Domain/Models/AppIconStyle.swift
  - DUNE/Presentation/Settings/AppIconPickerView.swift
  - DUNE/Presentation/Settings/AppIconService.swift
  - DUNE/Presentation/Shared/Components/AppLaunchBrandView.swift
  - scripts/generate-app-icon-assets.swift
related_solutions: []
---

# Solution: 선택한 아이콘 형태를 저장하고 테마별 색상을 연결하기

## Problem

아이콘 탐색112개와20팔레트 HTML 컬러랩은 있었지만 승인된82·71·87을 앱 설정에서 선택할 수 없었다. 홈 화면 아이콘과 시작 화면을 같은 저장 값으로 연결하고 기본 테마에는 P04를 적용해야 했다.

### Root Cause

시안은 앱 번들 밖에 있었고 저장 모델·대체 아이콘 카탈로그·AppTheme와 UIKit API의 조정 경로가 없었다. 불투명 아이콘을 스플래시에 그대로 쓰면 사각 바탕이 보이는 문제도 있었다.

## Solution

| 파일 | 변경 | 목적 |
|---|---|---|
| AppIconStyle | interleave/ocean/flow와 기본82 | 테마와 독립적으로 형태 저장 |
| AppIconStyle+View | 미리보기·전경·대체 이름·팔레트 매핑 | 자산 이름 계약 유지 |
| AppIconService | 요청 직렬화·마지막 요청 보존 | 연속 선택 때 최종 조합으로 수렴 |
| AppIconPickerView / SettingsView | 세 선택·현재 상태·시작 화면 미리보기·재시도 | 네이티브 설정 흐름 완성 |
| DUNEApp / AppLaunchBrandView | 설정 변경·포그라운드 동기화와 같은 로고 View | 시스템 아이콘과 스플래시 연결 |
| generate-app-icon-assets.swift / project.yml | 기본82/P04·대체23개·미리보기24개·투명 로고24개 | 번들 계약과 깨끗한 시작 화면 |

생성기는 기존 컬러랩의4기준점 색상 행렬을 재현한다. 홈 화면 아이콘은 불투명 사각형으로 두고 시스템이 마스크를 적용한다. 시작 로고는 별도 투명 전경으로 분리한다. iOS 프로세스 실행 전 정적 시작 화면은82/P04이며, 앱의 SwiftUI 스플래시가 저장한 형태·테마를 읽는다.

최종 통합 검증은 승인 형태·저장·24프리뷰·23대체 선언을 확인하는 AppIconStyle 단위 검사와, 설정 선택·재실행·테마 전환·세 스플래시의 네이티브 UI 검사다. 최신 main의 결과와 이전 브랜치 개발 이력, 기기별 receipt·원본 PNG·소스 해시는 [실제 화면 갤러리](../../design/phone-design-map/actual/app-icon-2026-11-16/README.md)에 구분한다. 요청되지 않은 전체 회귀는 실행하지 않는다.

## Prevention

- 3×8 자산과 대체 이름을 함께 유지한다. 이름·불투명 아이콘 변경 후 `swift scripts/generate-app-icon-assets.swift`와 관련 번들 계약 검사를 사용한다.
- 시작 화면용 투명 전경과 홈 화면용 사각 아이콘을 구분한다.
- 상위 접근성 식별자가 내부 이미지·버튼 식별자를 덮지 않게 한다. 첫 스플래시 실패는 실제 XCTest 계층에서 상위 식별자가 노출된 것을 확인하고 제거해 해결했다.
- 설정의 특정 행에는 짧고 제한된 스크롤을 사용한다. 큰 테마 미리보기 사이의 작은 항목을 페이지 스와이프가 지나칠 수 있다. iPad 하단에서 `isHittable`만 확인하면 부분 노출된 행도 허용되므로 항목 전체가 표시 영역 안에 들어온 뒤 탭한다.
- 시뮬레이터 이름과 실제 기기 유형을 함께 확인한다. 오래된 iPhone17 요청 이름이 Duo로 해석된 실행과 일반 iPhone18Pro 실행을 구분했다.

## Lessons Learned

네이티브 동작·캡처와 과거 웹 시안은 별도의 증거다. 최종 갤러리는 PNG를 HTML에 포함해 상대 이미지 경로에 의존하지 않는다. 시스템 다크/클리어/틴트 표현, 실물 홈 화면과 Duo 자세 캡처는 수행한 범위와 구분해 기록한다.
