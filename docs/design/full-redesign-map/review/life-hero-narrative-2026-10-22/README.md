---
tags: [design, life, hero, layout, dynamic-type, actual-capture]
date: 2026-10-22
category: solution
status: reviewed
---

# Life 히어로 진행 설명 실제 화면

[실제 화면 15장](index.html) · [캡처 출처](capture-index.json) · [실행 결과](test-results.json)

L01의 Today 기준 완료 링을 유지하고, 링 옆의 습관 이름 3개를 기존 `LifeViewModel.heroNarrative` 진행 설명으로 바꿨다. 개별 습관은 아래 실행 목록에 두며 히어로의 오늘 체크리스트 행동은 유지한다. 데이터 계산과 번역 문자열은 변경하지 않았다.

## 검증 범위

| 기기 조건 | 상태 | 결과 |
|---|---|---|
| 전용 iPhone 18 Pro · 402pt | 밝음·어두움·접근성 XXXL | 1건 통과, 실제 화면 3장 |
| 전용 iPhone 18 Pro Max · 440pt | 밝음·어두움·접근성 XXXL | 1건 통과, 실제 화면 3장 |
| 전용 iPad Pro 13-inch (M5) | 밝음·어두움·접근성 XXXL | 1건 통과, 실제 화면 3장 |
| 전용 Duo 접힘 세로 · 외부 LCD | 밝음·어두움·접근성 XXXL | 1건 통과, 실제 화면 3장 |
| 전용 Duo 펼침 가로 · 내부 LCD-1 | 밝음·어두움·접근성 XXXL | 1건 통과, 실제 화면 3장 |

모두 `LifeSeededSmokeTests.testHeroNarrativeLayout` 단일 selector로 정상 종료했으며 합계 5건 통과·실패 0건·건너뜀 0건이다. 테스트 실행은 순차 진행했고 각 기기는 현재 worktree 소유로 등록했다. 일반 iPhone·iPad·Duo의 기존 실제 맵 L01과 보드에는 같은 기기 모델의 새 기본 밝은 모드 PNG와 새 UDID 출처를 반영했다. 402pt iPhone은 별도 추가 증거로 보존한다.

## 확인한 배치

- 기본 글씨에서는 링 옆에서 설명이 줄바꿈된다. 접근성 XXXL에서는 링 아래에 설명을 쌓는다.
- 설명 프레임이 히어로 안에 있고 전체 링이 화면 안에 들어오며 체크리스트 행동이 도달 가능한지 검사했다.
- `Morning Stretch`가 히어로에 다시 나열되지 않는지 확인했다. 개별 실행 목록은 아래에 유지된다.
- host 감사 도구로 화면을 고정한 동안 촬영한 PNG에서 실제 픽셀, 잘림, 링·문장·행동의 배치를 검토했다. Duo 펼침 가로의 앱 viewport는 951×669pt다.

초기 접힘 검사에서 `ViewThatFits`가 문장을 한 줄로 펼쳤을 때의 폭을 기준으로 세로 배치를 선택했다. 기본 글씨를 `HStack`으로 고정하고 큰 글씨에서만 `VStack`을 쓰도록 수정한 뒤 실패한 접힘 검사를 한 번 재실행해 통과했다. 첫 실패 실행의 SDK 결과 정리도 60초 제한을 넘었으며 통과로 계산하지 않는다. 최종 펼침 화면도 수정된 코드로 다시 확인했다.

## 적용 범위와 남은 확인

DESERT HORIZON의 L01 배치 증거다. 다른 7개 테마는 같은 구조를 상속하지만 새 문장의 테마별 실제 대비는 이번 테스트의 통과 범위가 아니다. 다른 탭·탭 레일 전환·펼침 세로·고대비·VoiceOver 전체 흐름도 포함하지 않는다. 출처의 `source_worktree_dirty`는 캡처 당시 `ViewThatFits` 제거가 미커밋 상태였음을 뜻하며 앱 소스 hash를 함께 보존했다.
