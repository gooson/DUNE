---
tags: [swiftui, strength, detail-redesign, w10, accessibility, native-capture]
category: general
date: 2026-11-07
severity: minor
status: resolved-with-explicit-capture-limits
related_files: [DUNE/Presentation/Exercise/Components/WorkoutCompletionSheet.swift]
related_solutions: []
---

# W10 기록 화면 큰 글씨 배치

## Problem / Solution

운동 완료 요약과 노력 입력을 큰 글씨에서 읽도록 배치했다. 원래 1세트 요약·노력 값·공유·Done 동작을 유지했다. 구현 전에 배치·테마 시안을 저장했고 실제 앱 화면과 시안을 분리했다.

## Actual verification

[새 PNG/AX와 원본 실행 결과](../../design/full-redesign-map/review/workout-completion-w10-2026-11-07/index.html)는 통과한 selector의 이름 붙은 캡처만 after로 표시한다. W27 Phone 헤더·세트 캡처는 진단 자료이며 일반 Phone 실제 맵은 미갱신이다. 실패와 누락은 원본 receipt 및 갤러리에 남긴다. 분리 PR에서도 앱 파일 SHA-256 `6f20370f45d5507e7e513b4c4fd66b8eb9cb02d1310268ab207ff10a5e3944f4`를 확인한다.

## Review / Limits

독립 Security, Performance, Architecture, Data Integrity, Simplicity, SwiftUI 관점과 현재 native 결과를 확인했다. Duo 접힘/펼침은 현재 소스 캡처가 없으면 역사적 PNG를 유지하고 미갱신으로 표시한다. 화면의 특정 스크롤 위치는 전체 화면을 한 번에 보여 주지 않는다. 외부 공유 실행·제목 저장·삭제·실제 HealthKit 쓰기는 검증 범위가 아니다.

## Prevention

원래 데이터·단위·정렬·행동을 UI 배치만으로 바꾸지 않는다. W11은 W26 세션 Share로 열린 렌더링 이미지 시트이고 W10의 시스템 공유와 다르다. 바뀐 하단 통계·세트 값·노력 입력·완료 버튼을 실제 스크롤 위치에서 확인한다. W28 PR에는 통과한 W10/W28 네 selector와 두 helper만 넣고, W11/W26 보류 초안에 실패한 기록 두 selector를 남긴다.
