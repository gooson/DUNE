---
tags: [today, wellness, review, observation, actual-capture]
date: 2026-10-28
category: solution
status: reviewed
---

# 후속 변경 최종 검증

[새 실제 iPhone 화면4장](index.html) · [개별 기기·소스·시각·해시](manifest.json) · [실행 기록](proof/verification.json)

최종 카드 equality/hash 수정과 main 문자열 변경 통합 후 Today 같은 행의 높이·폭·위치, 비교 없는 체중 표시·상세 목적지 및 Wellness 네 신체 지표·헤더 가장자리 상세 진입2개 UI가 통과했다. 이전 PNG를 복사하지 않고 이 실행의 XCTest 첨부만 추출했다. 기본 글씨·테스트 데이터·iPhone 밝음/어두움 Today 상태다. H01 body 검사는 기능 검사이며 새 성공 캡처는 없다. 최초2개 중 Today1개가 통과하고 body1개는 아래 버튼에서 헤더를 위쪽으로 찾는 테스트 방향 오류로 실패했다. 실패 hierarchy는 헤더 y=-414.3을 보였다. 해당 최종 reveal에 direction .down 한 줄을 지정한 뒤 그 메서드만1회 재실행해 통과했다. 최초 실패 화면·계층·실행 receipt를 보존하며 성공으로 덮어쓰지 않는다.

관련 단위3개는 canonical test build 후 정확한 Swift Testing 식별자를 기존 simulator lock·deadline 안에서 실행해 통과했다. 새 Observation 테스트는 최신 값·시각을 고정하고 과거 값만 바꿔 카드 배열의 갱신 알림1회와 equality/Set 계약을 확인한다. 표준 unit script에 selector가 없어 기존에 확인한 focused fallback을 사용했고 runner는 변경하지 않았다.

앞선 [희소 수면](../wellness-sparse-sleep-2026-10-28/README.md), [예측 시각화](../wellness-prediction-visual-2026-10-28/README.md), [Today 레이아웃](../today-wellness-metrics-2026-10-28/README.md)의 다른 소스/기기 증거는 당시 출처로 보존한다. 이번4장을 iPad/최대 글씨/희소 수면/예측의 새 실행으로 표시하지 않는다.

자동 판정기의 full fallback은 최신 adapter에 따라 targeted로 확인했다. 전체 UI 회귀·Duo 접힘/펼침·이번 equality delta의 iPad/최대 글씨·실제 VoiceOver는 미검증이다. 전체 단위의 이전 무관한 AI 평가 실패와 timeout은 이전 갤러리에서 보존하며 전체 통과로 집계하지 않는다. 재개하려면 해당 전용 기기/상태로 관련 selector를 실행하고 새 화면을 수집한다.
