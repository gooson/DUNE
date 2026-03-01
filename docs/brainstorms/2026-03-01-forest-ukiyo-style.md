---
tags: [theme, forest, ukiyo-e, design-system, dark-mode]
date: 2026-03-01
category: brainstorm
status: draft
---

# Brainstorm: Forest Ukiyo Style Theme

## Problem Statement
현재 Forest 테마가 존재하지만, 전체 탭 기준으로 봤을 때 "우키요에 숲"의 스타일 정체성이 충분히 강하게 전달되지 않습니다.
앱 전체 테마 톤과 충돌하지 않으면서 Forest 주제에 맞는 우키요 스타일을 강화하고, 특히 다크모드에서도 선명하게 보이도록 개선이 필요합니다.

## Target Users
- 전체 탭을 사용하는 모든 사용자
- 다크모드 사용 비중이 높은 사용자

## Success Criteria
- Forest 테마 진입 시 분위기(무드)만으로도 우키요 스타일이 즉시 인지된다.
- Tab/Detail/Sheet 배경이 동일한 스타일 언어를 유지한다.
- 다크모드에서 배경 요소가 뭉개지지 않고 충분히 식별된다.
- 스타일 강화 후에도 앱 전체 테마와 이질감이 없다.

## Proposed Approach
- 스타일 원칙:
  - 숲 실루엣은 둔한 곡선/몽글한 리듬 중심으로 유지
  - 우키요 느낌의 반투명 크레스트(굵은 밴드 + 내부 선) 레이어 사용
  - 그레인/워시 텍스처는 분위기 보강 수준으로 절제
- 시각 구성:
  - Far/Mid/Near 레이어 간 대비를 "형태 + 톤"으로 분리
  - 크레스트는 숲 계열 밝은 톤(`forestMist` 기반)으로 통일
  - 그라디언트는 상단 가독성 확보 우선
- 다크모드 정책:
  - 실루엣 대비를 우선 보정
  - 크레스트 폭/불투명도 최소 가시성 기준 유지
  - 그레인 과다 적용 금지(텍스트 인접 영역 혼탁 방지)

## Constraints
- Forest라는 테마 주제를 벗어나지 않아야 함
- 기존 앱 테마 시스템과 시각적 일관성 유지
- 전체 탭에 동일한 스타일 규칙으로 적용 가능해야 함
- 다크모드 가시성이 우선 보장되어야 함

## Edge Cases
- 다크모드에서 배경 레이어가 서로 합쳐져 형태가 사라지는 경우
- Reduce Motion 활성화 시에도 스타일 정체성이 유지되어야 함
- 작은 화면에서 크레스트 폭이 UI 가독성을 해치지 않아야 함
- 날씨 오버레이 활성화 시 Forest 무드가 약해지지 않아야 함

## Scope
### MVP (Must-have)
- Forest Tab/Detail/Sheet에 우키요 스타일 시각 언어를 일관 적용
- 숲 실루엣의 몽글한 노이즈/형태 튜닝
- 다크모드 가시성 기준(실루엣/크레스트/그레인) 확정 및 반영

### Nice-to-have (Future)
- 계절별 Forest 우키요 변형(봄 안개/가을 잉크톤)
- 성능 프로파일별 텍스처 강도 자동 조절
- watchOS Forest 테마의 우키요 스타일 동기화

## Open Questions
- Forest 전용 하이라이트 색 토큰을 추가할지, 기존 `forestMist`만 사용할지
- 성능 예산(FPS/배터리) 기준을 어디까지 엄격히 둘지
- 1차 범위에 watchOS 동시 반영이 필요한지

## Next Steps
- [ ] /plan forest-ukiyo-style 으로 구현 계획 생성
