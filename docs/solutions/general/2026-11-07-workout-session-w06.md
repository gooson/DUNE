---
tags: [swiftui, strength, detail-redesign, w06, accessibility, native-capture]
category: general
date: 2026-11-07
severity: minor
status: resolved-with-explicit-capture-limits
related_files: [DUNE/Presentation/Exercise/WorkoutSessionView.swift]
related_solutions: []
---

# W06 운동 시작/세션 읽기 배치

## Problem / Solution

MAX에서도 기존 활동 아이콘과 실제 운동명을 Label로 유지하고 여러 줄로 읽게 했다. normal도 같은 Label의 높이를 유연하게 했다. 현재 세트·입력·이전 값·휴식·draft·저장·완료 동작은 변경하지 않았다. 원래 아이콘·실제 운동 정의·단위·고정 CTA와 합의한 데이터 강조를 보존한다. 배치/테마 맵을 구현 전에 등록하고 같은 타깃의 W05/W06/W31 두 경로를 묶어 검증했다.

## Actual verification

iPad 일반 경로가 W05 Start→W06 이름/아이콘/입력→W31 선택→+1 Set/개수2까지 통과했다. 최대 글씨는 짧은 창에서 완료 버튼이 스크롤 내부로 들어가는 원래 scrollsChrome 분기를 확인하고, 직접 보이면 사용하고 아니면 같은 controls를 bounded scroll하도록 검사만 수정해1/1통과했다. 앱 코드는 초기4fd3과 같다. 원래 실행 수는 iPad최초2:1통과1실패→실패MAX만1:1통과다.

Phone최초2건과 재검증2건은 모두 실패했다. 최초는 identifier가 자식 leaf에 전파된 이름 그 자체의 descendants를 조회한 검사 오류였고, 수정 후 실제 전체 이름/아이콘·KG/reps와+2.5/+1입력을 확인했다. 이후 고정 완료 버튼이 controlsviewport 바깥에 있는데 그 안으로 찾으려는 검사에서 멈췄다. 두 실패 한도는 유지하고 Phone세번째 실행은 하지 않았다. W05 고정 Start의 실제 hit/다음화면, W06 실제 표현과62.5kg/11reps까지의 prefix는 관찰했으나 Phone testcase가 통과했다고 주장하지 않는다. Phone 캡처는 diagnostic·pending으로 표시한다. W31 Phone은 전혀 도달하지 못해 별도 draft로 보류한다.

[새 PNG/AX·원본 실행 수·소스·독립 리뷰](../../design/full-redesign-map/review/workout-session-w06-2026-11-07/index.html)에 normal/MAX·overview/input을 구분해 보존한다. iPad actual map은 새통과 PNG/AX, Phone은 실제 진단 캡처와 미완료 표시, Duo는 역사적이미지/현재미갱신이다. 보드의 미완료 행은 placeholder다. Source-adjudication은 W06의 정확한 View 구간 바이트를 검증된 소스와 대조하며, W06과 같은 파일의 보류 W31 hunk를 통과로 묶지 않는다.

## Review / Limits

독립 Security/Data/Architecture/Performance/Simplicity/SwiftUI/AppleUX와 실제 PNG/AX 검토를 수행했다. 새 P1/P2가 없고 해당 W06의 target표현은 source와native관찰로 확인했다. 마지막 세트 시트의 Phone medium/large/행동은 미검증이다. 결합한 두 UI harness는 원격 integration ref에 보존하고 W31 draft와 함께 둔다. W05/W06을 먼저 머지하면서 존재하지 않는 W31 ScrollView를 요구하는 새 테스트를 main에 넣지 않는다.

동일 XCTest 빌드를 재사용했고 phase별 build나 전체 로컬 회귀는 반복하지 않았다. 새 HealthKit/알림/저장 경로·카탈로그 키는 없으며 Finish/save를 호출하지 않는다. 영어UI에서도 원래 운동 이름은 한국어일 수 있다. 다른 언어/테마/다크/모든운동길이·Watch/Vision·외부영속성 증거는 아니다. Duo의 빈 소유 기기 migration실패 뒤 재실행하지 않고, l03/batch04 실종 원인/복구도 미확인 그대로다. H08/P03/P08/S03/W04의 실패 횟수는 초기화하지 않는다.

## Prevention

AX ID가 root가 아니라 leaf에 전파되는지 실제 트리를 본다. 고정 footer는 window/hittable로, 짧은 창의 inline footer는 실제 scrollviewport로 검사한다. 이름/아이콘과 입력이 다른 viewport면 각 PNG/AX를 따로 캡처한다. 실패한 결합 selector의 실행 수를 screen별 성공으로 재표기하지 않는다.
