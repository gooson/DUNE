---
tags: [swiftui, body-composition, accessibility, healthkit, design-map]
date: 2026-11-05
category: solution
status: implemented
---

# H06 신체 기록 목록의 출처별 측정값 표시

현행 소스 `438d9e8376fc4929cbf977893055eb4124d4d318`의 기존 UI 여섯 사례와 실제 PNG/AX 12쌍을 네 실행에서 검증·독립 검토했다. [H06 네이티브 갤러리](../../design/full-redesign-map/review/h06-body-history-native-2026-11-05/index.html)에 새 캡처와 출처를 보존한다.

## Problem

기존 H06 목록은 값의 관계와 기록 출처를 빠르게 읽기 어려웠다. 수동 `muscleMass`와 Apple Health의 `fetchLeanBodyMass`가 같은 저장 속성을 거쳐 표시되므로, 접근성 이름을 출처 없이 일괄 적용하면 Apple Health의 Lean Body Mass를 Muscle Mass로 잘못 알린다. 큰 글씨에서는 한 줄 배치가 지표를 가릴 수 있다.

## Solution

`BodyHistoryDetailView`의 날짜 아래에 실제로 존재하는 Weight·Body Fat·세 번째 신체값만 원래 category SF Symbol과 DUNE 신체 색의 캡슐로 놓았다. 좁은 폭과 접근성 큰 글씨에서는 세로로 배치한다. 밝은 외관의 작은 아이콘은 기존 신체 색을 검정과 35% 섞어 진하게 하고, 값 글자는 의미상 기본 대비를 쓴다. AX 이름은 수동 행에서 `Muscle Mass (kg)`, Apple Health 행에서 `Lean Body Mass`와 실제 값·단위를 읽는다. 수동 더 보기·Edit/Delete와 Apple Health 심장·읽기 전용 경로는 그대로다.

현행 438d의 Duo 접힘은 기존 Add·일반 Edit·MAX Edit 3/3, 펼침은 일반 Edit 1/1, 일반 iPhone과 iPad는 일반 Edit 각 1/1로 총 6/6이 통과했고, 대응하는 선택 PNG/AX 12쌍을 독립 검토했다. 접힘 Add의 체중만 있는 91.2 kg 행은 없는 지방·근육 값을 만들지 않았다. 일반 Edit 복귀에는 88.8 kg이 보인다. 밝은 접힘 실제 픽셀의 아이콘/캡슐 표본 대비는 6.03:1이다. 이전 12ecc Duo 접힘 3/3도 통과했지만 출처별 AX 수정 전 기록이므로 역사적 성공으로 따로 보존한다.

## Prevention

같은 저장 속성이라도 공급원이 다른 신체 지표는 목록 AX 이름을 출처별로 확인한다. 동일한 `H06 body history rows` 캡처 이름이 일반 Edit와 MAX Edit에 반복되므로 SDK testIdentifier와 시간 순서로 묶은 PNG/AX만 선택한다. Duo 펼침은 활성 LCD-1 이미지와 계층만 게시하고 검은 외부 디스플레이 프레임은 제외한다. 기기별 실제 결과가 모두 봉인되고 독립 검토되기 전에는 H06 디자인맵을 현행 캡처로 갱신하지 않는다.

## 검증 범위

- 완료: Duo 접힘 3건, 펼침 1건, 일반 iPhone 1건, iPad 1건의 현행 소스 통과 및 선택 캡처 검토.
- 게시: 네 기기·자세의 일반 Edit 목록을 각 H06 카드에 연결하고 Add·MAX Edit 보조 증거는 갤러리에서 구분한다.
- 미검증: 다른 언어, 어두운 외관, VoiceOver 음성, 실사용 HealthKit 쓰기, Duo 펼침과 일반 iPhone·iPad의 MAX/Add.

## Lessons Learned

- 수동 근육량과 Apple Health 제지방량은 저장 속성이 같아도 사용자에게 같은 측정으로 소개하지 않는다. AX 라벨은 공급원과 실제 단위를 기준으로 정한다.
- 같은 캡처 이름이 일반 Edit와 MAX Edit에 반복되면 SDK testIdentifier, 타임스탬프, 활성 디스플레이를 함께 확인해야 사례가 섞이지 않는다.
- 이전 12ecc 3/3 통과는 실패로 바꾸거나 현행 438d 6/6에 더하지 않는다. 수정 전 성공 이력으로 별도 보존한다.
