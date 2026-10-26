---
tags: [swiftui, card-header, navigation, accessibility, sleep-debt]
category: architecture
date: 2026-10-26
severity: minor
related_files: [DUNE/Presentation/Shared/Components/CardNavigationHeader.swift, DUNE/Presentation/Shared/Components/SectionGroup.swift, DUNE/Presentation/Dashboard/Components/RecoverySleepCard.swift]
related_solutions: [docs/solutions/design/hero-cta-button-pattern.md]
---

# Solution: 카드 제목과 상세 진입을 같은 헤더로 묶기

## Problem

네 메인 탭의 카드가 상세 링크를 상단 오른쪽·하단·전체 카드 등에 따로 구현해 이동 위치와 화살표가 달랐다. Today 수면 부채도 레이블과 시간만 있어 다른 수면 텍스트와 구분하기 어려웠다.

### Symptoms

- 카드 제목과 `상세 ›`가 떨어져 관계를 파악하기 어렵다.
- 같은 목적지를 가리키는 하단 CTA나 두 번째 chevron이 반복된다.
- 숫자만 있는 부채 값에 시각적 단서가 부족하다.

### Root Cause

실제 목적지의 소유권과 공통 표현이 분리되어 있지 않아 각 소비자가 위치·서체·터치 영역을 반복 정의했다.

## Solution

`CardNavigationHeader`는 제목 바로 옆 chevron, 남은 너비를 포함하는 레이블, 최소 44pt 높이를 제공한다. 실제 `NavigationLink(value:)` 또는 `Button`은 각 화면이 소유한다. 전체 카드가 이미 링크면 헤더는 레이블만 제공해 중첩 버튼을 만들지 않는다.

`SectionGroup.headerLink`는 정적 헤더 레이블에만 좁게 타입 소거를 적용한 래퍼를 받아 기존 타입 목적지를 유지한다. 정보 버튼은 별도 형제로 남긴다. 헤더로 옮긴 링크에는 기존 ID를 유지하고 본문 링크가 남는 경우 `-content` ID로 구분한다.

### Changes Made

| File | Change | Reason |
|---|---|---|
| CardNavigationHeader.swift | 공통 레이블·눌림 스타일·chevronColor | 위치/터치 일관성과 불투명 표면 대비 |
| SectionGroup.swift | 선택적 헤더 래퍼·독립 정보 버튼 | 기존 목적지와 보조 행동 유지 |
| 네 탭 소비자 | 중복 CTA 제거·헤더 진입 | 제목과 이동 동작을 가깝게 묶기 |
| RecoverySleepCard.swift | 기존 ProgressRingView 40pt 재사용 | 부채의 양을 도식으로 구분 |

### Key Code

```swift
NavigationLink(value: existingDestination) {
    CardNavigationHeader {
        Text(existingTitle)
    }
}
.buttonStyle(CardNavigationButtonStyle())
```

수면 링은 기존 수면 상세와 동일한 600분 표시 상한만 적용한다. 실제 누적 시간·계산·심각도 기준은 변경하지 않으며 장식 링을 회복률로 읽지 않도록 접근성에서 숨긴다. 정확한 시간은 텍스트로 유지하고 0분은 체크 아이콘으로 구분한다.

## Prevention

- 카드 상세와 별도 실제 행동(입력·정보·같은 화면 스크롤)을 구분한다. Life 체크리스트 이동을 상세 링크로 바꾸지 않는다.
- 불투명한 어두운 히어로는 밝은 시스템 모드에서도 올바른 chevron 색을 명시한다.
- SwiftUI가 버튼 레이블의 접근성 자식을 합칠 수 있으므로 독립 헤더 터치는 실제 버튼 ID와 프레임으로 검증한다. 테스트 때문에 기존 VoiceOver 구성을 바꾸지 않는다.
- 새 Swift 파일은 표준 실행기의 프로젝트 재생성을 거친다. pre-commit은 project.yml 변경이 없으면 `--no-regen` 빌드를 수행하므로 새 파일 등록을 자동으로 보장하지 않는다.
- pre-commit은 `.xcodebuild`를 정리한다. 필요한 실행 증거는 별도로 보존한다.

### Checklist Addition

- [ ] 헤더의 빈 영역까지 기존 상세로 이동하는가?
- [ ] 정보 버튼·기록 입력이 중첩되지 않았는가?
- [ ] 상태 없는 카드에 거짓 상세 표시를 만들지 않았는가?
- [ ] 시안과 실제 화면, UI 실행 성공과 단순 캡처를 구분했는가?

## Lessons Learned

링의 의미와 척도를 기존 화면과 통일하고 정확한 숫자를 남기면 데이터 의미를 바꾸지 않고 읽기 위계를 개선할 수 있다. UI 테스트가 접근성 트리의 내부 형태를 가정하면 실제 이동 경로보다 레이블 병합 방식에 종속된다.

## Verification Limits

변경 소스의 Swift 구문 검사와 최종 앱·테스트 타깃의 컴파일/링크는 완료했다. 이전 수면 상세 진입과 Life 헤더 터치는 각각 통과했으나 최종 5개 UI 실행은 테스트 러너 시작 후 결과가 나오지 않아 900초에서 종료됐다. 전체 UI 통과로 처리하지 않는다. [실행 기록](../../reviews/2026-10-26-card-header-navigation.md)에 실패·재시도·새 캡처 상태를 구분한다. `.claude/**` 규칙은 수정하지 않았다.
