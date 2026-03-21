---
tags: [mac, icloud, ux, cloudkit, messaging]
date: 2026-03-21
category: plan
status: draft
---

# Plan: Mac Cloud Sync Waiting View UX 개선

## Problem Statement

Mac 앱 시작 시 `CloudSyncWaitingView`가 표시되는데, 메시지가 "Waiting for health data from your iPhone"으로 되어 있어 iPhone 직접 연결을 기다리는 것처럼 보인다.

실제 데이터 경로는 iPhone → HealthKit → SwiftData/CloudKit → Mac 이며, Mac은 iCloud에서만 데이터를 읽으면 된다. 메시지가 이를 정확히 반영해야 한다.

## Root Cause

`CloudSyncWaitingView.swift`의 두 메시지가 "iPhone"을 직접 언급하여 사용자에게 iPhone 연결이 필요한 것처럼 오해를 줌:
1. 초기 메시지: "Waiting for health data from your iPhone. This may take a moment."
2. 30초 후 확장 도움말: "Taking longer than expected. Make sure iCloud sync is enabled on your iPhone and the DUNE app has been opened recently."

## Affected Files

| File | Change | Risk |
|------|--------|------|
| `DUNE/Presentation/Shared/Components/CloudSyncWaitingView.swift` | 메시지 텍스트 변경 | Low |
| `Shared/Resources/Localizable.xcstrings` | 기존 키 삭제 + 새 키 en/ko/ja 추가 | Low |

## Implementation Steps

### Step 1: CloudSyncWaitingView 메시지 변경

**현재**:
- 초기: `"Waiting for health data from your iPhone. This may take a moment."`
- 확장: `"Taking longer than expected. Make sure iCloud sync is enabled on your iPhone and the DUNE app has been opened recently."`

**변경**:
- 초기: `"Health data syncs through iCloud. This may take a moment on first launch."`
- 확장: `"If data doesn't appear, make sure iCloud sync is enabled in DUNE settings on your iPhone and the app has been opened at least once."`

### Step 2: Localizable.xcstrings 업데이트

기존 키 2개 삭제, 새 키 2개 추가 (en/ko/ja):

| Old Key | New Key |
|---------|---------|
| `Waiting for health data from your iPhone. This may take a moment.` | `Health data syncs through iCloud. This may take a moment on first launch.` |
| `Taking longer than expected. Make sure iCloud sync is enabled on your iPhone and the DUNE app has been opened recently.` | `If data doesn't appear, make sure iCloud sync is enabled in DUNE settings on your iPhone and the app has been opened at least once.` |

번역:
- ko 초기: `"건강 데이터가 iCloud를 통해 동기화됩니다. 첫 실행 시 잠시 걸릴 수 있어요."`
- ko 확장: `"데이터가 표시되지 않으면 iPhone의 DUNE 설정에서 iCloud 동기화가 켜져 있고, 앱을 한 번 이상 실행했는지 확인하세요."`
- ja 초기: `"健康データはiCloudを通じて同期されます。初回起動時は少々お待ちください。"`
- ja 확장: `"データが表示されない場合は、iPhoneのDUNE設定でiCloud同期が有効になっていて、アプリを一度は開いたことを確認してください。"`

## Test Strategy

- 빌드 성공 확인 (`scripts/build-ios.sh`)
- xcstrings orphan 키 없음 확인

## Risks & Edge Cases

- 기존 번역 키 삭제 시 orphan 발생 방지: 코드 문자열과 xcstrings 키가 정확히 일치해야 함
- "DUNE app has been opened recently" → "at least once"로 변경하여 지속적 사용이 필요한 것처럼 오해하지 않도록 함
