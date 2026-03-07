---
tags: [whats-new, json, codable, localization, sf-symbols, architecture]
date: 2026-03-08
category: solution
status: implemented
---

# What's New: JSON-Driven Catalog with SF Symbol Cards

## Problem

What's New 화면이 Swift enum에 하드코딩된 데이터와 프로시저럴 아트워크를 사용하여:
1. 새 릴리스 추가 시 코드 변경이 필수
2. 아트워크가 컨텐츠와 불일치
3. 히스토리 관리가 불가
4. ~480줄의 중복 코드

## Solution

### 1. JSON-Driven Data Architecture

`whats-new.json` 파일에서 릴리스 카탈로그를 관리:

```json
{
  "releases": [{
    "version": "0.2.0",
    "introKey": "whatsNew.v0_2_0.intro",
    "features": [{
      "id": "conditionScore",
      "titleKey": "whatsNew.conditionScore.title",
      "summaryKey": "whatsNew.conditionScore.summary",
      "symbolName": "heart.text.square",
      "area": "today"
    }]
  }]
}
```

### 2. Codable Structs with Cached Localization

`String.LocalizationValue` 기반 런타임 번역을 decode 시점에 캐싱:

```swift
struct WhatsNewFeatureItem: Codable, Sendable {
    let titleKey: String
    let title: String  // cached at decode time

    enum CodingKeys: String, CodingKey {
        case id, titleKey, summaryKey, symbolName, area  // title/summary excluded
    }

    init(from decoder: Decoder) throws {
        // ... decode keys from JSON
        title = String(localized: String.LocalizationValue(titleKey))
    }
}
```

**핵심**: `CodingKeys`에서 cached fields를 제외하여 encode 시 JSON에 불필요한 필드가 포함되지 않음.

### 3. SF Symbol Combination Cards

프로시저럴 아트워크(~280줄) → SF Symbol 조합 카드(~60줄):
- Primary symbol: JSON `symbolName` 필드
- Secondary symbol: area 기반 데코레이션 (WhatsNewStyle)
- Area gradient: DS.Color 토큰 기반

### 4. Layer Boundary Compliance

- **Domain** (`WhatsNew.swift`): Foundation만 import, UI 로직 없음
- **Presentation** (`WhatsNewArea+View.swift`): `badgeTitle` extension
- **Data** (`WhatsNewManager.swift`): JSON 파싱 + AppLogger 에러 로깅

## Key Patterns

| 패턴 | 적용 |
|------|------|
| JSON → Codable cached strings | 번역 키를 저장, decode 시 localized string 캐싱 |
| CodingKeys exclusion | 런타임 전용 필드를 encode에서 제외 |
| Memberwise init | 테스트용 convenience init 별도 제공 |
| DS.Opacity tokens | `.white.opacity(0.08)` → `DS.Opacity.light` |
| Unknown enum fallback | `WhatsNewArea.init(from:)` 에서 알 수 없는 rawValue → `.today` |

## Prevention

- 새 릴리스 추가 시 코드 변경 없이 JSON 수정만 필요
- xcstrings에 번역 키 등록으로 3개 언어 동시 관리
- 릴리스 히스토리가 JSON에 자동 보존
