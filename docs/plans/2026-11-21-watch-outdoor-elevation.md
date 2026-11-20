---
tags: [reference-design, implementation]
date: 2026-11-21
category: plan
status: approved
---
# 야외 운동에서 고도와 누적 상승 표시

승인 시안 R04을 단일 기능으로 적용한다.

## 대상

- DUNEWatch/Managers/WorkoutRouteRecorder.swift
- DUNEWatch/Managers/WorkoutManager.swift
- DUNEWatch/Views/Cardio/CardioSecondaryPage.swift
- DUNEWatch/Resources/Localizable.xcstrings
- DUNEWatchTests/WorkoutRouteRecorderTests.swift
- DUNEWatch/ContentView.swift
- DUNEWatch/Models/WatchElevationProfile.swift
- DUNEWatchUITests/Smoke/WatchOutdoorElevationUITests.swift

## 검증

표준 iOS 빌드, 변경된 기능의 대상 테스트와 화면 캡처를 수행한다. 관측 누락과 접근성 글씨 크기에서 지표가 누락되거나 잘리지 않는지 확인한다.
