---
tags: [design, hero-ring, duo, layout, actual-capture]
date: 2026-10-22
category: solution
status: reviewed
---

# Duo 4탭 히어로 링 실제 배치

[실제 화면 16장](index.html) · [화면별 출처](capture-index.json) · [테스트 결과](test-results.json)

현재 worktree가 생성·등록한 전용 `iPhone Duo-wt-Health-c658-3d55863c6a19`에서 DESERT HORIZON의 T03 Today, A01 Activity, H01 Wellness, L01 Life를 확인했다. 접힘 세로의 활성 외부 LCD와 펼침 가로의 활성 내부 LCD-1을 공식 기기 조회로 대조했다. 원본 PNG를 보존하며 시안 이미지를 사용하지 않았다.

이후 Life 히어로의 습관 이름을 진행 설명으로 바꿨다. 이 갤러리의 L01은 해당 변경 전 배치이며 [최신 Life 실제 화면](../life-hero-narrative-2026-10-22/README.md)을 현재 배치의 증거로 사용한다.

## 검사와 결과

- `ThemeMatrixUITests.testDesertHeroRingsByInitialTab`을 자세별로 실행했다. 두 실행 모두 정상 종료했으며 합계 2건 통과·실패 0건·건너뜀 0건이다.
- 밝음·어두움에서 링의 실제 프레임이 Today와 같은지, 원형을 유지하는지, 전체 링이 화면 안에 들어오는지, 히어로 행동이 도달 가능한지 검사했다. Wellness 설명이 카드 오른쪽을 넘지 않는지도 확인했다.
- host 감사 도구가 각 화면을 고정한 동안 양쪽 디스플레이를 촬영했다. 활성 화면의 16장을 골라 픽셀 유효성과 실제 배치를 검토했다. 접힘은 1398×2034, 펼침 가로는 2853×2007 PNG다.
- 기기별 실제 디자인맵의 T03·A01·H01·L01과 보드는 이번 밝은 모드 캡처로 갱신했다.

첫 강화 검사에서는 124pt 원의 바깥으로 그려진 11pt 획까지 포함한 접근성 프레임을 124pt로 가정해 실패했다. Today의 실제 프레임을 기준으로 비교하도록 고친 뒤 한 번 재검증해 통과했다. 첫 실패 실행은 SDK 결과 정리도 60초 제한을 넘었으며 통과 증거에 포함하지 않는다. [검증 이력](validation-history.json)에 구분했다.

## 적용 범위

탭별 직접 진입의 기본 글씨 배치 결과다. 탭 레일을 통한 전환, 펼침 세로, 최대 접근성 글씨, 다른 테마의 Duo 화면은 이번 통과 범위에 포함하지 않는다. 펼침 전환은 검토된 hinge helper에 180°를 요청한 후 활성 내부 LCD·방향·새 화면으로 확인했다. 현재 SDK에 힌지 각도 조회 명령이 없어 정확한 각도 readback을 확인한 것으로 기록하지 않는다.

앱 화면 소스는 최신 `main`의 링 구현이며 이번 단위에서는 테스트와 문서만 수정했다. 출처의 `source_worktree_dirty`는 캡처 당시 링 프레임 검사 수정이 미커밋 상태였음을 뜻한다.
