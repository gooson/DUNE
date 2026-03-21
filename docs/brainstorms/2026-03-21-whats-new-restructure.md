---
tags: [whats-new, json, screenshots, ui-redesign, asset-catalog]
date: 2026-03-21
category: brainstorm
status: draft
---

# Brainstorm: What's New 데이터 구조 개편 + 스크린샷 지원

## Problem Statement

현재 What's New 시스템의 한계:

1. **단일 JSON 비대화**: `whats-new.json`에 5개 릴리스 × 7-12 features = 39개 feature가 하나의 파일에 집중. 릴리스가 쌓일수록 파일 크기, 관리 복잡도, merge conflict 위험 증가
2. **텍스트 전용 UI**: SF Symbol + gradient로 자동 생성되는 hero artwork는 실제 앱 화면을 보여주지 못함. 유저가 "이 기능이 뭔지" 직관적으로 인지하기 어려움
3. **미사용 에셋**: Asset catalog에 `whatsnew-*` 이미지 11개(~8.7MB)가 존재하지만 코드에서 참조하지 않음

## Target Users

- 앱 업데이트 후 첫 실행 유저 (automatic 모드)
- Settings → About → What's New 탐색 유저 (manual 모드)
- 핵심 니즈: "이번 업데이트로 뭐가 바뀌었는지 한눈에 파악"

## Success Criteria

1. 새 릴리스 추가 시 기존 JSON 파일 수정 불필요 (새 파일만 추가)
2. 주요 feature에 실제 앱 스크린샷이 포함되어 유저가 기능을 시각적으로 인식
3. 기존 릴리스(0.1.0~0.4.0) 호환: 스크린샷 없는 feature는 현재 SF Symbol hero로 fallback

## Current Architecture

```
Domain/Models/WhatsNew.swift
├── WhatsNewArea (enum)
├── WhatsNewFeatureItem (struct): id, titleKey, summaryKey, symbolName, area
├── WhatsNewReleaseData (struct): version, introKey, features[]
└── WhatsNewCatalog (struct): releases[]

Data/Resources/whats-new.json          ← 단일 파일, 모든 릴리스
Data/Persistence/WhatsNewManager.swift ← JSON 로딩 + 버전 조회
Data/Persistence/WhatsNewStore.swift   ← UserDefaults lastOpenedBuild

Presentation/WhatsNew/WhatsNewView.swift
├── WhatsNewView (list: releases → feature rows)
├── WhatsNewFeatureRow (SF Symbol + title + summary)
├── WhatsNewFeatureDetailView (programmatic hero artwork)
└── WhatsNewStyle, WhatsNewBadge, WhatsNewVersionBadge

Resources/Assets.xcassets/whatsnew-*.imageset × 11  ← 미사용 (~8.7MB)
```

## Proposed Approach

### 1. 버전별 JSON 분리

```
Data/Resources/whats-new/
  catalog.json          ← 릴리스 목록 + 순서 (메타데이터만)
  0.5.0.json            ← 해당 버전 features
  0.4.0.json
  0.3.0.json
  0.2.0.json
  0.1.0.json
```

**catalog.json** (경량 인덱스):
```json
{
  "releases": [
    { "version": "0.5.0", "introKey": "AI posture analysis, morning briefings..." },
    { "version": "0.4.0", "introKey": "Set-level RPE, stair climbing..." }
  ]
}
```

**0.5.0.json** (버전별 상세):
```json
{
  "version": "0.5.0",
  "features": [
    {
      "id": "postureAssessment",
      "titleKey": "Posture Analysis",
      "summaryKey": "Capture a photo and get AI-powered posture scoring...",
      "symbolName": "figure.stand.line.dotted.figure.stand",
      "area": "wellness",
      "screenshotAsset": "WhatsNew/0.5.0/postureAssessment"
    }
  ]
}
```

**장점**:
- 새 릴리스 = 새 JSON 파일 + catalog.json에 1줄 추가
- 기존 버전 파일 건드리지 않음
- catalog.json만 읽으면 릴리스 목록 즉시 확보
- 버전별 diff가 깔끔함

### 2. 스크린샷 Asset Catalog 구조

```
Resources/Assets.xcassets/WhatsNew/
  Contents.json                                ← provides-namespace: true
  0.5.0/
    Contents.json                              ← provides-namespace: true
    postureAssessment.imageset/
      postureAssessment@2x.png                 ← 780×1688 (iPhone 15 Pro @2x)
      postureAssessment@3x.png                 ← 1170×2532 (iPhone 15 Pro @3x)
      Contents.json
    morningBriefing.imageset/
      ...
  0.4.0/
    setLevelRPE.imageset/
      ...
```

**네이밍 규칙**: `WhatsNew/{version}/{featureId}`
- JSON의 `screenshotAsset` 값과 1:1 매핑
- `provides-namespace: true`로 충돌 방지

**이미지 사양**:
| 항목 | 값 |
|------|-----|
| 포맷 | PNG (asset catalog 표준) |
| 해상도 | @2x (780×1688), @3x (1170×2532) |
| 콘텐츠 | 실제 앱 스크린샷 (기능 핵심 영역 크롭) |
| rendering | original (template 아님) |
| 예상 크기 | feature당 ~400-800KB |

**번들 사이즈 영향**:
- 최신 2개 버전(0.5.0, 0.4.0): 14 features × ~600KB = ~8.4MB
- 전체 5개 버전: 39 features × ~600KB = ~23.4MB
- 권장: 최신 2-3개 버전만 스크린샷 제공, 구 버전은 SF Symbol fallback 유지

### 3. 데이터 모델 변경

```swift
struct WhatsNewFeatureItem: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let titleKey: String
    let summaryKey: String
    let symbolName: String
    let area: WhatsNewArea
    let screenshotAsset: String?  // ← NEW: optional, asset catalog name

    // derived
    let title: String
    let summary: String

    var hasScreenshot: Bool { screenshotAsset != nil }
}
```

### 4. WhatsNewManager 개편

```swift
final class WhatsNewManager: Sendable {
    static let shared = WhatsNewManager()

    private let catalog: WhatsNewCatalog       // catalog.json (메타데이터)
    private let releaseCache: [String: WhatsNewReleaseData]  // version → detail

    init(bundle: Bundle = .main) {
        // 1. catalog.json 로드 → 릴리스 목록 확보
        // 2. 각 버전 JSON 개별 로드 → releaseCache에 저장
        // 번들 파일이므로 init-time 전체 로드 OK (네트워크 아님)
    }
}
```

### 5. UI 전면 리디자인

#### Feature Detail View (핵심 변경)

**현재**: SF Symbol + gradient 배경 (programmatic hero)
**변경**: 실제 스크린샷 hero + fallback

```
┌─────────────────────────────┐
│  ┌───────────────────────┐  │
│  │                       │  │
│  │   📱 실제 스크린샷     │  │  ← 둥근 모서리 + 그림자
│  │   (기능 핵심 영역)     │  │     screenshotAsset 있으면 Image
│  │                       │  │     없으면 기존 SF Symbol hero
│  └───────────────────────┘  │
│                             │
│  ┌─ Wellness ─┐             │
│  Posture Analysis           │  ← area badge + title
│  v0.5.0                     │  ← version badge
│                             │
│  Capture a photo and get    │  ← full description
│  AI-powered posture         │
│  scoring with plumb-line... │
│                             │
│  ┌───────────────────────┐  │
│  │  📖 Release Summary   │  │  ← release intro card
│  └───────────────────────┘  │
└─────────────────────────────┘
```

#### What's New List View (버전별 섹션 분리)

현재는 모든 릴리스가 한 ScrollView에 연속 나열. 버전별 명확한 섹션 구분으로 개편:

```
┌─────────────────────────────────┐
│  What's New                     │
│                                 │
│  ┌─ Version 0.5.0 ───────────┐  │  ← 섹션 헤더 (sticky or inline)
│  │ intro text...              │  │
│  │                            │  │
│  │ 🟣 Posture Analysis        │  │
│  │ 🟠 Morning Briefing        │  │
│  │ 🔵 RPE Trend               │  │
│  └────────────────────────────┘  │
│                                 │
│  ┌─ Version 0.4.0 ───────────┐  │  ← 이전 버전 섹션 (접힘 가능)
│  │ intro text...              │  │
│  │                            │  │
│  │ 🔵 Set-Level RPE           │  │
│  │ ...                        │  │
│  └────────────────────────────┘  │
│                                 │
│  ┌─ Earlier Versions ─────────┐  │  ← 구 버전 그룹 (선택적)
│  │ 0.3.0 · 0.2.0 · 0.1.0     │  │
│  └────────────────────────────┘  │
└─────────────────────────────────┘
```

- automatic 모드: 최신 버전 섹션만 펼침, 나머지는 접힘/생략
- manual 모드: 전체 버전 섹션 표시, 각 섹션 독립 구분

## Constraints

### 기술적
- Asset catalog namespace: `provides-namespace: true` 필수
- xcodegen: `Data/Resources/whats-new/` 폴더를 `sources` 에 포함 (JSON 번들 리소스)
- 기존 `whatsnew-*` imageset 11개 정리 필요 (사용 안 함)
- `WhatsNewCatalog` 모델 변경 → 기존 테스트 수정

### 리소스
- 스크린샷 제작: feature당 1장 × 최신 2-3 버전 = 14-21장
- 스크린샷은 수동 캡처 → 릴리스마다 유지보수 비용 발생
- 3개 언어 지원 시 스크린샷 3배 → MVP에서는 영어 전용 권장

### 번들 사이즈
- 현재 미사용 whatsnew 에셋: ~8.7MB (정리 대상)
- 신규 스크린샷 예상: 최신 2개 버전 기준 ~8-10MB
- 순증: ~0-2MB (미사용 에셋 정리 효과)

## Edge Cases

1. **스크린샷 없는 feature**: `screenshotAsset == nil` → 기존 SF Symbol + gradient hero fallback
2. **구 버전 JSON 파일 없음**: catalog에 version이 있지만 `{version}.json`이 번들에 없음 → skip 또는 메타데이터만 표시
3. **catalog.json 파싱 실패**: 전체 What's New 비활성화 (현재 동작과 동일)
4. **이미지 에셋 누락**: `UIImage(named: screenshotAsset)` → nil → fallback hero
5. **iPad / landscape**: 스크린샷이 iPhone 비율 → iPad에서는 centered + 최대 너비 제한

## Scope

### MVP (Must-have)
- [ ] 버전별 JSON 분리 (catalog.json + per-version files)
- [ ] `WhatsNewFeatureItem`에 `screenshotAsset` optional 필드 추가
- [ ] `WhatsNewManager` 디렉토리 기반 로딩으로 개편
- [ ] Feature Detail View에 실제 스크린샷 표시 (있으면 image, 없으면 SF Symbol fallback)
- [ ] Asset catalog 구조 생성 (`WhatsNew/{version}/{featureId}`)
- [ ] 0.5.0 features 스크린샷 7장 제작 + 등록
- [ ] 미사용 `whatsnew-*` imageset 11개 정리
- [ ] 기존 테스트 수정 + 새 구조 테스트 추가
- [ ] xcodegen project.yml 업데이트

### Nice-to-have (Future)
- [ ] Feature list row에 썸네일 미리보기 추가
- [ ] 0.4.0 이전 버전 스크린샷 소급 제작
- [ ] 다국어 스크린샷 (ko/ja) 지원
- [ ] Remote JSON fetch (서버에서 최신 버전 다운로드)
- [ ] "Try it" 딥링크: 스크린샷 아래 버튼으로 해당 기능 화면으로 이동
- [ ] 스크린샷 자동 생성 파이프라인 (UI test + snapshot)
- [ ] watchOS What's New 지원
- [ ] Carousel/PageView 스타일 대안 UI

## Design Decisions (확정)

1. **크롭 기준**: 핵심 영역만 크롭 (전체 화면 아님). 기능의 핵심 UI 요소가 잘 보이도록 포커스
2. **디바이스 프레임**: 미포함. 크롭된 UI 영역을 둥근 모서리 카드로 표시 — 프레임 없이 콘텐츠에 집중
3. **다크/라이트 모드**: 다크 모드 단일 기준. 앱의 기본 테마가 다크이며, 다크 배경에서 스크린샷 가독성이 더 높음
4. **구 버전 소급**: 주요 feature만 선별 대응. 모든 feature에 스크린샷을 넣지 않고, 버전당 대표 2-3개만

## Next Steps

- [ ] `/plan whats-new-restructure` 으로 구현 계획 생성
