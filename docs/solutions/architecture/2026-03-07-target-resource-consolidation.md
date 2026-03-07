---
tags: [resources, xcstrings, localization, shared, multi-target, xcodegen, visionos, asset-catalog]
date: 2026-03-07
category: solution
status: implemented
---

# 타겟별 리소스 통합 및 관리 원칙 수립

## Problem

5개 타겟(DUNE, DUNEWatch, DUNEWidget, DUNEVision, DUNEVisionWidgets)의 리소스가 일관된 원칙 없이 관리되고 있었음.

1. **iOS xcstrings 완전 중복**: `DUNE/Resources/Localizable.xcstrings`(원본)과 `Shared/Resources/Localizable.xcstrings`(symlink)가 존재. 22,471줄 동일 내용이지만 관계가 역전 — Shared가 원본이 아니라 iOS를 가리키는 symlink
2. **DUNEVisionWidgets Colors 미참조**: 다른 4개 타겟은 모두 `Shared/Resources/Colors.xcassets` 참조하지만 VisionWidgets만 누락
3. **리소스 관리 원칙 부재**: 새 타겟 추가 시 어떤 리소스를 참조해야 하는지 가이드라인 없음

## Solution

### 1. xcstrings 통합

```
Before:
  DUNE/Resources/Localizable.xcstrings    (실파일, 원본)
  Shared/Resources/Localizable.xcstrings  (symlink → ../../DUNE/Resources/Localizable.xcstrings)

After:
  Shared/Resources/Localizable.xcstrings  (실파일, 단일 소스)
  DUNE/Resources/Localizable.xcstrings    (삭제)
```

project.yml에서 DUNE target에 Shared xcstrings 참조 추가:
```yaml
# DUNE target sources
- path: ../Shared/Resources/Localizable.xcstrings
  group: Shared
```

### 2. DUNEVisionWidgets Colors 참조 추가

```yaml
# DUNEVisionWidgets target sources
- path: ../Shared/Resources/Colors.xcassets
  group: Shared/Resources
```

### 3. 리소스 관리 원칙 문서화

`.claude/rules/resource-management.md` 생성:
- Single Source of Truth 테이블 (리소스 유형별 소스 위치)
- Equipment Icons 분리 근거 (iOS 512px vs Watch 128px)
- 중복 금지 기준 (동일 파일 → Shared, 다른 포맷 → 타겟별)
- 새 타겟 추가 시 체크리스트

### 4. localization.md 경로 업데이트

iOS 파일 경로를 `Shared/Resources/Localizable.xcstrings`로 변경, Watch 경로도 정확하게 수정.

## Prevention

- `.claude/rules/resource-management.md`의 "새 타겟 추가 시 체크리스트"를 따르면 리소스 참조 누락 방지
- "중복 금지 기준" 정책으로 동일 파일 중복 방지
- Equipment icons처럼 해상도가 다른 경우 분리 근거를 문서에 명시

## Lessons Learned

1. **Symlink 방향 주의**: Shared가 원본이어야 하는데 실제로는 iOS 파일이 원본이고 Shared가 symlink. 단순 삭제하면 dangling symlink 발생 → 파일 이동 순서가 중요
2. **Git worktree에서 symlink**: Git은 symlink를 그대로 커밋. worktree에서도 symlink 타겟의 상대 경로가 유지되므로, symlink 타겟이 삭제되면 worktree에서도 즉시 broken
3. **xcodegen 경로 검증**: project.yml에서 참조하는 파일이 존재하지 않으면 `Spec validation error`로 즉시 실패. 이 덕분에 빠른 피드백 가능
