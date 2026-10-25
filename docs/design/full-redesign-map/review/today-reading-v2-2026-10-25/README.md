---
tags: [today, swiftui, typography, dynamic-type, actual-capture]
date: 2026-10-25
category: testing
status: verified-feature-scope
---

# Today 하단 V2 실제 화면

[갤러리](index.html) · [출처 목록](capture-index.json) · [방향 시안](../../../theme-map/themes/dune-today-reading.html) · [검증 결과 원본](evidence/)

T03 회복·수면, 장기 스트레스, 오늘의 요약과 T10 일간 요약을 이 작업 소유 전용 기기에서 캡처했다.38장의 원본 PNG다. [기기별 축소 비교 보드](board.png)는 그중8장을 모은 파생 이미지이며 원본 캡처 수에 더하지 않는다. 데이터는 seeded fixture이며 사용자 사진의 실제 건강 기록이 아니다. Xcode27.1, ko_KR, 고정 시각21시, 자동 Morning Briefing 비활성 조건이다.

| 기기·자세 | 실제 캡처 | 최종 관련 테스트 |
|---|---:|---|
| iPhone18Pro / iOS27.0 |17장 |2/2통과. 이전44018fcc의7/7에는 밝음·어두움·AXXXL와 상세 경로 포함 |
| iPadPro13(M5) / iOS27.0 |7장 |2/2통과 |
| Duo 외부 LCD / iOS27.1 / 실제 힌지0° |7장 |2/2통과. AX창466×678pt |
| Duo 내부 LCD-1 / iOS27.1 / 실제 힌지180° |7장 |초기1/2, 실패한 카드 검사 수정 후1/1통과. 기존 통과 T10결과 유지. AX창951×669pt |

Duo 펼침의 첫 실패는 테스트가 `dashboard-stress-contributions`를 물려받은 장식 Image를 선택해 지나쳐 스크롤한 문제였다. 앱 소스는 변경하지 않고 테스트의 읽기 대상만 StaticText로 바꾸고 작은 양방향 drag를 사용했다. 실패 기록과 별도 재시도 결과를 보존한다. `duo-open/notification-digest.png`는 최초 실행에서 통과한 T10 case의 이미지이며 전체 번들에는 다른 case실패가 있다. 나머지 펼침6장은 재시도 통과 결과다. 인덱스에서 case상태와 번들상태를 구분한다.

이전 devicectl의 `device motion hinge-angle`은 현재 도구에 없다. 외부 source7acb090dd7d28fb0aea8e1907211ceff15aa450e의 검토한 HID setter만 사용하고, public UIKit.UIHingeInteraction을 붙인 독립 보조 앱으로 실제 각도·상태·시각을 읽었다. [읽기 코드](evidence/HingeProbe.m), [닫힘 읽기값](evidence/duo-closed-hinge.json), [펼침 읽기값](evidence/duo-open-hinge.json), 각 활성 디스플레이 JSON을 보존한다. 이 보조 앱은 제품 코드가 아니다. 방향 설정 직후 값과 앱 재활성 뒤 compositor방향이 달라, 실제 native PNG와 AX창 크기를 기준으로 설명한다. 펼침은 실제 가로창의 증거이며 펼침 세로·회전 전환의 합격으로 확대하지 않는다.

앱 구현 소스는14d37e32다. iPhone·iPad 캡처 HEAD는 문서 커밋d1d09bcf, Duo접힘 및 첫 펼침은 main병합fc05f89c, 펼침 재시도는 테스트 수정a8fa79b8다. 이 사이 Today 제품 소스에는 diff가 없다. 인덱스의 source_commit은 캡처 당시 HEAD, app_source_commit은 해당 카드 소스 기준이다. iPhone의 기존 variant10장은44018fcc를 유지하며 최신 캡처로 재표기하지 않는다.

눈금·기간·수치·근거·요약의 가시 영역을 실제 이미지로 확인했다. 최대 글씨와 긴 원문은 스크롤 viewport캡처라 화면 밖까지 동시에 검증했다고 주장하지 않는다. 기본 DUNE 외 다른 테마, iPad/Duo의 어두움·최대 글씨, 펼침 세로·물리 회전 전환, 실제 HealthKit 권한·센서 상태, 기록 없음 native상태, 전체 UI회귀는 이번 증거에 포함하지 않는다. Watch는 이 카드 소비자가 없어 영향 제외다.

다른 UDID를 사용한 기존 actual/regular·ipad·duo·duo-open 인덱스와 보드는 덮어쓰지 않았다. 통합 실제 화면 포털은 이 최신 갤러리로 연결한다. iPad의 이전 잠금 실패2회는 기록으로 남기며 사용자의 명시적 허용 뒤 잠금 해제를 확인해 검증을 재개했다. 초기 공통 smoke36건 중34건 통과, 변경되지 않은 알림함2건은 자동 Morning Briefing 시트가 앞에 있어 실패했다. 이 기록을 전체 UI성공으로 바꾸지 않는다.
