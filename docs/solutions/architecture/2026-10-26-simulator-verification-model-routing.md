---
tags: [codex, model-routing, simulator, screenshots, evidence, tokens]
category: architecture
date: 2026-10-26
status: implemented
severity: important
related_files:
  - .codex/agent-map.md
  - .codex/skill-compat.md
  - .codex/token-efficiency.md
related_solutions:
  - docs/solutions/architecture/2026-09-26-codex-token-efficiency.md
---

# 시뮬레이터 실행 수집과 품질 판단의 모델 분담

## Problem

테스트 실행에는 셸 우선 규칙이 있었지만 화면 진입·스크린샷 수집·품질 판단의 모델 경계가 명확하지 않았다. 실행에 필요한 짧은 판단까지 상위 모델의 전체 문맥에서 반복하거나, `ui-test-expert` 전체를 경량화해 테스트 설계 품질을 낮출 가능성이 있었다.

### Root Cause

기존 역할이 테스트 설계·작성·검토를 함께 담당했다. 수집 전용 모드 없이 모델명만 바꾸면 source 역할의 테스트 작성 지시와 긴 응답 템플릿도 그대로 적용된다.

## Solution

| 작업 | 담당 |
|------|------|
| 정해진 명령 실행·대기·캡처 저장 | 기존 셸·표준 실행기 |
| 언어 판단이 필요한 여러 화면 진입·상태 readback·캡처 수집 | `ui-test-expert` 실행 수집 모드, Luna low |
| 검증 범위·테스트 설계·시각적 품질 판단 | Sol medium |
| 복잡한 원인 불명 실패 분석 | Astra high, 기존 증거 전달 |

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `.codex/agent-map.md` | 수집 모드 모델·추론·편집 제한 | 기본 Sol 역할과 경량 수집 역할 구분 |
| `.codex/skill-compat.md` | 위임 조건·입력 계약·source 출력 형식 대체 | 대화 전체 상속과 불필요한 리뷰 출력 방지 |
| `.codex/token-efficiency.md` | 결과·캡처 출처 계약 | 테스트 통과, 캡처 완료, 시각적 승인 구분 |

parent는 기기·selector·locale/seed·예상 상태·캡처 목록·완료/중단 조건을 먼저 정한다. 독립 작업을 병행할 수 있고 수집에 언어 판단이 필요할 때만 `model="gpt-6-luna"`, `reasoning_effort="low"`, `fork_turns="none"`으로 위임한다. 단일 셸 실행이나 parent의 독립 작업이 없는 경우에는 별도 agent를 만들지 않는다.

수집 모드는 앱/테스트/실행기/지침을 수정하지 않는다. 지정 로그·receipt·새 PNG와 출처만 저장한다. source 역할의 매 응답 리뷰 템플릿 대신 짧은 수집 결과 계약을 적용한다. 테스트가 포함된 작업은 실제 건수·selector·receipt가 필수이며, 캡처 전용 작업만 해당 항목을 `n/a`로 둔다. 캡처 완료로 필수 UI 테스트 게이트를 대신하지 않는다.

전용 시뮬레이터 소유권·잠금·deadline·최대 1회 조건부 재시도와 실제 디자인맵 갱신 의무는 유지된다. 모델 상향은 재실행 허가가 아니다. 병행 구현이 실행 입력을 바꾸면 이전 성공을 최종 상태의 증거로 재사용하지 않는다.

## Verification

- Claude parity 검사 통과: 원본 agent 14종과 adapter 매핑 14종 유지.
- Agent-Native 리뷰의 P2 두 건(캡처 전용 `n/a`, source 출력 템플릿 충돌)을 수정하고 재리뷰에서 해소 확인.
- `git diff --check`와 pre-commit 검사 통과.
- `plan-ui-tests.py --base main`은 정책 Markdown·문서만 변경되어 iOS/watch `skip`으로 판정했다. 앱 빌드·테스트·실제 캡처는 수행하지 않았으며 UI 품질을 검증했다고 주장하지 않는다.

## Prevention

- 모델 배정 문서와 실제 호출 인자를 구분한다. parent/앱 전역 모델이 자동 변경됐다고 보고하지 않는다.
- 단일 명령 실행용 agent를 만들지 않는다. 수집 결과에 정상 로그·전체 대화를 반복 복사하지 않는다.
- screenshot-only 완료, 테스트 통과, 시각적 품질 승인을 각각 증거에 맞게 보고한다.
- 새 역할 모드가 source 지시를 좁히면 편집 범위와 출력 형식의 우선순위를 함께 명시한다.
- `.claude/**`와 공통 규칙은 변경하지 않았다. Codex 전용 절차는 기존 adapter에 유지하므로 별도 공통 규칙 승격·Correction Log 추가는 필요하지 않다. 관련 기존 TODO는 검색 결과 없었다.

## Lessons Learned

저비용 모델 배정만으로 총 토큰 수가 줄어드는 것은 아니다. 최소 입력, 짧은 결과, 스크립트 우선, 중복 실행 방지가 함께 필요하다. 이번 변경은 실행 정책 검증이며 Luna로 실제 시뮬레이터 수집을 수행한 벤치마크는 아니다. 절감률과 수집 품질은 다음 실제 작업에서 제공되는 모델·토큰 지표·재시도·누락 여부로 확인한다.
