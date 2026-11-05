---
tags: [swiftui, injury-history, dynamic-type, contrast, lazy-list, ui-test-fixture]
category: general
status: implemented
date: 2026-11-05
severity: important
related_files:
  - DUNE/Presentation/Injury/InjuryHistoryView.swift
  - DUNE/App/TestDataSeeder.swift
  - DUNEUITests/Full/WellnessRegressionTests.swift
related_solutions:
  - architecture/2026-02-23-injury-ui-bilingual-radio-list-patterns
  - architecture/2026-02-20-injury-tracking-review-fixes
---

# 부상 이력의 상태 기호·전경과 lazy List 검증

## Problem

H09 목록의 상태 제목에는 기호가 없고, 날짜와 심각도 아이콘의 강조가 약했다. 원래 SF Symbol·기록값·목록 행동을 유지하면서 두 상태와 각 기록을 읽기 쉽게 구분할 필요가 있었다. 실제 Duo 캡처에서는 기존 통계 버튼의 밝은 accent가 밝은 원형 면과 2.57:1에 그쳐 그래픽 조작 요소의 대비도 부족했다.

기본 UI seed는 활성 기록 한 건뿐이므로 회복 그룹의 실제 표현을 확인할 수 없었다. 최대 글씨의 List에서는 화면 밖 행이 AX 트리에서 빠질 수 있어, AX 행 개수를 모델 기록 수로 해석하거나 부재 행을 항상 아래로 찾는 검증도 적절하지 않다.

## Solution

| 파일 | 변경 | 보존한 동작 |
| --- | --- | --- |
| `InjuryHistoryView.swift` | 상태 Label, 원래 심각도 기호의 가변 폭·밝은 전경, 이름 headline, 날짜 보조색, 통계 버튼의 Light tint | 쿼리·캐시·정렬·필드·회복·삭제·편집·통계 및 H10 이동 |
| `TestDataSeeder.swift` | DEBUG에서 UI 테스트와 전용 플래그를 함께 사용한 경우만 회복 기록 한 건 추가 | 플래그가 없는 기본 seed와 실제 앱 데이터 |
| `WellnessRegressionTests.swift` | 두 상태의 전체 행 캡처, 기존 상세·편집·저장 복귀, 목록만 확인하는 AXXXL 사례 | 기존 플로우 assertion과 원래 행 ID |

심각도는 기존 상태색을 사용한다. Light에서만 검정과 섞어 진하게 만들고 Dark는 원래 상태색을 유지한다. 통계 버튼도 Light에서만 현재 테마 accent를 진하게 섞고 Dark는 상위 화면의 테마 accent와 같은 값을 사용한다. 새 색상 배열·의료 점수·저장 로직은 추가하지 않는다.

```swift
private var statisticsTint: Color {
    colorScheme == .light
        ? theme.accentColor.mix(with: .black, by: 0.45)
        : theme.accentColor
}
```

UI fixture는 `--uitesting`과 `--ui-injury-history-fixture`가 함께 있을 때만 기존 활성 Knee와 과거의 회복 Shoulder를 보여 준다. 날짜는 실행일에 상대적인 기존 모델 필드다. MAX 검사는 실제 List/window의 교집합과 겹치는 내비게이션 바를 기준으로 행 전체가 보이는지 확인한다. 화면 밖의 앞선 행으로 복귀할 때는 이전 콘텐츠 방향을 명시하고, 최대 12번의 작은 드래그만 허용한다.

## Verification

검증 소스는 `611d70b10b2c5ddcf9f2ddf64098c9bf3dcee69e`다. [실제 화면과 출처](../../design/full-redesign-map/review/h09-injury-history-native-2026-11-05/index.html)를 별도 갤러리에 보존했다. 일반 iPhone 1건·iPad 1건·Duo 접힘 2건·펼침 1건의 선택 검사 **5/5**와 실제 PNG/AX **10쌍**을 독립 검토했다. 통계 기호의 실제 대비는 접힘 9.50:1, 펼침 9.09:1, iPhone 9.12:1, iPad 9.07:1이었다. App/UI 컴파일은 이 실행에서 확인했다.

범위는 English·Light의 네 프로필과 Duo 접힘 AXXXL이다. Dark는 코드의 색상 보존을 확인했으며 새 Dark·VoiceOver·90°·Watch 실행으로 확대하지 않았다. 회복·삭제·통계 행동 코드는 보존했으며 해당 행동의 새 동적 실행을 주장하지 않는다. 모델·계산·저장 로직 변경이 없어 새 unit·full·smoke 검사는 추가하지 않았다.

이전 `640cc681`의 Duo SDK 3건은 원본·UID·자세·캡처와 함께 이전 소스 기록으로 남겼다. 초기 통계 대비 P2를 해결한 현재 소스의 5건과 합산하지 않는다. 기존 네 H09 이미지는 날짜·기기·fixture가 다른 역사적 참고이며 같은 조건의 before가 아니다.

## Prevention

- 행만 살피지 말고 해당 화면이 소유한 toolbar 기호와 행동 문구의 전경도 첫 실제 캡처에서 측정한다.
- 첫 프로필의 네이티브 검토가 끝난 후 나머지 프로필로 확장해, 수정 전 소스의 캡처를 반복 수집하지 않는다.
- lazy List에서는 보이는 AX 행 수 대신 목표 기록의 ID·전체 프레임·도달성을 확인한다. 부재 행을 찾는 방향도 명시한다.
- 실제 모델 필드를 쓰는 opt-in UI fixture로 필요한 상태만 추가하고 기본 데이터·실제 앱의 경로를 유지한다.
- 이전 실패·발견사항·소스별 통과를 보존하고 새 소스의 완료 수와 구분한다.
- 보드의 사진 타일 바깥 보존 여부는 RGB 차이로 확인한다. 알파가 동일한 RGBA 차이에 `getbbox()`를 적용해 전체 RGB 차이가 없다고 판단하지 않는다.

## Lessons Learned

기능 검사가 통과해도 전경 대비는 별도 실제 검토가 필요하다. 시스템 List·원래 심볼·기존 필드를 유지한 작은 표현 변경으로 읽기 위계를 개선할 수 있으며, 프레임을 확인하는 유한 스크롤은 최대 글씨의 목록 가상화에도 대응할 수 있다.
