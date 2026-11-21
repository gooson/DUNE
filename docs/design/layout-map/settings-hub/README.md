---
tags: [settings, ios, ipados, accessibility, design]
date: 2026-11-21
category: brainstorm
status: draft
---

# S01 설정 개편안

[인터랙티브 시안](index.html) · [세 화면 한눈에 보기](overview.png) · [기존 S01 배치](../settings-s01.html)

## 첫 화면에서 찾기

현재 일반 기기의 설정 화면은 10개 섹션, 42개 행이다. 테마 앞에 운동·알림·브리핑 24개 행과 앱 아이콘이 있고, 개인정보는 원화 9장 아래에 있다. 시뮬레이터는 테스트 데이터 섹션 4개 행을 추가로 노출한다. [현재 설정](../../../../DUNE/Presentation/Settings/SettingsView.swift) · [알림 섹션](../../../../DUNE/Presentation/Settings/Components/NotificationSettingsSection.swift) · [테마 목록](../../../../DUNE/Presentation/Settings/Components/ThemePickerSection.swift)

| 홈에서 여는 곳 | 상세 화면에 두는 항목 |
|---|---|
| 현재 테마 카드 | 기존 원화 9장, Today 화면의 밝은·어두운 예시, 테마 적용 |
| 앱 아이콘 | 세 가지 형태, 현재 테마를 따르는 아이콘 색상, 시작 화면 예시 |
| 운동 설정 | 휴식 시간·기본 세트·체중, 운동별 기본값, 즐겨찾는 운동, 실시간 현황 |
| 알림과 브리핑 | 아침 브리핑, 건강 알림, iPhone·Watch 취침 알림, 운동·생활 알림 |
| 데이터와 개인정보 | iCloud 동기화와 동기화 요청, Apple 건강 권한, 위치 접근 |
| 앱 정보 | 새 소식, 버전, 빌드, 날씨 데이터 출처 |

검색 버튼은 설정 이름이나 테마 이름을 알고 있을 때 쓴다. 예를 들어 ‘취침’을 입력하면 iPhone과 Watch 관련 결과가 뜨고, 결과를 누르면 해당 취침 설정 화면이 열린다. 뒤로 가면 검색어가 유지된다. 시스템 권한과 동기화 실행은 실제 앱에서 처리하는 동작으로 표시했다. 시뮬레이터 전용 데이터 도구는 구현 시 조건부 개발 항목으로 둔다.

## 테마 선택

1. 설정 홈에서는 현재 적용한 테마 원화 한 장을 보여준다.
2. **테마 변경**을 누르면 갤러리가 열린다. 카드에는 이름과 원화를 함께 표시한다. 사용 중인 테마에는 테두리와 체크를 붙인다.
3. 원화를 누르면 그 테마의 기존 Today 예시를 볼 수 있다. **밝게**와 **어둡게**는 미리보기 조명만 전환한다. **이 테마 적용**을 눌러 선택을 확정하고 갤러리로 돌아간다. 뒤로 가면 기존 선택이 유지된다.
4. 다른 테마를 적용하면 홈 카드, 선택 표시, 선택한 형태의 앱 아이콘이 함께 바뀐다.

갤러리는 [앱 번들의 아홉 원화](../../../../DUNE/Resources/ArtistEditions/)를 직접 사용한다. 미리보기 속 Today 이미지는 [기존 아티스트 테마 검증 자료](../../phone-design-map/actual/artist-themes/index.html)에서 가져왔다. 함께 표시한 설정 홈·갤러리·적용 화면은 새 브라우저 시안이다.

## 기기별 배치

| 조건 | 배치 |
|---|---|
| iPhone 기본 크기 | 현재 테마와 네 가지 설정 범주가 홈에 함께 보인다. 갤러리는 3열이다. |
| 아주 좁은 폭·큰 글씨 | 갤러리를 2열로 줄이고 본문 스크롤을 허용한다. 미리보기의 적용 버튼은 아래쪽에 둔다. |
| iPad 넓은 창 | 왼쪽에는 설정 홈을 두고 오른쪽에서 범주·갤러리·미리보기를 연다. |
| iPad 좁은 창 | 홈과 상세를 한 번에 하나씩 보여준다. 뒤로 가면 목록으로 복귀한다. |

섹션을 접는 방식도 검토했다. 한 섹션을 펼쳤을 때 뒤쪽 메뉴의 위치가 다시 바뀌는 점이 이번 요청과 맞지 않았다. 허브 방식에서는 테마 수나 알림 세부 항목이 늘어도 첫 화면의 메뉴 위치가 유지된다.

## 참고한 앱 패턴

- iPhone은 설정에서 배경화면 갤러리를 별도로 열고 선택 후 적용 범위를 정한다. DUNE에는 원화 비교와 명시적 적용을 가져왔다. [Apple 배경화면 가이드](https://support.apple.com/guide/iphone/change-the-wallpaper-iph3d267104/ios)
- iPhone 설정은 항목 이름을 검색해 해당 위치로 이동할 수 있다. DUNE에서도 이름이 분명한 설정에는 검색 경로를 제공한다. [Apple 설정 검색 가이드](https://support.apple.com/guide/iphone/find-settings-iph079e1fe9d/ios)
- Oura는 Today에서 주요 지표에 바로 접근하고 Vitals에서는 관련 지표를 묶어 상세로 연결한다. DUNE에서는 현재 테마를 먼저 보여주고 나머지 설정은 목적별로 묶었다. [Oura 앱 가이드](https://support.ouraring.com/hc/en-us/articles/360058599753-How-to-Use-the-Oura-App)
- Slack은 테마 색상과 밝기 모드를 별도로 제공한다. DUNE 시안에서는 테마 고르기와 밝기 미리보기를 분리했다. [Slack 테마](https://slack.com/help/articles/205166337-Change-your-Slack-theme) · [Slack 밝기 모드](https://slack.com/help/articles/360019434914-Use-dark-mode-in-Slack)
