---
tags: [all-data-history, dynamic-type, healthkit, native-evidence, stacked-pr]
category: architecture
date: 2026-11-02
severity: important
related_files:
  - DUNE/Presentation/Shared/Detail/AllDataView.swift
  - DUNE/Data/HealthKit/BreathingDisturbanceQueryService.swift
  - DUNEUITests/Full/AllDataDetailRedesignTests.swift
related_solutions:
  - docs/solutions/healthkit/2026-03-04-all-data-sleep-awake-alignment.md
  - docs/solutions/healthkit/2026-03-11-sleep-all-data-time-anchor.md
---

# 전체 데이터 이력: 식별성과 실제 날짜·단위의 보존

## Problem

16개 분류의 이력 화면을 강조하면서 원래 날짜 그룹·실제 시각·수치 정밀도·단위·페이지 조회·제한 이력과 빈 상태를 보존해야 했다. 큰 글씨에서 시각과 긴 단위가 서로 밀려서는 안 된다. 수면은 보고 날짜와 실제 첫 비각성 단계의 시각이 서로 다른 의미를 가진다.

Duo 검증의 공통 setup은 탭·사이드바를 요구하지만 이 테스트는 독립 이력 화면으로 시작한다. 또한 T06에 쌓인 T07 PR은 부모 브랜치를 먼저 정리했을 때 자동으로 닫혔다. 데이터와 리뷰를 보존한 채 기존 PR을 복구해야 했다.

## Solution

- 기존 category 이름과 SF Symbol을 정적인 사구 히어로에 사용한다. 원래 `AllDataViewModel`과 조회·취소·페이지 동작을 변경하지 않고 의미 없는 평균·전체 개수·가상 필터를 추가하지 않는다.
- 원래 날짜 섹션과 `displayDate ?? date` 시각을 유지한다. 16개 값 formatter, 수면 각성 제외, 백분율 변환과 부호 있는 온도를 보존한다. 페이지의 30일은 기록 수나 전체 이력 상한이 아니다.
- 기본 행은 시각·값을 같은 기준선에 두고 최대 접근성 글씨에서는 세로로 배열한다. 시간·수치·단위의 결합된 VoiceOver 의미는 유지한다.
- 호흡 장애의 재현 데이터는 DEBUG·Simulator·명시적인 UI 테스트·mock·해당 category 인자가 모두 있을 때만 사용한다. 정상 HealthKit 권한 확인과 조회는 그대로이며, 고정 표본은 반개구간 `[start, end)` 밖에서 반환하지 않는다.
- T06에서 도입한 준비 hook을 T07도 override하여 정확한 `all-data-screen-hrv`를 확인한다. 공통 기본 탭 확인, orientation, strict audit와 모든 기존 본문 assertion은 보존한다.

부모 #879가 머지된 뒤 브랜치를 삭제하면서 #880이 자동으로 닫힌 사건은 원래 시각·원인과 함께 보존했다. 이미 머지된 부모 tip의 참조를 임시 복원하고 기존 #880을 다시 열어 main을 기준으로 바꾼 뒤, 이전 기준에 열린 의존 PR이 없고 참조가 예상 tip인지 확인해 임시 참조를 정리했다. 새 PR로 이력을 대체하거나 source ref를 강제로 덮어쓰지 않았다.

## 검증과 범위

| 증거 | 실제 범위 |
|---|---|
| 과거 Phone 원본·개편 행렬 | 각각 한 메서드가 16개 분류를 확인했다. 16개 테스트로 계산하지 않는다. 원본 상태 4개와 개편 상태·실제 진입 6개도 별도로 통과했다. |
| 큰 글씨 | 과거 Phone 한 메서드가 온도·VO₂ 두 분류의 어두운 최대 글씨와 실제 하위 frame을 확인했다. 다른 모든 분류·기기의 최대 글씨로 확대하지 않는다. |
| 과거 iPad·unit | iPad의 16개 분류 행렬 한 메서드와 관련 BreathingDisturbanceTests 11개 통과 기록을 변경 없는 소스 범위에서 재사용한다. |
| 새 Duo 접힘 | `e2759822`에서 제한된 HRV ready/empty 한 메서드 통과. 0°·활성 LCD와 strict PNG/AX 4쌍의 ACK를 확인했다. 초기 75ms, 제한 안내와 실제 빈 상태를 직접 검토했다. |
| 새 Duo 펼침 | 같은 소스에서 수면 보고 날짜·실제 시작 시각 한 메서드 통과. 180°·활성 LCD-1과 strict 3쌍의 ACK, 01:00·7h46min 표기를 확인했다. |
| 소스·빌드 | 공개 `95f5bc59`의 T07 제품·단위·UI 소스는 동결 검증 후보와 동일하며 두 새 UI 실행이 앱·UI target 컴파일을 포함한다. 병합은 T05·T06·main 입력과 등록을 보존했다. |
| 리뷰 | 보안·성능·구조·데이터·단순성의 독립 5개 검토와 SwiftUI·Apple UX·최종 품질 관점에서 새 P1/P2/P3가 없었다. |

[실제 비교 갤러리](../../design/full-redesign-map/review/t07-all-data-native-2026-11-02/index.html)는 과거 Phone의 16개 대응 쌍과 기기별 출처를 구분한다. canonical 원본은 Phone·Duo 접힘에서 HRV, iPad·Duo 펼침에서 Sleep이므로 같은 기기 안의 category를 맞춘다. 과거 전체 수집의 dirty global 출처를 개별 소스·기기·자세 검증으로 바꾸지 않는다. 오래된 펼침 PNG의 EXIF 방향은 표시에서 존중하고 원본 bytes는 보존한다.

이 PR의 새로운 원격 CI 실행은 없었다. 기존 stacked base 밖으로 push한 뒤 base를 편집한 이벤트는 현재 workflow에서 실행을 시작하지 않으므로 CI 통과로 표시하지 않는다. 실제 native 컴파일과 변경 없는 관련 unit·Phone/iPad 기록의 소스 동등성을 근거로 필요한 검증만 사용했다. 필수 원격 검사가 설정돼 있다면 이 근거로 보호를 우회할 수 없다. 별도 전체 회귀·Watch·Vision·모든 언어/상태를 검사했다는 뜻이 아니다.

## Prevention

- 기존 단위·날짜·시간·빈 상태와 실제 조회를 먼저 대응시킨 뒤 화면 위계만 바꾼다.
- 큰 글씨에서는 원래 정보를 숨기는 대신 세로로 배열한다.
- 과거 이미지·새 이미지·원래 실패와 수정 후 통과를 출처별로 분리한다.
- stacked PR은 부모를 머지한 후 의존 PR의 기준을 main으로 바꾸고, 그 다음 부모 브랜치를 삭제한다. base 편집이 CI 실행 이벤트인지 별도로 확인한다.
- 원래 카테고리가 다른 기존 그림을 새 화면의 비교 이미지로 붙이지 않는다.

## Lessons Learned

시각 강조와 데이터 계약을 분리하면 새로운 장식 때문에 실제 이력 의미를 바꾸지 않을 수 있다. 재사용한 검증은 소스와 상태의 동등성으로 뒷받침하고, 원격 실행이 없거나 확인하지 않은 범위는 그대로 명시해야 한다.
