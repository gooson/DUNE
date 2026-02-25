---
source: brainstorm/2026-02-26-visual-overhaul-icon-alignment
priority: p2
status: done
created: 2026-02-26
updated: 2026-02-26
depends_on: visual-overhaul MVP (color palette + card style) 완료 후 진행
---

# Wave 모티프 + 추가 비주얼 개선

MVP(색상 팔레트 워밍 + 카드 스타일)가 적용된 후 진행할 비주얼 개선 항목.

## 대기 항목

### Wave 모티프 (아이콘 아이덴티티)
- [x] `WaveShape.swift` — 아이콘 파동선을 SwiftUI Shape로 구현
- [x] Dashboard 배경에 subtle wave overlay 적용 (TabWaveBackground — 전체 4탭 적용)
- [x] EmptyStateView에 wave 장식 추가
- [x] Loading state wave 애니메이션 (맥박 느낌) — TabWaveBackground animated drift
- [x] Pull-to-refresh 커스텀 wave indicator (Canvas 기반 80x20pt 캡슐)

### 히어로 카드 비주얼 업그레이드
- [x] Progress Ring에 앰버-골드 기반 그라디언트 통일
- [x] 점수 숫자에 미세한 골드 그라디언트 텍스트
- [x] Hero 배경을 골드→상태색 gradient overlay로 강화

### 디자인 시스템 문서화
- [x] `.claude/skills/design-system/SKILL.md` 완전 정의 (Colors, Typography, Spacing, Components)
- [x] 색상 팔레트 최종 확정 후 문서 반영

### watchOS 색상 동기화
- [x] watchOS asset catalog 색상을 iOS와 동일한 warm 톤으로 조정 — 기존 11개 색상이 이미 iOS와 동일 확인 완료

## 주의사항
- Wave 모티프는 **2-3곳**에만 절제된 적용 (과용 금지)
- `Shape.path(in:)` 내 무거운 연산 금지 (Correction #82)
- Color 인스턴스 hot path 생성 금지 (Correction #83) — static 캐싱 필수
