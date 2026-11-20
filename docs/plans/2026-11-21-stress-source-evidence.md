---
tags: [reference-design, implementation]
date: 2026-11-21
category: plan
status: approved
---
# 실제 관측 이력으로 누적 스트레스 근거 표시

승인 시안 R09을 단일 기능으로 적용한다.

## 대상

- DUNE/Presentation/Dashboard/DashboardViewModel.swift
- DUNE/Presentation/Dashboard/DashboardView.swift
- DUNE/Domain/UseCases/CalculateCumulativeStressUseCase.swift
- DUNETests/CalculateCumulativeStressUseCaseTests.swift
- DUNE/Data/Services/ScoreRefreshService.swift
- Shared/Resources/Localizable.xcstrings
- DUNEUITests/Visual/TodayCompactUITests.swift
- DUNETests/DashboardViewModelTests.swift

## 검증

표준 iOS 빌드, 변경된 기능의 대상 테스트와 화면 캡처를 수행한다. 관측 누락과 접근성 글씨 크기에서 지표가 누락되거나 잘리지 않는지 확인한다.
