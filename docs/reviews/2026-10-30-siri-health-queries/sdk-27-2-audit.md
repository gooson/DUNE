---
tags: [xcode-27-2, sdk, siri, app-intents, foundation-models, compatibility]
date: 2026-10-30
category: review
---

# 설치된 Xcode 27.2 SDK 확인

사용자의 27.2 업데이트 확인 요청에 따라 실제 설치된 SDK 선언과 공식 릴리스 노트를 대조했다. 도구는 **Xcode 27.2 (27B52), Swift 6.4.2, iOS Simulator SDK 27.2**다. 앱 소스 `19754ce6`은 이 도구로 `scripts/build-ios.sh --no-regen` generic iOS 빌드에 성공했다.

## 앱 코드 판정

검토한 Siri·Foundation Models 경로에서 필수 API 교체는 발견되지 않았다. 27.1 SDK가 현재 설치돼 있지 않아 두 SDK의 정확한 바이너리 차이를 주장하지 않는다. 사용 중인 API가 27.2에도 공개돼 있고 호출 지점의 가용성 분기와 맞는지 확인했다.

| 현재 사용 | 27.2 SDK 판정 |
|---|---|
| DynamicProfile·Profile·SessionProperty | 유지. iOS 27.0 API이므로 현재 가용성 분기 유지 |
| required → disallowed 도구 호출 | 유지. 실제 1회 읽기 제한은 앱의 actor 예산으로 보장 |
| LongRunningIntent·performBackgroundTask | 유지. 작업 진행률·취소 처리의 기존 계약 보존 |
| IntentSystemContext.locale·요청별 TaskLocal | 유지. 앱 언어와 다른 Siri 언어·숫자·날짜 처리에 계속 필요 |
| `.system.searchInApp` | 현재 대체 스키마 사용 중. 예전 search로 되돌릴 이유 없음 |
| ProvidesDialog·SnippetIntent·기기 인증 | 현재 조합과 결과 반환 오버로드 유지 |

27.2의 데이터 첨부·데이터 엔트리 지원은 현재의 문자열 질문·typed 도구·AppEntity 반환에 필수적이지 않다. 추후 파일·이미지 입력을 설계할 때 지원 여부와 iOS 27.2 가용성을 확인한다. 현재 배포 대상 iOS 27.0을 올릴 근거는 없다.

공개 건강 기록 읽기용 AssistantSchema나 Siri 전용 음색 선택 API는 확인되지 않았다. Spotlight 도구는 이미 iOS 27.0 API이며 현재의 보호된 메모 검색을 교체할 새 근거가 없다. PCC는 관리 entitlement·적격성 확인이 계속 필요하므로 권한이 검증되지 않은 현재 상태에서 켜지 않는다. [Apple의 PCC 안내](https://developer.apple.com/documentation/foundationmodels/adding-server-side-intelligence-with-private-cloud-compute/).

## 검증 환경에서 바꾼 부분

기존 전용 기기 3개의 UDID는 현재 목록에서 사라졌고, 27.0 기반 대상을 그대로 사용할 수 없었다. 새 iOS 27.2 iPhone을 생성해 baseline·정확한 이름·UDID로 소유권을 등록하고 정상 부팅 readback을 확인했다. 공유 기기를 종료하거나 그 데이터를 정리하지 않았다.

27.2 릴리스 노트는 시뮬레이터 복제의 파일 권한 문제(188407822)를 알린다. 따라서 검증용 빈 기기를 새로 만드는 방법을 사용했다. Device Hub의 키보드·입력 수정 사항과 Duo의 일시적인 검은 캡처·접근성 제약도 실제 검증 환경에 적용해 판단한다. [Xcode 27.2 릴리스 노트](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_2-release-notes), [iOS·iPadOS 27.2 릴리스 노트](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27_2-release-notes).

UIKit의 기본 layoutMargins 변경은 iOS 27.1 이후의 내용이며, 이번 Siri 화면은 SwiftUI와 시스템 컨트롤을 사용한다. 이 경로에 일괄 margin 보정을 추가할 이유는 찾지 못했다.

SDK 선언 확인과 빌드 성공은 실제 Siri 발화·음색·억양 검증과 다르다. 현재 기기의 음성을 청취했다고 보고하지 않는다. 단위·UI 실행 결과는 [실행 기록](README.md)의 소스 버전·기기·결과를 따른다. [SDK 선언별 상세 감사](reviews/review-siri-sdk272.md)에서 실제 SDK 경로와 줄 번호를 확인할 수 있다.

관련 단위 63개·9개 suite가 실제 iOS 27.2 전용 기기에서 통과했다. 새 iPhone UI에서는 14종 전환·키보드와 기록 없음이 통과해 원본 17장을 보존했다. 최대 글씨 메뉴 선택은 한 번 보완한 재시도까지 실패했으므로 그 상태의 호환성을 승인하지 않는다. 앱 API 변경 없이 테스트의 메뉴 스크롤만 보완했으며, 앱 소스는 `19754ce6`과 동일하다. [새 실제 화면과 남은 범위](../../design/full-redesign-map/review/siri-health-queries-2026-10-30/index.html)를 확인할 수 있다.
