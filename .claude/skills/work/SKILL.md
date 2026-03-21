---
name: work
description: "구현 계획을 4단계(Setup, Implement, Quality Check, Ship)로 실행합니다. 구현 중에는 기능/화면/작은 변경 단위로 지속적으로 로컬 커밋하고, 각 Phase 완료 시 새 커밋을 push하여 작업 손실을 방지합니다."
---

# Work: 4단계 구현 실행

$ARGUMENTS 에 대한 구현을 수행합니다.

## Phase 1: Setup (준비)

1. **계획 확인**: docs/plans/ 에서 최신 관련 계획을 찾아 읽습니다
   - 계획이 없으면 사용자에게 `/plan` 먼저 실행을 권장합니다
2. **과거 해결책 확인**: docs/solutions/ 에서 참고할 수 있는 해결책 검색
3. **Git 상태 확인**: 현재 브랜치, 변경사항 확인
   - 시작 시점에 이미 dirty인 파일 목록을 baseline으로 기록합니다
   - baseline 파일은 이후 자동 커밋 대상에서 제외합니다
4. **브랜치 안전장치**:
   - 현재 브랜치가 `main` 이면 Phase 2 전에 반드시 작업 브랜치로 전환합니다
   - 권장 형식: `git checkout -b feature/{topic-slug}`
   - `main` 에서는 구현 커밋이나 자동 push를 진행하지 않습니다

## Phase 2: Implement (구현)

계획의 각 Step을 순서대로 구현합니다:

1. 각 Step 시작 전:
   - 계획서의 해당 Step을 다시 읽습니다
   - 기존 코드 패턴을 확인합니다
   - 재사용 가능한 기존 유틸리티를 검색합니다
   - Step이 크면 **커밋 가능한 작은 단위**로 먼저 쪼갭니다
   - 기본 단위는 `기능 1개`, `화면 1개`, `버그 수정 1개`, `리팩터링 1개` 입니다
   - 각 작은 단위마다 **이번 단위에서 수정할 파일 목록**을 먼저 확정합니다

2. 각 작은 단위 완료 후:
   - 해당 단위의 Verification 기준을 확인합니다
   - 구문 오류가 없는지 확인합니다
   - **새 로직이 포함된 경우 유닛 테스트를 작성합니다** (testing-patterns skill 참조)
   - **즉시 커밋합니다**
     - `git add -- {current-unit-files...} && git commit -m "<type>(<scope>): <summary>"`
     - `git add -A` 로 전체 worktree를 스테이징하지 않습니다
     - baseline 파일이나 관련 없는 기존 변경은 커밋에 포함하지 않습니다
     - 다음 단위로 넘어가기 전에 working tree를 가능한 한 깨끗하게 유지합니다
     - 여러 화면/기능 변경을 마지막에 한 번에 몰아 커밋하지 않습니다
     - **push는 각 커밋마다 하지 않고 Phase 완료 시점에 모아서 합니다**

3. 위험 작업 전 체크포인트:
   - 대규모 리팩터링, 광범위한 치환, 프로젝트 재생성, 오래 걸리는 검증 전에 현재 변경을 먼저 커밋합니다
   - 아직 커밋 가능한 상태가 아니면 더 작은 단위로 다시 쪼갭니다
   - 정말 커밋이 불가능한 중간 상태라면 마지막 수단으로만 임시 보존(`git stash push -u -m "work-checkpoint-{timestamp}"`)을 사용하고 이유를 함께 남깁니다
   - `work-checkpoint-*` stash는 **Phase 완료로 인정하지 않습니다**
   - Phase를 끝내기 전 stash를 복원하여 정상 커밋으로 승격하고, stash가 남지 않은 상태를 확인합니다

4. 중요 규칙:
   - 기존 패턴을 최대한 따릅니다
   - 필요한 경우에만 새 패턴을 도입합니다
   - .claude/rules/ 의 컨벤션을 준수합니다
   - 과잉 설계를 피합니다
   - **한 번에 하나의 논리적 변경 단위만 진행합니다**
   - **화면/기능/수정 단위가 끝날 때마다 커밋합니다**
   - **큰 diff를 오래 미커밋 상태로 방치하지 않습니다**

## Phase 3: Quality Check (품질 검증)

구현 완료 후 다음을 순서대로 실행합니다:

### 3.1 자동 검증

프로젝트에 맞는 명령을 실행합니다:
- Build: `scripts/build-ios.sh` (xcodebuild 직접 실행 금지 — build-pipeline.md 참조)
- Test suite: `xcodebuild test ...` (xcode-project skill 참조)

### 3.2 전문 에이전트 검증

변경 내용에 따라 적절한 에이전트를 실행합니다:

| 변경 유형 | 에이전트 | 실행 조건 |
|-----------|---------|-----------|
| UI/View 변경 | `swift-ui-expert` | SwiftUI View, Auto Layout, 복잡한 UI 구현 |
| UI/View 변경 | `apple-ux-expert` | UX 흐름, HIG 준수, 애니메이션, 시각적 완성도 |
| 대량 데이터 처리 | `perf-optimizer` | 1000+ 노드 렌더링, 대용량 파싱, 메모리 집약 작업 |
| 기능 구현 완료 | `app-quality-gate` | 주요 기능 완성 시 종합 품질 심사 |

- UI 변경이 포함된 경우: `swift-ui-expert` → `apple-ux-expert` 순서로 실행
- 성능 민감 코드인 경우: `perf-optimizer` 실행
- 주요 기능 완성 시: `app-quality-gate`로 종합 점검

### 3.3 자체 검토

- [ ] 계획서의 모든 Step이 구현되었는가?
- [ ] Edge case가 처리되었는가?
- [ ] 에러 핸들링이 적절한가?
- [ ] 불필요한 코드가 없는가?
- [ ] 보안 취약점이 없는가?

### 3.4 품질 Gate

품질 검증에 실패하면:
1. 실패 원인을 분석합니다
2. 수정합니다
   - 수정이 코드/테스트 변경이면 다시 작은 단위로 커밋합니다
3. 다시 Phase 3을 실행합니다

## Phase 4: Ship (배포 준비)

1. **정리**:
   - 디버그 코드 제거
   - 임시 파일 정리
   - console.log / print 문 제거

2. **남은 변경 정리**:
   - 이 시점에는 이미 구현 중간에 여러 개의 작은 커밋이 존재해야 합니다
   - 남은 변경이 있으면 마지막 정리 성격의 변경만 별도 커밋합니다
   - 남은 변경도 하나의 큰 커밋으로 합치지 말고 논리적 단위로 나눕니다
   - Conventional commit 형식 사용 (feat:, fix:, refactor:, docs:, test:, chore:)
   - 완료 시점 기준으로 working tree가 깨끗한 상태인지 확인합니다

3. **다음 단계 안내**:
   - `/review` 로 코드 리뷰를 수행할 수 있습니다
   - `/compound` 로 해결책을 문서화할 수 있습니다
   - PR 생성이 필요하면 안내합니다

## Phase 경계 Push 정책

1. 각 Phase 완료 시:
   - 현재 브랜치가 `main` 이면 push하지 않고 먼저 작업 브랜치로 전환합니다
   - `work-checkpoint-*` stash가 남아 있으면 Phase 완료로 간주하지 않습니다
   - 해당 Phase에서 새 로컬 커밋이 생겼으면 `git push` 합니다
   - upstream이 아직 없으면 첫 push는 `git push -u origin {branch}` 를 사용합니다
   - 새 커밋이 없으면 push하지 않습니다

2. push 타이밍:
   - 작은 단위 구현 완료 시점에는 **커밋만** 합니다
   - 여러 작은 커밋이 모인 뒤 **Phase가 끝날 때 한 번** push 합니다
   - 미완성 상태를 매 커밋마다 원격에 올리지 않습니다

3. push 실패 시:
   - 로컬 커밋은 유지합니다
   - 실패 원인을 사용자에게 보고합니다
   - 자동 재시도가 안전한 경우에만 재시도하고, 불가하면 다음 Phase로 넘어가지 않습니다

## Progress Markers

각 Phase **시작 시** 아래 형식으로 시작 표시를 출력합니다:

```
━━━ Work Phase {N}: {Name} Start ━━━
```

각 Phase **완료 시** 완료 표시를 출력합니다:

```
━━━ Work Phase {N}: {Name} Complete ━━━
```

시작 표시는 실제 작업 수행 **직전에** 반드시 출력합니다. 이를 통해 사용자가 추후 로그에서 각 Phase의 시작점을 식별할 수 있습니다.
