---
name: onboard
description: "프로젝트 온보딩. CLAUDE.md, rules, skills, 구조를 종합적으로 설명합니다."
---

# Onboard: 프로젝트 온보딩

이 프로젝트의 구조와 워크플로우를 종합적으로 설명합니다.

## Process

### Step 1: 프로젝트 구조 파악

다음 파일들을 읽고 분석합니다:
- **CLAUDE.md**: 프로젝트 개요, 원칙, 컨벤션
- **.claude/rules/**: 자동 적용 규칙들
- **.claude/skills/**: 사용 가능한 워크플로우
- **.claude/agents/**: 전문 서브에이전트들
- **docs/**: 문서 구조와 기존 문서
- **Memory 파일**: 프로젝트 memory 디렉토리의 MEMORY.md와 관련 memory 파일 확인

### Step 2: 워크플로우 설명

사용자에게 다음을 설명합니다:

**Compound Engineering 루프**:
```
Brainstorm -> Plan -> Work -> Review -> Triage -> Compound
     │                                                │
     └──────── 지식 축적 & 자기 개선 ────────────────┘
```

**사용 가능한 Skills**:
- 각 skill의 용도와 사용 시점
- skill 간의 연결 관계

**Fidelity Levels**:
- F1 (단순): 직접 수정
- F2 (중간): /plan -> /work
- F3 (복잡): 전체 루프

### Step 3: 현재 상태 확인

- todos/ 에서 진행 중인 작업 항목 확인
- docs/plans/ 에서 최근 계획 확인
- docs/solutions/ 에서 축적된 지식 확인
- CLAUDE.md Correction Log에서 교정사항 확인

### Step 4: 온보딩 가이드 생성

분석 결과를 기반으로 간결한 온보딩 요약을 생성합니다:
- 프로젝트 개요 (1-2문장)
- 현재 상태 (진행 중인 작업, 최근 변경)
- 핵심 컨벤션 (코드 스타일, 문서화 규칙)
- 시작 방법 (어떤 skill부터 사용할지)
- 주의사항 (Correction Log의 교정사항)
