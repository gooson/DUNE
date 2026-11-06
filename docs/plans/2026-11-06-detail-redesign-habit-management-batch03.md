---
tags: [detail-redesign, habits, targeted-ui, validation-reuse]
date: 2026-11-06
category: plan
status: done
---

# L02·L04·L09 습관 관리 묶음

사용자는 관련 화면의 구현·빌드·검증을 묶고 화면별 PR을 유지하도록 승인했다. 기존 12개 습관 아이콘·폼·검증·일정·알림·저장·복원·날짜/총량 계산을 유지한다. L02는 새/수정 상태와 입력 이름을 히어로로, L04는 실제 필터별 건수와 원래 행을 HeroCard/StandardCard로, L09는 실제 선택 날짜와 습관 아이콘을 히어로로 강조한다. MAX에서는 콘텐츠 높이와 자연 줄바꿈을 유지한다.

## 조사와 영향

LifeView의 신규/수정 시트·지난 기록 시트와 ContentView의 관리 목적지를 확인했다. 기존 관련 해결책은 습관 일정 시작점, archive management, action menu, date-sensitive boundaries 및 Life hero rhythm이다. 기존 brainstorm과 완료 todo 072/073/074는 배경이며 현재 구현 증거가 아니다. 재사용할 컴포넌트는 기존 HeroCard/StandardCard/DS 색상·간격과 native Form이다. Domain/ViewModel/저장 스키마·서비스·공통 실행기는 변경하지 않는다. 원래 onSave/Cancel·active/archived @Query와 기록 합계·오늘 불변식을 보존한다.

## 구현 단위

L02: HabitFormSheet.swift와 LifeRegressionTests의 신규/수정/큰 글씨 검사.
L04: HabitManagementView.swift와 LifeRegressionTests 관리 검사, DuoRemainingRouteTests 복원 검사. 공유 테스트 파일은 L02 이후 prefix를 유지한다.
L09: HabitPastRecordSheet.swift와 LifeFlowUITests의 종류별 취소/어제30→40대체/큰 글씨 검사. 기존 --ui-hero-rhythm-fixtures를 그대로 사용한다.

각 전용 layout/theme 맵과 index/manifest를 앱보다 먼저 갱신하며 정적 시안과 실제 캡처를 구분한다. 각 화면별 구현 커밋을 쌓고 하나의 통합 소스를 검증한다. 최종 PR은 L02→L04→L09 순서로 main 기준으로 분리하며 마지막 PR은 통합 검증 커밋 ancestry를 보존한다.

## 핵심 검증

정확한 selector는 각 화면 계획과 실행 전 source-rebind.json에 고정한다. 정상 5개 메서드를 일반 iPhone·iPad·Duo 접힘·펼침 각각 실행하고 접힌 Duo MAX 3개 메서드를 더해 23개 메서드·프로필 조합을 검증한다. 한 번에 소유 기기1개·표준 runner1개, jobs2·index OFF·테스트 병렬 OFF·1200초/실행·300초/case를 적용한다. 예상 실행이 초과하면 소유 기기를 유지하며 검사 묶음을 나누고 캐시를 재사용한다. 같은 소스의 컴파일을 별도 build로 반복하지 않는다. 기능이 바뀌지 않은 계산의 전체 unit/fullUI를 실행하지 않는다.

각 프로필의 새 PNG/AX를 수집해 입력 키보드·아이콘·가독성·44pt·가상화 행·복원/복귀를 독립 검토하고 해당 actual-map 행을 갱신한다. 실패·source·횟수는 보존하고 원인 수정 근거가 있는 실패 검사만 조건부 재시도한다. Mac 잠금을 실패로 추정하지 않는다. 신선한 실제 증거와 열린 P1/P2 없음·Compound·화면별 정상 PR 머지가 완료 기준이다. Dark/VoiceOver/실기기/전체회귀는 별도 수행 없이는 완료로 주장하지 않는다.

## 공유 검증과 화면별 게시

23개 정확한 메서드·프로필 조합과 실제 PNG·AX 144쌍의 독립 검토를 마쳤다. 원본 실패 6건의 aggregate와 원래 재시도 기록은 source closure에 보존하고, 중복 장면을 제외한 82쌍만 화면별 갤러리에 게시했다. 각 화면의 네 일반 프로필 actual-map 행과 레이아웃·테마·해결 문서를 갱신했다. L02 PR #932와 L04 PR #933은 일반 머지했으며 L09의 PR/CI 결과는 별도 기록을 따른다. 최종 PR HEAD 전체 회귀·Dark·VoiceOver·실기기·Watch 실행으로 확대하지 않는다.
