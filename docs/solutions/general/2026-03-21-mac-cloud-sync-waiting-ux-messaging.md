---
tags: [mac, icloud, cloudkit, ux, messaging, sync, cloud-mirror]
date: 2026-03-21
category: general
status: implemented
related_files:
  - DUNE/Presentation/Shared/Components/CloudSyncWaitingView.swift
  - Shared/Resources/Localizable.xcstrings
related_solutions:
  - docs/solutions/architecture/2026-03-03-macos-healthkit-cloud-mirror-foundation.md
  - docs/solutions/architecture/2026-03-08-mac-cloud-sync-runtime-refresh.md
  - docs/solutions/architecture/2026-03-12-mac-cloudkit-remote-change-auto-refresh.md
---

# Solution: Mac Cloud Sync Waiting View UX 메시징 수정

## Problem

Mac 앱 시작 시 `CloudSyncWaitingView`가 "Waiting for health data from your iPhone"이라는 메시지를 표시하여, 사용자가 iPhone 직접 연결이 필요하다고 오해했다.

### Symptoms

- Mac 앱이 "iPhone에서 건강 데이터를 기다리고 있습니다"라고 표시
- 30초 후 "iPhone에서 iCloud 동기화가 활성화되어 있고 DUNE 앱을 최근에 열었는지 확인"이라는 안내 표시
- 사용자가 iCloud에서만 동기화하면 되는데 왜 iPhone을 기다리는지 혼란

### Root Cause

`CloudSyncWaitingView`의 두 메시지가 데이터 소스를 "iPhone"으로 명시. 실제 Mac 데이터 경로는:
1. iPhone → HealthKit → SwiftData/CloudKit mirror (`HealthSnapshotMirrorStore`)
2. CloudKit → Mac의 SwiftData
3. Mac → `CloudMirroredSharedHealthDataService`가 최신 snapshot 읽기

Mac은 iCloud에서만 읽으므로, 메시지가 iCloud 중심이어야 한다.

## Solution

메시지를 iCloud 중심으로 변경:

| Before | After |
|--------|-------|
| "Waiting for health data from your iPhone. This may take a moment." | "Health data syncs through iCloud. This may take a moment on first launch." |
| "Taking longer than expected. Make sure iCloud sync is enabled on your iPhone and the DUNE app has been opened recently." | "If data doesn't appear, make sure iCloud sync is enabled in DUNE settings on your iPhone and the app has been opened at least once." |

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `CloudSyncWaitingView.swift` | 두 Text 문자열을 iCloud 중심으로 변경 | 정확한 데이터 경로 반영 |
| `Localizable.xcstrings` | 구 키 삭제, 신규 키 + en/ko/ja 번역 추가 | orphan 방지 + 3개 언어 동시 반영 |

## Prevention

- Mac/secondary consumer용 UX 메시지 작성 시 데이터 소스를 "iCloud" 또는 "cloud sync"로 표현
- "iPhone"은 문제 해결 안내(troubleshooting) 맥락에서만 간접 언급
- CloudKit 미러 기반 consumer가 추가될 때 기존 메시지를 그대로 복사하지 말고 데이터 경로 확인 후 작성

## Lessons Learned

- 동기화 메시지는 사용자가 보는 관점에서 작성해야 한다: Mac 사용자에게 "iPhone에서 기다리는 중"은 직접 연결이 필요한 것처럼 들린다
- 실제 데이터 경로(iPhone → CloudKit → Mac)와 사용자 멘탈 모델(iCloud에서 자동 동기화)이 다를 수 있으므로, 기술적 정확성보다 사용자 이해도를 우선한다
