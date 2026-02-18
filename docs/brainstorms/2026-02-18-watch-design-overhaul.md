---
tags: [watch, watchos, ux, design, redesign, digital-crown, sync, workout]
date: 2026-02-18
category: brainstorm
status: draft
---

# Brainstorm: Watch 디자인 전면 수정

## Problem Statement

현재 Watch 앱의 UX가 7가지 핵심 문제로 인해 실제 운동 환경에서 사용하기 어려움:

| # | 문제 | 심각도 | 현재 상태 |
|---|------|--------|----------|
| 1 | 퀵스타트/템플릿 배치 혼란 | High | 홈에 혼재, 우선순위 불명확 |
| 2 | 싱크 상태 불투명 | High | exerciseLibrary 싱크 진행/완료 알 수 없음 |
| 3 | 시뮬레이터 퀵스타트 테스트 불가 | Medium | WCSession 시뮬레이터 미지원 |
| 4 | 워크아웃 시작 피드백 부재 | High | HKWorkoutSession 시작 비동기, 상태 전환 느림 |
| 5 | 크라운 = 무게만, 스크롤 불가 | Critical | `.digitalCrownRotation`이 ScrollView 스크롤 가로챔 |
| 6 | 정보 과밀 | High | `.caption2`, `size: 9` 극소 폰트 + 4개 ±버튼 동시 노출 |
| 7 | 최신 디자인 미반영 | Medium | watchOS 26 패턴 미적용 |

**핵심**: 운동 중 땀이 나는 상태에서 작은 버튼을 정확히 누르기 어렵고, 정보 우선순위가 불명확하며, 크라운을 돌려도 화면 이동이 안 됨.

## Target Users

- 헬스장에서 Watch만 착용하고 운동하는 사용자
- 미리 짠 루틴(템플릿)을 실행하는 중급 이상 사용자
- 세트 간 빠르게 무게/랩 기록하고 다음 세트로 넘어가는 패턴

## Success Criteria

1. 홈 화면에서 1탭으로 루틴 시작 가능
2. 싱크 상태가 시각적으로 명확 (진행 중 / 완료 / 실패)
3. 크라운으로 화면 스크롤이 가능하고, 무게 입력은 별도 시트에서
4. 운동 시작/종료 상태가 명확한 시각적 피드백
5. 핵심 정보(세트/무게/랩)가 한눈에 보이고, 부가 정보는 계층 분리
6. 땀이 나는 상태에서도 미스탭 없이 조작 가능 (큰 터치 타겟)

## Decisions

| 질문 | 결정 | 근거 |
|------|------|------|
| 홈 화면 우선순위 | **템플릿 우선** | 사용자 대부분 루틴 기반 운동. Hevy 스타일 |
| 크라운 역할 | **전용 입력 시트** | 크라운=스크롤(기본). 무게/랩은 sheet에서 크라운 사용 |
| 정보 밀도 | **계층적 표시** | 핵심(무게+랩+완료)은 크게, 부가(심박수+세트진행)는 작게 |
| 싱크/테스트 | **싱크 UI만 추가** | 진행 상태 표시만 MVP. Mock/Preview는 후순위 |

## Proposed Design

### 1. 홈 화면 재설계 (RoutineListView)

**현재**:
```
┌──────────────────┐
│ Quick Start ▶    │  ← 퀵스타트와 템플릿이 혼재
│ ─────────────── │
│ Template A       │
│ Template B       │
│ Template C       │
└──────────────────┘
```

**변경**:
```
┌──────────────────┐
│ 📋 My Routines   │  ← 섹션 헤더
│                  │
│ ┌──────────────┐ │
│ │ Template A   │ │  ← 카드형. 1탭으로 시작
│ │ 4 exercises  │ │
│ └──────────────┘ │
│ ┌──────────────┐ │
│ │ Template B   │ │
│ │ 6 exercises  │ │
│ └──────────────┘ │
│                  │
│ ── Quick Start ──│  ← 하단 섹션, 구분 명확
│ ⚡ Start Exercise │
│                  │
│ ⟳ Last synced    │  ← 싱크 상태 표시
│   2 min ago      │
└──────────────────┘
```

**변경 포인트**:
- 템플릿이 메인 콘텐츠 (스크롤 가능)
- 퀵스타트는 하단 별도 섹션
- 싱크 상태 인디케이터 추가 (하단)
- 크라운으로 자연스러운 스크롤

### 2. 싱크 상태 표시

**현재**: 표시 없음. 빈 라이브러리면 "Open iPhone app" 텍스트만.

**변경**:
```swift
enum SyncStatus {
    case syncing       // ⟳ 회전 아이콘
    case synced(Date)  // ✓ "2 min ago"
    case failed        // ⚠ "Tap to retry"
    case notConnected  // 📱 "Open iPhone"
}
```

**표시 위치**: 홈 화면 하단, 작은 캡션 + 아이콘
**동작**: WatchConnectivityManager의 `activationState` + `applicationContext` 수신 타이밍으로 판단

### 3. 워크아웃 시작 피드백

**현재**: 탭 → (로딩 없음) → 갑자기 SessionPagingView 표시

**변경**:
```
탭 → 즉시 로딩 오버레이 ("Starting...")
   → HKWorkoutSession 시작 완료
   → 세션 화면 전환 + 햅틱 피드백 (.success)
   → 실패 시 에러 메시지 + 햅틱 (.failure)
```

### 4. 세션 메트릭 화면 재설계 (MetricsView)

**현재 (문제)**:
```
┌──────────────────┐
│ Exercise Name    │ .caption
│ Set 2/4 ●●○○    │ .caption2
│ ─────────────── │
│ Weight    45.0kg │ .caption
│ -5 -2.5  +2.5 +5│ ← 4개 작은 버튼
│ ─────────────── │
│ Reps         10  │
│   -      +       │
│ ─────────────── │
│ [Complete Set]   │
│ ❤️ 142 bpm       │ .caption2
└──────────────────┘
크라운 = 무게 조작 (스크롤 불가)
```

**변경 (계층적 표시 + 입력 시트)**:
```
┌──────────────────────┐
│ ━━━━━━━━━━━━━━━━━━━━ │  ← 전체 진행 바 (얇게)
│                      │
│    Bench Press       │  .headline, 볼드
│    Set 2 of 4        │  .subheadline
│    ●●○○              │  세트 도트 (큰 사이즈)
│                      │
│  ┌────────────────┐  │
│  │   45.0 kg      │  │  ← 큰 폰트, 탭하면 입력 시트
│  │   × 10 reps    │  │
│  └────────────────┘  │
│                      │
│  ╔════════════════╗  │
│  ║  Complete Set  ║  │  ← 큰 버튼 (44pt+ 높이)
│  ╚════════════════╝  │
│                      │
│     ❤️ 142            │  .caption, 하단 고정
└──────────────────────┘
크라운 = 스크롤 (기본 동작)
```

**무게/랩 입력 시트** (무게/랩 영역 탭 시):
```
┌──────────────────────┐
│     Weight (kg)      │
│                      │
│      ╔══════╗        │
│      ║ 45.0 ║        │  ← 대형 숫자, 크라운으로 조작
│      ╚══════╝        │
│                      │
│   -5   -2.5  +2.5  +5│  ← 보조 버튼
│                      │
│  ──────────────────  │
│     Reps             │
│                      │
│    -    [ 10 ]    +  │  ← ±1 버튼, 큰 터치 타겟
│                      │
│  [Done]              │  ← 시트 닫기
└──────────────────────┘
크라운 = 무게 조작 (시트 내에서만)
```

### 5. 크라운 UX 해결 전략

| 컨텍스트 | 크라운 동작 | 구현 |
|----------|------------|------|
| 홈 화면 | 스크롤 (기본) | ScrollView 기본 동작 |
| 메트릭 화면 | 스크롤 (기본) | `.digitalCrownRotation` 제거 |
| 입력 시트 | 무게 조작 | 시트 내 `.digitalCrownRotation` + `.focusable()` |
| 레스트 타이머 | 시간 추가/감소 | ±30초 (옵션) |

**핵심**: `.digitalCrownRotation`을 메인 뷰에서 제거하고, 전용 입력 시트에서만 사용.

### 6. 정보 계층 재정의

| 계층 | 정보 | 폰트 | 위치 |
|------|------|------|------|
| **Primary** | 운동명, 세트 번호 | `.headline` / `.subheadline` | 상단 |
| **Action** | 무게 × 랩, Complete 버튼 | `.title3` / 큰 버튼 | 중앙 |
| **Secondary** | 심박수, 진행 바 | `.caption` | 하단/상단 가장자리 |
| **Hidden** | 칼로리, 경과시간 | (다른 페이지) | Controls 페이지에서 |

### 7. 레스트 타이머 (유지 + 개선)

현재 RestTimerView의 원형 게이지는 좋은 패턴. 개선 사항:

- 햅틱 피드백 강화: 10초 전 `.start`, 완료 시 `.notification`
- Skip 버튼 크기 확대 (터치 타겟 44pt+)
- 남은 시간 폰트 확대 (`.title` → `.largeTitle`)

### 8. 최신 디자인 참고 포인트

**watchOS 26 Workout 앱 변경사항**:
- 4-corner 아이콘 레이아웃 (metric/buddy/media/alerts)
- Liquid Glass 머티리얼
- 더 큰 폰트, 더 넓은 간격
- 컨텍스트 기반 정보 표시

**우리 앱에 적용할 것 (MVP)**:
- 큰 폰트 + 넓은 간격 → 정보 과밀 해결
- 명확한 계층 → Primary/Action/Secondary 분리
- 입력 시트 패턴 → 크라운 충돌 해결
- 상태 피드백 → 싱크/워크아웃 시작 명확화

**후순위 (Future)**:
- Liquid Glass 머티리얼 적용
- 4-corner 레이아웃
- Smart Stack Widget

## Constraints

### 기술적 제약
- WCSession 시뮬레이터 미지원 → 싱크 테스트는 실기기 필요
- `.digitalCrownRotation` 제거 시 기존 크라운 무게 입력 사용자 학습곡선 변경
- Sheet 내 `.digitalCrownRotation`은 sheet 포커스 관리 필요

### 범위 제약
- 기존 3-Page TabView 구조 유지 (대규모 구조 변경 최소화)
- WorkoutManager/WatchConnectivityManager 로직 변경 최소화
- 주로 View 레이어 변경에 집중

## Edge Cases

1. **템플릿 0개**: "iPhone에서 루틴을 만들어 주세요" + 퀵스타트로 유도
2. **싱크 중 운동 시작**: 싱크 완료 대기 없이 즉시 시작 허용 (로컬 데이터로)
3. **입력 시트에서 앱 백그라운드**: sheet dismiss 시 현재 입력값 보존
4. **운동 중 크라운 실수 조작**: 시트 밖에서는 크라운이 스크롤만 하므로 실수 무게 변경 불가
5. **극단적 무게값**: 시트 내 0-500kg 범위 제한 유지

## Scope

### MVP (Must-have)

1. **홈 화면 재배치**: 템플릿 우선 + 퀵스타트 하단 분리
2. **싱크 상태 UI**: SyncStatus enum + 하단 인디케이터
3. **무게/랩 입력 시트**: MetricsView에서 탭 → sheet → 크라운 무게 조작
4. **메트릭 화면 계층화**: 큰 폰트 + 핵심 정보 중심 + 크라운 스크롤 복원
5. **워크아웃 시작 피드백**: 로딩 상태 + 햅틱 + 에러 표시
6. **Complete Set 버튼 확대**: 44pt+ 터치 타겟
7. **레스트 타이머 햅틱 강화**: 10초 전 + 완료 시

### Nice-to-have (Future)

1. Liquid Glass 머티리얼 적용
2. 시뮬레이터용 Mock exerciseLibrary 주입
3. SwiftUI Preview 지원
4. 4-corner 레이아웃
5. 운동 기록 히스토리 오버레이 (이전 무게/랩 참고)
6. Smart Stack Widget

## Open Questions

1. 입력 시트에서 무게와 랩을 하나의 시트로 합칠지, 각각 별도 시트로 할지?
   → **제안**: 하나의 시트에 무게(상단, 크라운) + 랩(하단, ±버튼) 합침. 탭 수 최소화.
2. 레스트 타이머 완료 시 자동으로 입력 시트를 열지, 메트릭 화면만 보여줄지?
   → **제안**: 메트릭 화면만 (이전 값 프리필). 사용자가 수정 필요시만 탭.
3. 3-Page TabView를 유지할지, 수직 스크롤로 변경할지?
   → **제안**: 유지. Apple 표준 패턴이고 구조 변경 최소화.

## Affected Files (예상)

| 파일 | 변경 내용 |
|------|----------|
| `Views/RoutineListView.swift` | 템플릿 우선 배치 + 싱크 UI |
| `Views/MetricsView.swift` | 계층화 + 입력 시트 분리 + 크라운 제거 |
| `Views/SetInputSheet.swift` | **신규** - 무게/랩 입력 전용 시트 |
| `Views/RestTimerView.swift` | 햅틱 강화 + Skip 버튼 확대 |
| `Views/SessionPagingView.swift` | 워크아웃 시작 피드백 |
| `ContentView.swift` | 로딩 상태 관리 |
| `WatchConnectivityManager.swift` | SyncStatus 프로퍼티 추가 |

## Next Steps

- [ ] `/plan` 으로 구현 계획 생성
- [ ] SetInputSheet 프로토타입
- [ ] 메트릭 화면 계층 레이아웃 프로토타입
