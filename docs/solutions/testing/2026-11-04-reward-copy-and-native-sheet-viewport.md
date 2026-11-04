---
tags: [swiftui, xctest, rewards, native-sheet, dynamic-type, simulator-provenance]
category: testing
date: 2026-11-04
severity: important
related_files:
  - DUNE/Presentation/Activity/PersonalRecords/Components/RewardProgressSection.swift
  - DUNEUITests/Full/ActivityExerciseRegressionTests.swift
  - DUNEUITests/Full/DesignMapAdditionalRoutesTests.swift
related_solutions:
  - 2026-11-04-personal-records-native-sheet-reading.md
---

# 보상 설명의 실제 계산 경로와 네이티브 시트 읽기 검증

## Problem

보상 설명의 포인트·배지 조건이 실제 호출 경로보다 넓게 읽힐 수 있었고, 최대 글씨의 긴 본문은 중간 높이 시트 한 프레임에 모두 들어가지 않았다. 작은 드래그나 보이는 본문 밖에서 시작한 제스처는 실제 AX 프레임을 이동시키지 않았다. 별도로 캡처 저장 공간 부족과 존재하지 않는 iPad 기기형 설정이 검증을 막았다.

## Solution

기존 private 시트와 네 아이콘을 유지하고 공통 팔레트의 제목 히어로·불투명 설명 카드로 배치했다. 설명은 새 활동 마일스톤, 새 유산소 PR 포인트, 레벨당200점과 운동일 기준 배지를 구분한다. 모델·저장·보상 계산은 변경하지 않았다.

짧은 본문은 실제 뷰포트 안의 전체 프레임을 검사한다. 화면 높이에 가까운 본문과 더 긴 본문은 정확한 전체 라벨·가로 폭을 유지하고, 겹치는 읽기 구간으로 앞과 끝까지 도달한다. 진행 드래그는 보이는 텍스트 구간의 중앙에서 시작하며, 정지한 제스처는 기존 양의 진행 판정에서 계속 실패한다. 앱 글씨·시트 detent·시간 제한을 줄이거나 존재 여부만으로 검사를 통과시키지 않았다.

앱 소스 `9208e68c`의 선택 검사6개가 모두 통과했다. 원본 iPhone1회는 별도 보존했고, 네 기기·자세의 기본 화면, 접힘 Duo 최대 글씨, 실제 알림 진입·복귀를 확인했다. 이전 d87a·400c의 각1통과/1실패, cc0의 불완전 SDK와 집계 없음, 미지원 iPad 준비0UI를 그대로 남겼다. 실제 설치된 A20 Pro iPad 전용 복사본으로 마지막1개만 실행하여 앞선5개를 반복하지 않았다.

## Prevention

설명 문구는 보상 모델뿐 아니라 실제 호출자를 추적한다. 스크롤은 의도한 제스처와 실제 프레임 진행을 구분하고, 원본/개편·테스트 결과/캡처 파일·실패 이력/현재 통과를 각각 보존한다. 기기 모델은 화면 ID나 이전 초안으로 추정하지 않고 설치 SDK의 식별자·런타임을 확인한다. 소스와 다른 검증 환경 문제를 새 앱 실패나 통과로 바꾸지 않는다.

전체 로컬 회귀 대신 변경 소비자와 필요한 기기·상태만 검사한다. 기존 핵심 검증·소유권·재시도 규칙을 적용할 수 있으므로 `.claude` 규칙이나 CLAUDE.md 원본을 추가 변경하지 않았다. 별도 진행 중 TODO는 없어 완료로 바꿀 항목이 없다.

## Lessons Learned

내부 검증 도구들끼리 이름이 일치해도 실제 설치 SDK에 존재하는 기기형이라는 뜻은 아니다. 같은 방법으로 XCTest 통과와 네이티브 시각 검토도 구분해야 한다. 원본 한 장은 다른 기기의 과거 화면을 대신하지 않으며, 비교 갤러리는 그 한계를 명시하고 실제 개편 캡처의 출처와 PNG/AX 해시를 연결해야 한다.
