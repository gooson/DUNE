---
tags: [watchos, workout, design-system, screen-inventory, visual-qa]
date: 2026-10-12
category: plan
status: implemented
---

# Watch 운동 화면 디자인 기준

이 폴더는 DUNE Watch 운동 흐름의 **단일 최종 시안**과 검증 자료를 보관한다. 화면 상태 전체와 코드 위치는 [구현 계획·상태표](../../plans/2026-10-12-watch-workout-redesign.md)를 기준으로 찾는다. 보드의 12개 화면은 대표 상태이며, 상태표의 모든 분기를 각각 그린 그림은 아니다.

| 파일 | 역할 |
|---|---|
| [watch-workout-design.png](watch-workout-design.png) | 공유·검토용 최종 보드 |
| [watch-workout-design.svg](watch-workout-design.svg) | 편집 가능한 벡터 원본 |
| [build-watch-workout-design.py](build-watch-workout-design.py) | 같은 두 파일을 재생성하는 스크립트 |
| [simulator-evidence/](simulator-evidence/) | 현재 구현에서 캡처한 화면과 테스트 출처 |
| [research-screens/](research-screens/) | 비교에 사용한 공개 제품 화면 자료 |

## 이후 변경 순서

1. 구현 계획의 상태 코드에서 영향을 받는 분기와 SwiftUI View를 찾는다.
2. `DUNEWatch/DesignSystem.swift`와 `AppTheme+WatchView.swift`의 기존 색·간격을 적용한다. 보드의 픽셀 숫자를 watchOS pt로 그대로 복사하지 않는다.
3. 화면을 수정하면 보드 생성 스크립트를 저장소 루트에서 다시 실행한다. PNG 렌더링에는 `rsvg-convert`가 필요하다.
4. 작은 워치·큰 글씨에서 필수 조작의 실제 프레임과 도달성을 검사하고 새 캡처로 `simulator-evidence/`를 갱신한다.
5. 상태표, 이 폴더, 관련 [해결책 문서](../../solutions/general/2026-10-12-watch-workout-screen-system.md)를 같은 변경에서 갱신한다. 이전 시안의 번호 붙은 복제본은 남기지 않는다.

실제 워치의 AOD, Digital Crown, VoiceOver 동작은 시뮬레이터 캡처만으로 확정할 수 없다. 각 검증의 범위는 구현 계획의 검증 항목에 기록한다.
