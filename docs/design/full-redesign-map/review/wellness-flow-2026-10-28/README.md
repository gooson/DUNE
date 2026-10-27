---
tags: [wellness, flow, native-capture, accessibility, design-map]
date: 2026-10-28
category: review
status: reviewed
---

# Wellness Flow · 실제 화면 · 2026-10-28

[갤러리](index.html) · [이미지별 출처·해시](manifest.json) · [검증 영수증](proof/verification.json)

Duo · LCD, Duo · LCD-1, iPad Pro 13-inch (M5), iPhone 18 Pro에서 H01 Flow 실제 화면 66장을 보존했다. iPhone·iPad 이미지는 통과한 XCTest의 이름 붙은 첨부 파일이며, Duo 이미지는 통과한 호스트 체크포인트의 활성 패널 원본이다. PNG는 수정하지 않았다. 화면 내용은 테스트 데이터이며 사용자 건강 기록이 아니다.

| 선택 실행 | 결과 | 근거 |
| --- | ---: | --- |
| Phone 원본 batch | 41/46 통과, 5 실패 | `ui-phone.log.result.json` |
| Phone 관련 실패 보정 | 3/3 통과 | `ui-phone-corrections.log.result.json` |
| Phone 독립 기록 probe | 1/1 통과 | `ui-phone-probe.log.result.json` |
| Phone 최종 delta | 3/3 통과 | `ui-phone-final-delta.log.result.json` |
| Phone 현행 기준선 건강 상세 | 1/1 통과 | `ui-phone-health-baseline-final.log.result.json` |
| iPad 기본 선택 검사 | 5/5 통과 | `ui-ipad.log.result.json` |
| iPad 현행 건강 상세 | 1/1 통과 | `ui-ipad-health-final.log.result.json` |
| iPad 신체 네 항목 전체 프레임 | 1/1 통과 | `ui-ipad-body-final.log.result.json` |
| Duo 닫힘 호스트 캡처 | 2/2 통과 | `duo-closed/ui.log.result.json` |
| Duo 펼침 호스트 캡처 | 2/2 통과 | `duo-open/ui.log.result.json` |

원본 Phone batch의 Wellness 실패 3개는 선택 재실행에서 보정됐다. 남은 Dashboard 알림 2개 실패의 AX에는 `dashboard-morning-briefing-screen`과 한국어 ‘좋은 아침’ 오버레이가 나타났다. 이 실패는 Wellness 변경 범위 밖이다. 알림·Today 소스나 기본 seed 동작은 이 작업에서 바뀌지 않았다. 기기별 class/method 중복을 제거한 최종 선택 검사 목록은 Phone 47, iPad 6, Duo 닫힘 2, Duo 펼침 2로 **57개 통과·범위 밖 2개 실패**다. 이 수치는 전체 앱 suite 통과가 아니다. 원본 영수증과 선택 목록, 단위 테스트 19/19 영수증은 `proof/verification.json`에 보존했다.

원본 Phone batch의 실행 HEAD·앱 소스는 `22ea46ae`였다. `e4a56620`은 테스트 전용 변경이다. 앱 변경 `b1dbdfda`는 Desert Warm 이외 링 색과 최대 글씨 자세 헤더를 수정했다. 원본 Desert Warm 밝음·어두움 이미지는 이 표현에 영향받지 않는다. 이후 앱 변경 `6c1d3f77`은 손목 온도 기준선 설명, 관측 수면이 10시간을 넘는 경우의 bar scale, 쓰이지 않는 hero 인자를 수정했다. 영향받는 건강 상세는 iPhone·iPad 모두 이 소스에서 다시 촬영했다. `887c2d3e`와 `08b320c7`의 후속 차이는 테스트 전용이며 앱 화면 소스는 `6c1d3f77`이다. manifest는 각 PNG의 실행 소스와 앱 소스를 따로 보존한다.

iPad `body-light`는 첫 viewport의 신체 카드 시작 부분만 보이므로 네 항목의 전체 배치 근거는 별도 `body-detail-light`다. 원본 `health-light`도 Health Indicators 제목만 하단에 걸쳐 있어 펼쳐진 카드 근거는 현행 `health-detail-light/dark`를 사용한다. 독립 dark 진단 실행(7363)은 갤러리에 포함하지 않았다. `hero-Ocean`은 별도 Ocean 테마 링 확인 화면이다.

Duo 닫힘은 외부 `LCD`, 펼침은 내부 `LCD-1`의 활성 패널과 native viewport를 전후 display readback, 실제 PNG 크기, AX viewport×scale, 새 hierarchy로 확인했다. 각 상태의 H01 10장만 gallery card에 넣고 짝이 되는 비활성 검은 PNG와 두 system view chrome을 `proof/duo-*`에 보존했다. 호스트 getter가 접힘각을 돌려주지 않아 `actualAngle=null`, `angleVerified=false`다. 따라서 물리 접힘각이 아니라 활성 패널과 viewport를 검증한 결과다. 이 호스트 사진을 XCResult screenshot으로 표시하지 않는다.

이 증거는 요청한 기기·상태의 대상 검사다. 전체 UI 재실행은 요청되지 않았고, Watch의 nonempty 상태, VoiceOver 실제 조작, 한국어·일본어 런타임, 전체 테마 조합은 검증하지 않았다. `proof/verification.json`은 실제 실행 영수증의 복사본·해시와 이미지·proof 파일 해시를 기록한다.

호스트 실행 원본 로그 두 개는 `proof/duo-*/ui.log.gz`에 무손실 gzip으로 보존했다. 원본의 공백을 고치지 않았으며 압축 해제한 SHA256과 archive SHA256을 `proof/verification.json`에 함께 기록한다.
