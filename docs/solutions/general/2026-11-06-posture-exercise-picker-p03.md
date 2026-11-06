---
tags: [swiftui, posture, detail-redesign, p03, accessibility, native-capture]
category: general
date: 2026-11-06
severity: minor
status: in-progress
related_files: [DUNE/Presentation/Posture/Components/ExercisePickerSheet.swift, DUNEUITests/Full/WellnessRegressionTests.swift]
related_solutions: []
---

# Solution: P03 운동 선택 개편

## Problem

자세 상세 개편의 원래 기능·기호를 유지하면서 핵심 내용과 조작을 읽기 쉽게 정리해야 했다. B05 네 화면은 같은 앱 타깃과 합성 fixture를 소비하므로 증분 컴파일을 공유하고 화면별 PR로 분리한다.

### Root Cause

기존 표현의 강조면·읽기 폭·접근성 그룹이 화면마다 달랐다. MAX 원래 NavigationBar는 수정 전 Duo에서 제목·Close 자식을 노출하지 않았다. 해당 실행 AX와 native PNG로 증상을 확인했으며 프레임워크 내부 원인은 증명하지 않았다.

## Solution

원래 List·종목 아이콘·General·체크·선택 callback을 보존한다. accessibility5에서만 안전 영역 상단에 닫기·제목을 고정하고 큰 시트를 사용한다. 일반 크기의 NavigationStack과 medium/large는 유지한다.

### Changes Made

| File | Change | Reason |
|---|---|---|
| `DUNE/Presentation/Posture/Components/ExercisePickerSheet.swift` | 원래 흐름을 보존한 화면 표현과 AXID | 읽기·조작 접근 |
| `docs/design/layout-map/posture-exercise-picker-p03.html` | 구현 전 배치 계약 | 실제 구현과 대조 |
| `docs/design/theme-map/themes/dune-posture-exercise-picker-p03.html` | 정적 시안 | 실제 PNG와 구분 |

### Verification

General → squat → 재진입·선택 유지 → General 복구. MAX에서 마지막 Lunge까지 스크롤·선택·재진입 후 닫기. 수정 전 Duo MAX 닫기 실패 기록은 유지한다.

공유 실행 소스: iPhone 최초23fa2883(5개 중4통과, P04 점수 AX 실패), P04만 수정6fe1f089 재실행2/2통과. iPad6fe1f089 일반3/3통과. Duo 외부 LCD6fe1f089의5개 중4통과·P03 MAX 실패. 내부 LCD-1 d6ac3110 일반3/3통과. P03 MAX 헤더·닫기 대비 수정 후 iPhone d6ac3110 관련1/1통과. 실패·준비 단계 오류·재시도 기록을 합격 수로 숨기지 않는다. 모든 값은 해당 실행·소스 범위이며 PR HEAD 전체 회귀 통과를 뜻하지 않는다.

**남은 게이트:** 수정된 P03의 Duo 접힘 MAX는 미검증이다. 기존 check의 준비 단계1회+실제 테스트1회 실패로 자동 실행 한도2회에 도달했다. 사용자에게 근거와 정확한 selector로 추가1회 예외 승인을 요청했으며 답변 전 재실행·완료·머지를 하지 않는다. H08 한도는 별도 보존한다.

독립 Security·Performance·Architecture·Data Integrity·Simplicity·SwiftUI·Apple UX·App Quality 및 최종 PR 소스 리뷰에서 추가 차단 사항은 없었다. 실제 iPhone·iPad·Duo PNG/AX도 별도로 검토했다. 동반 P03의 MAX 실패는 P03 일반 흐름의 이미 통과한 증거와 구분한다.

### Evidence / Limits

[새 실제 화면과 출처](../../design/full-redesign-map/review/posture-exercise-picker-p03-2026-11-06/index.html). 각 PNG는 캡처 소스·기기·selector·시각·AX·해시를 가진다. 이전 같은 ID의 화면은 before로 보존하며 새 증거로 재사용하지 않는다. Duo는 활성 LCD/LCD-1과 physical portrait·internal display rotation90·native PNG로 상태를 대조했다. 현재 공식 CLI에 hinge-angle 조회가 없어 숫자 각도는 미측정(null)이다.

시뮬레이터 카메라 사용 불가·기존 합성 full-result fixture만 사용했다. 실제 frame·추론·자동 촬영·실물 방향, partial-result, 다른 locale·어두운 모드·전체 회귀·Watch는 이번 검증이 아니다. 카탈로그 번역 값은 변경하지 않았다. 사라진 detail-redesign-l03/batch04 원본 SDK 자료의 원인·복구는 미확인이며 Git과 별도 보관 증거로 이어간다.

## Prevention

- AX 그룹 식별자는 최종 ignore/combine·명시적 label 뒤에 두고 새 AX의 유일한 대상과 전체 label을 검사한다.
- MAX 조작은 마지막 행 선택·재진입·닫기까지 실제 PNG와 AX로 확인한다. 다른 기기 통과로 실패한 기기를 대신 완료 처리하지 않는다.
- 관련 selector와 source/dependency 동일성을 기록해 통과한 compile·검증을 재사용하고 불필요한 전체 빌드를 반복하지 않는다.

## Lessons Learned

시각적 통과·상호작용 통과·원본 자료 보존은 서로 다른 증거다. 준비 단계 오류도 기록된 실행 한도에서 빼지 않으며 수정 범위에 맞춘 검증과 화면별 PR을 유지한다.
