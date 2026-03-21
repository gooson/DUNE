---
tags: [whats-new, json, screenshots, ui-redesign, asset-catalog]
date: 2026-03-21
category: plan
status: draft
---

# Plan: What's New 데이터 구조 개편 + 스크린샷 지원 + UI 리디자인

## Summary

단일 `whats-new.json`을 버전별 JSON으로 분리하고, feature별 스크린샷 asset을 지원하며, What's New UI를 버전별 섹션 구분 + 스크린샷 hero로 전면 리디자인한다.

## Brainstorm Reference

`docs/brainstorms/2026-03-21-whats-new-restructure.md`

## Affected Files

| 파일 | 변경 유형 | 설명 |
|------|----------|------|
| `DUNE/Domain/Models/WhatsNew.swift` | 수정 | `screenshotAsset: String?` 필드 추가, `WhatsNewCatalog` → release metadata only |
| `DUNE/Data/Persistence/WhatsNewManager.swift` | 수정 | 디렉토리 기반 JSON 로딩으로 개편 |
| `DUNE/Presentation/WhatsNew/WhatsNewView.swift` | 수정 | 버전별 섹션 분리 UI + 스크린샷 hero 지원 |
| `DUNE/Data/Resources/whats-new/catalog.json` | 신규 | 릴리스 메타데이터 인덱스 |
| `DUNE/Data/Resources/whats-new/0.5.0.json` | 신규 | 0.5.0 features |
| `DUNE/Data/Resources/whats-new/0.4.0.json` | 신규 | 0.4.0 features |
| `DUNE/Data/Resources/whats-new/0.3.0.json` | 신규 | 0.3.0 features |
| `DUNE/Data/Resources/whats-new/0.2.0.json` | 신규 | 0.2.0 features |
| `DUNE/Data/Resources/whats-new/0.1.0.json` | 신규 | 0.1.0 features |
| `DUNE/Data/Resources/whats-new.json` | 삭제 | 기존 단일 파일 |
| `DUNE/project.yml` | 수정 | 리소스 경로 변경 (단일 파일 → 디렉토리) |
| `DUNETests/WhatsNewManagerTests.swift` | 수정 | 새 구조에 맞춘 테스트 |
| `DUNE/Resources/Assets.xcassets/whatsnew-*.imageset/` (11개) | 삭제 | 미사용 에셋 정리 |

## Implementation Steps

### Step 1: JSON 분리 — 데이터 레이어 (Domain + Data)

**목표**: 단일 JSON → 버전별 JSON 파일로 분리, 모델/매니저 개편

1. **catalog.json 생성**: `DUNE/Data/Resources/whats-new/catalog.json`
   ```json
   {
     "releases": [
       { "version": "0.5.0", "introKey": "AI posture analysis..." },
       { "version": "0.4.0", "introKey": "Set-level RPE..." },
       { "version": "0.3.0", "introKey": "Health Q&A..." },
       { "version": "0.2.0", "introKey": "Widgets, weather..." },
       { "version": "0.1.0", "introKey": "Track workouts..." }
     ]
   }
   ```

2. **버전별 JSON 생성**: `DUNE/Data/Resources/whats-new/{version}.json`
   - 기존 `whats-new.json`에서 각 버전의 features 배열을 추출
   - 0.5.0 features에만 `screenshotAsset` 필드 추가 (나머지는 생략 → nil)

3. **WhatsNew.swift 모델 수정**:
   - `WhatsNewFeatureItem`에 `screenshotAsset: String?` 추가 (CodingKeys에도 추가)
   - `WhatsNewCatalog` → `WhatsNewCatalogIndex` (메타데이터만 포함하는 인덱스)
   - `WhatsNewReleaseIndex` 추가 (version + introKey만 — features 없음)
   - `WhatsNewReleaseData`는 유지 (version + introKey + features)

4. **WhatsNewManager.swift 개편**:
   - `init(bundle:)`: catalog.json 로드 → 각 `{version}.json` 로드 → releases 구성
   - 버전별 파일이 없으면 경고 로그 후 스킵 (graceful degradation)
   - 테스트용 `init(releases:)` 유지
   - 기존 public API (`orderedReleases`, `currentRelease`) 변경 없음

5. **기존 `whats-new.json` 삭제**

6. **project.yml 업데이트**: 리소스 경로 변경
   ```yaml
   # 기존
   - path: Data/Resources/whats-new.json
   # 변경
   - path: Data/Resources/whats-new
     type: folder
   ```

**Verification**: 테스트 빌드 성공, `WhatsNewManager.shared.orderedReleases()` 5개 릴리스 반환

### Step 2: 미사용 에셋 정리

**목표**: 코드에서 참조되지 않는 `whatsnew-*` imageset 11개 삭제

1. `DUNE/Resources/Assets.xcassets/whatsnew-*.imageset/` 11개 디렉토리 삭제
2. 참조 확인: 코드에서 `whatsnew-` 문자열 Grep → 0건 확인 후 삭제

**Verification**: 빌드 성공, ~8.7MB 에셋 제거

### Step 3: UI 리디자인 — WhatsNewView

**목표**: 버전별 섹션 분리 + 스크린샷 hero

1. **WhatsNewView 리디자인**:
   - automatic 모드: 최신 릴리스만 표시 (단일 섹션)
   - manual 모드: 전체 릴리스를 버전별 `Section`으로 구분
   - 각 섹션 헤더: 버전 배지 + intro 텍스트
   - Feature row: 기존 패턴 유지 (SF Symbol + title + summary)

2. **WhatsNewFeatureDetailView 리디자인**:
   - `screenshotAsset`이 있으면: `Image(feature.screenshotAsset!)` hero
     - 둥근 모서리 카드 (DS.Radius.xl)
     - 그림자 (shadow)
     - `scaledToFit()` + `frame(maxHeight: 400)`
   - `screenshotAsset`이 nil이면: 기존 SF Symbol + gradient hero (fallback)
   - 나머지: title, area badge, description, release info 유지

3. **automatic 모드 섹션 로직**:
   - `releases` 배열에서 첫 번째(최신)만 보여주는 것은 DUNEApp이 이미 `orderedReleases(preferredVersion:)`로 처리
   - automatic에서는 ForEach를 최신 1개로 제한

**Verification**: Preview에서 automatic/manual 양쪽 모드 렌더링 확인

### Step 4: 테스트 업데이트

**목표**: WhatsNewManagerTests를 새 JSON 구조에 맞게 수정

1. 기존 테스트: `WhatsNewManager.shared`가 번들에서 로딩 → 새 디렉토리 구조에서도 동작하도록 확인
2. 새 테스트 추가:
   - `screenshotAsset` 필드 파싱 테스트 (있는 feature, 없는 feature)
   - catalog.json에 버전이 있지만 detail JSON이 없는 경우 graceful skip
   - `hasScreenshot` computed property 테스트

**Verification**: `xcodebuild test` 전체 통과

### Step 5: 빌드 + xcodegen

**목표**: 전체 빌드 파이프라인 통과

1. `scripts/build-ios.sh` 실행 (xcodegen 포함)
2. 빌드 성공 확인

## Test Strategy

| 테스트 | 유형 | 파일 |
|--------|------|------|
| JSON 파싱 (catalog + per-version) | Unit | `WhatsNewManagerTests.swift` |
| screenshotAsset optional 파싱 | Unit | `WhatsNewManagerTests.swift` |
| missing version JSON graceful skip | Unit | `WhatsNewManagerTests.swift` |
| orderedReleases API 호환성 | Unit | `WhatsNewManagerTests.swift` |

## Risks & Edge Cases

| 리스크 | 영향 | 완화 |
|--------|------|------|
| xcodegen이 `type: folder`를 다르게 처리 | 빌드 실패 | `type: folder` 또는 `group` 확인 후 적용 |
| 기존 WhatsNewStore build tracking 깨짐 | What's New 재표시 | WhatsNewStore 변경 없음 — 영향 없음 |
| 스크린샷 에셋이 아직 없는 상태 | hero fallback | `screenshotAsset == nil` → SF Symbol fallback |
| 구버전 JSON에 screenshotAsset 없음 | 파싱 에러 | Optional 필드로 선언 → 자동 nil |

## Alternatives Considered

1. **Remote JSON fetch**: 서버에서 최신 JSON 다운로드 → MVP에서는 오버엔지니어링. 번들만으로 충분
2. **LazyVStack + lazy loading**: 버전별 lazy load → 번들 리소스이므로 불필요 (init-time 전체 로드 OK)
3. **WhatsNewKit 라이브러리**: 외부 의존성 추가 대신 기존 커스텀 시스템 개편이 더 적합

## Checklist

- [ ] catalog.json + 5개 버전별 JSON 생성
- [ ] WhatsNew.swift 모델 수정 (screenshotAsset optional)
- [ ] WhatsNewManager 디렉토리 로딩
- [ ] WhatsNewView 버전별 섹션 분리
- [ ] WhatsNewFeatureDetailView 스크린샷 hero + fallback
- [ ] 미사용 whatsnew-* imageset 삭제
- [ ] project.yml 리소스 경로 업데이트
- [ ] 테스트 업데이트
- [ ] 빌드 통과
