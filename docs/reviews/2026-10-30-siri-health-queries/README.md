---
tags: [siri, app-intents, foundation-models, healthkit, localization, ui-testing]
date: 2026-10-30
category: review
status: ui-verification-blocked
---

# Siri 건강 정보 조회 — 구현과 검증 기록

구현 소스 기준은 `401cbf3d`이다. Xcode 27.1 / SDK 27.1에서 최종 generic iOS 빌드는 성공했다. 관련 단위 테스트는 `3999e507`에서 **62개·9개 suite 통과**했으며, 이후 변경은 컨디션 링·수면 단계 구성·유산소 지표·메모 강조·기간/오류 안내와 접근성 문구다. Domain·Data·App Intents 및 단위 테스트 소스는 `3999e507` 이후 동일하다. 문서 변경을 앱 코드의 재빌드로 오인하지 않는다.

**최종 UI 및 Ship 게이트는 미완료다.** 디자인 시안 PNG는 실제 앱 캡처가 아니며, 수정 전 실패 진단용 캡처도 최종 화면 증거로 재사용하지 않는다.

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
| 최종 iOS 빌드 | `401cbf3d`, `scripts/build-ios.sh --no-regen`, generic iOS, 성공 |
| 관련 단위 테스트 | `3999e507`, `scripts/test-unit.sh`, 62개·9개 suite 통과 |
| 문자열 포맷·manual | `swift scripts/format-xcstrings.swift --check --check-manual`, 성공 |
| 테마맵 동기화 | `python3 docs/design/theme-map/build-theme-map.py --check`, 성공 |
| 초기 iPhone UI | `9ae252af`, 실제 **DUNEUITests-Full / FullConfiguration**, 선택된 34개 중 27개 통과·7개 실패 |
| 수정 후 iPhone UI | 테스트 시작 전 저장소 시뮬레이터 잠금 대기 60초 만료. 0개 실행, 통과 아님 |
| iPad·Duo 접힘/펼침·최대 글씨 | 최종 구현 미실행·새 캡처 없음 |
| Vision 빌드 | 변경하지 않은 bedtime reminder protocol 의존성 오류로 실패. 통과 아님 |
| Xcode 27.2 | 설치된 컴파일러가 27.1이므로 실제 27.2 빌드 미검증 |

초기 UI의 공통 smoke 3개 실패는 Dashboard의 7일 추세 그래프·알림함 제목·최대 글씨의 설정 버튼이다. 해당 소스와 테스트는 당시 `origin/main`과 동일했지만, main 자체의 동일 환경 실행으로 기존 실패를 입증한 것은 아니다. 이번 변경의 성공으로 합산하거나 관계없는 화면을 수정하지 않았다. 정확한 실패는 [초기 실행 오류](evidence/ui-initial-errors.log)에 보존한다.

나머지 4개는 `HealthQuerySmokeTests`다. 실제 PNG에는 값이 렌더링됐지만 결과 카드 부모의 접근성 ID가 자식에게 전파되어 테스트의 종류·상태 ID가 사라졌다. [접근성 트리 발췌](evidence/root-identifier-proof.txt)를 확인하고 ID를 독립된 기간 Text로 옮겼다. 중복 제목·날짜, `45:00 s` 표기, 큰 값의 배치도 수정했다. 정적 재검토에서 기존 SwiftUI 발견사항은 해결됐으나 **수정 후 런타임 성공은 아직 없다**.

## 실행권 차단과 재개 조건

- 분류: `waiting-for-owner`. Mac 화면 잠금이나 앱 크래시로 분류하지 않는다.
- 소유 작업: `live-activity-gold-preferences/Health`의 `test-ui.sh`, 다른 전용 UDID의 실제 XCTest 실행. 소유 작업과 기기는 종료·변경하지 않았다.
- 이 작업의 iPhone: `396B168F-7AB7-4118-BD8C-A209A3C672FE`, iPhone 18 Pro, iOS 27.0. iPad 및 Duo도 worktree 전용 clone으로 등록되어 있다.
- 기존 `siri-ui-iphone` 검증 ID는 초기 assertion 실패와 수정 후 잠금 실패, 두 시도를 보존한다. 새 ID·다른 실행기·수동 캡처로 같은 검증의 재시도 제한을 우회하지 않는다.
- 재개하려면 소유 실행이 끝나 실행권이 정상임을 확인하고, 이미 사용한 재시도 한도에 대한 추가 실행 승인이 필요하다. 소유 작업을 중단시키는 승인을 요청하는 것은 아니다.
- 먼저 미검증 4개 owned selector를 확인한다. 그 뒤 영향받는 iPad·Duo 두 자세·최대 글씨와 소프트웨어 키보드를 순차 검증한다. 새 PNG·접근성 계층·viewport·시각·소스 커밋을 함께 수집한다. 전체 suite는 요청하지 않았으므로 자동 확대하지 않는다.

## 디자인맵 상태

[14개 기능별 비주얼 시안](../../design/theme-map/themes/dune-siri-health-queries.html), [PNG 모음](../../design/theme-map/themes/assets/siri-health-queries-overview.png), [배치·상태 계약](../../design/layout-map/siri-health-queries-proposal.md)은 테마맵과 레이아웃맵에 연결했다. 합성 데이터의 시안이며 시스템 Siri 외곽은 모식도다.

실제 화면 인벤토리의 T17(Q&A 진입)·T19(건강 조회), SQ01–SQ14 및 no-data·출처·공유·키보드 상태는 iPhone·iPad·Duo 접힘/펼침에서 최종 캡처 미갱신이다. Watch는 이번 새 화면의 타깃 멤버가 아니며 시안만 있다. [통합 실제 화면맵의 갱신 상태](../../design/full-redesign-map/review/siri-health-queries-2026-10-30/index.html)에서도 이 차이를 표시한다.

## 리뷰와 파이프라인

Security·Data Integrity·Performance·Architecture·Simplicity 리뷰의 소스 발견사항을 수정했다. Agent-Native는 지침·에이전트 설정 변경이 없어 제외했다. 이후 변경분은 SwiftUI·앱 품질 관점으로 재검토했고 새로운 확정 소스 발견사항은 없었다. 정적 검토를 시각적 승인이나 UI 통과로 승격하지 않는다. [리뷰 보존본](reviews/)과 [기계 실행 증거](evidence/executions.json)를 따른다.

| 단계 | 상태 |
|---|---|
| Init / Plan / Work | 완료. 계획서·소스·빌드·관련 단위 검증 보존 |
| UI Test | 차단. 수정 후 owned 4개 및 최종 캡처 미검증 |
| Review / Quality | 독립적인 정적 검토 수행. UI 증거를 포함한 최종 승인 보류 |
| Resolve | 소스 수정 완료. 런타임 재확인 보류 |
| Compound | 해결한 설계·음성 처리 문서 준비. 파이프라인 완료 선언 보류 |
| Pre-Ship / Ship | 최종 UI 게이트를 통과하지 않아 머지·정리 진행하지 않음 |

리서치는 [Apple 공식 기술 조사](../../brainstorms/2026-10-30-siri-health-queries-xcode-27-2-research.md), 구현 계획은 [계획서](../../plans/2026-10-30-siri-health-information.md)를 참조한다.
