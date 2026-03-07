---
tags: [whats-new, sf-symbol, build-script, changelog, data-structure]
date: 2026-03-08
category: brainstorm
status: draft
---

# Brainstorm: What's New 기능 개편

## Problem Statement

현재 What's New 시스템의 3가지 문제:

1. **이미지 불일치**: fallback artwork(코드 기반 mock)가 실제 기능과 잘 매칭되지 않음
2. **히스토리 수동 관리**: `WhatsNewManager.releaseCatalog`에 매 릴리스마다 수동으로 하드코딩해야 함
3. **데이터 구조 경직성**: `WhatsNewFeature` enum에 새 case 추가 → 코드 변경 필수, 유연성 부족

## Target Users

- 앱 업데이트 후 새 기능을 확인하려는 사용자
- Settings > About에서 과거 변경사항을 열람하려는 사용자

## Success Criteria

1. 새 릴리스 추가 시 Swift 코드 변경 없이 콘텐츠만 추가 가능
2. 이미지가 기능과 시각적으로 일치하며, 추가 에셋 없이 자동 생성
3. git tag/commit 기반으로 릴리스 노트가 반자동 생성

## Proposed Approach

### A. 이미지: SF Symbol 조합 카드

현재 `WhatsNewArtwork` fallback을 **SF Symbol 조합 카드**로 교체.

**구성 요소**:
- 대표 SF Symbol 1-2개 (기능별 지정)
- 영역별(area) 브랜드 색상 그라디언트 배경
- RoundedRectangle 카드 형태

**장점**:
- 추가 에셋 불필요 (SF Symbol은 시스템 제공)
- Dark/Light 모드 자동 대응
- 새 기능 추가 시 symbolName만 지정하면 됨

**구현 방향**:
```
현재: WhatsNewFeature.imageAssetName → UIImage 로드 → 실패 시 WhatsNewArtwork fallback
개편: WhatsNewFeature의 symbolName + area 색상 → FeatureCardView 렌더링 (fallback 불필요)
```

### B. 히스토리: Build-time 스크립트 자동 생성

**흐름**:
```
git tag (v0.2.0 등)
    ↓
build-time 스크립트 (scripts/generate-whats-new.sh)
    ↓
whats-new.json (번들에 포함)
    ↓
WhatsNewManager가 JSON 파싱
```

**스크립트 역할**:
1. git tag 목록에서 버전 추출
2. 각 tag 간 conventional commit (`feat:`) 필터링
3. 수동 오버라이드 JSON(`whats-new-overrides.json`)과 병합
4. 최종 `whats-new.json` 생성 → 번들 Resources에 배치

**수동 + 자동 혼합 전략**:
- **자동**: 버전, 날짜, commit에서 추출 가능한 feature 목록
- **수동 오버라이드**: title, summary, symbolName, area 등 사용자 대면 텍스트

**오버라이드 파일 예시** (`DUNE/Data/Resources/whats-new-overrides.json`):
```json
{
  "releases": [
    {
      "version": "0.2.0",
      "intro": "Start with condition, weather, sleep debt...",
      "features": [
        {
          "id": "widgets",
          "title": "Widgets",
          "summary": "홈 화면에서 컨디션 점수를...",
          "symbolName": "rectangle.3.group",
          "area": "today"
        }
      ]
    }
  ]
}
```

### C. 데이터 구조: enum → JSON 기반 모델

**현재** (하드코딩):
```swift
enum WhatsNewFeature: String, CaseIterable {
    case widgets, conditionScore, weather, ...
    var title: String { switch self { ... } }
}
```

**개편** (데이터 드리븐):
```swift
struct WhatsNewFeatureItem: Codable, Identifiable, Hashable {
    let id: String           // "widgets"
    let title: String        // localized key
    let summary: String      // localized key
    let symbolName: String   // SF Symbol
    let area: String         // "today", "activity", etc.
}

struct WhatsNewReleaseData: Codable, Identifiable {
    let version: String
    let intro: String
    let features: [WhatsNewFeatureItem]
    var id: String { version }
}
```

**Localization 전략**:
- JSON에는 영어 텍스트를 키로 저장
- 런타임에 `String(localized:)` 또는 `NSLocalizedString`로 변환
- xcstrings에 키 등록은 기존과 동일

## Constraints

| 제약 | 대응 |
|------|------|
| 서버 없음 | 번들 JSON + build-time 스크립트 |
| CloudKit 동기화 불필요 | 앱 번들에 정적 포함, 디바이스 간 일관성 보장 |
| Localization 3개 언어 | JSON 키 = 영어 텍스트, xcstrings에서 ko/ja 번역 |
| Build pipeline 규칙 | `scripts/build-ios.sh`에 generate 스크립트 통합 |

## Edge Cases

1. **git tag 없는 개발 빌드**: 오버라이드 JSON만으로 동작 (스크립트 출력 = 빈 자동 목록)
2. **오버라이드에 없는 commit**: 자동 추출된 항목은 기본 SF Symbol(`sparkles`) + area(`settings`)
3. **이전 버전 JSON 없음**: 0.2.0 이전 히스토리는 현재 releaseCatalog에서 마이그레이션
4. **JSON 파싱 실패**: 기존 하드코딩 fallback 유지 (graceful degradation)

## Scope

### MVP (Must-have)
- [ ] `WhatsNewFeatureItem` / `WhatsNewReleaseData` Codable 모델
- [ ] JSON 파일 기반 `WhatsNewManager` 리팩토링
- [ ] SF Symbol 조합 카드 View (`WhatsNewFeatureCard`)
- [ ] 기존 `WhatsNewArtwork` fallback mock 제거
- [ ] 현재 0.2.0 데이터를 JSON으로 마이그레이션
- [ ] 기존 테스트 업데이트

### Nice-to-have (Future)
- [ ] build-time 스크립트 (`scripts/generate-whats-new.sh`)
- [ ] git conventional commit 파싱
- [ ] 오버라이드 JSON 스키마 검증
- [ ] 버전별 히스토리 스크롤 UI 개선
- [ ] 애니메이션 카드 전환 효과

## Open Questions

1. **Localization 접근**: JSON에 영어 키를 넣고 `String(localized:)`로 변환 vs JSON 자체를 locale별로 분리?
   → 전자 권장 (xcstrings 단일 소스 원칙 유지)
2. **build-time 스크립트 시점**: `scripts/build-ios.sh` 내 xcodegen 전? 후?
   → xcodegen 전 (JSON 파일이 프로젝트에 포함되어야 하므로)
3. **기존 WhatsNewFeature enum 제거 시점**: JSON 마이그레이션 완료 후 즉시? 점진적?
   → 즉시 (하위 호환 불필요, MVP 단계에서 전환)

## Next Steps

- [ ] `/plan whats-new-revamp` 으로 구현 계획 생성
- [ ] SF Symbol 조합 카드 프로토타입 (WhatsNewFeatureCard)
- [ ] JSON 스키마 확정 + 0.2.0 데이터 마이그레이션
