---
tags: [life, actual-screen, iphone, partial-evidence]
date: 2026-10-28
status: partial
---

# Life Flow · 네이티브 실제 화면 (부분 증거)

이 갤러리의 PNG 10장은 **iPhone 18 Pro 전용 시뮬레이터**에서 XCTest가 첨부한 실제 앱 화면을 원본 바이트 그대로 복사했다. 시안 렌더가 아니다. 실행 앱 소스는 `19f43ee3`이며, xcresult는 `.deriveddata/ui-tests/Logs/Test/Test-DUNEUITests-2026.10.28_14-42-50-+0900.xcresult`다. 기기 UDID는 `E31D1A6A-8649-4FCF-9DAE-76DD59DE0192`다. 각 파일의 원본 첨부명, 테스트, 통과 여부, 해시와 크기는 [manifest.json](manifest.json)에 있다.

## 확보한 범위

| 화면 | 증거 | 테스트 상태 |
|---|---|---|
| L01 밝은 모드 | 히어로, 오늘 습관 카드, 리듬 | 캡처는 완료. `testCaptureL01AndPastRecordLightDarkAndMaximumAX`는 이후 접근성 제목 앵커에서 실패 |
| L01 compact hero | 밝음, 어두움, Accessibility XXXL | `testCompactHeroLayout` 통과 |
| L02 습관 편집 | 이름 입력 화면 | `testEditFlowRenamesSeededHabit` 통과 |
| L09 지난 기록 | 밝은 모드 sheet | 캡처는 완료. 위 L01/L09 종합 테스트가 이후 단계에서 실패 |
| L01 주간 돌아보기 카드 | 밝은 모드 요약 | 캡처는 완료. `testWeeklyReflectionOpensMeasuredComparison`는 이후 한국어/영어 문구 기대치 불일치로 실패 |

## 이미지 육안 확인

- 밝은 L01 히어로는 `1 / 3` 링과 큰 `2 Remaining`을 같은 카드에 보여 준다. 독서 카드의 시간 값과 수분 카드의 `0 / 8 glasses`가 서로 다른 표면과 아이콘으로 구분된다.
- 어두운 compact hero는 밝은 골드 링과 텍스트를 유지한다. Accessibility XXXL에서는 링 대신 `3개 중 1개 완료`, 큰 남은 수를 표시한다. 첫 화면의 카드 하단은 스크롤 아래로 이어지므로 이 PNG 하나로 전체 카드 높이를 판정하지 않는다.
- L09 sheet는 중간 높이 상태로 촬영되어 아래 입력 영역은 화면 밖에 있다. 스크롤 가능한 Form의 일부이며 전체 저장 흐름의 통과 증거가 아니다.
- L01 리듬 PNG는 스크롤 위치에서 촬영되어 상단 제목 일부가 내비게이션 바 아래에 있다. 보이는 7일 막대·28일 패턴·주간 요약의 내용만 확인했다.

## 미확인·제외

- L01/L09 종합 테스트는 후속 접근성 제목 앵커에서 실패했다. **L09 어두운 모드·최대 글씨 화면은 생성되지 않았다.** 이후 AX 전용 수정과 main 병합을 포함한 최종 소스의 재촬영 증거도 없다.
- L07은 카탈로그의 `HabitHeatmapDetailView`다. 실제 내비게이션 제목이 **Activity Detail**인 것을 소스와 화면 목록에서 확인해 히트맵 요약 캡처를 포함했다. L05/L06 개별 습관 이력과 구분하며, L07 완료율 차트의 최종 수정 검증은 남아 있다.
- 주간 돌아보기 요약은 L01 루트 카드다. L08 주간 리포트 상세로 분류하지 않는다.
- L08/L09의 어두운 모드·최대 글씨, iPad, Duo 접힘·펼침은 이 xcresult에 없다. 기존 디자인맵 이미지를 이번 실행의 증거로 재사용하지 않았다.
- 이 갤러리는 **UI 게이트 통과나 최종 병합 검증 완료를 뜻하지 않는다.** 실패한 테스트와 남은 범위는 실행 기록에 남는다.

[이미지 갤러리](index.html) · [통합 실제 화면 포털](../../../phone-design-map/actual/index.html)
