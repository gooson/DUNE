---
tags: [ios, ipados, app-icon, splash, theme, native-capture]
date: 2026-11-16
category: plan
status: implemented
---

# 82·71·87 아이콘 선택과 시작 화면

[이미지 포함 HTML 갤러리](index.html) · [이미지별 출처와 소스 해시](manifest.json) · [배치·팔레트 기준](../../../layout-map/app-icon-settings.md) · [통합 전 개발 기록](before-main-sync/index.html)

설정 → 외관 → 앱 아이콘에서82(인터리브)·71(오션글라스)·87(네거티브 플로)를 선택한다. 기본은82/P04이고 다른 테마에서는 선택한 형태를 유지하며 색상만 바꾼다. 앱 스플래시와 설정의 시작 화면 미리보기도 같은 선택을 따른다. iOS 프로세스 실행 전 정적 화면은82/P04를 사용한다.

이 갤러리의 최상위 PNG는 최신 origin/main36839aa0d7에 아이콘 변경만 통합한 뒤 새로 촬영한 네이티브 시뮬레이터 화면이다. 통합 전269a61dbe의18장과 실패 진단·receipt는 `before-main-sync/`에 보존하며 최신 main의 증거로 재사용하지 않는다. HTML에는 실제 PNG를 포함해 상대 이미지 경로 없이 볼 수 있다.

## 검증 범위

- `DUNETests/AppIconStyleTests`: 승인 형태·기본값·저장·24프리뷰 로드·23대체 선언의4개 검사.
- `DUNEUITests/AppIconSettingsUITests/testSelectionPersistsAndThemeUpdatesIconAndSplash`: 세 형태 표시, 기본82,87 선택과 적용 완료 상태, 재실행 저장, FOREST 자동 팔레트·미리보기.
- `DUNEUITests/AppIconLaunchUITests/testSplashUsesAllThreeSelectedDesigns`: 운영 스플래시 View를 유지하는 DEBUG 캡처 분기에서82/DUNE·71/OCEAN·87/FOREST 표시.
- iPhone18Pro 소유 기기4FBA2086-77FE-470C-958F-D4A882918C84와 iPad mini(A20Pro) 소유 기기6073655F-9A6E-40B7-A377-CC1E57A30150, iOS27.2, 기본 밝음·영문 앱 환경.

실행별 결과·시각·이미지와 소스 해시·결과 번들은 `manifest.json`을 따른다. 원본 PNG는 `images/`, 작은 검증 결과 사본은 `verification/`에 둔다. 스플래시를 유지하는 DEBUG 분기는 실제 자연 실행의 표시 시간을 변경한 것이 아니다.

## 미갱신 범위

Duo 접힘·펼침의 T01·S01·S08, 실물 홈 화면, iOS 정적 실행 프레임, 시스템 다크/클리어/틴트 아이콘 표현, 최대 글씨는 이번 통합 캡처에 포함하지 않는다. Watch·visionOS 앱 아이콘은 변경하지 않았다. 전체 회귀는 요청되지 않았으며 관련 selector만 실행한다.

기존 기기별 regular/ipad/duo 인덱스의 과거 PNG를 다른 UDID로 덮어쓰지 않았다. 신규 S08의 증거는 이 별도 갤러리에서 확인한다. 이전 웹 시안112개·20팔레트 탐색과 네이티브 캡처도 구분한다.

최종 통합 결과: 단위4/4, iPhone 고유 UI2개·새 원본9장, iPad 스플래시와 설정 고유 UI2개·새 원본9장이다. iPad 설정은 최초10초 완료 대기 실패 뒤90초로 보정한 한 번의 조건부 재실행에서 통과했다. 같은 성공 값과 선택·저장·테마 assertion은 유지했고 앱 코드는 바꾸지 않았다. iPad의 두 통과 selector는 별도 결과 번들의 유효한 증거를 합친 것이며 최초 실패 receipt·PNG도 보존한다.

단위 결과 번들은 Xcode 관리 로그 저장소에서 이미 정리돼 재보존할 수 없었으며,4/4 통과 원본 로그를 보존했다. 남아 있는 최종 UI 결과 번들·실패 결과·로그는 manifest의 raw_evidence_archive 위치에 따로 보관한다.

캡처 글자 누락으로 보였던 판독은 원본 픽셀 대조로 반증됐다. 세 이름·Theme 영역이 정상 참조와 RGB까지 같고 footer 글자 마스크도 동일하다. 대조 결과는 verification/text-pixel-comparison.json에 보존한다. 불필요한 촬영 대기는 최종 코드에서 제거했으며 기존 통과 실행과 소스 해시가 일치한다.
