---
tags: [claude-md, correction-log, progress-markers, skills, documentation, restructure]
date: 2026-03-07
category: architecture
status: implemented
---

# CLAUDE.md 재구조화 + 스킬 Progress Markers

## Problem

1. **CLAUDE.md 비대화**: Correction Log가 133줄(전체 238줄의 56%)을 차지하여 매 세션마다 불필요한 컨텍스트 소비
2. **중복 교정**: Watch/iOS Parity(18개), Design System(8개), Asset Catalog(9개) 교정이 이미 `.claude/rules/`에 해당 내용이 있거나 졸업 가능한 상태인데도 CLAUDE.md에 인라인 유지
3. **스킬 실행 추적 불가**: `/run` 파이프라인 실행 시 각 Phase/Step 시작점을 로그에서 식별할 수 없어 디버깅/리뷰 어려움

## Solution

### 1. Correction Log 졸업 + 분리

- **3개 새 규칙 파일 생성**: 성숙한 교정 35개를 전용 `.claude/rules/` 파일로 졸업
  - `watch-ios-parity.md`: DTO 동기화, UI 표시, Watch 운동 세션 패턴
  - `design-system-rules.md`: 색상 관리, 토큰 네이밍, 변경 프로세스
  - `asset-catalog.md`: xcodegen 후처리, visionOS, PBXGroup, Asset Catalog 구조
- **`docs/corrections-active.md`**: 남은 프로젝트 특화 교정 (~51개) 분리
- **CLAUDE.md**: compact 참조 링크 + 졸업 현황 테이블로 대체 (238줄 → 128줄)

### 2. Progress Markers 통합

6개 스킬에 일관된 Progress Markers 섹션 추가:

```
━━━ {Skill} {Phase/Step} {N}: {Name} Start ━━━
... 작업 수행 ...
━━━ {Skill} {Phase/Step} {N}: {Name} Complete ━━━
```

- `/run`, `/plan`, `/work`: "Phase" 용어
- `/review`, `/compound`, `/ship`: "Step" 용어

### 변경 파일

| 파일 | 변경 |
|------|------|
| `.claude/skills/{run,plan,work,review,compound,ship}/SKILL.md` | Progress Markers 추가 |
| `CLAUDE.md` | Correction Log → compact 참조 |
| `.claude/rules/watch-ios-parity.md` | 신규 (졸업) |
| `.claude/rules/design-system-rules.md` | 신규 (졸업) |
| `.claude/rules/asset-catalog.md` | 신규 (졸업) |
| `docs/corrections-active.md` | 신규 (분리) |

## Prevention

- CLAUDE.md Correction Log에 새 교정 추가 시 `docs/corrections-active.md`에 추가
- 3회 이상 참조된 교정은 `.claude/rules/`로 졸업 검토
- `/retrospective` 수행 시 졸업 후보 자동 식별

## Lessons Learned

1. **졸업 번호 추적이 중요**: 범위 표기(`#189-200`)를 사용하면 중간에 다른 카테고리 번호(`#196`)가 포함될 수 있음. 명시적 나열이 안전함
2. **워크트리 파일 동기화**: main repo에 생성한 새 파일은 worktree에 자동 반영되지 않음. 명시적 복사 필요
3. **중복 제거 시 본문 확인 필수**: 졸업 주석에 포함되었지만 본문에 여전히 남아있는 항목이 있을 수 있음 (예: #151)
