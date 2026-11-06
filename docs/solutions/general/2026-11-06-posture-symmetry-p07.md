---
tags: [swiftui, posture, detail-redesign, p07, accessibility, native-capture]
category: general
date: 2026-11-06
severity: minor
status: resolved-with-capture-limits
related_files: [DUNE/Presentation/Posture/PostureSymmetryView.swift, DUNEUITests/Full/WellnessRegressionTests.swift]
related_solutions: []
---

# Solution: P07 자세 상세 개편

## Problem

원래 기능·값·기호를 보존하면서 자세 상세의 읽기 위계를 일관되게 해야 했다. 같은 앱 타깃의 P05·P07·P08을 한 번의 증분 빌드와 묶음 검사로 검증하고 PR은 화면별로 분리했다.

## Solution

기존 제목·평가일을 불투명 히어로에 배치하고 세 지표의 원래 좌우 값·단위·차이·색 막대·설명을 카드로 정리했다. 밝은 배경의 상태 문구·아이콘·요약 화살표만 더 어둡게 하여 읽기 대비를 확보했다. 원래 막대 색·계산·값·아이콘·데이터·없음 상태는 유지한다. MAX에서 세로 읽기와 전체 값의 접근을 확인했다.

## Verification

현재 소스의 iPhone 일반/MAX 검사 모두 통과했다. 각 테스트는 저장된 어깨50.0/48.0cm·골반0.0/-1.0cm·무릎8.1/2.7°의 여섯 값을 확인하고 MAX에서는 전체 frame이 보이는지 검사한다. iPad 일반 검사도 통과했다. 독립 PNG·AX 리뷰에서 상태 문구와 전체 값·단위가 읽히는 것을 확인했다. 확인한 iPad 밝은 일반 화면의 Caution 대비는 약8:1이며 다른 테마·다크 모드의 측정으로 확대하지 않는다.

최종 공유 iPhone 실행은 4개 중3통과·1실패다. 통과한 P07 일반/MAX·P08 MAX와 실패한 P08 일반 사진 확대 전 가시성 검사를 분리한다. iPad 최초3개 중2통과·P08 실패, P08 재시도1개 실패도 원본 그대로 보존했다. 이 P07 판정은 해당 화면의 통과한 selector와 바이트가 같은 View에 한정되며 B06 전체 합격이 아니다. Security·Performance·Architecture·Data Integrity·Simplicity·SwiftUI·Apple UX·App Quality 및 최종 PR 소스의 독립 검토에서 P07에 남은 차단 사항은 없었다.

단일 수치 분수 `%lld / 100`의 수동 en/ja/ko 등록과 카탈로그 포맷을 검사했다. View·테스트를 실제 컴파일하고 실행한 공유 결과를 재사용하며 문서 단계에서 다시 빌드하지 않는다. Watch·Vision·widget은 해당 View를 소비하지 않고 로컬 전체 회귀는 요청되지 않아 실행하지 않았다.

## Evidence / Limits

[새 실제 화면·AX·변경 전 비교](../../design/full-redesign-map/review/posture-symmetry-p07-2026-11-06/index.html)에 캡처 소스·selector·시각·기기·SHA와 원본 실행 수를 보존했다. iPhone 일반/MAX와 iPad 일반만 이번 증거다. iPad MAX와 Duo 접힘·펼침의 현재 캡처는 없다. 전용 Duo는 부팅 migration 실패 후 기기 목록에서 사라져 재개 근거가 없었으며 원인·복구는 미확인이다. Duo 실제 맵은 이전 이미지를 유지하고 미갱신으로 표시했다. 이전 PNG는 새 증거가 아니다.

합성 두 기록과 시스템 심볼 사진의 격리 fixture를 사용했다. 실제 카메라 추론·다른 locale·테마·다크·전체 회귀는 이번 검증이 아니다. P03 추가1회는 SDK 전 준비 오류로 소진됐고 P08 실패 한도와 H08의 기존 기록은 초기화하지 않았다. 사라진 l03/batch04 임시 자료 원인과 원본 복구도 미확인이다.

## Prevention

- 새 요약이 기존 행과 같은 문구를 읽으면 행만의 AX 식별자에 검사 범위를 한정한다.
- iPad native overflow 메뉴는 원래 보이는 행동명으로 찾고 실제 AX에서 확인한다.
- 사진 중심점만 요구하는 단방향 스크롤은 일부 보이는 tappable 이미지도 지나칠 수 있다. P08의 별도 검사는 실패로 남겨 완료로 합산하지 않는다.
- 소스·selector별 증거를 재사용하고 실패한 동반 화면이 통과한 화면의 불필요한 반복 빌드를 만들지 않게 한다.
