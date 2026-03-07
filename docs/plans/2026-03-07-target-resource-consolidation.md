---
tags: [resources, xcstrings, xcassets, multi-target, shared, localization, visionos]
date: 2026-03-07
category: plan
status: implemented
---

# Plan: 타겟별 리소스 통합 및 관리 원칙 수립

## Summary

iOS xcstrings 중복 제거, DUNEVisionWidgets Colors 참조 추가, localization 규칙 업데이트, 리소스 관리 원칙 규칙 문서 추가.

## Reference

- Brainstorm: `docs/brainstorms/2026-03-07-target-resource-strategy.md`
- Past Solution: `docs/solutions/architecture/2026-03-02-shared-colors-xcassets.md`
- Past Solution: `docs/solutions/architecture/full-localization-xcstrings.md`

## Affected Files

| File | Action | Description |
|------|--------|-------------|
| `DUNE/Resources/Localizable.xcstrings` | **삭제** | Shared와 동일한 22,471줄 중복 파일 |
| `DUNE/project.yml` | 수정 | DUNE target에 Shared xcstrings 참조 추가, VisionWidgets에 Colors 참조 추가 |
| `.claude/rules/localization.md` | 수정 | iOS 파일 경로를 Shared로 업데이트 |
| `.claude/rules/resource-management.md` | **생성** | 리소스 관리 원칙 규칙 문서 |

## Implementation Steps

### Step 1: project.yml 수정 — DUNE target에 Shared xcstrings 추가

DUNE target의 `sources:`에 `../Shared/Resources/Localizable.xcstrings` 참조를 추가한다.

```yaml
# DUNE target sources에 추가
- path: ../Shared/Resources/Localizable.xcstrings
  group: Shared
```

**Verification**: project.yml에 참조가 올바르게 추가됨

### Step 2: DUNE/Resources/Localizable.xcstrings 삭제

iOS 자체 xcstrings 파일을 삭제한다. Shared와 byte-for-byte 동일하므로 데이터 손실 없음.

**Verification**: 파일이 삭제됨, Shared 파일이 여전히 존재

### Step 3: project.yml 수정 — DUNEVisionWidgets에 Colors.xcassets 참조 추가

DUNEVisionWidgets target의 `sources:`에 Shared Colors 참조를 추가한다.

```yaml
# DUNEVisionWidgets target sources에 추가
- path: ../Shared/Resources/Colors.xcassets
  group: Shared/Resources
```

**Verification**: project.yml에 참조가 올바르게 추가됨

### Step 4: localization.md 규칙 업데이트

`.claude/rules/localization.md`의 파일 위치 테이블에서:
- iOS (DUNE) 경로를 `Shared/Resources/Localizable.xcstrings`로 변경
- 주석 추가: DUNEWidget, DUNEVision도 같은 파일 참조

**Verification**: 규칙 문서가 현재 구조를 정확히 반영

### Step 5: resource-management.md 규칙 문서 생성

`.claude/rules/resource-management.md`에 리소스 관리 원칙을 문서화:
- 리소스 유형별 소스 위치 원칙
- 새 타겟 추가 시 체크리스트
- 중복 금지 기준
- Equipment icons 해상도 분리 근거

**Verification**: 규칙 문서가 `.claude/rules/`에 존재

### Step 6: 빌드 검증

`scripts/build-ios.sh`로 빌드하여 xcstrings 참조 변경이 정상 동작하는지 확인.

**Verification**: 빌드 성공

## Test Strategy

- 빌드 검증으로 충분 (리소스 참조 변경은 런타임 로직 변경 없음)
- xcstrings 파일 자체는 변경하지 않으므로 번역 누락 위험 없음
- 유닛 테스트 대상 아님 (프로젝트 구성 + 문서 변경)

## Risks & Edge Cases

| Risk | Mitigation |
|------|-----------|
| DUNE xcstrings 삭제 후 Shared 참조 누락 | Step 1 (참조 추가)을 Step 2 (삭제) 전에 수행 |
| VisionWidgets Colors 참조로 빌드 크기 증가 | 색상 asset만이므로 무시 가능 수준 |
| localization.md 규칙 변경으로 기존 프로세스 혼동 | 명확한 경로 변경 + Watch 별도 유지 명시 |
