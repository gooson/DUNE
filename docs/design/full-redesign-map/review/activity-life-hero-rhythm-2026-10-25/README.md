---
tags: [design, activity, life, hero, actual-capture, accessibility]
date: 2026-10-25
category: validation
status: partial
---

# Activity·Life 히어로 — 흐름과 근거 실제 화면

[실제 화면 갤러리](index.html) · [캡처 출처](capture-index.json) · [실행 결과](test-results.json) · [승인 계획](../../../../plans/2026-10-25-activity-life-hero-rhythm.md)

A01에 HRV·수면·회복의 구성 점수와 저장된 준비도 이력을 추가했다. L01에는 현재 완료·대상·남음 요약과 현재 수동 습관의 일별 완료 기록을 추가했다. 기존 124pt 링, 준비도 상세와 체크리스트 목적지를 유지한다. 큰 글씨의 기록은 날짜·값 목록으로 전환한다.

이 갤러리는 새 앱 빌드의 실제 PNG 23장이다. 시안 이미지가 아니며 원본 픽셀을 수정하지 않았다. 모든 건강·습관 값은 UI 테스트의 고정 fixture다. 기본 테마는 DESERT HORIZON이다.

| 기기·상태 | 새 PNG | 검증 |
|---|---:|---|
| iPhone 18 Pro Max · 밝음/어두움 | 4 | A01·L01 개요 |
| 같은 iPhone · 어두움/접근성 XXXL | 4 | 개요와 마지막 날짜까지 스크롤한 하단 |
| 같은 iPhone · 기록 부족/자동 연동 습관만 있음 | 3 | 임의 이력·가짜 0/0 없음 |
| iPad Pro 13-inch (M5) · 밝음/어두움 | 4 | A01·L01 개요 |
| Duo 외부 LCD · 세로 · 밝음/어두움 | 8 | 개요·기록, 활성 외부 화면과 방향 readback |
| Duo 내부 LCD-1 · 가로 | 0 | 회전 readback이 세로에 남아 미완료 |

기존 기기 인덱스의 다른 UDID와 섞지 않고 통합 포털에서 이 갤러리로 연결한다. 기존 Duo 내부 A01·L01 이미지는 이번 변경의 증거로 사용하지 않는다.

## 데이터와 접근성 확인

- 준비도의 과거 값은 저장된 hourly snapshot 중 날짜별 최신 유효값이다. 결측을 보간하거나 0점으로 표시하지 않는다. 오늘은 링의 현재 점수와 일치시킨다. 구성 점수는 원시 HRV·수면 시간이 아닌 100점 기준 점수다.
- 습관 차트에는 과거 분모를 만들지 않는다. 수동 습관의 실제 완료 횟수를 세며 skip·snooze·자동 완료·미래·생성 전 기록을 제외한다. 수동 습관이 존재한 날짜의 완료 0회와 생성 전 결측을 구분한다. 현재 진행은 주기형 습관의 현재 상태도 포함하므로 일별 완료 기록과 의미가 다르다.
- 자동 연동 습관만 있으면 시작 안내를 표시한다. 기존 추가 메뉴에서 템플릿 화면에 진입하는 검사도 통과했다.
- 최대 글씨의 날짜·값 열과 마지막 값·하단 행동은 겹치거나 잘리지 않았다. 하단 캡처는 스크롤된 화면이며 카드 전체가 한 화면에 들어온다는 증거가 아니다. Activity 하단의 10/19 행은 이 스크롤 위치에서 상단 내비게이션 위에 있다.
- SwiftUI·Apple UX 사전 점검의 P2(고정 테마 카드의 보조 문구 대비, 링크 내부 접근성 그룹, 0회/결측 구분, 결측 음성 레이블)는 수정했다. Activity 머리말과 하단의 같은 상세 링크는 기존 접근성 식별자와 동작 호환을 위한 P3 선택으로 유지한다. VoiceOver 전체 탐색과 대비 비율 계측은 미검증이다.

## 실제 실행과 남은 게이트

관련 단위 테스트는 41/41 통과했다. 최초 iPhone UI 합집합은 39개 중 37개 통과, 2개 실패였다. 새 히어로 9개는 모두 통과했으며, 실패는 변경하지 않은 `DashboardSmokeTests/testNavigateToNotificationHub`와 `testNotificationHubSummaryAtMaximumAccessibilitySize`다. 로그에는 잘못된 AX hit point `{-1,-1}`가 있었지만, baseline 실패라고 입증하지는 않았다. 새 fixture는 opt-in이며 이 두 테스트에서는 켜지지 않는다. 이 실패를 면제하거나 전체 UI 통과로 보고하지 않는다.

후속 iPhone delta 실행은 8개 중 7개 통과했고, 자동 연동 빈 상태 테스트가 닫힌 Menu의 항목을 바로 조회하여 실패했다. 테스트를 실제 메뉴 순서로 고친 뒤 실패한 검사와 기록 부족 검사를 2/2 통과했다. 이전 7개 통과 증거를 보존하며, 새 실행 2개를 8개 전체 재실행으로 계산하지 않는다. 기존 Life 설명 배치 검사도 1/1 통과했고 밝음·어두움·최대 AX의 3상태를 검사했다. iPad와 Duo 외부 캡처는 각각 4/4 통과했다. 전체 회귀·Watch 검증은 수행하지 않았다.

Duo 최초 준비는 현재 CoreDevice 651.13.5에 없는 `device motion hinge-angle` 조회 때문에 UI 검사 전에 실패했다. 현재는 공식 활성 화면·물리 방향 readback과 fresh native viewport로 **배치만** 검증한다. 숫자 힌지 각도는 미검증이다. 외부 화면은 LCD·portrait를 실행 전후 확인했다. 내부는 LCD-1이 활성화됐지만 검토한 HID 회전 도구의 성공 응답 뒤에도 공식 readback이 portrait여서 가로 캡처를 시작하지 않았다. 공식 `orientation set/get` 대안 확인은 처음에는 다른 worktree의 UI 실행이 저장소 잠금을 보유하여 60초 후 시작하지 못했다. 이후 잠금 해제를 비차단 조회로 확인하고 한 번 실행했지만, setter는 landscapeLeft 성공을 반환하고 실제 getter는 portrait에 남아 assertion이 실패했다. 두 설정 경로 모두 같은 조건으로 다시 실행하지 않았다.

재개 조건: 수정된 회전 도구 또는 외부에서 복원한 시뮬레이터 상태가 이 worktree 소유 Duo `D472D221-3BB2-44F0-A2B7-8EF63A9EEE5D`에서 공식 `landscapeLeft` readback·활성 LCD-1을 보여야 한다. 그때 내부 A01·L01 캡처만 한 번 재시도한다. 실패한 회전 경로를 같은 조건으로 반복하지 않는다. Today 알림함 두 실패의 처리 범위는 사용자 선택을 기다리고 있으며, `/run` Phase 2.5 게이트를 아직 통과하지 않았다. 정식 Review·Compound·Ship은 미실행이다.

## 출처

앱 소스는 `471a82f0`와 동일하며 이후 `88790777`은 기존 UI 테스트의 스크롤 조건만 바꿨다. iPhone 캡처 당시 기준 커밋은 `38ce0d8c`, 앱 수정은 미커밋 상태였다. iPad는 `471a82f0`, Duo 외부는 `88790777`이다. 앱 파일 hash, 실제 UDID·시각·테스트·원본 PNG hash는 `capture-index.json`에 기록했다. 캡처 후 문서·갤러리 변경은 앱 픽셀 검증의 범위를 넓히지 않는다. 자동 검증 receipt의 전체 worktree fingerprint는 후속 문서 변경으로 stale일 수 있으므로 앱 소스 일치와 실제 실행 범위를 구분한다.
