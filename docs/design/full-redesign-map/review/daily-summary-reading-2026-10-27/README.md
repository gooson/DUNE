---
tags: [today, digest, actual-capture, dynamic-type, ipad, duo]
date: 2026-10-27
category: review
status: reviewed
---

# 오늘의 요약 · 핵심 먼저 실제 화면

[갤러리](index.html) · [사진별 출처·SHA-256](captures.json) · [리뷰와 실행 기록](../../../../reviews/2026-10-27-daily-summary-reading.md)

25장의 활성 화면 원본과 10장의 비활성 패널 짝을 보존했다. 시안이나 실제 사용자 건강 기록이 아닌 seeded 시뮬레이터 앱이다. 한국어, 밝음, desertWarm, 저녁21시 fixture이며 큰 글씨는 iPhone AXXXL 접근성 범주(UICTContentSizeCategoryAccessibilityXXXL)다. 앱 카드 소스는 `4f09dff3` 이후 동일하며 해시는 captures.json에 있다. `final_test_artifact_sha256`는 최종 촬영 테스트 파일의 해시다. iPhone 기본 캡처는 초기 촬영 헬퍼, 최대 글씨의 하단 두 장은 기존 동작 검사에서 얻었으며 앱 표시 소스는 같다.

| 범위 | 실제 결과 |
|---|---|
| iPhone 핵심 동작 | 일반·최대 글씨2/2 통과. 원문 펼침·미리보기 교체·접기·상태·44pt·행 오른쪽 터치 |
| iPhone 상단 촬영·알림 | 첫3개 중 일반·알림2개 통과, 최대 글씨 촬영1개 실패. 실패 항목만 보정했고 최종 최대 글씨1개 통과 |
| iPad | Today 상단/펼침과 알림 상세2/2 통과·정상 종료 |
| Duo 외부 LCD | Today·알림2/2 통과·정상 종료. AX 창466×678pt, native1398×2034px |
| Duo 내부 LCD-1 | 복구 후 Today·알림2/2 통과·정상 종료. AX 창951×669pt, native2853×2007px |
| Duo 내부 T10 | 최종 실행에서 요약의 새 접힘/펼침 원본 확보. 첫 미도달 실행과 구분 |

촬영 헬퍼의 첫 실패는 Label의 장식 Image가 첫 대상으로 선택된 것이었다. 실제 텍스트 기준으로 바꾼 뒤 상단 촬영이 성공해 이 원인은 해소됐다. 이후 처음 도달한 펼침 후 복귀 단계에서 위쪽 지표를 찾으며 위로만 스와이프하는 별도 방향 오류를 확인했다. 초기 탐색과 상단 복귀를 분리하고 실제 제목 프레임으로 방향을 정해 해당 단계1회 검증을 통과했다. 앱과 기존 핵심 동작 검사는 바꾸지 않았다. 각 실패와 수정 근거는 proof의 remediation 문서를 따른다.

Duo 내부 첫 캡처 실행은 teardown 디스플레이 열거8초 초과로 중단됐다. 소유 xcodebuild/test-ui 프로세스 종료를 확인했으며, 직접 native 캡처와 후속 simctl list도 각각8초·15초 초과해 바로 재시도하지 않았다. 공식 `devicectl device reboot --device <전용Duo>`로 이 기기만 재부팅한 뒤 실제 조회·PNG 생성이1.51초, 내부 포트의 열거·PNG 생성이1.16초에 끝난 것을 확인했다. 사용이 끝난 전용 iPhone·iPad도 종료했다. 이 원인 해소 증거 후 미완료 두 selector만1회 실행해2/2 통과·정상 종료했다. 갤러리의 내부 이미지는 이 최종 성공 실행으로 교체했고, 첫 실패 runner/checkpoint 및 복구 근거는 proof에 남겼다.

`proof`에는 실행기 receipt, 원본 checkpoint/runner 결과, 새 AX 계층, Duo 활성 패널 전후 readback, Swift Testing13개 통과 summary를 보존했다. 비활성 패널은 paired에 있으며 UI 완료 증거로 세지 않는다. 모든 활성 PNG를 육안으로 대조했고, 큰 글씨는 상단과 기존 본문·제어 viewport를 함께 읽는다. 한 화면에 전체 큰 글씨 카드가 들어온다고 주장하지 않는다. 최신 iPhone T10 사진은 스크롤된 상단으로 헤더가 내비게이션 뒤에 있으며, 전체 카드 배치는 같은 공유 컴포넌트의 T03 및 iPad/Duo 외부 T10 원본을 함께 대조한다.

수치 힌지 각도·물리 회전·실기기 VoiceOver, 어두움·다른 테마·iPad/Duo 최대 글씨·기록 없음은 미검증이다. 전체 회귀는 요청되지 않아 실행하지 않았다. 이 iOS 카드는 Watch에서 사용하지 않는다. 기존 다른 UDID의 인덱스는 이번 새 출처로 덮어쓰지 않았다.
