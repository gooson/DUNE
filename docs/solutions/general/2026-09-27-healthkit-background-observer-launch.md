---
tags: [healthkit, background-delivery, observer-query, launch, notifications]
category: general
date: 2026-09-27
severity: important
related_files:
  - DUNE/App/DUNEApp.swift
  - DUNE/App/LaunchExperiencePlanner.swift
  - DUNE/Data/HealthKit/HealthKitObserverManager.swift
  - DUNETests/HealthKitObserverManagerTests.swift
  - DUNEUITests/Helpers/UITestHelpers.swift
related_solutions:
  - 2026-09-19-healthkit-launch-authorization-revalidation.md
  - ../healthkit/background-notification-system.md
---

# HealthKit 백그라운드 실행에서 체중 감시 복구

## Problem

HealthKit에 체중이 추가돼도 앱 프로세스가 없었던 경우 알림이 누락될 수 있었다. observer 시작이 active scene을 요구하는 이번 실행의 권한 확인 이후에만 연결되어, 백그라운드 cold launch에서는 감시가 복구되지 않았다. 체중·체지방·BMI 전달 주기도 hourly였다.

## Solution

| File | Change | Reason |
|------|--------|--------|
| DUNEApp / LaunchExperiencePlanner | 기존 권한 요청 이력이 있는 설치에서 runtime 생성 시 observer 복구 | active scene 없이 시작되는 실행 지원 |
| HealthKitObserverManager | MainActor에서 query 보관·등록·중지 직렬화 | 별도 Task/actor 사이 등록 경쟁 제거 |
| HealthKitObserverManager | 체성분 immediate 요청, 중복 query 없이 delivery 설정 재시도 | 전달 지연 완화 및 권한 확인 전 설정 실패 복구 |
| Observer / LaunchExperience 테스트 | 등록·중지·재시작·실패 재시도 및 시작 조건 검증 | 수명 주기 회귀 방지 |
| CardioSession 테스트 | 기존 steps/vitals mock을 기본 주입 | 전체 단위 테스트의 실제 HealthKit 쿼리 정체 제거 |
| UI helper | 탭 후 포커스 또는 키보드 확인, 최대 1회 재탭 | 입력 준비 전 typeText 실패 방지 |

저장된 권한 요청 이력은 읽기 권한의 증거로 사용하지 않는다. foreground 권한 재확인과 화면 데이터 조회 gate는 유지한다. observer completion은 비동기 처리 완료 후 호출하며, 기존 하루 1회 알림 정책은 변경하지 않는다.

## Validation

- 앱 빌드 성공. iOS Swift Testing 2,241개/244 suite 및 XCTest 9개 통과.
- 보완된 helper로 cardio 검색·요약과 quick-start 검색·상세 진입 UI 2개 통과.
- 사용자가 전체 UI 실행을 중단하고 관련 테스트만 검증하도록 명시했다. 중단된 전체 실행은 성공 근거로 사용하지 않는다. 원격 CI 실행도 하지 않았다.
- 보안·성능·아키텍처·데이터 정합성·단순성 리뷰: 지적 0건.
- 품질 리뷰 P3: 키보드가 보여도 포커스 판정에 최대 2초 대기한다. 탭한 필드의 포커스를 먼저 확인하는 순서를 유지하는 trade-off로 기록했다. P1/P2는 없다.
- 실기기 HealthKit background delivery는 미검증이다. OS 전달 시점, 잠금 상태, 사용자 강제 종료 후 실행 여부는 이 수정으로 보장하지 않는다.

## Prevention

- HealthKit observer 복구 경로가 scene 활성화나 splash 완료에만 의존하지 않는지 확인한다.
- query 등록 중복 방지와 background delivery 재시도를 별도 검증한다.
- 단위 테스트에 서비스 기본값을 사용할 때 실제 HealthKit 접근이 발생하지 않도록 mock을 명시한다.
- SwiftUI 접근성의 hasKeyboardFocus가 false여도 실제 커서와 키보드가 표시될 수 있다. 실패 스크린샷으로 판정을 확인하고 실제 입력 결과 assertion을 유지한다.

별도 공통 규칙이나 교정 로그 변경은 필요하지 않다. 기존 HealthKit completion·권한 원칙을 유지하는 수정이며 관련 미완료 TODO는 없었다.

## Lessons Learned

백그라운드 깨우기와 observer 재등록은 다른 단계다. 앱 초기화 시 등록을 복구해야 OS가 전달한 기회를 처리할 수 있다. 시뮬레이터 UI 성공은 실기기 백그라운드 전달 보장이 아니므로 두 검증을 구분해야 한다.

## Device Check

HealthKit 및 알림 권한을 허용하고, 당일 체중 알림을 아직 받지 않은 상태에서 앱을 백그라운드로 보낸 뒤 건강 앱에 오늘 체중을 추가한다. OS가 프로세스를 종료한 이후의 백그라운드 실행에서도 observer 등록과 알림을 확인한다. 잠금/해제와 당일 반복 입력에 따른 의도적 중복 억제도 확인한다.
