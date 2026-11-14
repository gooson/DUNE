---
tags: [swiftui, exercise, detail-redesign, w03, accessibility, native-capture]
category: general
date: 2026-11-07
severity: minor
status: resolved-with-explicit-capture-limits
related_files: [DUNE/Presentation/Exercise/Components/ExerciseDetailSheet.swift, DUNEUITests/Full/ActivityExercisePickerRegressionTests.swift]
related_solutions: []
---

# Solution: W03 운동 화면 읽기 배치

## Problem

원래 기능·아이콘·사용자 기록·탭/시트 상태와 조작을 유지하면서 운동 화면의 일반 및 최대 글씨 읽기 배치를 개선해야 했다. W01–W04는 같은 타깃에서 구현·검사를 묶고 화면별 PR로 분리했다.

## Solution

최대 글씨에서 원래 SVG·이름·카테고리/장비와 Input/MET를 세로 배치하고 cue 번호의 최소 크기를 24pt로 했다. Close·Start의 순서와 실제 운동 정의·설명·근육 지도는 유지한다. 새로운 데이터·기간 선택·모델·문자열 키·테마 색은 도입하지 않았다. layout/theme map을 구현 전에 등록했다.

## Verification

공유 Phone 최초4건은3통과·1실패였다. 맞춤 운동 MAX는 수정 화면 진입 전 기존 템플릿 Form에서 화면 밖 Add Exercise를 스크롤 없이 기다리다 실패했다. 실제 PNG/AX에서 AI Generator와 Template Name만 보이고 버튼이 lazy 미생성인 것을 확인했다. 새 MAX audit 전용 helper에 최대12회 Form swipe와 원래 버튼의 hittable 검사를 추가했다. 앱 코드는 바꾸지 않았고 일반 글씨 경로는 원래 helper를 유지한다. 동일 b09-phone의 실패1건만 조건부 재검증하여1/1통과했고 기존3통과는 반복하지 않았다. iPad 최초4건은2통과·2실패였다. W04 전 템플릿 도구가 native More에 숨겨져 진입하지 못했다. 새 audit만 More를 여는 보완 후 W04 두 건 재검증도0통과·2실패여서 한도와 원본을 유지하고 W04는 draft로 보류했다. W01–W03의 iPhone/iPad 일반/MAX 통과만 화면별로 승인했으며 네 화면 전체 합격이 아니다. 모든 원래 수·selector·실패·소스와 기기는 [갤러리](../../design/full-redesign-map/review/exercise-detail-w03-2026-11-07/index.html)의 raw receipt가 기준이다.

W01 목록→W02 검색/info→W03 Close→picker Cancel 또는 원래 운동 선택 경로, W04 빈 이름 Create 비활성·Category Cardio 선택·원래 Duration+Distance reset·Cancel을 확인했다. 변경하지 않은 validation/create persistence는 static byte 동일성으로 확인했고 실제 새 운동 생성이나 외부 저장 검사는 추가하지 않았다. 실제 XCTest 앱 컴파일을 재사용하고 phase별 build/full regression을 반복하지 않았다.

독립 Security/DataIntegrity/Architecture/Performance/Simplicity/SwiftUI/AppleUX/AppQuality 검토와 분리 source 동등성을 확인했다. 원래 테스트와 전역 helper는 유지한다. 변경된 iOS View의 Watch/widget/Vision 소비자는 없으며 추가 로컬 실행을 만들지 않았다.

## Evidence / Limits

새 실제 iPhone/iPad 일반 PNG+AX, 별도 MAX와 검색/카테고리 상태, source hash, 원본 실행 수를 갤러리에 보존한다. 실제 맵 normal 화면과 보드도 갱신하며 Duo의 역사적 PNG는 미갱신으로 표시한다. 빈 소유 Duo의 Data Migration 실패 후 근거 없는 재시도는 하지 않는다. 원래 l03/batch04 실종 원인·복구는 미확인이며 P03/P08/S03/H08의 기존 실패 횟수를 유지한다.

UI는 영어로 실행했지만 운동 정의 이름은 기존 데이터의 한국어/영어 값이 그대로 보일 수 있다. 모든 번역·다크·테마·모든 운동 길이를 검증한 것은 아니다. W01 두 줄 상한의 장문 wrapping 자체가 모든 fixture에 나타났다고 주장하지 않는다. W02 MAX 검색 입력의 native 말줄임과 W04의 변경하지 않은 Input Type menu 값 말줄임은 남아 있으며 AX는 전체 상태를 읽는다. W03 lower Input/Weight+Reps/MET/5.0의 MAX 세로 frame은 fresh AX에서 비중첩으로 확인했지만 해당 하단의 on-screen PNG/스크롤 상호작용을 완료했다고 주장하지 않는다. 원래 toolbar·아이콘·설명·데이터 강조는 보존한다.

## Prevention

고정 프레임은 Button 바깥 장식보다 label/contentShape의 실제 hit region에 적용한다. Lazy Form의 화면 밖 컨트롤은 새 audit 범위에서만 bounded scroll로 찾는다. 변경하지 않은 저장 로직을 시각 검사에 무리하게 추가하지 않는다. 통과한 selector는 source·fixture·영향 구간이 동일하면 재사용하고 원래 실패는 그대로 남긴다. 정적 시안·과거 PNG·실패 teardown을 native pass로 승격하지 않는다.
