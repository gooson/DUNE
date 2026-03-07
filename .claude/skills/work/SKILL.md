---
name: work
description: "구현 계획을 4단계(Setup, Implement, Quality Check, Ship)로 실행합니다."
---

# Work: 4단계 구현 실행

$ARGUMENTS 에 대한 구현을 수행합니다.

## Phase 1: Setup (준비)

1. **계획 확인**: docs/plans/ 에서 최신 관련 계획을 찾아 읽습니다
   - 계획이 없으면 사용자에게 `/plan` 먼저 실행을 권장합니다
2. **과거 해결책 확인**: docs/solutions/ 에서 참고할 수 있는 해결책 검색
3. **Git 상태 확인**: 현재 브랜치, 변경사항 확인
4. **브랜치 생성** (필요시): `git checkout -b feature/{topic-slug}`

## Phase 2: Implement (구현)

계획의 각 Step을 순서대로 구현합니다:

1. 각 Step 시작 전:
   - 계획서의 해당 Step을 다시 읽습니다
   - 기존 코드 패턴을 확인합니다
   - 재사용 가능한 기존 유틸리티를 검색합니다

2. 각 Step 완료 후:
   - 해당 Step의 Verification 기준을 확인합니다
   - 구문 오류가 없는지 확인합니다
   - **새 로직이 포함된 경우 유닛 테스트를 작성합니다** (testing-patterns skill 참조)

3. 중요 규칙:
   - 기존 패턴을 최대한 따릅니다
   - 필요한 경우에만 새 패턴을 도입합니다
   - .claude/rules/ 의 컨벤션을 준수합니다
   - 과잉 설계를 피합니다

## Phase 3: Quality Check (품질 검증)

구현 완료 후 다음을 순서대로 실행합니다:

### 3.1 자동 검증

프로젝트에 맞는 명령을 실행합니다:
- Build: `xcodebuild build ...`
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
3. 다시 Phase 3을 실행합니다

## Phase 4: Ship (배포 준비)

1. **정리**:
   - 디버그 코드 제거
   - 임시 파일 정리
   - console.log / print 문 제거

2. **Git 커밋**:
   - Conventional commit 형식 사용 (feat:, fix:, refactor:, etc.)
   - 변경사항을 논리적 단위로 분리
   - 의미 있는 커밋 메시지 작성

3. **다음 단계 안내**:
   - `/review` 로 코드 리뷰를 수행할 수 있습니다
   - `/compound` 로 해결책을 문서화할 수 있습니다
   - PR 생성이 필요하면 안내합니다

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
