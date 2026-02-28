---
tags: [cloudkit, background-mode, remote-notification, info-plist, healthkit, background-delivery, entitlements, xcodegen]
category: general
date: 2026-02-28
severity: important
related_files: [DUNE/Resources/Info.plist, DUNE/Resources/DUNE.entitlements, DUNE/project.yml]
related_solutions: []
---

# Solution: CloudKit remote-notification 배경 모드 및 HealthKit Background Delivery 설정

## Problem

### Symptoms

- 콘솔에 `BUG IN CLIENT OF CLOUDKIT: CloudKit push notifications require the 'remote-notification' background mode in your info plist.` 경고 출력
- Xcode HealthKit capability에서 Background Delivery 체크박스 비활성 상태

### Root Cause

1. **CloudKit silent push**: CloudKit은 데이터 변경 시 `remote-notification` silent push로 다른 디바이스에 알림. `UIBackgroundModes`에 `remote-notification`이 없으면 수신 불가
2. **INFOPLIST_KEY_ 빌드 설정 한계**: `INFOPLIST_KEY_UIBackgroundModes` 빌드 설정은 배열 타입 plist 키를 제대로 생성하지 못함. Info.plist에 직접 배열로 선언해야 함
3. **HealthKit Background Delivery**: `com.apple.developer.healthkit.background-delivery` 엔타이틀먼트 누락

## Solution

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Resources/Info.plist` | `UIBackgroundModes` 배열에 `remote-notification` 추가 | CloudKit silent push 수신 |
| `DUNE/Resources/DUNE.entitlements` | `com.apple.developer.healthkit.background-delivery: true` 추가 | HealthKit Background Delivery 활성화 |
| `DUNE/project.yml` | entitlements properties에 `background-delivery` 추가 | xcodegen 재생성 시 entitlements 동기화 |

### Key Code

**Info.plist** (빌드 설정이 아닌 plist 직접 선언):
```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

**project.yml** (entitlements):
```yaml
com.apple.developer.healthkit.background-delivery: true
```

## Prevention

### Checklist Addition

- [ ] CloudKit 사용 시 `UIBackgroundModes: [remote-notification]`이 Info.plist에 있는지 확인
- [ ] HealthKit Observer Query 사용 시 `background-delivery` 엔타이틀먼트 확인
- [ ] 배열 타입 plist 키는 `INFOPLIST_KEY_` 빌드 설정 대신 Info.plist에 직접 선언

### Rule Addition (if applicable)

없음 (일회성 설정이므로 규칙 추가 불필요)

## Lessons Learned

- `INFOPLIST_KEY_` 빌드 설정은 문자열/불리언 타입에 적합. 배열 타입(`UIBackgroundModes` 등)은 Info.plist에 직접 선언하는 것이 확실함
- CloudKit + HealthKit Background Delivery는 세트로 설정해야 실시간 동기화가 완성됨
- Xcode capability UI 체크박스 상태와 실제 entitlements 파일을 교차 확인해야 누락을 잡을 수 있음
