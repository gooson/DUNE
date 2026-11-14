---
tags: [design, themes, native-evidence, accessibility]
date: 2026-11-14
category: testing
status: in-progress
---

# 최신 8개 테마 마무리 검증

기준 main `96d1a60e5`. [실행 계획](../../../../plans/2026-11-14-theme-overhaul-completion.md)과 현재 4탭의 Compact·Flow 배치를 따른다. 기존 10월 테마 캡처를 이번 실행의 새 증거로 사용하지 않는다.

## 구현과 현재 판정

- 8개 영속 값·별도 장면·탭/상세/시트 라우터·공유 asset은 기존 구현을 재사용한다.
- WATER LILIES는 21개 Today 수련 군집·작은 수면 붓질·앞뒤 깊이와 비활성/Reduce Motion 정지 장면을 보완했다. 원본 시안은 변경하지 않았다.
- 최대 글씨에서 링을 숨기고 점수/습관 진행률을 외부에 표시하는 현재 계약으로 UI 검사를 교정했다.
- OCEAN·FOREST의 30개 색상은 명시적 Light를 Any 기본 변형으로 바꾸고 기존 RGBA·Dark 변형을 보존했다. 초기 AppTheme 검사에서 22개 named color lookup 실패가 실제 확인됐으며, 같은 형태의 배경 장면 리소스 8개까지 함께 수정했다.
- 공유 장면 라우터는 Reduce Motion/scenePhase 변경 시 장식 하위 트리만 교체한다. legacy repeatForever가 정리되며 화면의 데이터·내비게이션·입력은 유지된다.
- 전체 맵의 108 고정 개수는 현재 110개 인벤토리와 충돌해 생성 실패했다. 고유 ID/빈 목록 검증은 유지하고 개수는 인벤토리에서 계산한다. 컨디션/스트레스 상세 시안 두 개는 여덟 테마와 별도의 studies로 보존한다.
- Watch는 iOS의 theme 변경을 message와 applicationContext로 전달한다. 직접 Watch launch override를 쓰는 UI 캡처는 실제 전파 성공의 증거가 아니다.
- Widget은 iOS의 공유 App Group 선택값을 읽는다. Vision은 해당 앱의 독립 저장값·테마 피커를 사용한다. App Group은 기기 간 동기화 수단으로 해석하지 않는다.

## 실행 상태

| 범위 | 상태 | 근거 |
|---|---|---|
| iOS theme/palette/geometry unit | XCTest 17/17 통과 | 원인 수정 후 재검사 exit 0. 최초 17 tests / 22 issues (requiredAssets 한 test)는 보존 |
| iPhone 8테마 4탭 밝음/어두움 | 대기 | 새 PNG/AX와 source pin을 수집한 뒤 갱신 |
| iPhone 상세/시트/운동 선택 | 대기 | 테마별 실제 진입·화면 준비 후 캡처 |
| 최대 글씨·고대비·동작 줄이기·언어 | 대기 | 설정·상태별 실행 결과를 구분 |
| iPad·Duo Closed/Open | 대기 | 소유 기기 순차 실행; 실제 viewport/readback 확인 |
| Watch 테마·실전파 | 대기 | 테마 캡처와 paired 전파 검증 분리 |
| Widget·Vision | 대기 | 실제 runtime 지원과 render/build 근거 분리 |
| 소스·시각 품질 리뷰 | 진행 중 | 초기 Water Lilies SwiftUI/성능 조사에 blocking finding 없음; 최종 리뷰 대기 |

## 증거 규칙

새 캡처는 소스 revision·dirty 상태·기기 UDID/runtime·viewport·시각·selector와 연결한다. PNG/AX 수집 성공, XCTest 통과, 시각적 판정을 각각 기록한다. 실패한 batch의 일부 passed case를 batch 전체 성공으로 바꾸지 않는다. MAX의 큰 콘텐츠는 scroll 위치별로 대조한다. VoiceOver용 AX label 확인만으로 실제 VoiceOver 탐색을 통과했다고 주장하지 않는다.

원본 실패/SDK 진단과 재시도는 같은 갤러리에 보존한다. 동일 원인은 원인에 대응한 변화가 있을 때 한 번만 재시도한다. 이전 10월 자료는 Git 이력과 원래 갤러리의 역사적 근거로 유지하며 새 출처로 재표기하지 않는다.

### Unit 증거와 실행 지문 제한

`AppThemeTests`·`WaveShapeTests`는 Xcode 27B52, iOS 27.2, 소유 iPhone `9D0602F1-9D0B-4AB0-B144-666748CCDC19`에서 수정 후 17/17, xcodebuild exit 0이었다. 앱·asset·unit 소스는 `958e4dada`이며 실행 중 변경하지 않았다. 다만 병행 문서/맵 스크립트 편집으로 전체 worktree fingerprint가 바뀌어 pipeline wrapper는 `worktree changed during command`로 실패했다. 이를 pipeline 통과로 바꾸지 않는다. [원본 실행과 출처](unit-evidence.json)에서 XCTest 결과와 wrapper 판정을 분리하며 이후 UI는 파일을 고정하고 실행한다.

색상 Any/Dark 구성의 근거: [Apple의 Dark Mode 리소스 지침](https://developer.apple.com/documentation/UIKit/supporting-dark-mode-in-your-interface). 이번 수정은 기존 색상 값을 바꾸지 않고 기본 lookup 누락을 해결한다.
