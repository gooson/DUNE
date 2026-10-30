---
tags: [today, local-time, timezone, morning-briefing, native-capture]
date: 2026-10-31
category: general
status: implemented
---

# 로컬 시간 인사·Today 인사이트 실제 화면

[새 캡처 17장](index.html)과 [화면별 출처·해시](manifest.json)를 보존한다. 기존 다른 worktree·기기의 PNG는 이번 변경의 증거로 사용하지 않았다.

## 표시 기준

- 아침 인사와 브리핑 자동 표시: 기기 로컬 시간 06:00–09:59. 00:00·10:00·11:59에는 아침 인사를 표시하지 않는다.
- 다른 시간에 브리핑을 수동으로 열면 기능명 `Morning Briefing`을 표시한다.
- Today 하단과 컨디션 상세 인사이트는 22:00–05:59에 회복 안내를 사용한다. 운동 시작·낮의 야외 운동 권유는 제외하고 회복/수면 경고와 폭염·한파 정보는 보존한다.

## 최종 검증

| 범위 | 결과 | 새 실제 PNG |
|---|---|---|
| 관련 단위 3개 suite | 40개 통과 | 해당 없음 |
| iPhone 18 Pro Max | UI 2건 통과 | T03 자정·하단 인사이트, T04 자정, T09 06시·11시: 5장 |
| iPad mini (A20 Pro) | UI 1건 통과 | T03 자정·하단 인사이트, T04 자정, T09 11시: 4장 |
| Duo 접힘 | UI 1건 통과 | 같은 4개 상태: 4장 |
| Duo 펼침 | UI 1건 통과, native 캡처용 동일 경로 추가 1건 통과 | 같은 4개 상태: 4장 |

기능 검증은 기기별 총 5건이며 펼침 native 캡처 실행 1건을 별도로 기록한다. JSON receipt는 이 디렉터리의 `*-result.json`에 보존한다. 선택한 테스트만 실행했으며 전체 UI 회귀를 의미하지 않는다.

앱은 DEBUG `--ui-dashboard-hour`로 00시·06시·11시를 사용한다. **상태 막대는 실제 기기 시각**이므로 화면 상단 시간이 테스트 시각과 다를 수 있다. mock 건강 데이터, 밝은 DUNE, 영어, 기본 글씨의 증거다. 다른 테마·언어·큰 글씨 전체를 검증했다고 표시하지 않는다. Watch는 이번 변경의 소비자가 아니다. AI는 프롬프트의 로컬 시간 전달을 검증했으며 실기기 생성 결과를 검증한 것은 아니다.

## Duo 펼침 캡처

기존 테스트 실행기의 clone 이름은 `iPhone 17-wt-Health-f282-0ed31d09679e`지만 실제 기기는 Duo이며, UDID는 `4DDDAB52-9B0B-43B9-9CF7-4140AB0FBCC1`이다. 접힘은 외부 LCD 활성, 펼침은 내부 LCD-1 활성·landscapeRight를 실행 전후 공식 `devicectl device info displays` JSON으로 확인했다. 펼침 원본은 2853×2007px, viewport는 951×669pt다. 각도 수치 자체는 측정하지 않았다.

펼침의 최초 XCTest `app.screenshot()` 첨부 4장은 검은 PNG였으므로 갤러리에서 제외했다. `rejected_captures`는 그 출처만 기록한다. 기존 `DUNEUITests-DuoAudit`·`duo-visual-audit.py`의 명시적 UDID와 ACK 핸드셰이크로 활성 내부 디스플레이를 다시 캡처했다. 8개 checkpoint가 모두 ACK됐고 실행기는 exit 0이었다. 이 가운데 요청 상태 4장의 내부 화면만 보존했고 비활성 외부 화면의 검은 PNG는 제외했다. 원본 PNG를 편집하거나 이전 캡처로 대체하지 않았다.

Device Hub 전환 준비용 lock lease는 90초 만료(exit 124)로 끝났다. 이후 내부 화면 활성 상태를 readback으로 확인하고, 새 표준 UI runner가 실행권을 다시 얻어 통과했다. 준비용 lease를 UI 통과로 계산하지 않았다.

앱 소스는 최종 단위·기능 검증 이후 변경하지 않았다. 캡처 테스트에만 opt-in `VisualAudit.capture`를 추가했으며 일반 Full plan에서는 기존 기능 경로가 유지된다. 앱 소스 해시와 실행별 테스트 소스 증거는 manifest에 구분했다.
