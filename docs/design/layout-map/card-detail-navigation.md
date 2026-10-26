---
tags: [card-navigation, design-map]
date: 2026-10-26
category: plan
status: reviewed
---

# 메인 탭 카드 상세 헤더 · 2026-10-26

사용자가 Today·Activity·Wellness·Life 전체에 승인한 배치다.

```text
아이콘  카드 제목 ›                         ⓘ
        본문 수치·그래프·기록
```

- 상세 chevron은 제목에서 4pt 떨어진다. 헤더의 나머지 빈 공간까지 같은 링크/버튼으로 터치할 수 있다.
- 독립 헤더의 터치 높이는 최소 44pt다. 큰 글씨에서는 제목이 줄바꿈하고 높이를 늘린다.
- 이미 전체 카드가 링크인 경우 헤더는 동일한 표시만 사용하며 중첩 버튼을 만들지 않는다.
- 관련 없는 상세·전체 보기 문구와 하단 방향 표시를 반복하지 않는다. 실제 추가·기록·입력 행동과 정보 버튼은 별도 동작으로 유지한다.
- 기존 데이터 상태에 상세 목적지가 없으면 chevron과 터치 링크를 숨기고 제목만 유지한다.
- 복수 목적지가 있는 Wellness 점수/수면처럼 각각의 제목과 진입 영역을 보존한다.

공식 기준은 [관련 정보 그룹화·Dynamic Type](https://developer.apple.com/design/human-interface-guidelines/layout), [하위 화면 이동용 chevron](https://developer.apple.com/design/human-interface-guidelines/lists-and-tables), [44pt 터치·눌림 피드백](https://developer.apple.com/design/human-interface-guidelines/buttons)이다. 제목 옆 4pt와 카드 헤더 구조는 이 앱을 위한 설계 선택이며 Apple의 카드 전용 강제 규격으로 표현하지 않는다.

구현과 검증 범위는 [계획](../../plans/2026-10-26-sleep-debt-and-card-navigation.md)을 따른다. 영향 화면은 T03/A01/H01/L01과 해당 카드가 나타나는 상태다. iPhone·iPad·Duo에 영향이 있고 Watch는 이 공통 iOS 컴포넌트를 사용하지 않는다. 실제 캡처 완료 여부는 실제 화면맵에서 별도로 기록한다.
