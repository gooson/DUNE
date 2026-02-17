---
tags: [watch, watchos, ux, workout, fitness, independent, cloudkit, healthkit]
date: 2026-02-18
category: brainstorm
status: reviewed
---

# Brainstorm: Watch-First Workout UX

## Problem Statement

현재 Watch 앱은 iPhone에 완전 종속된 companion 구조:
- 운동 시작: iPhone에서만 가능 (Watch의 QuickStart는 1운동만)
- 데이터 보존: iPhone 미연결 시 운동 데이터 유실
- 세션 구조: 멀티 운동 미지원, Rest Timer 없음, HR placeholder

**헬스장에서 iPhone을 가방에 넣고 Watch만으로 운동하는 것이 불가능.**

## Target Users

- 헬스장에서 Watch만 착용하고 운동하는 사용자
- iPhone은 락커/가방에 두고 Watch로 세트 기록하는 패턴
- 루틴 기반으로 운동하는 중급 이상 사용자

## Success Criteria

1. Watch 단독으로 루틴 선택 → 운동 시작 → 세트 기록 → 완료 가능
2. iPhone 미연결 상태에서도 데이터 유실 없음
3. 세트 완료 → 자동 Rest Timer → 햅틱 알림 → 다음 세트 루프
4. 실시간 HR 표시
5. 운동 완료 후 iPhone/다른 기기에 자동 동기화

## Reference Analysis

### Apple Fitness (watchOS 26)

| 패턴 | 상세 |
|------|------|
| 3-Page TabView | Controls (좌) \| Metrics (중) \| Media (우) |
| 운동 시작 | 1탭으로 시작. 운동 타입별 페이지 스와이프 |
| Modal 세션 | 운동 중 다른 기능 접근 차단. 집중 UX |
| Digital Crown | 메트릭 단일 뷰 스크롤, 값 입력 |
| AOD | 1초 간격 업데이트, 서브초 숨김, 블랙 배경 |
| watchOS 26 | Liquid Glass, Custom Workout Builder (iPhone→Watch 동기화) |
| Workout Buddy | AI 동기부여 코치 (음성, on-device) |

### 경쟁 앱 패턴 종합

| 기능 | Strong | Hevy | StrongLifts |
|------|--------|------|-------------|
| Watch 독립 운동 | O | O (루틴 동기화) | O |
| 멀티 운동 | O | O | O |
| Rest Timer | O (자동) | O | O (원형 게이지) |
| 햅틱 | O | O | O |
| HR | O | O | - |
| 세트 타입 | - | O (워밍업/드롭셋) | O (워밍업/작업) |
| 진행률 UI | 리스트 | 리스트 | **원형 링 세그먼트** |
| 루틴 생성 위치 | Watch+iPhone | iPhone만 | iPhone만 |

### 업계 표준 UX 루프 (Set-Log-Rest)

```
루틴 선택 → 첫 운동 표시
  ↓
목표 Weight/Reps 표시 (이전 기록 기반)
  ↓
[Digital Crown으로 Weight 조정] → [+/- 로 Reps 조정]
  ↓
"Complete Set" 탭 (1탭)
  ↓
자동 Rest Timer 시작 (원형 카운트다운)
  ↓
햅틱 + 소리 알림 → 다음 세트 자동 표시
  ↓
모든 세트 완료 → 다음 운동으로 자동 전환
  ↓
모든 운동 완료 → 세션 요약 화면
```

## Proposed Architecture

### 데이터 레이어: Watch-First with CloudKit

```
┌─────────────┐     CloudKit      ┌─────────────┐
│   iPhone     │ ←───────────────→ │  Watch      │
│  SwiftData   │     자동 동기화     │  SwiftData  │
└─────────────┘                    └─────────────┘
       ↕                                  ↕
  WatchConnectivity (실시간 최적화 레이어)
```

- **Primary**: SwiftData + CloudKit으로 양방향 동기화
- **Optimization**: WatchConnectivity로 실시간 동기화 (둘 다 활성 시)
- **Offline**: Watch 로컬 SwiftData에 저장 → 연결 시 CloudKit 자동 동기화
- **데이터 경량화**: Watch에는 루틴/운동 라이브러리/최근 기록만 동기화 (전체 DB X)

### UI 구조: watchOS 26 표준

```
App Launch
├── Smart Stack Widget (오늘의 루틴 / 주간 요약)
│
├── 루틴 목록 (NavigationStack)
│   ├── 루틴 A → 탭하면 운동 세션 시작
│   ├── 루틴 B
│   └── Quick Start (개별 운동 선택)
│
└── Active Workout Session (Modal, 3-Page TabView)
    ├── [좌] Controls: Pause / End / Skip Exercise
    ├── [중] Metrics: 현재 운동/세트/Weight/Reps + HR
    └── [우] Media: Now Playing
```

### 운동 세션 상세 UX

#### 메트릭 뷰 (중앙 페이지) 상태 머신

```
[Set Entry] ←→ [Rest Timer] ←→ [Next Exercise]
     ↓              ↓                ↓
  Weight/Reps   카운트다운         운동명 전환
  Digital Crown  원형 게이지       자동/수동
  Complete 버튼  햅틱 알림         진행률 표시
```

**Set Entry 모드**:
- 운동명 + "Set N/Total"
- Weight: Digital Crown (0-500kg, 2.5kg 간격, 이전 기록 프리필)
- Reps: +/- 버튼 (0-100, 이전 기록 프리필)
- "Complete Set" 버튼 (1탭)
- HR 하단 상시 표시

**Rest Timer 모드**:
- 원형 카운트다운 게이지 (배경 전체)
- 남은 시간 대형 숫자
- HR 표시 유지
- +30s / Skip 버튼
- 완료 시: `.notification` 햅틱 + 자동으로 다음 세트 전환

**운동 전환**:
- 모든 세트 완료 → "Next: [운동명]" 표시
- 자동 전환 (3초) 또는 탭하여 즉시 전환
- 전체 세션 진행률 바 (상단)

#### Controls 뷰 (좌측 페이지)

- Pause/Resume 토글
- End Workout → 확인 다이얼로그 → 세션 요약
- Skip Exercise → 다음 운동으로 건너뛰기

#### 세션 요약 (운동 완료 후)

- 총 시간, 총 볼륨 (kg), 총 세트 수
- 평균/최대 HR
- 운동별 요약 리스트
- "Done" 버튼 → 홈으로 복귀

### HR 모니터링 구현

```swift
// HKAnchoredObjectQuery for real-time HR
let hrType = HKQuantityType(.heartRate)
let query = HKAnchoredObjectQuery(
    type: hrType,
    predicate: HKQuery.predicateForSamples(withStart: workoutStart, end: nil),
    anchor: nil,
    limit: HKObjectQueryNoLimit
) { query, samples, deleted, anchor, error in
    // Update HR display
}
query.updateHandler = { query, samples, deleted, anchor, error in
    // Real-time updates
}
healthStore.execute(query)
```

### WidgetKit Complications (Smart Stack)

| Widget Family | 내용 |
|---------------|------|
| `.accessoryCircular` | 오늘 운동 완료 여부 (체크/미완료) |
| `.accessoryRectangular` | 다음 루틴명 + 운동 수 + 예상 시간 |
| `.accessoryInline` | "가슴/삼두 - 6 exercises" |

Smart Stack Relevance: 루틴 예정 시간 ±1시간에 score 100 부여

### Live Activity

운동 세션 중 Lock Screen / Dynamic Island에 표시:
- 현재 운동명 + 세트 진행률
- 경과 시간
- HR

## Constraints

### 기술적 제약
- Watch 스토리지 제한: 전체 DB 동기화 불가 → 루틴/운동 라이브러리/최근 30일 기록만
- CloudKit 동기화: ~1,000 엔티티까지 10초 내 동기화. 10,000+ 비현실적
- WKExtendedRuntimeSession: 운동 세션 중 백그라운드 실행 유지 필수
- Digital Crown precision: 2.5kg 단위가 적절 (0.5kg은 너무 민감)

### 아키텍처 제약
- 현재 SwiftData 모델은 iPhone용. Watch용 경량 모델 또는 ModelConfiguration 분리 필요
- WatchConnectivity DTO 구조 확장 필요 (루틴 전체 정보)
- Watch Target에 SwiftData + CloudKit 설정 추가 필요

### watchOS 26 요구사항
- Apple Watch Series 6+ / SE 2nd gen+ / Ultra 필수
- 64-bit 빌드 필수 (2026년 4월부터)
- Liquid Glass 디자인 언어 적용

## Edge Cases

1. **운동 중 Watch 배터리 소진**: SwiftData 로컬 저장이므로 데이터 보존. 재시작 시 복구
2. **CloudKit 동기화 충돌**: iPhone과 Watch에서 동시에 같은 루틴 수정 → last-writer-wins 또는 머지
3. **루틴 동기화 전 Watch 운동 시작**: 빈 라이브러리 → "iPhone에서 루틴을 먼저 만들어주세요" 안내
4. **운동 중 iPhone에서 같은 루틴 시작**: 세션 충돌 → Watch 우선 또는 경고
5. **HR 센서 일시적 실패**: "—" 표시, 자동 재시도, 세션 기록에는 gap으로 표시
6. **Rest Timer 중 앱 백그라운드**: WKExtendedRuntimeSession으로 타이머 유지 + 로컬 노티피케이션

## Scope

### MVP (Must-have)

1. **Watch 독립 운동 시작**: 루틴 목록에서 선택 → 전체 세션 진행
2. **멀티 운동 세션**: 루틴 내 여러 운동 순서대로 진행, 운동 간 자동 전환
3. **자동 Rest Timer + 햅틱**: 세트 완료 후 카운트다운, `.notification` 햅틱
4. **HR 모니터링**: HKAnchoredObjectQuery로 실시간 표시
5. **오프라인 저장**: SwiftData 로컬 저장 → CloudKit 자동 동기화
6. **Set-Log-Rest UX 루프**: Digital Crown weight, +/- reps, 1탭 완료
7. **세션 요약**: 운동 완료 후 총 볼륨/시간/HR 요약
8. **3-Page TabView**: Controls | Metrics | Media (표준 레이아웃)

### Nice-to-have (Future)

1. **Smart Stack Widget**: 오늘의 루틴, 주간 요약
2. **Live Activity**: Lock Screen에 운동 진행 상태
3. **Liquid Glass UI**: watchOS 26 디자인 언어
4. **Custom Workout Builder 연동**: iPhone Fitness 앱 스타일 루틴 빌더
5. **세트 타입 구분**: 워밍업 / 작업 / 드롭셋 / 실패 마킹
6. **운동 간 Superset 지원**: 2-3개 운동을 번갈아 수행
7. **이전 기록 오버레이**: 저번 같은 운동의 Weight/Reps를 참고로 표시
8. **음성 피드백**: 세트 완료/Rest 종료 시 TTS 안내
9. **Workout Buddy 연동**: watchOS 26 AI 코치 통합
10. **Apple Watch 문자판 Complication**: 빠른 운동 시작

## Decisions (Resolved)

| 질문 | 결정 | 근거 |
|------|------|------|
| SwiftData 모델 | **동일 모델 공유** | ModelConfiguration으로 Watch 동기화 범위 제한. 변환 레이어 불필요 |
| Rest Timer | **운동별 설정** | iPhone에서 운동마다 기본 Rest 시간 저장 (벤치 90초, 데드 180초 등) |
| Watch 루틴 편집 | **읽기 전용** | 루틴 구조는 iPhone에서만 편집. Watch는 실행만. Strong/Hevy 방식 |
| Ad-hoc 운동 추가 | **미지원** | 루틴 그대로 진행. 단순하고 예측 가능한 UX. MVP에 적합 |
| CloudKit 동기화 범위 | **루틴 + 최근 30일** | Watch 스토리지/동기화 시간 균형. 이전 기록 참조 충분 |

## Next Steps

- [ ] `/plan` 으로 구현 계획 생성 (Phase 1: Watch-First 아키텍처 + MVP 기능)
- [ ] Watch SwiftData 모델 설계 (iPhone 모델과의 관계 정의)
- [ ] 3-Page TabView 프로토타입
- [ ] HR 모니터링 PoC (HKAnchoredObjectQuery)
