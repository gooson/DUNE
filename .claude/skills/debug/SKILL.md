---
name: debug
description: "구조화된 디버깅 워크플로우. 재현 -> 격리 -> 가설 -> 검증 -> 수정 -> 확인 -> 문서화."
---

# Debug: 구조화된 디버깅

$ARGUMENTS 에 대한 체계적인 디버깅을 수행합니다.

## 7-Phase Debugging Process

### Phase 1: Reproduce (재현)

문제를 정확히 재현합니다:
- 에러 메시지와 스택 트레이스 확인
- 재현 단계 파악 (언제, 어떤 조건에서 발생하는지)
- 환경 조건 확인 (OS, 버전, 설정, 데이터 상태)
- 일관적으로 재현되는지 확인

재현이 안 되면:
- 로그를 추가하여 발생 조건을 좁힙니다
- 간헐적 발생인 경우 패턴을 파악합니다

### Phase 2: Isolate (격리)

문제 범위를 좁힙니다:
- 문제가 발생하는 최소 범위 파악
- `git log` 로 최근 변경사항 확인
- 관련 파일과 함수 식별
- 외부 의존성 문제인지 내부 로직 문제인지 구분

**MCP 활용**:
- **Serena** `find_symbol` + `find_referencing_symbols`: 문제 함수의 호출 체인 추적
- **Sequential Thinking**: 격리 단계가 복잡할 때 단계적 사고로 범위 축소

### Phase 3: Hypothesize (가설)

가능한 원인을 나열합니다 (확률 순):

```
가설 1: {설명} - 확률: 높음/중간/낮음
  근거: {왜 이것이 원인일 수 있는지}
  검증 방법: {어떻게 확인할 수 있는지}

가설 2: {설명} - 확률: 높음/중간/낮음
  근거: ...
  검증 방법: ...
```

**가설이 3개 이상이거나 원인이 불명확할 때**:
- **Sequential Thinking** MCP로 각 가설의 근거와 반증을 체계적으로 분해
- **Context7**로 관련 API의 예상 동작과 실제 동작 비교

### Phase 4: Test (검증)

확률이 높은 가설부터 검증합니다:
- 디버그 로깅 추가
- 조건부 테스트
- 변수 상태 확인
- 각 가설의 검증 결과를 기록

### Phase 5: Fix (수정)

확인된 원인을 수정합니다:
- 최소한의 변경으로 수정 (side effect 방지)
- 기존 패턴 유지
- 근본 원인 해결 (증상만 가리지 않기)

### Phase 6: Verify (확인)

수정이 올바른지 확인합니다:
- 원래 문제가 해결되었는지 확인
- 재현 단계를 다시 실행
- 관련 테스트 실행
- 사이드 이펙트가 없는지 확인

### Phase 7: Document (문서화)

디버깅 결과를 기록합니다:
- `/compound` 로 해결책을 문서화할 것을 권장
- 특히 근본 원인과 예방 방법을 강조
- 비슷한 문제가 재발하지 않도록 Prevention 작성

## Debugging Report

각 Phase 완료 시 진행 상황을 보고합니다:

```
━━━ Debug Progress ━━━━━━━━━━━━━
Phase: {current phase}
Issue: {problem description}
Status: {investigating | hypothesis | testing | fixed | verified}
Hypotheses: {N tested, M remaining}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
