---
name: changelog
description: "최근 변경사항을 기반으로 릴리스 노트를 생성합니다. '릴리스 노트 만들어줘', '변경 이력 정리', '버전 노트', 'CHANGELOG 업데이트' 요청 시 사용합니다."
---

# Changelog: 릴리스 노트 생성

$ARGUMENTS 범위의 변경사항으로 릴리스 노트를 생성합니다.

## Process

### Step 1: 변경사항 수집

```bash
# 마지막 태그 이후의 커밋 (태그가 없으면 최근 20개)
git log $(git describe --tags --abbrev=0 2>/dev/null || echo "HEAD~20")..HEAD --oneline --no-merges
```

사용자가 범위를 지정한 경우 ($ARGUMENTS) 해당 범위를 사용합니다.

### Step 2: 분류

Conventional Commits 기준으로 분류합니다:

- **Features** (feat:) - 새로운 기능
- **Bug Fixes** (fix:) - 버그 수정
- **Performance** (perf:) - 성능 개선
- **Refactoring** (refactor:) - 코드 구조 개선
- **Documentation** (docs:) - 문서 변경
- **Testing** (test:) - 테스트 추가/수정
- **Chores** (chore:) - 기타 변경

### Step 3: Plan 컨텍스트 추가

각 커밋의 관련 계획서를 docs/plans/ 에서 찾아 사용자 관점의 설명을 보강합니다.

### Step 4: 릴리스 노트 생성

```markdown
# Release Notes v{version} - YYYY-MM-DD

## Highlights
주요 변경사항 1-3줄 요약 (사용자 혜택 중심)

## Features
- {사용자 혜택 중심 설명} ({commit-hash})

## Bug Fixes
- {무엇이 수정되었는지} ({commit-hash})

## Performance
- {어떤 개선이 있는지} ({commit-hash})

## Other Changes
- {설명} ({commit-hash})

## Breaking Changes (if any)
- {영향 범위와 마이그레이션 방법}
```

### Step 5: 출력

- 릴리스 노트를 사용자에게 표시합니다
- 파일 저장이 필요한 경우 CHANGELOG.md에 추가합니다

## 버전 번호 결정

`{version}`은 다음 순서로 결정합니다:
1. 사용자가 지정한 버전
2. `git describe --tags --abbrev=0`에서 마지막 태그 기반으로 semver 증가
3. 태그가 없으면 사용자에게 질문
