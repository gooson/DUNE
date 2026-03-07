---
tags: [widget, app-group, preferences, simulator, file-storage]
date: 2026-03-08
category: solution
status: implemented
---

# Widget App Group File Storage Fix

## Problem

시뮬레이터에서 widget shared data를 읽고 쓸 때 아래 로그가 반복될 수 있었다.

`Couldn't read values in CFPrefsPlistSource... Domain: group.com.raftel.dailve ... Using kCFPreferencesAnyUser with a container is only allowed for System Containers`

## Root Cause

main app과 widget이 App Group `UserDefaults(suiteName:)`에 JSON blob을 저장하고 있었다.

이 경로는 기능적으로 동작하더라도 simulator의 CFPreferences 내부 로그를 유발할 수 있고, 단일 blob 저장소로는 file storage가 더 단순하다.

## Solution

shared widget score 저장소를 App Group `UserDefaults`에서 App Group container file로 변경했다.

- `Shared/WidgetScoreData.swift`: shared file URL helper 추가
- `DUNE/Data/Services/WidgetDataWriter.swift`: JSON file write/read로 전환
- `DUNEWidget/WidgetScoreProvider.swift`: shared file read로 전환

## Prevention

- App Group에 단일 JSON blob을 공유할 때는 `UserDefaults(suiteName:)`보다 container file 저장을 우선 검토한다.
- simulator 전용 CFPreferences 로그가 보이면 entitlement 문제와 함께 저장 매체 자체가 과한지 같이 본다.
