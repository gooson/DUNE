---
tags: [hourly-tracking, sparkline, swiftdata, cloudkit, score-persistence, upsert]
date: 2026-03-13
category: solution
status: implemented
---

# Hourly Score Snapshot System

## Problem

사용자가 하루 동안 컨디션/웰니스/준비도 점수가 어떻게 변화했는지 확인할 수 없었음.
점수는 HealthKit 데이터 변경 시 재계산되지만 이전 시간대 값이 저장되지 않아 일중 트렌드 파악 불가.

## Solution

### Architecture

```
AppRefreshCoordinating.refreshNeededStream
    ↓
ScoreRefreshService.startListening()  ← sparkline 로드
    ↓
ViewModels (Dashboard/Wellness/Activity)
    ↓ recordSnapshot(partial scores)
ScoreRefreshService.recordSnapshot()
    ↓ debounced 200ms
ScoreRefreshService.loadTodaySparklines()
    ↓
Hero Cards (observe sparkline @Observable properties)
```

### Key Design Decisions

1. **Multi-VM Partial Upsert**: 3개 ViewModel이 각각 자신의 점수만 전달. `recordSnapshot()`은 기존 행을 찾아 non-nil 필드만 업데이트 (upsert). `lastSnapshotHour` 같은 early-return guard는 multi-VM 패턴을 깨뜨리므로 사용 금지.

2. **Debounced Sparkline Reload**: 3 VM이 거의 동시에 `recordSnapshot()` 호출 → 200ms 디바운스로 sparkline fetch 1회로 통합.

3. **Single ModelContext**: `ScoreRefreshService`는 init에서 `ModelContext` 1개 생성, 모든 메서드에서 재사용. 메서드별 `ModelContext(modelContainer)` 생성은 refresh cycle당 6 allocation으로 낭비.

4. **Bounds Validation at Persistence Layer**: 점수 0-100, HRV 0-500ms, RHR 20-300bpm으로 클램핑. CloudKit 전파 전 차단.

5. **Domain Model Separation**: `HourlySparklineData`(Domain)는 Foundation-only. `HourlyScoreSnapshot`(@Model)은 Data layer. ViewModel은 두 레이어 모두 접근 가능 (기존 SharedHealthDataService 패턴 준수).

### SwiftData Schema

```swift
@Model
final class HourlyScoreSnapshot {
    var date: Date?        // hour-truncated, unique per hour
    var conditionScore: Double?
    var wellnessScore: Double?
    var readinessScore: Double?
    var hrvValue: Double?
    var rhrValue: Double?
    var sleepScore: Double?
    var createdAt: Date?
}
```

모든 필드 Optional — CloudKit 필수 요건.

### UI Components

- `HourlySparklineView`: Swift Charts LineMark+AreaMark, max 24 points, catmullRom
- `ScoreDeltaBadge`: 이전 시간 대비 변화량 capsule badge
- `nonEmptyOrNil` convenience: call-site 중복 제거

## Prevention

### 반복 가능한 실수

1. **Guard로 idempotency 구현 시**: multi-caller 환경에서 첫 caller만 통과하고 나머지는 blocked. Upsert 패턴이 더 적합.
2. **메서드 내 ModelContext 생성**: `@MainActor` 서비스는 stored ModelContext 사용. 메서드별 생성은 불필요한 allocation + 캐시 미활용.
3. **Chart closure 내 allocation**: LinearGradient 등 computed property로 호이스트. body 평가마다 재생성 방지.

## Related Files

| 파일 | 역할 |
|------|------|
| `Data/Persistence/Models/HourlyScoreSnapshot.swift` | SwiftData 모델 |
| `Data/Services/ScoreRefreshService.swift` | 스냅샷 저장 + 스파크라인 로드 |
| `Domain/Models/HourlySparklineData.swift` | 도메인 모델 |
| `Presentation/Shared/Components/HourlySparklineView.swift` | 차트 컴포넌트 |
| `Presentation/Shared/Components/ScoreDeltaBadge.swift` | 델타 뱃지 |
