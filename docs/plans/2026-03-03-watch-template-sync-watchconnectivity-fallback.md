---
topic: watch-template-sync-watchconnectivity-fallback
date: 2026-03-03
status: implemented
confidence: high
related_solutions:
  - docs/solutions/general/2026-03-03-watch-template-sync-watchconnectivity-fallback.md
  - docs/solutions/general/2026-03-03-watch-simulator-cloudkit-noaccount-fallback.md
related_brainstorms: []
---

# Implementation Plan: Watch Template Sync WatchConnectivity Fallback

## Context

Watch 루틴 화면은 `WorkoutTemplate`를 CloudKit 경로로만 조회한다.  
iPhone에서 템플릿을 생성한 직후 CloudKit 지연/비활성 상태가 겹치면 Watch에서 템플릿이 보이지 않는 공백이 발생한다.

## Requirements

### Functional

- iPhone 템플릿이 Watch에서 CloudKit 반영 전에도 표시되어야 한다.
- iPhone 템플릿 생성/수정/삭제가 Watch 루틴 카드에 빠르게 반영되어야 한다.
- 기존 `exerciseLibrary` WatchConnectivity 동기화 경로와 충돌하지 않아야 한다.

### Non-functional

- 기존 CloudKit source-of-truth 구조를 유지한다.
- WatchConnectivity `applicationContext` key overwrite 회귀를 방지한다.
- 병합 로직(local 우선, fallback 허용)은 테스트로 고정한다.

## Approach

CloudKit primary + WatchConnectivity fallback의 하이브리드 동기화.

1. iPhone이 `WorkoutTemplate`를 `WatchWorkoutTemplateInfo` DTO로 직렬화하여 Watch로 전송
2. Watch는 local(`@Query WorkoutTemplate`) + synced(WC) 템플릿을 병합하여 루틴 카드 구성
3. ID 중복 시 local 우선 정책 적용
4. 템플릿 변경 이벤트(onAppear/count/updatedAt)에서 iPhone→Watch 재동기화 트리거

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| CloudKit-only 유지 | 구조 단순 | 반영 지연/비활성 공백 지속 | 기각 |
| WatchConnectivity-only로 전환 | 즉시 반영 | CloudKit 모델과 분리, 이중 저장 책임 증가 | 기각 |
| CloudKit + WC fallback | 지연 완충 + 기존 구조 유지 | 병합 정책 관리 필요 | 채택 |

## Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `DUNE/Domain/Models/WatchConnectivityModels.swift` | Modify | 템플릿 전송 DTO 추가 |
| `DUNE/Data/WatchConnectivity/WatchSessionManager.swift` | Modify | 템플릿 sync/전송/요청 응답 경로 추가 |
| `DUNE/App/DUNEApp.swift` | Modify | 앱 부팅 시 템플릿 선동기화 |
| `DUNE/Presentation/Exercise/Components/WorkoutTemplateListView.swift` | Modify | 템플릿 변경 이벤트에서 Watch sync 트리거 |
| `DUNEWatch/WatchConnectivityManager.swift` | Modify | 템플릿 수신 상태 + 재요청 경로 추가 |
| `DUNEWatch/Helpers/WatchExerciseHelpers.swift` | Modify | local/synced 템플릿 병합 유틸 추가 |
| `DUNEWatch/Views/CarouselHomeView.swift` | Modify | 루틴 카드 데이터 소스를 병합 결과로 전환 |
| `DUNEWatchTests/WatchExerciseHelpersTests.swift` | Modify | 병합 정책(우선순위/정렬/fallback) 테스트 추가 |

## Implementation Steps

### Step 1: iPhone 템플릿 동기화 채널 추가

- **Files**: `WatchConnectivityModels.swift`, `WatchSessionManager.swift`
- **Changes**:
  - `WatchWorkoutTemplateInfo` DTO 추가
  - 템플릿 fetch/encode/transfer 함수 추가
  - `requestWorkoutTemplateSync` 메시지 처리 추가
  - `applicationContext` merge 업데이트로 key 덮어쓰기 회귀 방지
- **Verification**: iOS 빌드 성공

### Step 2: 템플릿 변경 시 동기화 트리거 연결

- **Files**: `DUNEApp.swift`, `WorkoutTemplateListView.swift`
- **Changes**:
  - 앱 시작 시 템플릿 선동기화
  - 템플릿 목록 onAppear/count/updatedAt 변화 시 재동기화
- **Verification**: iOS 빌드 성공 + 템플릿 생성/수정/삭제 경로 컴파일 확인

### Step 3: Watch 수신/병합 렌더링 적용

- **Files**: `WatchConnectivityManager.swift`, `WatchExerciseHelpers.swift`, `CarouselHomeView.swift`
- **Changes**:
  - 템플릿 payload 수신 및 누락 시 pull-request
  - local+synced 병합 함수 추가(local 우선)
  - 루틴 카드/invalid key 계산에 병합 결과 사용
- **Verification**: watchOS 빌드 성공

### Step 4: 회귀 테스트 및 문서화

- **Files**: `WatchExerciseHelpersTests.swift`, `docs/solutions/general/2026-03-03-watch-template-sync-watchconnectivity-fallback.md`
- **Changes**:
  - 병합 우선순위/정렬 테스트 추가
  - 해결 문서 작성
- **Verification**: watch unit test 통과 + docs lint 규칙 만족(frontmatter 포함)

## Edge Cases

| Case | Handling |
|------|----------|
| Watch가 CloudKit 템플릿을 아직 못 받음 | WC 템플릿 fallback 표시 |
| local/synced에 동일 ID 템플릿 공존 | local(CloudKit) 우선 |
| iPhone에 템플릿이 0개 | 빈 배열 동기화로 Watch stale 데이터 정리 |
| watch 재설치 후 context 미수신 | Watch pull-request(`requestWorkoutTemplateSync`)로 재요청 |

## Testing Strategy

- Unit tests: `DUNEWatchTests/WatchExerciseHelpersTests` (병합 정책 추가 케이스 포함)
- Integration tests:
  - iOS build (`DUNE` scheme)
  - watch build (`DUNEWatch` scheme)
- Manual verification:
  - iPhone에서 템플릿 생성/수정/삭제 후 Watch 루틴 카드 반영 확인
  - iPhone CloudKit OFF 상태에서 WC fallback 반영 확인

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| applicationContext 키 충돌로 payload 유실 | 중간 | 높음 | 기존 context merge 방식으로 업데이트 |
| 병합 우선순위 역전(local보다 synced 노출) | 낮음 | 중간 | 병합 함수 테스트로 고정 |
| 과도한 동기화 호출 | 낮음 | 낮음 | 이벤트 지점을 제한(onAppear/count/updatedAt) |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: DTO/전송/수신/렌더링/테스트를 동일 경로로 묶어 적용했고 iOS/watch 빌드 + watch unit test로 핵심 회귀를 검증했다.
