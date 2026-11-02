---
tags: [swiftui, notification, unavailable-destination, localization, duo, scoped-validation, provenance]
category: general
date: 2026-11-02
severity: minor
related_files:
  - DUNE/Presentation/Dashboard/NotificationHubView.swift
  - DUNEUITests/Full/DesignMapAdditionalRoutesTests.swift
related_solutions:
  - docs/solutions/architecture/2026-03-03-notification-inbox-routing.md
---

# Solution: 알림 목적지 오류 화면의 위계와 복귀 기능 보존

## Problem

기존 알림 목적지 fallback은 안내·돌아가기·알림 ID를 제공한다. 시각 개편에서 원래 설명과 실제 ID 대신 시안 예시를 쓰거나 새 목적지를 추정하면 오류 상태의 의미가 바뀐다. 넓은 화면에서는 설명이 너무 길게 퍼질 수 있고 큰 글씨에서는 버튼·ID까지 스크롤로 도달할 수 있어야 한다.

## Solution

- T13 구간만 기존 ScoreHeroPalette의 불투명 카드로 구성했다. 원래 `arrow.triangle.branch`, 현지화된 제목·설명, 시스템 내비게이션 제목을 유지했다.
- 읽기 열은 최대560pt로 제한하고 고정 텍스트 높이 없이 세로 성장하게 했다. 실제 `itemID`는 조용한 footer로 남기고, 기존 Go Back은 원래 dismiss만 실행한다. 새 상태·날짜·측정값·설정 이동·재시도 행동을 만들지 않았다.
- 기존 normal 검사는 원래 문구·UUID 형식·명시적 Go Back 버튼과 실제 알림함 복귀를 확인한다. 검증된 상세 상태에 이미 paused checkpoint가 있어 새 테스트나 back 조회 패치를 추가하지 않았다.

### Source and actual verification

공개ff68a35c는 완료된 T11/T12 prefix를 유지하고 T13만 원본734db23d와 일치시켰다. 여기서는 공유 `NotificationHubView.swift` 한 파일 전체가 검증 후보3fac15d4와 실제로 같다. 테스트 파일 전체는 다르지만 T13 normal/MAX·UUID·viewport helper, 공통 상세 진입 helper와 실행 설정은 원본/공개/검증 후보가 동일하다. 다른 앱 파일까지 전체 통합 트리가 같다고 주장하지 않는다.

기존 clean734 Phone normal+dark/MAX2PASS를 T13 제품·관련 테스트 범위로 재사용했다. 새 iPad normal1, Duo closed1·open1은3fac의 같은 기존 선택자로 통과했다. 각 Duo는 전후0°LCD/180°LCD-1 및 엄격ACK7을 확인했다. 실제 원본에서 설명·Go Back·ID가 보이며, 버튼 뒤 알림함 캡처는 복귀 증거로 구분했다. 각 실행의 UUID는 실제 저장된 알림마다 다르므로 같은 화면 종류의 레이아웃 비교이며 동일 알림 기록의 기기 간 연속 비교가 아니다.

접힘 최초 시도는 UI 실행 전 SDK의 `simctl list devices --json`4초 시간 초과로 중단됐다. 부팅 로그의 migration 실패 표시와 원문을 보존했다. 이후 같은 소유 기기의 Booted/available 상태와 동일 조회0.461초를 확인하고, 원인·복구·근거를 표준 실행기에 첨부해 같은 검사 ID로 한 번만 조건부 재시도했다. 앱·실행기는 바꾸지 않았으며 원래 실패0tests와 재시도 성공 두 기록을 유지했다. 세 번째 같은 원인 실행은 추가하지 않았다.

원래 iPad baseline 그룹은 별도 bedtime 실패 때문에 전체FAILED6/5/1이다. 정확한 T13 개별 case만 PASS였으며, 이를 개편 전체 통과로 바꾸지 않고 올바른 before로 사용했다. iPad mini/Pro13, 촬영일·옛 Duo 미확인 자세 차이도 명시했다. 새 로컬 unit/full UI/Watch 검사는 추가하지 않았다. 원격 CI는 실제 상태로 별도 기록하며 pending/환경 실패를 PASS로 취급하지 않는다.

## Prevention

- 오류 화면의 원래 설명·실제 식별자·복귀 동작을 먼저 고정하고 시각 표현만 바꾼다.
- 넓은 화면은 읽기 폭을 제한하고 최대 글씨에서는 제목·본문·버튼·ID 도달성을 함께 확인한다.
- 같은 파일의 다른 화면과 공통 helper까지 소스 범위를 대조하고, 전체 파일/트리 일치 주장은 실제 비교 범위에 한정한다.
- 그룹 receipt와 개별 case 결과, 테스트 실행 전 실패와 앱 실패, 실제 상세와 복귀 화면을 구분한다.
- 기기 환경 복구 후 조건부 재시도는 같은 ID와 원래 실패 이력을 유지한다. 출판 상태 문구만 갱신하고 raw pose/history는 수정하지 않는다.

공통 규칙 추가는 필요하지 않다. `.claude/**`, 테스트 실행기, 공통 설정은 변경하지 않았다.

## Lessons Learned

기능이 작은 오류 화면도 원래 아이콘과 한 개의 명확한 행동, 적절한 읽기 폭으로 충분히 강조할 수 있다. 같은 화면 종류의 전후 비교와 실제 실행 이력을 정확히 연결하면 테스트를 늘리지 않고도 기능 보존과 시각 품질을 검토할 수 있다.
