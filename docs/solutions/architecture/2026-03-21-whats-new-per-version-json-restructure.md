---
tags: [whats-new, json, architecture, asset-catalog, per-version, screenshot]
date: 2026-03-21
category: solution
status: implemented
---

# What's New: Per-Version JSON + Screenshot Support

## Problem

단일 `whats-new.json`에 5개 릴리스(39 features)가 집중되어:
1. 릴리스 추가마다 파일이 비대해짐
2. merge conflict 위험 증가
3. 실제 앱 스크린샷 표시 불가 (SF Symbol + gradient만 사용)
4. Asset catalog에 미사용 `whatsnew-*` 이미지 11개(~8.7MB) 방치

## Solution

### 1. 버전별 JSON 분리

```
Data/Resources/whats-new/
  catalog.json      ← 릴리스 인덱스 (version + introKey)
  0.5.0.json        ← 해당 버전 features
  0.4.0.json
  ...
```

- `WhatsNewCatalogIndex`: version + introKey만 포함 (메타데이터)
- `WhatsNewVersionDetail`: version + features 배열
- `WhatsNewReleaseData`: catalog entry + detail을 합쳐 구성

### 2. screenshotAsset Optional 필드

`WhatsNewFeatureItem`에 `screenshotAsset: String?` 추가:
- 있으면: `Image(assetName)` hero (둥근 모서리 + 그림자)
- 없으면: 기존 SF Symbol + gradient hero (fallback)

### 3. UI 버전별 섹션 분리

- automatic 모드: 최신 릴리스만 표시
- manual 모드: 전체 릴리스를 섹션별 구분
- 섹션 헤더: "Version X.Y.Z" + intro 텍스트

### 변경 파일

| 파일 | 변경 |
|------|------|
| `Domain/Models/WhatsNew.swift` | `screenshotAsset`, `WhatsNewCatalogIndex`, `WhatsNewVersionDetail` 추가 |
| `Data/Persistence/WhatsNewManager.swift` | 디렉토리 기반 로딩 |
| `Presentation/WhatsNew/WhatsNewView.swift` | 섹션 분리 + 스크린샷 hero |
| `Data/Resources/whats-new/` | catalog.json + 5개 버전별 JSON |
| `project.yml` | 개별 JSON 파일 엔트리 |
| `DUNETests/WhatsNewManagerTests.swift` | 19개 테스트 (screenshotAsset 파싱 포함) |

## Key Patterns

| 패턴 | 적용 |
|------|------|
| catalog + detail 2단 로딩 | catalog.json → 버전 목록 → 개별 JSON 로드 |
| `decodeIfPresent` for optional field | screenshotAsset이 없는 구 버전 호환 |
| xcodegen 개별 파일 엔트리 | `type: folder`는 하위 콘텐츠를 번들 루트에 평탄화 — 개별 나열이 안전 |
| 단일 `.frame(maxWidth:maxHeight:)` | 체인된 `.frame()` 대신 단일 호출 (iPad 레이아웃 안정성) |

## Prevention

- 새 릴리스 추가 시: `whats-new/{version}.json` 생성 + `catalog.json`에 1줄 추가 + `project.yml`에 path 추가
- screenshotAsset 누락은 자동 SF Symbol fallback — silent degradation, crash 없음
- xcodegen `type: folder`는 bundle subdirectory를 보장하지 않음 — 항상 개별 파일 엔트리 사용

## Lessons Learned

1. xcodegen `type: folder`는 PBXFileReference를 folder type으로 생성하지만, 실제 빌드에서 하위 파일이 번들 루트에 평탄화될 수 있음. `Bundle.url(forResource:subdirectory:)` 의존 시 주의
2. SwiftUI의 `.frame(maxWidth:).frame(maxHeight:)` 체인은 단일 `.frame(maxWidth:maxHeight:)`와 다르게 동작 — 특히 `scaledToFit` 이미지에서 iPad 레이아웃이 깨질 수 있음
3. `.navigationTitle`과 body 내 제목 텍스트 중복은 manual(pushed) 모드에서 이중 헤더 발생
