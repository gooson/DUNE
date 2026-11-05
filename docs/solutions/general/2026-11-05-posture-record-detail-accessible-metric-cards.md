---
tags: [swiftui, posture, accessibility, visual-evidence]
category: general
date: 2026-11-05
status: implemented
severity: important
related_files:
  - DUNE/Presentation/Posture/PostureDetailView.swift
  - DUNE/Presentation/Shared/Extensions/PostureMetric+View.swift
  - DUNEUITests/Full/WellnessRegressionTests.swift
related_solutions: []
---

# 자세 기록 상세의 저장된 평가 정보를 사진 앞에 표시

## Problem

### Symptoms

기존 H07 자세 기록 상세에서는 큰 Front/Side 이미지가 첫 화면을 차지해, 이미 저장된 점수와 평가 항목이 있어도 상세 내용이 부족해 보였다. 같은 상세 뷰를 여는 P06 자세 이력에도 동일한 배치가 적용됐다.

### Root Cause

평가 항목이 이미지 아래의 긴 세로 목록에 있었고, 사진이 없는 기록에도 큰 자리표시자가 배치됐다. 최대 글씨에서는 고정된 아이콘 영역과 낮은 대비의 보조 문구가 읽기를 더 어렵게 했다.

## Solution

### Changes Made

| File | Change | Reason |
| --- | --- | --- |
| `PostureDetailView.swift` | 점수 다음에 저장된 평가 항목을 배치하고, 일반 글씨는 2열·접근성 글씨는 1열로 표시한다. 사진 없는 자리표시자는 높이 120pt로 줄였다. | 실제 저장된 내용을 먼저 볼 수 있게 한다. |
| `PostureDetailView.swift` | 기존 항목 아이콘·상태·값·단위·신뢰도를 카드에 유지하고, 아이콘 크기 상한과 밝은 화면 전경 대비를 조정했다. | 최대 글씨에서 제목과 기호가 겹치거나 중요한 문구가 흐려지는 문제를 다룬다. |
| `PostureMetric+View.swift` | 신뢰도 배지의 전경 스타일 인자를 추가하되 기본값을 유지했다. | 이 상세 화면만 명시적인 기본 전경을 쓰고 다른 소비자는 기존 표현을 유지한다. |
| `WellnessRegressionTests.swift` | Duo 끝점에서 정적 MAX 상세의 점수·평가 영역을 확인하는 기존 범위의 선택자를 추가했다. | 화면 배치 검증과 별도의 세 자세 FOLD 도구 검증을 정확히 구분한다. |

새 점수, 의료 문턱, 이미지, 측정값은 만들지 않았다. 사진 확대·관절 오버레이·교정 운동·좌우 비교·메모·PDF 공유·삭제 경로는 유지했다. 평가 배열이 비면 기존 `Unable to measure` 문구를 보여 준다.

### Evidence and limits

현재 소스 기준은 `1514deb76c33aee630c7bc44173716190af6aff2`다. 이전 `8a910fe3` 소스의 Duo 펼침 3건·접힘 4건 SDK 통과는 이 소스의 시각 품질 근거로 재사용하지 않는다. 그 실행에서 발견한 중립 캡션 대비 문제를 `1514deb7`에서 수정했으며, 수정 후 iPhone 2건, iPad 2건, Duo 접힘 4건·펼침 3건의 대상 SDK 검사 11건이 모두 통과했다. 네 프로필의 새 PNG/AX를 각각 검토했고 게시용으로 20쌍을 선택했다. 최대 글씨 검증은 Duo 두 끝점의 점수 전체와 아래 다섯 뷰포트를 포함한다. 일반 iPhone·iPad의 최대 글씨, 다른 앱 언어·외관, 사진 없음·부분 평가와 실제 카메라 관절 영상은 이번 네이티브 증거에 포함하지 않는다.

원래 세 자세 MAX FOLD 선택자는 90° 구동·readback 문제로 실패한 상태를 유지한다. 그 실행의 실패와 시작 전 저장공간 실패, 현재 `1514deb7`의 준비 단계 실패도 별도 기록으로 보존한다. Duo 0°/180° 정적 상세 검증이 성공하더라도 세 자세 회귀를 통과로 표시하지 않는다. 90° 활성 디스플레이 JSON을 확보했다고 주장하지 않는다.

[실제 화면과 기기별 검증 자료](../../design/full-redesign-map/review/h07-p06-posture-native-2026-11-05/index.html)에서 합성 fixture와 과거 기준 이미지를 구분한다. PDF 내보내기·사진 없는 기록·VoiceOver 실행 전체를 이번 표시 검사로 검증했다고 표현하지 않는다.

## Prevention

- 공유 상세 화면을 바꿀 때 H07 직접 진입과 P06 이력 소비자를 함께 확인한다.
- 사진·평가 항목의 출처를 구분하고, 합성 fixture 이미지를 실제 카메라 사진이나 관절 시각화 증거로 설명하지 않는다.
- SDK 결과와 실제 PNG/AX의 글자·아이콘·대비를 각각 검토한다. 이전 소스의 통과 화면을 새 소스의 증거로 올리지 않는다.
- 기기별 소스 커밋, 실제 SDK 건수와 PNG/AX를 같은 출처 기록으로 묶고, 다른 소스의 성공이나 중단된 실행의 그림을 대체 증거로 사용하지 않는다.

## Lessons Learned

저장된 내용을 먼저 보여 주는 배치만으로 화면의 정보 밀도가 달라진다. 접근성 크기의 기호 영역과 밝은 화면 전경은 실제 캡처로 확인해야 한다. 기기 구동 도구의 90° 실패는 끝점의 제품 화면 검증과 분리해 기록하되, 원래 회귀의 실패 상태를 지우지 않는다.
