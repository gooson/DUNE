---
tags: [watchconnectivity, watchos, sync, templates, userinfo, sendmessage]
date: 2026-03-08
category: solution
status: implemented
---

# Watch Template Sync Background Request Fix

## Problem

watch에서 workout template sync를 요청할 때 아래 로그가 간헐적으로 출력될 수 있었다.

`Failed to request workout template sync: 페어링된 기기에서 WatchConnectivity 세션에 접근할 수 없습니다.`

## Root Cause

workout template sync 요청은 즉시 응답이 필요 없는 background sync 성격인데도, watch가 `sendMessage`와 `transferUserInfo`를 함께 시도하고 있었다.

이때 `isReachable`가 일시적으로 true여도 paired device의 session이 interactive message를 받을 준비가 안 된 상태면 `sendMessage`만 실패 로그를 남길 수 있었다.

## Solution

workout template sync 요청은 background 전달만 사용하도록 바꿨다.

- exercise library sync: `sendMessage` + `transferUserInfo` 유지
- workout template sync: `transferUserInfo`만 사용

## Prevention

- 즉시 UI 응답이 필요 없는 WatchConnectivity 요청에는 `sendMessage`를 기본값으로 쓰지 않는다.
- interactive transport가 꼭 필요한 요청과 background transport로 충분한 요청을 policy로 분리해 테스트한다.
