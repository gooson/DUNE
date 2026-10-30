---
topic: T02 cloud sync consent redesign
date: 2026-10-31
status: approved
confidence: high
related_solutions:
  - docs/solutions/general/2026-03-08-cloud-sync-consent-localization-leak.md
  - docs/solutions/testing/2026-03-08-e2e-phase2-today-settings-regression.md
related_brainstorms: []
---

# Implementation Plan: T02 iCloud 동기화 동의

## Context

승인된 T02 제안은 시작 시 표시되는 동의 시트에서 저장 위치와 선택 결과를 먼저 이해할 수 있게 한다. 기존 4개 기기 형태의 T02 캡처는 화면과 일치하며 변경 전 기록으로만 보존한다.

## Requirements

### Functional

- iCloud/로컬 선택과 기존 저장·닫기 콜백을 유지한다.
- 개인 iCloud, Apple 기기 간 신체·운동 기록, 로컬 사용을 각각 설명한다.
- 결정 전 임의 닫기를 막는다.

### Non-functional

- iPhone, iPad, Duo 접힘·펼침과 큰 글씨·다크 모드에서 내용을 읽고 두 선택을 누를 수 있게 한다.
- 사용자 문구는 en/ko/ja 수동 카탈로그와 연결한다.
- CloudKit/서비스/설정 저장 로직은 변경하지 않는다.

## Approach

기존 `CloudSyncConsentView`의 스크롤+하단 고정 선택 구조를 유지하면서, 상단을 SF Symbol 중심의 테마 히어로 카드로 만들고 세 설명을 동일한 아이콘/텍스트 행으로 묶는다. 좁은 폭과 접근성 글씨에서는 내용이 세로 스크롤되며 선택 영역은 safe area에 남는다. 기존 동의 callback을 그대로 호출한다.

### Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|---|---|---|---|
| 기존 VStack의 간격만 조정 | 작음 | 승인된 위계와 카드 표현 부족 | 제외 |
| 별도 화면/설정 흐름 추가 | 자유로운 공간 | 동의 경로 변경 | 제외 |
| 시트 안의 히어로+설명 카드 | 현재 경로 보존 | 큰 글씨에서 스크롤 필요 | 선택 |

## Affected Files

| File | Change Type | Description |
|---|---|---|
| `docs/design/layout-map/cloud-sync-consent-t02.html`, `index.html`, `README.md` | add/update | T02 배치 계약과 링크 |
| `docs/design/theme-map/themes/dune-cloud-sync-consent-t02.html`, `manifest.json`, `README.md`, `index.html` | add/update | 기존 테마의 T02 화면별 표현 연구와 등록 |
| `DUNE/Presentation/Shared/CloudSyncConsentView.swift` | update | 히어로, 설명, 선택 영역 |
| `Shared/Resources/Localizable.xcstrings` | update | en/ko/ja 신규 문구 |
| `DUNEUITests/Full/TodaySettingsRegressionTests.swift` | update | 두 선택 경로와 정보/조작 노출 |
| `docs/design/phone-design-map/actual/` | update later | 영향 기기 새 실제 PNG·출처 |

## Implementation Steps

### Step 1: 배치와 문구 계약

- **Files**: T02 레이아웃 맵, 테마 표현 연구, 인덱스, 계획서
- **Changes**: 승인안의 순서·폭·상태·행동을 기록하고 테마 맵과 구분한다.
- **Verification**: 승인 제안과 기존 4기기 캡처를 대조한다.

### Step 2: 네이티브 UI와 번역

- **Files**: consent view, shared string catalog
- **Changes**: 고유 iCloud 히어로와 3행, 두 버튼을 구현한다. 저장 callback은 보존한다.
- **Verification**: format-xcstrings check, diff review, 빌드와 기기별 캡처는 단일 실행 담당이 수행한다.

### Step 3: 동작과 실제 화면 검증

- **Files**: focused UI test, actual design map
- **Changes**: 로컬/동기화 각각 누르고 닫힘 확인; 네 기기형 기본, 영향받는 다크/최대 글씨 확인 후 새 캡처를 실제 맵에 반영한다.
- **Verification**: `CloudSyncConsentRegressionTests` selector 및 새 PNG의 제목·본문·버튼·출처 확인. 실제 iCloud 계정/데이터 동작은 이 테스트 범위 밖이다.

## Edge Cases

| Case | Handling |
|---|---|
| 긴 번역/최대 글씨 | ScrollView와 줄바꿈, 하단 CTA safe area |
| iPad/Duo 넓은 시트 | 본문 최대 폭 제한, 시트 중앙 정렬 |
| 다크 모드 | DS 테마 배경/전경 대비 확인 |

## Testing Strategy

- Unit tests: 순수 로직 변경 없음으로 새 단위 테스트 불필요.
- Integration tests: 기존 mock UI launch hook에서 두 CTA 경로 확인.
- Manual verification: 실제 T02 캡처 iPhone/iPad/Duo 접힘/펼침, dark와 최대 글씨; 부모 실행 담당이 단일 전용 시뮬레이터로 수행.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| 큰 글씨에서 버튼 가림 | medium | high | 고정 safe area + 스크롤/최대 글씨 캡처 |
| 번역 누락 | low | medium | 수동 3언어 항목과 formatter check |
| 동의 저장 의미 변형 | low | high | 기존 callback/키 diff 보존, 두 경로 UI 검사 |

## Confidence Assessment

- **Overall**: High
- **Reasoning**: 기존 시트 구조와 deterministic UI hook이 있으며 서비스 로직은 건드리지 않는다.

## Fresh maximum-text visual review

The e7167f3f maximum-accessibility test passed after its gesture was moved above the pinned footer. Native inspection then found a separate presentation problem: the scaled leading icon narrowed the explanation to frequent one-word lines. At accessibility sizes only, InfoRow now uses a vertical icon/text layout, caps decorative badge size at64pt, and leaves text at the user's system size. Normal layout, original symbols, copy, callbacks and footer remain unchanged. Re-run only the existing maximum-text method and inspect its fresh information capture. This is a new visual finding; the resolved gesture failure and all original receipts stay preserved.
