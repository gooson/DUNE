---
topic: watch-design-overhaul
date: 2026-02-18
status: draft
confidence: high
related_solutions:
  - architecture/2026-02-18-watch-navigation-state-management
  - general/2026-02-18-watch-weight-prefill-pattern
related_brainstorms:
  - 2026-02-18-watch-design-overhaul
  - 2026-02-18-watch-first-workout-ux
---

# Implementation Plan: Watch 디자인 전면 수정

## Context

현재 Watch 앱의 7가지 UX 문제를 해결하기 위한 디자인 전면 수정:
1. 퀵스타트/템플릿 배치 혼란 (퀵스타트가 상단에 위치)
2. 싱크 상태 불투명 (exerciseLibrary 싱크 진행/완료 알 수 없음)
3. 워크아웃 시작 피드백 부재
4. 크라운이 무게 조작에 바인딩되어 스크롤 불가
5. 정보 과밀 (`.caption2`, `size: 9` 극소 폰트 + 4개 ±버튼)
6. Complete Set 터치 타겟 불충분
7. 레스트 타이머 햅틱 부족

## Requirements

### Functional

- 홈 화면: 템플릿 목록이 메인, 퀵스타트는 하단 별도 섹션
- 싱크 상태: `SyncStatus` enum으로 syncing/synced/failed/notConnected 표시
- 무게/랩 입력: 메트릭 화면에서 탭 → 전용 시트 → 크라운으로 무게 조작
- 메트릭 화면: 큰 폰트 계층적 표시 (Primary/Action/Secondary)
- 워크아웃 시작: 로딩 오버레이 + 성공 햅틱 + 실패 에러 표시
- Complete Set: 44pt+ 터치 타겟
- 레스트 타이머: 10초 전 경고 햅틱 + 완료 시 `.notification` 햅틱

### Non-functional

- 기존 3-Page TabView 구조 유지 (구조 변경 최소화)
- WorkoutManager/WatchConnectivityManager 로직 변경 최소화
- View 레이어 중심 변경
- 기존 prefill 로직 보존 (lastCompletedSet → template default)
- 크라운 스크롤이 메인 화면에서 자연스럽게 동작

## Approach

**View 레이어 리디자인 + 입력 시트 분리** 접근법을 사용한다.

핵심: MetricsView에서 `.digitalCrownRotation`을 제거하고, 무게/랩 입력을 별도 sheet으로 분리한다. 메인 화면은 현재 세트 정보 표시 + Complete 버튼에 집중한다. 크라운은 메인 화면에서 스크롤 전용으로 복원된다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| 입력 시트 분리 (선택) | 크라운 충돌 해결, 정보 과밀 해소, 큰 입력 UI | 탭 수 1회 증가 | **채택**: UX 이점이 탭 수 증가를 상쇄 |
| 크라운 모드 전환 (포커스 기반) | 기존 구조 유지 | 모드 전환이 비직관적, 실수 조작 가능 | 기각 |
| 스크롤 불필요하게 리디자인 | 화면 정보를 한 화면에 최소화 | 정보 부족, 추가 탭 필요 | 기각 |
| 카드 기반 단계별 입력 | 한 화면에 한 가지만 | 세트 완료까지 3스텝 필요, 느림 | 기각 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DailveWatch/Views/MetricsView.swift` | **Major Rewrite** | 계층적 레이아웃 + 크라운 제거 + 입력 시트 트리거 |
| `DailveWatch/Views/SetInputSheet.swift` | **New File** | 무게/랩 전용 입력 시트 (크라운 바인딩) |
| `DailveWatch/Views/RoutineListView.swift` | **Modify** | 템플릿 우선 배치 + 싱크 상태 UI |
| `DailveWatch/WatchConnectivityManager.swift` | **Modify** | `SyncStatus` enum + 상태 추적 프로퍼티 |
| `DailveWatch/Views/RestTimerView.swift` | **Modify** | 10초 전 햅틱 + Skip 버튼 확대 |
| `DailveWatch/ContentView.swift` | **Modify** | 워크아웃 시작 로딩 상태 |
| `DailveWatch/Views/SessionPagingView.swift` | **Minor** | 시작 피드백 전달 |
| `DailveWatch/Views/ControlsView.swift` | **Minor** | 버튼 터치 타겟 검증 |
| `Dailve/project.yml` | **Modify** | 새 파일 추가 (xcodegen) |

## Implementation Steps

### Step 1: SyncStatus + WatchConnectivityManager 업데이트

- **Files**: `WatchConnectivityManager.swift`
- **Changes**:
  - `SyncStatus` enum 추가: `.syncing`, `.synced(Date)`, `.failed(String)`, `.notConnected`
  - `private(set) var syncStatus: SyncStatus = .notConnected` 프로퍼티 추가
  - `handleContext()` 에서 상태 전환: syncing → synced(Date()) / failed
  - `sessionReachabilityDidChange` 에서 `.notConnected` 감지
  - `activationDidCompleteWith` 에서 초기 상태 설정
- **Verification**: 빌드 성공. WatchConnectivityManager가 syncStatus를 올바르게 업데이트하는지 수동 확인

```swift
enum SyncStatus: Equatable {
    case syncing
    case synced(Date)
    case failed(String)
    case notConnected
}
```

### Step 2: RoutineListView 재배치

- **Files**: `RoutineListView.swift`
- **Changes**:
  - 섹션 순서 변경: "Routines" 섹션을 상단으로, "Quick Start" 섹션을 하단으로
  - 싱크 상태 인디케이터 추가 (하단 캡션):
    - `.syncing` → `ProgressView()` + "Syncing..."
    - `.synced(date)` → `checkmark.circle` + "N min ago"
    - `.failed` → `exclamationmark.triangle` + 에러 메시지
    - `.notConnected` → `iphone.slash` + "iPhone not connected"
  - 템플릿 카드에 운동 수 표시 유지
  - 빈 상태: "iPhone에서 루틴을 만들어 주세요" + 퀵스타트 유도
- **Verification**: 홈 화면에서 템플릿이 먼저 보이는지, 싱크 상태가 표시되는지 시각 확인

### Step 3: SetInputSheet 신규 생성

- **Files**: `Views/SetInputSheet.swift` (NEW)
- **Changes**:
  - `@Binding var weight: Double` + `@Binding var reps: Int` 수신
  - 상단: "Weight (kg)" 라벨 + 대형 숫자 (`.title.monospacedDigit.bold`)
  - 크라운: `.digitalCrownRotation($weight, from: 0, through: 500, by: 2.5, sensitivity: .medium)`
  - ±버튼: -5, -2.5, +2.5, +5 (기존 로직 재사용, 더 큰 터치 타겟)
  - 중간: 구분선
  - 하단: "Reps" 라벨 + 대형 숫자 + ±1 버튼 (큰 원형)
  - "Done" 버튼으로 시트 닫기
  - `.focusable()` + `.digitalCrownRotation()` 은 시트 내에서만 활성
- **Verification**: 시트 열기 → 크라운으로 무게 조작 → ±버튼 동작 → Done 닫기 확인

```swift
struct SetInputSheet: View {
    @Binding var weight: Double
    @Binding var reps: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Weight section
                Text("Weight (kg)").font(.caption).foregroundStyle(.secondary)
                Text("\(weight, specifier: "%.1f")")
                    .font(.title.monospacedDigit().bold())
                    .foregroundStyle(.green)

                HStack(spacing: 8) {
                    weightButton("-5", delta: -5)
                    weightButton("-2.5", delta: -2.5)
                    weightButton("+2.5", delta: 2.5)
                    weightButton("+5", delta: 5)
                }

                Divider()

                // Reps section
                Text("Reps").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 20) {
                    Button { if reps > 0 { reps -= 1 } } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                    }
                    Text("\(reps)")
                        .font(.title.monospacedDigit().bold())
                        .foregroundStyle(.green)
                    Button { if reps < 100 { reps += 1 } } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }

                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
            }
            .padding(.horizontal)
        }
        .focusable()
        .digitalCrownRotation($weight, from: 0, through: 500, by: 2.5, sensitivity: .medium)
    }
}
```

### Step 4: MetricsView 리디자인

- **Files**: `MetricsView.swift`
- **Changes**:
  - `.digitalCrownRotation()` 제거 (메인 뷰에서)
  - `.focusable()` 제거 (메인 뷰에서)
  - 4개 ±weight 버튼 제거
  - ±reps 버튼 제거
  - 새 레이아웃:
    1. 진행 바 (상단, 기존 유지)
    2. 운동명 (`.headline.bold`) + 세트 번호 (`.subheadline`)
    3. 세트 도트 (기존보다 큰 8px)
    4. 무게 × 랩 탭 영역 → `.sheet(isPresented:)` → `SetInputSheet`
       - 탭 가능한 카드: `"45.0 kg × 10 reps"` (`.title3.monospacedDigit`)
       - chevron 또는 pencil 아이콘으로 편집 가능 힌트
    5. Complete Set 버튼 (`.borderedProminent`, `.frame(minHeight: 44)`)
    6. 심박수 (하단, `.caption`)
  - `@State private var showInputSheet = false` 추가
  - prefill 로직 유지 (onAppear + onChange)
  - completeSet() 로직 유지
- **Verification**:
  - 크라운으로 스크롤 가능한지 확인
  - 무게/랩 영역 탭 → 시트 열림 확인
  - Complete Set 44pt+ 터치 타겟 확인
  - prefill 값이 올바르게 표시되는지 확인

### Step 5: 워크아웃 시작 피드백

- **Files**: `ContentView.swift`, `RoutineListView.swift`
- **Changes**:
  - `RoutineListView` 에서 템플릿 탭 시:
    - 즉시 `isStartingWorkout = true` 설정
    - 로딩 오버레이 표시 ("Starting..." + `ProgressView`)
    - `workoutManager.startWorkout()` 완료 시 오버레이 해제
    - 실패 시 에러 메시지 + `.failure` 햅틱
    - 성공 시 `.success` 햅틱 (ContentView가 자동 전환)
  - `ContentView` 에서:
    - `workoutManager.isActive` 전환 시 `.success` 햅틱 추가
- **Verification**: 템플릿 탭 → 로딩 표시 → 세션 전환 확인. 에러 시 메시지 표시 확인

### Step 6: RestTimerView 햅틱 강화

- **Files**: `RestTimerView.swift`
- **Changes**:
  - 카운트다운 루프에서 `remainingSeconds == 10` 검사 추가
  - 10초 남았을 때 `WKInterfaceDevice.current().play(.start)` 햅틱
  - 완료 시 기존 `.notification` 유지
  - Skip 버튼 `.frame(minHeight: 36)` 확대
  - 남은 시간 폰트 `.title2` → `.title` 확대
- **Verification**: 레스트 타이머 시작 → 10초 전 햅틱 확인 → 완료 햅틱 확인

### Step 7: xcodegen + 빌드 검증

- **Files**: `Dailve/project.yml`
- **Changes**:
  - `SetInputSheet.swift` 파일 경로 추가 (필요 시)
  - `cd Dailve && xcodegen generate`
  - 빌드: `xcodebuild build -project Dailve/Dailve.xcodeproj -scheme DailveWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm),OS=26.2'`
- **Verification**: 빌드 성공 (warning 0 목표)

## Edge Cases

| Case | Handling |
|------|----------|
| 템플릿 0개 + exerciseLibrary 비어있음 | 빈 상태 메시지 + "Open iPhone" 안내 |
| 입력 시트 열린 상태에서 백그라운드 | sheet dismiss 시 마지막 입력값 보존 (`@Binding`) |
| 크라운 시트 밖에서 조작 | 메인 뷰에서는 스크롤만 (안전) |
| prefill 값이 0인 경우 | "0.0 kg × 0 reps" 표시 + 탭하여 수정 유도 |
| 운동 시작 실패 (HealthKit 권한 없음) | 에러 메시지 표시 + `.failure` 햅틱 |
| 싱크 상태가 `.failed`인 상태에서 운동 시작 | 허용 (로컬 템플릿으로 시작 가능) |
| 레스트 타이머 10초 미만으로 설정 | 10초 경고 스킵, 완료 햅틱만 |
| 시트 내 무게 0-500 범위 초과 시도 | `.digitalCrownRotation(from:through:)` 자체가 범위 제한 |

## Testing Strategy

- **Unit tests**:
  - `SyncStatus` enum 동등성 테스트
  - MetricsView의 prefill 로직은 기존 테스트로 커버 (변경 없음)
- **Manual verification**:
  - 실기기에서 크라운 스크롤 동작 확인
  - 시트 내 크라운 → 무게 변경 확인
  - 싱크 상태 표시 확인 (실기기 iPhone 연결/해제)
  - 워크아웃 시작 → 로딩 → 세션 전환 흐름
  - 레스트 타이머 10초 전 햅틱 확인
  - Complete Set 버튼 터치 타겟 (운동 중 땀 상태)
- **빌드 검증**: Watch 시뮬레이터 빌드 성공

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 시트 내 `.digitalCrownRotation`이 시트 ScrollView와 충돌 | Medium | High | 시트 내 ScrollView 제거, VStack만 사용 |
| `.focusable()` 포커스 관리 문제 (시트 open/close 시) | Low | Medium | `onAppear`에서 포커스 명시적 설정 |
| 입력 시트 탭 수 증가로 사용자 불만 | Low | Medium | 이전 값 prefill로 대부분 수정 불필요 |
| SyncStatus 타이밍 오차 (synced 직후 데이터 변경) | Low | Low | "Last synced" 시간 표시로 사용자가 판단 |
| Watch 시뮬레이터에서 크라운 테스트 제한 | Medium | Low | 시뮬레이터에서는 마우스 스크롤로 대체 테스트 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**:
  - View 레이어 중심 변경으로 로직 변경 최소화
  - WorkoutManager/WatchConnectivity 핵심 로직 변경 없음
  - 기존 prefill, completeSet, restTimer 로직 재사용
  - 새 파일은 SetInputSheet 1개만
  - watchOS 표준 패턴 (`.sheet`, `.digitalCrownRotation`) 사용
  - 관련 brainstorm + solution 문서가 이미 존재
