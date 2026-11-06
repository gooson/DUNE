---
tags: [swiftui, posture, detail-redesign, p01, accessibility, native-capture]
category: general
date: 2026-11-06
severity: minor
status: resolved
related_files: [DUNE/Presentation/Posture/PostureCaptureView.swift, DUNEUITests/Full/WellnessRegressionTests.swift]
related_solutions: []
---

# Solution: P01 자세 촬영 개편

## Problem

자세 상세 개편의 원래 기능·기호를 유지하면서 핵심 내용과 조작을 읽기 쉽게 정리해야 했다. B05 네 화면은 같은 앱 타깃과 합성 fixture를 소비하므로 증분 컴파일을 공유하고 화면별 PR로 분리한다.

### Root Cause

기존 표현의 강조면·읽기 폭·접근성 그룹이 화면마다 달랐다. 기존 데이터·카메라 로직의 결함으로 단정하지 않고 View 표현과 안정적인 검증 식별자만 변경했다.

## Solution

스크롤 가능한 중앙 오류 카드와 명확한 원래 재시도·닫기 조작을 제공한다. 기존 카메라 세션·방향·mirror·front/side·자동 촬영·결과 전환은 보존한다.

### Changes Made

| File | Change | Reason |
|---|---|---|
| `DUNE/Presentation/Posture/PostureCaptureView.swift` | 원래 흐름을 보존한 화면 표현과 AXID | 읽기·조작 접근 |
| `docs/design/layout-map/posture-capture-p01.html` | 구현 전 배치 계약 | 실제 구현과 대조 |
| `docs/design/theme-map/themes/dune-posture-capture-p01.html` | 정적 시안 | 실제 PNG와 구분 |

### Verification

카메라 사용 불가 → Try Again → 준비 컨트롤 → Close → Wellness. 재시도 뒤 카메라 추론 재개를 주장하지 않는다.

공유 실행 소스: iPhone 최초23fa2883(5개 중4통과, P04 점수 AX 실패), P04만 수정6fe1f089 재실행2/2통과. iPad6fe1f089 일반3/3통과. Duo 외부 LCD6fe1f089의5개 중4통과·P03 MAX 실패. 내부 LCD-1 d6ac3110 일반3/3통과. P03 MAX 헤더·닫기 대비 수정 후 iPhone d6ac3110 관련1/1통과. 실패·준비 단계 오류·재시도 기록을 합격 수로 숨기지 않는다. 모든 값은 해당 실행·소스 범위이며 PR HEAD 전체 회귀 통과를 뜻하지 않는다.

독립 Security·Performance·Architecture·Data Integrity·Simplicity·SwiftUI·Apple UX·App Quality 및 최종 PR 소스 리뷰에서 추가 차단 사항은 없었다. 실제 iPhone·iPad·Duo PNG/AX도 별도로 검토했다. 동반 P03의 MAX 실패는 P01 일반 흐름의 이미 통과한 증거와 구분한다.

### Evidence / Limits

[새 실제 화면과 출처](../../design/full-redesign-map/review/posture-capture-p01-2026-11-06/index.html). 각 PNG는 캡처 소스·기기·selector·시각·AX·해시를 가진다. 이전 같은 ID의 화면은 before로 보존하며 새 증거로 재사용하지 않는다. Duo는 활성 LCD/LCD-1과 physical portrait·internal display rotation90·native PNG로 상태를 대조했다. 현재 공식 CLI에 hinge-angle 조회가 없어 숫자 각도는 미측정(null)이다.

시뮬레이터 카메라 사용 불가·기존 합성 full-result fixture만 사용했다. 실제 frame·추론·자동 촬영·실물 방향, partial-result, 다른 locale·어두운 모드·전체 회귀·Watch는 이번 검증이 아니다. 카탈로그 번역 값은 변경하지 않았다. 사라진 detail-redesign-l03/batch04 원본 SDK 자료의 원인·복구는 미확인이며 Git과 별도 보관 증거로 이어간다.

## Prevention

- AX 그룹 식별자는 최종 ignore/combine·명시적 label 뒤에 두고 새 AX의 유일한 대상과 전체 label을 검사한다.
- MAX 조작은 마지막 행 선택·재진입·닫기까지 실제 PNG와 AX로 확인한다. 다른 기기 통과로 실패한 기기를 대신 완료 처리하지 않는다.
- 관련 selector와 source/dependency 동일성을 기록해 통과한 compile·검증을 재사용하고 불필요한 전체 빌드를 반복하지 않는다.

## Lessons Learned

시각적 통과·상호작용 통과·원본 자료 보존은 서로 다른 증거다. 준비 단계 오류도 기록된 실행 한도에서 빼지 않으며 수정 범위에 맞춘 검증과 화면별 PR을 유지한다.
