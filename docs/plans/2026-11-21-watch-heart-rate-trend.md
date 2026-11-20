---
tags: [reference-design, implementation]
date: 2026-11-21
category: plan
status: approved
---
# 운동 중 최근 30분 심박 흐름 표시

승인 시안 R03을 단일 기능으로 적용한다.

## 대상

- DUNEWatch/Managers/WorkoutManager.swift
- DUNEWatch/Views/Cardio/CardioHRZonePage.swift
- DUNEWatch/Resources/Localizable.xcstrings
- DUNEWatchUITests/Smoke/WatchLiveHeartRateZonesUITests.swift
- DUNEWatch/Models/WatchHeartRateHistory.swift
- DUNEWatchTests/WatchHeartRateHistoryTests.swift

## 검증

표준 iOS 빌드, 변경된 기능의 대상 테스트와 화면 캡처를 수행한다. 관측 누락과 접근성 글씨 크기에서 지표가 누락되거나 잘리지 않는지 확인한다.
