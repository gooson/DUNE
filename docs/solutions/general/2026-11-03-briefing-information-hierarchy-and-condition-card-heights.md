---
tags: [swiftui, morning-briefing, condition-detail, typography, dynamic-type, layout]
date: 2026-11-03
category: general
status: reviewed
related_files:
  - DUNE/Presentation/Dashboard/MorningBriefingView.swift
  - DUNE/Domain/UseCases/BriefingTemplateEngine.swift
  - DUNE/Presentation/Dashboard/Components/ConditionDetailHeader.swift
---

# 아침 브리핑 정보 위계와 컨디션 기여 카드 높이

## Problem

T09는205pt 일출 헤더와 카드별80pt 장식 배너 때문에 작은 본문보다 그림의 비중이 컸다. T04는 HRV·RHR를 LazyVGrid에 넣어 각각 자연 높이로 렌더링했으므로 이전 RHR 날짜가 있는 카드만 더 길어졌다.

사용자는 시안을 먼저 요청한 뒤1번 **정보 강조**를 선택했고, 컨디션 카드의 높이도 함께 수정하도록 요청했다. 초기 앱 변경은 시안 요청 시 원복했으며 해당 UI 빌드는 사용자 지시에 따라 중단했다. 그 실행을 테스트 성공이나 제품 실패로 기록하지 않는다.

## Solution

- T09 일출 헤더를 기본 글씨126pt로 줄이고, 분류 아이콘·title3.bold 제목·title.bold 수치·body 본문으로 읽기 순서를 정했다.
- 템플릿 엔진이 실제 수면·어제 대비 HRV·운동 일수/목표·평균 컨디션의 label/value를 생성한다. 화면의 예시 수치는 제품 코드에 넣지 않는다. nil 측정값을0으로 표시하지 않으며 NaN·무한대·Int 변환 경계를 먼저 확인한다.
- 수치로 분리한 수면·HRV와 주간 요약을 같은 본문으로 반복하지 않는다. 추가 RHR 변화·기록 미수신의 기존 점수 안내, 실제 가이드·조건부 날씨는 유지한다.
- 기본 글씨에서 두 지표를 나란히 표시하고 접근성 글씨에서는 한 열로 자연 확장한다. 레이블·값을 함께 읽는 접근성 요소와 안정적인 식별자를 둔다.
- T04는 Layout에서 같은 폭으로 두 카드의 자연 높이를 측정한 뒤 큰 높이를 모두에 제안한다. 상태로 높이를 저장하는 피드백 경로나 고정 외곽 높이는 추가하지 않는다. 제목은 확대 가능한 두 줄 최소 공간을 공유하고 내용은 위쪽, 이전 측정 날짜는 아래쪽에 둔다. 접근성 글씨에서는 세로로 배치한다.
- 이전 RHR fixture를 별도 opt-in 인자로 분리해 기존 fixture를 바꾸지 않고 날짜 분기를 검증한다.

## Validation

초기 관련 `BriefingTemplateEngineTests`33개, 리뷰 보완 후 최종35개가 통과했다. 수면·HRV의 nil/0/부호/잘못된 실수, RHR 추가 안내, 주간 목표 없음/진행/초과 완료를 포함한다. SwiftUI·Apple UX 관점의 읽기 전용 검토에서 구체적인 P1/P2/P3 finding은 없었다. 실제 줄바꿈과 카드 높이는 별도 UI 결과·새 PNG로 확인하며 미실행 기기를 통과로 확대하지 않는다.

선택 UI는 한국어 브리핑, 브리핑 최대 접근성 글씨, 이전 RHR 날짜의 동등 높이·행 시작선, 해당 날짜의 최대 글씨 세로 배치다. 전체 회귀를 실행한 것으로 기록하지 않는다. 카탈로그 형식·manual 추출 상태와 테마맵 동기화를 확인한다. 최종 UI 실행과 기기별 캡처 상태는 실제 화면 디자인맵 기록에 연결한다.

## Prevention

같은 행의 서로 다른 길이 카드는 외곽 높이와 내부 수치 기준선을 별도로 확인한다. 날짜를 생략하거나 본문을 줄여서 외곽 높이를 맞추지 않는다. 장식을 줄이는 요청에서는 글씨 크기뿐 아니라 장식 면적·본문 읽기 폭·중복 설명도 함께 확인한다. 기본·큰 글씨의 새 PNG와 원본 출처를 보존한다.

리뷰 후에는 소수 HRV를 signed Double 유효숫자로 표시하고 이력이 없으면 주간 평균 지표를 생략한다. 주간 진행률은 Sections에서 정규화하며 사용하지 않는 기존 weeklyMessage를 제거했다.
