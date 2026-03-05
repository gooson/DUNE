---
tags: [theme, shanks, wave-background, bottom-sheet, interaction, swiftui]
date: 2026-03-05
category: solution
status: implemented
---

# Solution: 샹크스 테마 모티프 오버레이 고도화

## Problem

기존 `shanksRed` 테마는 색상/웨이브 기반은 구현되어 있었지만, 요청한 "해적 깃발 모티프"와 "샹크스 특유의 분위기"를 전 화면(Tab/Detail/Sheet)에서 일관되게 전달하기에는 표현 밀도가 부족했다.

### Symptoms

- 샹크스 테마가 다른 테마 대비 고유 시각 아이덴티티가 약함
- Bottom Sheet에서 테마 특성이 희미해 체감 일관성이 떨어짐
- 테마 선택 시 피드백 인터랙션 부재

### Root Cause

- 기존 `ShanksWaveBackground`는 웨이브 레이어 중심이라 모티프형 비주얼(깃발/질감/스트릭)이 없음
- 설정 화면 테마 선택 행이 모든 테마에 동일한 정적 피드백만 제공

## Solution

`ShanksWaveBackground`에 재사용 가능한 모티프 오버레이(깃발 실루엣, 질감, 스트릭)를 추가하고, `ThemePickerSection`에 샹크스 선택 전용 펄스 인터랙션을 도입했다.

### Changes Made

| File | Change | Reason |
|------|--------|--------|
| `DUNE/Presentation/Shared/Components/ShanksWaveBackground.swift` | `ShanksPirateFlagSigil`, texture/streak overlay 추가 + Tab/Detail/Sheet에 단계별 강도 적용 | 샹크스 고유 감성 강화 및 전 화면 일관성 확보 |
| `DUNE/Presentation/Settings/Components/ThemePickerSection.swift` | 샹크스 배지 및 선택 시 펄스 인터랙션 추가 (`Reduce Motion` 대응) | 테마 선택 순간 피드백 개선 |
| `DUNETests/ShanksThemeEnhancementTests.swift` | 깃발 Shape 경로 스모크 테스트 추가 | 모티프 렌더링의 기본 안정성 보장 |
| `DUNE/DUNE.xcodeproj/project.pbxproj` | 신규 테스트 파일 타깃 등록 반영 | 테스트 타깃 컴파일 포함 |

### Key Code

```swift
ShanksPirateFlagSigil()
    .fill(theme.sandColor.opacity(opacity * darkBoost), style: FillStyle(eoFill: true))
```

```swift
if appTheme == .shanksRed {
    ShanksPirateFlagSigil()
        .scaleEffect(selectedTheme == .shanksRed && shanksPulse ? 1.14 : 1.0)
}
```

## Prevention

새 테마를 고도화할 때 색상 토큰만 추가하지 말고, `Tab/Detail/Sheet` 각각에 "테마 고유 모티프 레이어"를 같은 아키텍처로 적용한다.

### Checklist Addition

- [ ] 신규 테마는 `Tab/Detail/Sheet` 3경로 모두에서 고유 모티프가 보이는가?
- [ ] `Reduce Motion` 환경에서 오버레이가 정적으로 degrade 되는가?
- [ ] 설정 화면 테마 선택에 테마별 피드백 인터랙션이 필요한가?

### Rule Addition (if applicable)

즉시 룰 승격이 필요한 반복 패턴은 아니므로 `.claude/rules/` 추가는 생략.

## Lessons Learned

- 테마 완성도는 색상보다 "모티프 일관성 + 선택 인터랙션"에서 체감 차이가 크게 난다.
- 배경 레이어를 강화할 때도 Bottom Sheet는 항상 가독성을 최우선으로 두어야 회귀를 줄일 수 있다.
