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
- Type check (if applicable)
- Lint check (if applicable)
- Test suite (if applicable)
- Build (if applicable)

### 3.2 자체 검토

- [ ] 계획서의 모든 Step이 구현되었는가?
- [ ] Edge case가 처리되었는가?
- [ ] 에러 핸들링이 적절한가?
- [ ] 불필요한 코드가 없는가?
- [ ] 보안 취약점이 없는가?

### 3.3 품질 Gate

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
