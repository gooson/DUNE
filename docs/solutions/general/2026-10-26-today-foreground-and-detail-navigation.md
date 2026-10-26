---
tags: [swiftui, healthkit, foreground, refresh, inspector, hit-testing, sparkline]
category: general
date: 2026-10-26
severity: important
related_files:
  - DUNE/Presentation/Dashboard/DashboardViewModel.swift
  - DUNE/App/ContentView.swift
  - DUNE/Presentation/Dashboard/Components/SmartInsightsSection.swift
  - DUNE/Presentation/Shared/Components/HourlySparklineView.swift
related_solutions:
  - 2026-10-26-today-compact-density-and-pin-hit-area.md
---

# Solution: Today 복귀 데이터·상세 내비게이션·실제 터치 범위

## Problem

복귀 후49점이 기준선0/7일로 바뀌고 수면이 사라졌다. 지표 상세가 빈 inspector로 남는 화면과 작은 X, 카드마다 다른 표면·큰 행동 행도 사용자 캡처에서 확인했다. 요약 그래프는 저장된 점수만, 상세는 HRV로 보완한 시계열을 사용했다.

### Root Cause

- snapshot 오류 확인 전에 점수·기준선을 변경하고, 실패 소스의 기존 지표도 빈 결과로 교체했다.
- 일부 재시도는 View의 운동 기록 보완을 건너뛰었다.
- 지표 선택을 root navigation path 대신 inspector 상태로 열었다.
- 작은 닫기 아이콘의 투명한 주변에 명시적인 hit shape가 없었다. 상위 접근성 ID가 자식 X·스트레스 근거 ID까지 덮었다.
- 고정24시간 축이 첫 관측 전 빈 구간을 남겼고, 면 채움 경계가 끊긴 그래프처럼 보였다.

## Solution

실패 소스는 당일 마지막 정상 값만 유지한다. 정상 빈 응답과 날짜 변경은 제거한다. 보존한 점수를 새 측정으로 위젯·시간별 저장소에 기록하지 않는다. 재시도는 `loadDashboard()`를 거쳐 운동 기록을 보완한다.

지표는 `todayNavPath`에 append하여 push한다. 읽기용 metric inspector를 제거했다. 어제·인사이트·루틴은 공통 지원 카드를 사용한다. 브리핑·수면·스트레스 상세는 헤더에 두고 큰 글씨에서는 세로로 배치한다. 스트레스 근거는 기본 표시한다.

X는44×44pt와 `contentShape(Rectangle())`, 독립 ID를 갖는다. 식별자가 있는 상위 그룹은 `.accessibilityElement(children: .contain)`을 명시한다. 그래프는 상세와 같은 시간별 계산·저장 점수·현재 점수 병합을 사용한다. Today만 면 채움을 제거하고 실제 첫 관측부터 시간축을 표시한다.

## Verification

- 관련 단위52/52 통과. 폰의 상세 background→resume→back→reopen→전체 데이터 경로 통과.
- 수면·스트레스 기본/최대 글씨와 상세 진입, 브리핑 양쪽 appearance 통과.
- 최종 T03 배치는 폰·iPad·Duo 외부에서 각1/1 통과.
- X 실제 클릭은 사용자 요청으로 추가 실행하지 않았다. 최종 독립 ID·44×44pt 프레임은 확인했다.
- Duo 내부는 active LCD-1을 확인했으나 hittability 오류·검은 PNG로 미검증이다. 검은 PNG를 실제 화면 갤러리에 등록하지 않았다.

[실행·실패 이력](../../reviews/2026-10-26-today-repair.md)과 [실제 캡처](../../design/full-redesign-map/review/today-repair-2026-10-26/index.html)를 함께 확인한다.

## Prevention

- 오류와 정상 빈 응답을 같은 회귀 테스트에서 구분한다.
- 요소 존재만으로 터치 성공을 판단하지 않는다. lifecycle 이후 가시성·뒤로가기·재진입을 확인한다.
- 요소가 없으면 fixture 추정 전에 실제 계층과 부모 식별자 전파를 확인한다.
- 소스 변경이 끝난 뒤 빌드하고, 새 PNG를 직접 확인한다.
- 변경 동선·실패 selector만 검증하고 재시도 한도를 지킨다. `.claude/**` 원본은 변경하지 않았다.

## Lessons Learned

seeded 요소 존재·링 기하 검사만으로 실제 복귀 상태와 터치 공간·읽기 위계가 검증되지는 않는다. 데이터의 의미와 사용자가 실제 누르는 위치를 각각 확인해야 한다.
