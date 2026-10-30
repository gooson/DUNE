---
tags: [siri, app-intents, foundation-models, healthkit, localization, ui-testing]
date: 2026-10-30
category: review
status: ui-verification-blocked
---

# Siri 건강 정보 조회 — 구현과 검증 기록

> **최종 머지 결정:** 사용자가 잔여 검증을 설명받은 뒤 “머지해 그냥”이라고 명시해, 아래 미검증 범위를 유지한 채 머지한다. UI 전체 통과나 Siri 음질 개선 확정을 뜻하지 않는다.
>
> 앱의 접근성 글자 크기 선택기를 줄바꿈 가능한 Menu로 수정했다(`adac0a30`). 통합 소스 `485e50eb`는 관련 UI 실행에서 iOS Simulator DUNE·테스트 타깃 컴파일에 성공했고, Duo 펼침6개 검사가 모두 통과했다. 접힘도 원인별 보완 후 고유6개 검사가 통과했다. 새 실제 원본은 각29장이다. 기존19754ce6의63개·9개 suite 단위 검증은 변경되지 않은 Domain·Data 경로의 역사적 증거로 보존한다.
>
> iPad 수정 후 최대 글씨 검사는 사용자의 세 기기 삭제 요청으로 중단됐고 iPhone 최종 검증은 실행하지 않았다. 실제 Siri 음색·억양·AirPods·Watch·VoiceOver는 직접 확인하지 않았다. 관찰된 P3 차트 위쪽 눈금 잘림은 남아 있다. 이전의 실패·부분 성공·잠금 이력은 삭제하지 않는다.


구현 소스 기준은 `19754ce6`이다. 20시 재개 후 **Xcode 27.2 (27B52) / Swift 6.4.2 / SDK 27.2**로 generic iOS 빌드와 관련 **63개·9개 suite** 단위 테스트가 통과했다. 실제 SDK 선언 감사에서 현재 Siri·App Intents·Foundation Models 경로의 필수 API 교체는 발견되지 않았다. [27.2 SDK 확인](sdk-27-2-audit.md)과 [실행 증거](evidence/sdk272-executions.json)를 따른다.

이전 `3999e507`의 62개 검증 이후 `19754ce6`에서 비교 기간 메타데이터와 회귀 검증을 추가하고 차트 단위를 표시했다. 따라서 이전의 Domain·Data 동일성 설명을 최신 소스에 적용하지 않는다.

**최종 UI 및 Ship 게이트는 미완료다.** 디자인 시안 PNG는 실제 앱 캡처가 아니며, 수정 전 실패 진단용 캡처도 최종 화면 증거로 재사용하지 않는다.

SDK 27.2에서 14종 전환·소프트웨어 키보드와 기록 없음 검사는 새로 통과했고 **네이티브 원본 17장**을 보존했다. 최대 글씨 검사는 메뉴의 화면 밖 행 선택에서 실패했고, 한 번 보완한 조건부 재시도도 목표 행이 일부만 보이는 상태로 실패했다. 최대 글씨 완료 캡처는 0장이다. 실패 이력과 자동 재시도 한도를 유지한다.

## 구현 범위

- 최근 운동, 기간 운동량, 완료한 근력 세트, 개인 기록, 유산소 세부 정보.
- 최신 신체 측정, 신체 변화, 수면, 컨디션, 지표·운동 비교.
- 운동 메모 검색, 통계 보고서 공유 미리보기, 긴 분석까지 총 14개 조회 종류.
- 날짜·기간·운동·종목 파라미터, 단축어용 구조화된 결과, 잠금 인증과 휘발성 결과 보관.
- 앱의 Q&A에서 같은 조회 화면에 진입하고 출처 기록으로 이동한다. 보고서 공유는 통계만 포함하며 메모·개별 기록을 내보내지 않는다.
- 자연어 계획은 Foundation Models가 만들고, 값·기간 검증과 실제 조회·집계는 코드가 수행한다. SDK 27의 요청별 세션은 도구 읽기 예산을 한 번만 허용한다. AI를 사용할 수 없어도 구조화된 조회는 가능하다.
- PCC entitlement와 관리 조건은 검증되지 않아 활성화하지 않았다. 보호된 개인 메모의 Spotlight 색인은 구현하지 않았다.

## Siri 음성 확인

`HealthQueryIntent.swift`는 `ProvidesDialog`와 `IntentDialog`를 반환한다. 전체·supporting 응답 모두 검증된 `spokenSummary`를 담으며 별도 AVSpeechSynthesizer를 재생하지 않는다. 음색·억양은 시스템 Siri가 정한다.

SDK 27의 `IntentSystemContext.locale`을 요청별 TaskLocal로 전달하여 앱 언어와 다른 Siri 언어도 유지한다. 숫자·단위·날짜를 이 locale로 만든다. 한국어 예시는 `75.5 킬로그램`, `1시간 1분 1초`, `분당 63회`다. 같은 날짜의 반복과 기간 끝의 다음 날 자정 표기를 제거했다. 동시 요청의 언어 격리와 한국어 단위·날짜 테스트가 통과했다.

실제 기기에서의 발화 라우팅·음색·억양·AirPods·Watch 청취는 수행하지 않았다. 앱 코드가 실제 음질 개선을 보장한다고 결론 내리지 않는다. 음성 선택은 [Apple의 Siri 음성 설정 안내](https://support.apple.com/ko-kr/120499), 요청 locale의 의미는 [IntentSystemContext.locale](https://developer.apple.com/documentation/appintents/intentsystemcontext/locale)을 따른다.

## 실제 실행 결과

| 검증 | 결과와 범위 |
|---|---|
| 최종 iOS 빌드 | `19754ce6`, Xcode 27.2 / SDK 27.2, `scripts/build-ios.sh --no-regen`, 성공 |
| 관련 단위 테스트 | `19754ce6`, iOS 27.2 전용 기기, `scripts/test-unit.sh`, **63개·9개 suite 통과** |
| 문자열 포맷·manual | `swift scripts/format-xcstrings.swift --check --check-manual`, 성공 |
| 테마맵 동기화 | `python3 docs/design/theme-map/build-theme-map.py --check`, 성공 |
| 초기 iPhone UI | `9ae252af`, 실제 **DUNEUITests-Full / FullConfiguration**, 선택된 34개 중 27개 통과·7개 실패 |
| 추가 승인 후 iPhone UI | `2282ab87`, 4개 중 2개 통과: 14종 전환·소프트웨어 키보드, 기록 없음. 기간 탭·공유 닫기 가정 2건 실패 후 테스트 보정. 두 검사 재실행은 잠금 대기에서 시작되지 못함 |
| SDK 27.2 iPhone UI | `be22072d`, 3개 중 2개 통과: 14종·키보드 및 기록 없음. 새 원본 17장. 최대 글씨 1개 실패 |
| 최대 글씨 조건부 재시도 | `a3877321`, 실패한 1개만 실행해 실패. 실제 메뉴 스크롤은 관찰됐으나 목표 행 전체 노출 실패. 추가 자동 실행 없음 |
| iPad·Duo 접힘/펼침 | 최종 구현 미실행·새 캡처 없음 |
| Vision 빌드 | 변경하지 않은 bedtime reminder protocol 의존성 오류로 실패. 통과 아님 |
| Xcode 27.2 | 설치·SDK 선언·앱 빌드·관련 단위와 위의 제한된 iPhone UI 실행 확인. 실제 Siri 및 다른 기기 확인은 별도 |

초기 UI의 공통 smoke 3개 실패는 Dashboard의 7일 추세 그래프·알림함 제목·최대 글씨의 설정 버튼이다. 해당 소스와 테스트는 당시 `origin/main`과 동일했지만, main 자체의 동일 환경 실행으로 기존 실패를 입증한 것은 아니다. 이번 변경의 성공으로 합산하거나 관계없는 화면을 수정하지 않았다. 정확한 실패는 [초기 실행 오류](evidence/ui-initial-errors.log)에 보존한다.

나머지 4개는 `HealthQuerySmokeTests`다. 실제 PNG에는 값이 렌더링됐지만 결과 카드 부모의 접근성 ID가 자식에게 전파되어 테스트의 종류·상태 ID가 사라졌다. [접근성 트리 발췌](evidence/root-identifier-proof.txt)를 확인하고 ID를 독립된 기간 Text로 옮겼다. 중복 제목·날짜, `45:00 s` 표기, 큰 값의 배치도 수정했다. 추가 승인 실행에서 종류·출처·no-data 식별자는 정상 조회돼 이전 AX 원인 해소가 확인됐다. 14종 캡처와 키보드 검사는 통과했다. 남은 두 실패는 가려진 기간 버튼의 탭 위치와 실제 시스템 공유 popover의 닫기 방식 가정이었고 `89df4b83`에서 테스트를 보정했다. 그 재실행은 잠금 대기에서 시작되지 못했다.

## 실행 환경과 남은 검증

- 이전 27.0/27.1 전용 기기 세 대는 20시의 정상 목록에서 사라졌다. 기존 실패와 UDID 기록은 보존한다.
- 새 iOS 27.2 iPhone `094E24A5-1AFD-4E52-ADA4-2F2BD2B396ED`를 생성하고 baseline·정확한 이름·소유권을 등록했다. 표준 부팅 helper와 readback에서 정상 Booted를 확인한 뒤 단위 검증을 한 번 재개해 63개가 통과했다.
- 공유 기기를 종료하거나 다른 작업과 병렬 검증하지 않았다. 사용자에게서 병렬 실행 승인은 받지 않았다.
- `siri-ui-iphone` 및 승인 후 추가 검사 이력은 삭제하지 않는다. 두 조작 검사의 미검증 상태를 통과로 바꾸지 않는다.
- 최신 비교 기간·차트 축 수정본의 iPhone PNG 17장을 새로 수집했다. 최대 글씨 검사는 첫 실행과 조건부 재시도가 실패했으며, 기간·출처 및 공유 취소의 기존 두 조작 검사, iPad·Duo 두 자세, 실제 Siri 청취는 남아 있다. 전체 suite는 요청되지 않았으므로 자동 확대하지 않는다.
- 과거 generic simulator build-for-testing timeout은 통과가 아니다. 이번 실제 iOS 27.2 단위 실행은 해당 테스트 타깃의 컴파일과 실행을 별도로 확인한 증거다.

## 디자인맵 상태

[14개 기능별 비주얼 시안](../../design/theme-map/themes/dune-siri-health-queries.html), [PNG 모음](../../design/theme-map/themes/assets/siri-health-queries-overview.png), [배치·상태 계약](../../design/layout-map/siri-health-queries-proposal.md)은 테마맵과 레이아웃맵에 연결했다. 합성 데이터의 시안이며 시스템 Siri 외곽은 모식도다.

T17(Q&A 진입)·T19(건강 조회)의 SQ01–SQ14와 키보드·기록 없음은 최신 앱 소스 `19754ce6`와 같은 앱을 SDK 27.2로 실행한 새 iPhone 17장에 반영했다. [원본·기기·테스트·해시](../../design/full-redesign-map/review/siri-health-queries-2026-10-30/iphone-sdk272/manifest.json)를 보존한다. 이는 합성 검증 기록을 넣은 실제 네이티브 앱이며 시스템 Siri 화면은 아니다. 최대 글씨 실패 진단 PNG 2장은 별도로 표시하고 완료 수에 포함하지 않는다. 출처 상세·공유 취소, iPad·Duo 접힘/펼침은 미갱신이다. Watch는 이번 새 화면의 타깃 멤버가 아니며 시안만 있다. [통합 실제 화면맵](../../design/full-redesign-map/review/siri-health-queries-2026-10-30/index.html)에서도 범위를 구분한다.

새 PNG 리뷰에서 SQ10의 집계 비교 기간은 해결을 확인했고 SQ02·SQ08의 초 단위 축을 확인했다. SQ10·SQ13의 축은 캡처 viewport 아래여서 시각 확인이 남아 있다. [SDK 27.2 실제 화면 재검토](reviews/review-siri-sdk272-native-delta.md)를 따른다.

## 리뷰와 파이프라인

Security·Data Integrity·Performance·Architecture·Simplicity 리뷰의 소스 발견사항을 수정했다. `19754ce6`의 비교 기간·단위 수정은 별도 데이터 정합성 재검토에서 새 발견사항이 없었다. Agent-Native는 지침·에이전트 설정 변경이 없어 제외했다. 이후 변경분은 SwiftUI·앱 품질 관점으로 재검토했고 새로운 확정 소스 발견사항은 없었다. 정적 검토를 시각적 승인이나 UI 통과로 승격하지 않는다. [리뷰 보존본](reviews/)과 [기계 실행 증거](evidence/executions.json)를 따른다.

| 단계 | 상태 |
|---|---|
| Init / Plan / Work | 완료. 계획서·소스·빌드·관련 단위 검증 보존 |
| UI Test | SDK 27.2에서 고유 검사 3개 중 2개 통과·1개 실패, 실패 검사의 조건부 재시도도 실패. 새 iPhone 원본 17장. 기존 두 조작·다른 기기 미검증 |
| Review / Quality | 독립적인 정적 검토 수행. UI 증거를 포함한 최종 승인 보류 |
| Resolve | 소스 수정 완료. 런타임 재확인 보류 |
| Compound | 해결한 설계·음성 처리 문서 준비. 파이프라인 완료 선언 보류 |
| Pre-Ship / Ship | 최종 UI 게이트를 통과하지 않아 머지·정리 진행하지 않음 |

리서치는 [Apple 공식 기술 조사](../../brainstorms/2026-10-30-siri-health-queries-xcode-27-2-research.md), 구현 계획은 [계획서](../../plans/2026-10-30-siri-health-information.md)를 참조한다.
