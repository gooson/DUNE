---
tags: [ios, ipados, app-icon, splash, theme, native-capture]
date: 2026-11-16
category: design
status: implemented-focused-validation
---

# 82·71·87 아이콘 선택과 시작 화면

[이미지 포함 HTML 갤러리](index.html) · [이미지별 출처와 소스 해시](manifest.json) · [배치·팔레트 기준](../../../../layout-map/app-icon-settings.md)

사용자 요청은 설정에서82·71·87을 선택하고 기본 컬러는 P04, 다른 테마의 컬러는 자동으로 연결하는 것이다. 기본 형태는82다. 설정 → 외관 → 앱 아이콘에서 선택하고, 같은 화면에서 시작 화면을 미리 본다. iOS의 앱 실행 전 정적 화면은82/P04를 사용하며, 앱의 SwiftUI 스플래시는 저장한 형태와 테마를 따른다.

영향 화면은 T01 시작, S01 설정의 외관 항목, 신규 S08 앱 아이콘 선택이다. 이 갤러리는 기존 웹 시안과 별도의 네이티브 앱 실행 결과다. 이미지 경로 해석에 의존하지 않도록 실제 PNG를 HTML에 포함했다. 원본 PNG도 `images/`에 그대로 보존한다. 기본 밝은 모드·영문 테스트 환경이며 UI 문구의 한국어·일본어 번역도 카탈로그에 등록했다.

## 검증

- `DUNETests/AppIconStyleTests`:4개 통과. 승인 형태·기본값·저장·24개 프리뷰 로드·23개 컴파일된 대체 아이콘 선언을 확인했다. 이후 스플래시 전경을 분리할 때 이 아이콘 PNG와 이름은 변경하지 않았으므로 해당 단위 증거를 재사용했다.
- `DUNEUITests/AppIconSettingsUITests/testSelectionPersistsAndThemeUpdatesIconAndSplash`: 세 형태 표시, 기본82 선택,87 선택·시스템 API 적용 완료 상태, 재실행 후 선택 유지, FOREST 전환 시87의 팔레트와 미리보기 변경을 확인한다.
- `DUNEUITests/AppIconLaunchUITests/testSplashUsesAllThreeSelectedDesigns`: 실제 운영 스플래시 View를 DEBUG 캡처 분기에서 유지해82/DUNE·71/OCEAN·87/FOREST를 확인한다. 실제 자연 실행의 표시 시간을 늘렸다는 의미는 아니다.
- 일반 iPhone은 실제 `iPhone-18-Pro` 기기 유형인 소유 기기 `7172E282-33AA-48DF-BA5A-69F107E6B5C4`, iPad는 `iPad-mini-A20-Pro` 유형인 소유 기기 `A173EFA4-245C-47FA-B2EC-EAFA72B85F77`를 사용한다. 둘 다 iOS27.2다.
- 투명 전경24개는1024px RGBA·투명 모서리이며, 홈 화면용 아이콘은1024px 불투명 사각 원본이다. 플랫폼이 홈 화면 마스크를 적용한다.

최종 실행별 통과 여부와 테스트 결과 번들·타임스탬프는 `manifest.json`의 `runs`와 `captured`를 따른다. 관련 selector만 실행했고 전체 회귀는 실행하지 않았다. 최종 캡처는 스플래시의 사각 바탕을 제거한 뒤 수집한 것만 포함한다.

## 이전 실패와 수정

첫 실행은 요청 이름iPhone17이 실제로 Duo 런타임을 가리켰다. 스플래시 이미지에 상위 `launch-splash` 식별자가 덮인 것을 실제 XCTest 계층에서 확인했고 상위 식별자를 제거했다. 설정 항목은 큰 페이지 스와이프가 지나쳤으므로 짧은 드래그로 바꿨다. 원인을 수정한 뒤 일반 iPhone의 해당2개 selector가 통과했다. iPad에서도 동일 흐름이 통과했다.

이후 실제 PNG 검토에서 스플래시의 사각 배경이 드러나 별도 투명 LaunchBrand 자산으로 분리했다. 이 화면 변경 때문에 해당2개 selector만 다시 실행하고 최종 PNG를 새로 수집했다. 이전 투명화 전 캡처를 최종 화면으로 재사용하지 않았다. 최종 iPad 재캡처에서는 S01 항목이 하단에 부분 노출된 채 탭되어 S08 진입 검사가 실패했다. 실패 계층의 항목 프레임은y1084.5~1136.5, 화면 높이는1134pt였다. 항목 전체가 상하 여유 안에 보일 때 탭하도록 테스트 helper만 보정하고, 통과한 스플래시 검사는 재사용하며 실패한 설정 selector만 조건부 재실행했다. [실패 PNG](diagnostics/ipad-settings-entry-edge.png)와 [계층](diagnostics/ipad-settings-entry-edge-hierarchy.txt)은 최종 완료 이미지에 포함하지 않는다.

최초 실패 결과와 중간 통과 결과는 로컬 `.deriveddata/unit-tests/Logs/Test/` 및 `.xcodebuild/app-icon-*.log`에 보존한다.

## 미갱신 범위

Duo 접힘·펼침의 T01·S01·S08은 최종 수정 후 재촬영하지 않았다. 첫 Duo 실패를 완료 증거로 사용하지 않는다. 기존 기기별 `regular`·`ipad`·`duo`·`duo-open` 인덱스의 과거 캡처를 새 UDID로 덮어쓰지 않았다. 신규 S08의 새 증거는 이 별도 갤러리에 있으며, 기존 기기별 인덱스에서는 미캡처로 남는다.

실물 기기의 홈 화면, iOS 정적 시작 프레임, 시스템 다크·클리어·틴트 아이콘 표현, 최대 글씨는 이번 캡처로 검증하지 않았다. Watch와 visionOS의 앱 아이콘 설정은 변경하지 않았다. HTML 컬러랩의 원래112개 이력은 보존하며 네이티브 캡처와 구분한다.

최종 결과: iPhone 관련2개 selector 통과·새 PNG9장, iPad 스플래시1개와 조건부 수정 후 설정1개가 통과·새 PNG9장이다. 총18장을 보존하며 iPad의 두 selector는 서로 다른 결과 번들의 유효한 통과 증거를 합친 것이다. iPhone 이후 변경은 iPad 하단 탭을 위한 테스트 스크롤 helper뿐이며 앱 코드·자산·검사 assertion은 같다. 실행별 테스트 소스 해시를 따로 기록했다.

이 폴더는 원래 작업 브랜치269a61dbe에서 촬영한 통합 전 기록이다. 최신 main의 완료 증거로 사용하지 않는다.
