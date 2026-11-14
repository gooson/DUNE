---
tags: [design, themes, native-evidence, accessibility]
date: 2026-11-14
category: testing
status: scoped-verification
---

# 최신 8개 테마 마무리 검증

기준 main은 `96d1a60e5`다. [실행 계획](../../../../plans/2026-11-14-theme-overhaul-completion.md), 현재 Today Compact·Activity Flow·Wellness Flow·Life 배치를 따른다. [실제 PNG·AX 갤러리](index.html)는 iPhone·iPad·Duo 접힘의 새 루트 192쌍을 제공한다. 이전 10월 이미지는 이력으로 보존하며 이번 완료 수에 포함하지 않는다.

## 구현 결과

- WATER LILIES Today를 21개 수련 군집·수면 붓질·깊이로 보완하고 탭·상세·시트의 밀도를 구분했다. 비활성·Reduce Motion에서 장식을 멈추며 입력과 내비게이션 상태를 유지한다.
- OCEAN·FOREST 30개 색상의 기존 Light 변형을 Any 기본값으로 바꿨다. 모든 RGBA와 Dark 변형은 유지한다. 초기 AppTheme 실행의 named-color lookup 22개 issue를 해결했다.
- Today의 데이터 선과 기간 색을 장식 강조색에서 분리했다. 여덟 테마의 밝음·어두움에서 선 3:1, 기간 4.5:1 이상을 unit으로 확인했고, 새 실제 화면에서 이전 FOREST P1 및 ARCTIC·SOLAR·SAKURA P2를 해소했다. OCEAN도 새 화면으로 확인했다.
- 일본어 전체 기간이 좁은 가로 배치에 안 들어가면 세로로 표시한다. 기간을 줄이거나 생략하지 않는다.
- 최대 글씨에서는 링 대신 외부 점수·습관 진행률을 표시하는 승인된 계약을 유지한다. 기본 링은 104pt다.
- 구현 맵의 고정 108개 가정을 현재 인벤토리 110개와 맞추고, 선언 개수 불일치·빈 목록·중복 ID를 검증한다. 테마 맵은 8개 테마와 상세 study를 구분한다.

## 검증 결과와 출처

| 범위 | 결과 | 실제 검증 소스와 한계 |
|---|---|---|
| AppTheme·WaveShape unit | 수정 후 17/17, 후속 AppTheme 12/12 통과 | 첫 수정 후 xcodebuild는 0이나 문서 편집으로 wrapper fingerprint는 실패했다. 후속 대비 검사는 wrapper도 통과했다. [기존 원본](unit-evidence.json), [보존 목록](evidence/evidence-files.json) |
| iPhone 8테마 4탭 밝음·어두움 | 8/8 메서드, PNG·AX 64쌍 | `c50647199`, iPhone 18 Pro, 402×874pt / 1206×2622px. [인덱스](../../actual/regular/capture-index.json) |
| iPhone 상세·시트·운동·MAX | 여덟 테마의 관련 selector 통과 | 기존 생산 소스의 흐름을 검증했다. FOREST 등 초기 루트 이미지는 대비 수정 전이므로 최종 루트 판정에 사용하지 않는다. 흐름·MAX 출처는 별도 보존 |
| 저장·복원 및 en/ko/ja | 관련 selector 통과 | Water Lilies 선택 복원, 언어별 루트·탭 진입. 일본어 전체 기간의 실제 화면 포함 |
| Reduce Motion·백그라운드 복귀 | 관련 selector 통과 | 실제 Settings와 UIKit 활성 상태·상세 선택 유지. Settings 복구 switch=0 뒤 UIKit readback은 지연돼 즉시 false였다고 주장하지 않는다. 혼합 batch의 Widget 실패는 그대로 보존 |
| VoiceOver | 실제 활성 상태에서 루트→상세→복귀 1/1 통과 | `c50647199`, UIKit true 및 실행 후 host 설정 false 확인. 음성·전체 읽기 순서 검증은 아님. 일반 CI에서 비활성이면 skip |
| 고대비 | 실제 활성 상태의 Water Lilies 밝음·어두움 1/1 통과 | host readback·실제 캡처, 실행 후 false 복구 |
| iPad | 10/10 메서드, 루트 PNG·AX 64쌍 | `2c8b55481`, iPad mini A20 Pro, 756×1158pt / 1512×2316px. 여덟 테마 및 Water Lilies MAX·흐름. [인덱스](../../actual/ipad/capture-index.json) |
| Duo 접힘 | 두 batch 4/4씩, 별도 Water Lilies MAX·흐름 2/2 | `861865174`, 활성 LCD, 466×678pt / 1398×2034px. 루트 PNG·AX 64쌍. 첫 batch는 UI 성공 후 metadata parser가 실패했고 저장된 원본을 재검증했다. [인덱스](../../actual/duo/capture-index.json) |
| Duo 펼침 | 이번 소스 미캡처 | 아래 실패·미검증 범위 참조. 이전 이미지를 새 완료로 표시하지 않음 |
| Watch | 16/16 메서드 통과, PNG·AX24쌍. `ddbae060e`, Apple Watch Series12(46mm), 208×248pt /416×496px. 초기16개 Home 준비 실패를 실제 화면·AX로 진단하고 테마 테스트의 lazy carousel 경로만 수정했다. [Watch 갤러리](watch.html) | UI fixture와 실전파는 별도 판정 |
| 최종 UI test helper 컴파일 | `973dea058` iOS UI target build-for-testing 통과. 후속 Watch test target도 pre-commit compile 및 native16/16 통과 | 마지막 `973dea058`의 Duo 테스트 보조 코드에 한정한 후속 검사 |
| 맵·카탈로그·도구 계약 | 최종 생성·포맷·계약 검사를 아래 최종 판정에 기록 | 앱 full 회귀를 의미하지 않음 |

테마 렌더링 코드는 `a5749e105` 이후 바뀌지 않았다. 11월15일 CI 후속 수정에서는 AI 운동 생성 결과의 출처 메타데이터를 추가하며 기존 앱 API의 반환 template과 복구 동작을 유지한다. 후속 커밋은 UI 테스트·인벤토리·실제 맵·문서 변경이다. 재사용한 증거에는 촬영 당시 revision을 유지하며 최신 문서 커밋을 붙이지 않는다. PNG·AX는 동일 capture activity 또는 acknowledged sequence와 실제 viewport로 연결하고 SHA-256을 기록한다. 시각 리뷰는 첫 viewport와 대표 흐름·MAX 표본에 한정하며 전체 스크롤·모든 상태의 육안 승인을 주장하지 않는다.

[추가 실제 화면31쌍](extras/gallery.html): iPad MAX4·흐름6(`2c8b55481`), Duo 접힘 MAX4·흐름6(`861865174`), Phone VoiceOver3·고대비8(`c50647199`). 모든 쌍의 원본 해시와 별도 provenance를 보존한다. 초기 Phone 흐름·MAX는 positive 실행 receipt와 이미지가 있으나 정확한 clean source 상태의 기계 증명이 충분하지 않아 새 공식 flow 인덱스로 승격하지 않았다. 후보 커밋 fingerprint 대조도 일치하지 않아 unknown을 false로 바꾸지 않았다.

## 실패·미검증 범위

**Duo 펼침:** T03·A01·H01·L01 × 여덟 테마 × 밝음·어두움 64조합은 이번 생산 소스에서 미캡처다. HID 프로세스가 ACK 직후 끝나 방향 변경이 취소되던 문제는 stdin 유지·upstream 대기·공식 방향 readback으로 해결했다. 이후 물리 landscapeLeft와 실제 앱 669×951pt 세로 viewport가 불일치해 UI가 실패했다. 최소 조건부 검사를 위해 물리 portrait를 요구하도록 테스트 보조 코드를 바꿨지만, 격리 전용 기기 `5B59EC29-360D-4AA9-B01F-31A8C9814FAB`에서는 hinge target 180 뒤에도 LCD만 활성이고 내부 LCD-1은 inactive여서 UI 시작 전에 중단됐다. 실제 numeric angle은 SDK에 get 경로가 없어 `null`이다. 같은 경로를 더 자동 재시도하지 않는다. functioning owned device의 내부 패널 readback과 실제 951×669pt viewport를 얻기 전에는 펼침 게이트를 완료로 닫지 않는다.

**Widget:** SpringBoard의 Edit Home Screen/App Library 사전 조건이 충족되지 않아 native family 렌더링을 얻지 못했다. 미검증 prototype 테스트는 원래 main과 동일하게 되돌렸다. Widget 소비자의 변경은 없으며 native Widget 성공을 주장하지 않는다.

**Vision:** SDK만 있고 visionOS 실행 runtime이 없다. Vision의 독립 테마 저장과 팔레트 연결을 소스로 확인했으며 실제 실행은 미검증이다. iPhone 설정과의 기기 간 동기화 기능으로 해석하지 않는다.

**iPhone→Watch 실전파:** UI override 캡처는 WatchConnectivity를 우회한다. sender의 `appTheme`와 Watch의 수신 context가 실제 선택 변경마다 일치하는 정상 실행 증거는 이번 작업에서 얻지 못했다. transport 코드는 변경하지 않았으며 렌더링 성공과 전파 성공을 구분한다.

**소스 격리:** 처음 재사용한 `detail-posture-b05/Health`에 다른 활성 Today 작업이 들어와 source freeze가 UI 시작 전에 차단했다. 그 변경은 커밋·stash·삭제하지 않았다. 완료된 캡처의 해시를 보존해 하나의 필요한 managed worktree `theme-overhaul-final/Health`로 옮겼다. 이전 기기와 원본 자료는 다른 활성 작업 보호를 위해 조작하지 않는다.

## 리뷰와 최종 판정

Security·Performance·Architecture 리뷰에 blocking finding이 없었다. Data의 선언 인벤토리 검증 P2는 수정 후 확인했다. Simplicity의 중복 scenePhase 방어 P3는 standalone/preview의 독립 동작을 위해 유지했다. Phone 대비 finding은 현재 루트로 해소했고 iPad와 Duo 접힘의 대표 실제 화면에 새 blocking finding이 없었다. Agent-Native는 지침 변경이 없어 제외했다.

품질 게이트와 최종 PR 리뷰의 판정은 아래에 기록한다. Duo 펼침의 캡처 불가 예외와 Widget·Vision·Watch 실전파 한계는 공개하며, 여덟 테마의 모든 기기·모든 상태가 완료됐다고 표시하지 않는다.

**최종 품질 게이트: 제한사항을 명시한 통과. 최종 PR 리뷰: 병합 권장, 미해결 P1/P2 없음.** P3 인벤토리 문구는 현재 110개 ID·진입 가능108개로 수정했다. [최종 리뷰 기록](final-review.md)을 따른다. 테마 맵·전체 구현 맵 `--check`, 도구 계약13개, 문자열 카탈로그 `--check --check-manual`, diff 공백 검사 통과. native247 PNG/AX쌍과 base맵12개 복사의 SHA-256 및 갤러리 로컬 참조도 검증했다. 생산 소스 `a5749e105` 대비 최종 app/Watch/Widget/Vision/Shared diff는 없다.

Duo 펼침 캡처 불가 예외는 정확한 미갱신64조합과 실패 사유를 공개하는 조건으로 수용했다. 위의 native·플랫폼 한계를 해소한 전체 완료나 전체 회귀 통과를 의미하지 않는다.

## 원본 보존

[보존 파일 목록](evidence/evidence-files.json)은 압축 전 SHA-256과 원래 로컬 경로를 기록한다. `.gz`에는 실제 로그·selector receipt·설정 readback·wrapper 실패·재시도 원인·시각 리뷰 원문을 보존했다. 경로가 옛 worktree를 가리키는 것은 출처를 유지하기 위한 것이며 해당 worktree가 지금도 동일한 소스라는 뜻이 아니다. 이력의 failed/running 기록은 최종 상태를 덮어쓰는 근거로 사용하지 않는다.
