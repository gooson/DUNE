---
tags: [reference-design, implementation]
date: 2026-11-21
category: plan
status: approved
---
# 준비도 근거가 부족할 때 수집 상태 표시

승인 시안 R08을 단일 기능으로 적용한다.

## 대상

- DUNE/Data/Services/ScoreRefreshService.swift
- DUNE/Domain/UseCases/CalculateTrainingReadinessUseCase.swift
- DUNE/Presentation/Activity/ActivityView.swift
- DUNE/Presentation/Activity/ActivityViewModel.swift
- DUNETests/ActivityViewModelTests.swift
- DUNETests/CalculateTrainingReadinessUseCaseTests.swift
- DUNETests/ScoreRefreshServiceTests.swift
- Shared/Resources/Localizable.xcstrings

## 검증

표준 iOS 빌드, 변경된 기능의 대상 테스트와 화면 캡처를 수행한다. 관측 누락과 접근성 글씨 크기에서 지표가 누락되거나 잘리지 않는지 확인한다.
