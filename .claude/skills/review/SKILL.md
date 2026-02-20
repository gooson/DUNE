---
name: review
description: "6개 전문가 관점에서 코드를 리뷰합니다. Security, Performance, Architecture, Data Integrity, Simplicity, Agent-Native."
---

# Review: 다관점 코드 리뷰

$ARGUMENTS 에 대한 다관점 코드 리뷰를 수행합니다.

## Process

### Step 1: 변경사항 파악 및 diff 수집

변경된 파일과 내용을 파악합니다:
- `git diff` 로 변경 내용 확인 (staged + unstaged)
- 변경된 파일 목록 정리
- 변경의 성격 파악 (기능 추가, 버그 수정, 리팩토링 등)

**diff를 임시 파일에 저장**:
```bash
git diff HEAD > /tmp/review-diff.txt
```
- diff가 비어있으면 `git diff main...HEAD` 로 브랜치 전체 변경 확인
- diff 라인 수를 세어 크기 파악: `wc -l /tmp/review-diff.txt`

### Step 2: 6관점 리뷰 실행

다음 6개 전문가 관점에서 리뷰를 수행합니다.
**반드시 서브에이전트를 병렬로 실행합니다.**

**CRITICAL - Output 크기 제어**:
서브에이전트의 output file에 전체 대화 로그(tool calls, API responses)가 기록되어
truncation이 발생합니다. 이를 방지하기 위해:

1. **`max_turns: 6`으로 제한**: 각 에이전트의 Task 호출에 `max_turns: 6` 설정
2. **간결한 prompt**: 에이전트에게 "git diff 1회 실행 후 findings만 출력"하도록 지시
3. **model: sonnet**: 각 에이전트를 sonnet (claude-sonnet-4-6) 모델로 실행

**Agent-Native 리뷰어 스킵 조건**:
- diff에 AI/Agent 관련 파일(.claude/agents/, .claude/skills/, prompt 파일 등)이 없으면 항상 스킵
- 순수 앱 코드(View, ViewModel, Service 등)만 변경된 경우 5개 에이전트만 실행

**diff가 2000줄 이상이면 에이전트 대신 직접 리뷰**:
- 에이전트에 git diff를 전달하면 토큰 한도(25000)를 초과하여 실패합니다
- 대신 주 에이전트가 `git diff main...HEAD -- {path}` 로 폴더별로 나눠 읽고 직접 5관점 리뷰합니다
- Agent-Native는 `.claude/` 파일 변경이 있을 때만 추가 검토합니다

1. **Security Sentinel** (@.claude/agents/reviewer-security.md)
   - OWASP Top 10 취약점
   - 인증/인가 문제
   - 입력 유효성 검증
   - 비밀 노출

2. **Performance Oracle** (@.claude/agents/reviewer-performance.md)
   - N+1 쿼리
   - 불필요한 재렌더링
   - 메모리 누수
   - 캐싱 기회

3. **Architecture Strategist** (@.claude/agents/reviewer-architecture.md)
   - SOLID 원칙 준수
   - 패턴 일관성
   - 모듈 결합도/응집도
   - 확장성

4. **Data Integrity Guardian** (@.claude/agents/reviewer-data-integrity.md)
   - 입력 유효성 검증
   - 트랜잭션 경계
   - 레이스 컨디션
   - 데이터 일관성

5. **Code Simplicity Reviewer** (@.claude/agents/reviewer-simplicity.md)
   - 과잉 설계
   - 불필요한 추상화
   - 가독성
   - Dead code

6. **Agent-Native Reviewer** (@.claude/agents/reviewer-agent-native.md)
   - 프롬프트 품질
   - 컨텍스트 관리
   - 도구 사용 적절성
   - 에러 복구 전략

### Step 3: 결과 통합

각 리뷰어의 발견사항을 우선순위별로 정리합니다.
`.claude/skills/review/templates/review-report.md` 형식을 따릅니다.

**출력 형식**:

```
P1 - CRITICAL (must fix): N건
P2 - IMPORTANT (should fix): N건
P3 - MINOR (nice to fix): N건
```

### Step 4: 다음 단계 안내

- P1이 있으면 즉시 수정을 권장합니다
- `/triage` 로 각 발견사항을 하나씩 처리할 수 있습니다
- `/compound` 로 학습한 내용을 문서화할 수 있습니다
