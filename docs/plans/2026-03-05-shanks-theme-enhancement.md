---
tags: [theme, shanks, wave-background, bottom-sheet, animation, interaction]
date: 2026-03-05
category: plan
status: approved
---

# Plan: 샹크스 테마 고도화 (해적 깃발 + 시그니처 백그라운드)

## Summary

기존 `shanksRed` 테마는 색상/웨이브 기반은 갖춰져 있으나, 요청한 "붉은머리 해적단 깃발 모티프"와 "샹크스 특유의 배경 연출"이 약하다.
`Tab/Detail/Sheet` 공통 경로에서 재사용 가능한 오버레이 레이어를 추가하고, 테마 선택 시 인터랙션 피드백을 강화한다.

## Related References

- Brainstorm: `docs/brainstorms/2026-03-05-shanks-theme-enhancement.md`
- Solution: `docs/solutions/design/2026-03-04-adding-new-theme.md`
- Solution: `docs/solutions/design/theme-wave-visual-upgrade.md`
- Rule: `.claude/rules/testing-required.md`
- Rule: `.claude/rules/swift-layer-boundaries.md`

## Affected Files

| File | Action | Description |
|------|--------|-------------|
| `DUNE/Presentation/Shared/Components/ShanksWaveBackground.swift` | Edit | 해적 깃발 실루엣/텍스처 오버레이, 탭/디테일/시트 모션 및 가독성 튜닝 |
| `DUNE/Presentation/Settings/Components/ThemePickerSection.swift` | Edit | 샹크스 선택 인터랙션(펄스) 추가, 해적 모티프 미리보기 노출 |
| `DUNETests/ShanksThemeEnhancementTests.swift` | New | 깃발 모티프 경로/동작 스모크 테스트(0-size 안전성 포함) |

## Implementation Steps

### Step 1: 공통 해적 깃발 모티프 레이어 추가

- **Files**: `ShanksWaveBackground.swift`
- **Changes**:
  - `ShanksPirateFlagSigil`(Shape) 추가
  - `ShanksFlagTextureView`(정적 pre-render texture) 추가
  - `ShanksFlagOverlay`(ViewModifier 또는 내부 View)로 Tab/Detail/Sheet에서 공통 재사용
- **Verification**:
  - Shape path가 빈 rect/0-size rect에서도 안전
  - `Reduce Motion`에서 애니메이션 자동 비활성

### Step 2: 샹크스 백그라운드 시그니처 강화

- **Files**: `ShanksWaveBackground.swift`
- **Changes**:
  - Tab: 기존 3레이어 웨이브에 깃발 워터마크/패기 스트릭/텍스처 오버레이 추가
  - Detail: 가독성 우선의 저강도 오버레이 적용
  - Sheet: 가장 약한 오버레이 + 텍스트 대비 보장
- **Verification**:
  - Tab/Detail/Sheet 모두에서 모티프가 보이되 텍스트 가독성 저하 없음
  - 다크/라이트 전환 시 과도한 밝기 점멸 없음

### Step 3: 테마 선택 인터랙션 강화

- **Files**: `ThemePickerSection.swift`
- **Changes**:
  - `selectedTheme`가 `.shanksRed`로 변경될 때 짧은 펄스 애니메이션 추가
  - 샹크스 행에만 소형 깃발 배지 표시
- **Verification**:
  - 테마 선택 기능 기존 동작 유지
  - `Reduce Motion`에서 과한 효과 제거

### Step 4: 테스트/품질 검증

- **Files**: `DUNETests/ShanksThemeEnhancementTests.swift`
- **Changes**:
  - Shape path smoke test
  - 애니메이션 상태와 무관한 deterministic 검증 추가
- **Verification**:
  - `scripts/build-ios.sh` 성공
  - `scripts/test-unit.sh` 성공

## Edge Cases

| Case | Handling |
|------|----------|
| Reduce Motion 활성화 | overlay pulse/drift 정지, 정적 레이아웃 유지 |
| Dynamic Type 큰 설정 | 상단 워터마크 opacity 하향으로 텍스트 가독성 확보 |
| Sheet 좁은 높이 | 오버레이 y-offset 축소, gradient 우선 |
| 테마 전환 직후 | `.id(theme)` 기반 배경 재시작 패턴 유지 |

## Testing Strategy

- Unit tests:
  - `ShanksThemeEnhancementTests` 신규
  - 기존 `AppThemeTests` 회귀 확인
- Integration:
  - `scripts/build-ios.sh`
  - `scripts/test-unit.sh`
- Manual:
  - Settings > Theme에서 샹크스 선택 시 펄스 확인
  - Tab/Detail/Sheet 3경로 시각 확인
  - Reduce Motion ON/OFF 동작 비교

## Risks & Mitigations

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| 배경 오버레이 과다로 가독성 저하 | Medium | High | Detail/Sheet opacity cap + gradient veil 유지 |
| 애니메이션 추가로 프레임 저하 | Medium | Medium | pre-render texture + lightweight sine drift만 사용 |
| 테마 행 인터랙션이 다른 테마 UX와 불균형 | Low | Medium | 샹크스 전용 효과를 짧은 1회 펄스로 제한 |

## Done Criteria

- 샹크스 모티프가 Tab/Detail/Sheet 전부에 반영된다.
- 바텀시트 포함 주요 화면에서 가독성/성능 회귀가 없다.
- 빌드/유닛테스트가 통과한다.
