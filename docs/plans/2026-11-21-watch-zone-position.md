---
tags: [reference-design, implementation]
date: 2026-11-21
category: plan
status: approved
---
# Watch 심박 존에 현재 위치 표시

승인 시안 R01을 단일 기능으로 적용한다.

## 대상

- DUNEWatch/Views/Cardio/Components/HRZoneBar.swift
- DUNEWatchUITests/Smoke/WatchLiveHeartRateZonesUITests.swift
- DUNEWatch/Resources/Localizable.xcstrings

## 검증

표준 iOS 빌드, 변경된 기능의 대상 테스트와 화면 캡처를 수행한다. 관측 누락과 접근성 글씨 크기에서 지표가 누락되거나 잘리지 않는지 확인한다.
