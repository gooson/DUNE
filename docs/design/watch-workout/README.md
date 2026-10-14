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
| [62개 상태별 실제 화면 맵](../phone-design-map/actual/watch/index.html) | 기본 글자 크기 실제 캡처 58개, 미캡처 4개, 기존 검증 캡처 3개 |
| [collect-actual-captures.py](collect-actual-captures.py) | Watch UI 테스트 결과에서 실제 화면을 추출하고 맵 갱신 |
| [research-screens/](research-screens/) | 비교에 사용한 공개 제품 화면 자료 |

현재 실제 화면 맵은 58/62개 상태가 채워져 있다. S08 이전 세트는 완료한 세트에서 진입 버튼이 나타나지 않았고, S11 휴식 AOD와 C12 유산소 AOD는 시뮬레이터에서 실제 저휘도 화면을 캡처하지 못했다. S16 심박 미측정 휴식은 화면 수정 후 시뮬레이터 연결 실패로 재캡처하지 못해 이전 이미지를 제거했다. 이 맵의 빈 칸은 디자인 시안으로 대체하지 않는다. 기본 글자 크기의 실제 화면에서 루틴 이름 잘림, 운동 재정렬 조작 가림, 저장 요약의 버튼과 내용 겹침을 확인했다. 각 상태의 캡처 출처와 예외는 [인덱스](../phone-design-map/actual/watch/capture-index.json)에 기록했다.

## 이후 변경 순서

1. 구현 계획의 상태 코드에서 영향을 받는 분기와 SwiftUI View를 찾는다.
2. `DUNEWatch/DesignSystem.swift`와 `AppTheme+WatchView.swift`의 기존 색·간격을 적용한다. 보드의 픽셀 숫자를 watchOS pt로 그대로 복사하지 않는다.
3. 화면을 수정하면 보드 생성 스크립트를 저장소 루트에서 다시 실행한다. PNG 렌더링에는 `rsvg-convert`가 필요하다.
4. 작은 워치·큰 글씨에서 필수 조작의 실제 프레임과 도달성을 검사하고 새 캡처로 `simulator-evidence/`를 갱신한다.
5. 상태표, 이 폴더, 관련 [해결책 문서](../../solutions/general/2026-10-12-watch-workout-screen-system.md)를 같은 변경에서 갱신한다. 이전 시안의 번호 붙은 복제본은 남기지 않는다.

실제 워치의 AOD, Digital Crown, VoiceOver 동작은 시뮬레이터 캡처만으로 확정할 수 없다. 각 검증의 범위는 구현 계획의 검증 항목에 기록한다.
