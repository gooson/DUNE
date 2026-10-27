---
tags: [wellness, measured-comparison, accessibility-identifier, dynamic-type, native-capture, duo, evidence-reuse]
category: testing
date: 2026-10-28
severity: important
related_files:
  - DUNE/Presentation/Wellness/WellnessBodyComparison.swift
  - DUNE/Presentation/Wellness/WellnessViewModel.swift
  - DUNE/Presentation/Wellness/WellnessView.swift
  - DUNEUITests/Visual/WellnessFlowUITests.swift
related_solutions:
  - ../performance/2026-02-28-wellness-scrollview-infinite-bounce.md
  - ../general/2026-10-22-wellness-hero-separate-destinations.md
---

# Wellness Flow: 실측 비교와 네이티브 접근성 증거

## Problem

Today Compact·Activity Flow와 맞춘 Wellness 시안을 실제 앱으로 옮기면서, 큰 숫자·비교·새 카드의 의미와 실행 증거를 함께 확인해야 했다. 브라우저 시안의 예시 수치나 캡처 이름만으로 네이티브 구현을 검증할 수 없었다.

### Symptoms and root causes

- 신체 항목의 현재 값만으로 이전 측정값/날짜를 만들 수 없었다. 오늘 날짜를 BMI 측정일로 쓰거나 정확히7일 전 기록만 요구하면 실제 관측을 잃는다.
- 건강 요약이 없는 상태에서 독립적인 부상·사진 자세·수동 입력도 root empty gate 안에 들어가 보이지 않았다.
- 복합 카드 부모의 accessibilityIdentifier가 이 SwiftUI 조합에서는 하위 행과 링크까지 덮었다. 실제 AX hierarchy에서 네 근거 행과 수면 링크가 같은 식별자를 상속했다.
- XCTest에서44pt 높이가 `43.99999999999977`로 나왔고, 자세까지 내려간 뒤 체중을 찾는 테스트가 계속 위로 swipe했다. heading의 isHittable만으로는 카드 전체를 캡처했다고 판단할 수 없었다.
- 손목 온도는 기준선 차이인데 확대된 타일에 의미 설명이 없었다. Astra가 실제 PNG와 ViewModel 원천을 대조해 찾았다.
- Duo 펼침의 canonical nativeSize는2007×2853이지만 `currentOrientation=rot90`인 실제 PNG는2853×2007이었다. 물리 orientation 조회값과 앱 viewport도 구분해야 했다.

## Solution

### Changes made

| 영역 | 변경 | 검증 |
|---|---|---|
| 비교 DTO/VM | 표시 중인 실제 최신 값/날짜를 고정하고 각 항목의40일 범위 이력에서 기준일 이하 최신 유효 관측 선택 |19개 단위 검사·2개 suite |
| Root/격리 child | 건강 empty 상태에도 부상·사진·Watch·수동 기록 유지, eager 배치와 기존 바운스 정책 보존 | records-only route와 입력 진입 |
| 카드 의미 | 관측 수면/예측 분리, 네 점수 근거, 실제 비교일과 `%p`, 손목 기준선 설명, 수면 최대 표본을 포함한 막대 범위 | 소스·native PNG·Astra 재검토 |
| AX/테스트 | 행/실제 NavigationLink에 식별자를 배치하고 화면 anchor는 제목에 한정. 반환 방향과0.5pt 측정 허용오차 명시 | 실패 사례만 수정 후 통과 |
| 넓은 화면 | 네 신체 타일의 전체 frame을 가용 viewport 안에 확인하는 별도 캡처 | 큰 viewport에서1/1 통과; 작은 화면은 해당 동시표시 검사를 skip |
| 실제 맵 | 새 H01 이미지66장과 원본 source/UDID/selector/시각/해시, host와 xcresult 출처 분리 | 선택 기기 사례57개 통과, 범위 밖 실패2개 보존 |

### Measured dates

`WellnessBodyComparison`은 현재 카드의 실제 측정일에서 달력상7일 전을 찾고 그 날짜의 끝 이전 관측 중 가장 최근 것을 선택한다. 비교일을 합성하지 않는다. 현재보다 새로운 history가 있어도 표시 중인 현재값을 바꾸지 않으며, 유효한0 변화와 비교 없음은 다르게 취급한다. 카드에서도 currentDate/value가 현재 metric과 일치하는지 확인한다. 체지방률 차이는 `%p`다.

### Capture geometry and provenance

Duo는 소유 registry·저장소 잠금·표준 runner/deadline 아래에서 한 번에 하나씩 실행했다. task-local boot wrapper는 기존 헬퍼가 요구하는 `ROOT_DIR`을 먼저 설정해야 한다. 이 누락으로 테스트 시작 전에 실패한 실행은 수정 후1회만 재시도했다.

활성 패널의 nativeSize로 capture port를 찾되, PNG 크기 검증에는 실제 display rotation을 적용한다. fresh AX의 Window 크기×pointScale가 PNG와 일치하는지도 확인한다.

```python
pixels = native_size[::-1] if rotation in ("rot90", "rot270") else native_size
assert png_size == pixels
assert all(abs(point * point_scale - pixel) <= 1
           for point, pixel in zip(actual_ax_viewport, pixels))
```

실제 외부는466×678pt, 내부는951×669pt였다. setter에는 검토한 [hinge 소스 커밋](https://github.com/artemnovichkov/hinge/tree/7acb090dd7d28fb0aea8e1907211ceff15aa450e)을 고정했다. 현재 Xcode CLI에는 힌지각 getter가 없어 actualAngle=null/angleVerified=false를 보존했다. 확인 범위는 활성 패널·viewport·실제 앱 표시와 선택 testcase이며 물리 각도/접힘 전환이 아니다. 양쪽 native PNG·ACK·fresh AX·전후 display 정보를 함께 보존하고 비활성 검은 PNG는 갤러리에서 제외했다.

원본 host 로그의 공백은 수정하지 않고 gzip으로 무손실 보관했다. archive 해시와 압축 해제한 원본 해시를 함께 기록한다. PNG는 수정하지 않는다. [실제 갤러리와 증거](../../design/full-redesign-map/review/wellness-flow-2026-10-28/README.md), [최종 리뷰](../../reviews/2026-10-28-wellness-flow.md)에 원래 실패와 후속 성공을 구분했다.

## Prevention

- 모델 날짜·단위·결측/0·기준선 의미를 시안 계약에 먼저 적고, 비교 원천과 실제 표시 날짜를 함께 검증한다.
- 새 복합 카드의 버튼 ID와 개별 근거 행을 실제 AX hierarchy에서 확인한다. 기존 `corrections-active.md`의 안정 anchor 규칙을 적용한다.
- 스크롤 목표가 보이는 것과 본문/수치가 온전히 담긴 것은 별도로 확인한다. native PNG를 열고 필요한 부분만 보완한다.
- 큰 화면 전용 동시표시 assertion은 작은 viewport에서 skip한다. 원래 UI의 자연스러운 스크롤은 유지한다.
- 같은 실패는 원인 변화 후1회만 재시도하고, source를 실행 중 동결한다. 판정기의 full 제안을 full 실행/통과로 바꾸지 않는다.
- 바뀌지 않은 데이터/단위 소스의 실제 결과는 의존성 동일성을 확인해 재사용한다. 오래된 자동 receipt를 새 결과로 덮어쓰지 않는다.
- 앱이 바뀐 상태는 새 native 캡처로 교체하고 이미지별 원래 source를 유지한다. prototype PNG는 actual 증거로 사용하지 않는다.

### Rule and TODO disposition

새 전역 교정이나 `.claude` 규칙은 추가하지 않았다. AX anchor·Query 격리·전용 기기·재시도 규칙이 이미 존재하며 이 문서에 관찰 조건과 재현 방법을 보완했다. 이 Flow의 별도 active TODO 파일은 없었고 구현 계획을 completed로 갱신했다. 미공개 API에 의존하는 기존 Apple 수면 점수 비교 TODO는 별도 범위라 유지했다.

## Lessons learned

디자인 통일성은 링과 색뿐 아니라 날짜·예측·기준선의 의미에도 적용된다. Astra의 픽셀 검토는 손목 온도 문맥을, 실제 AX/기기 검사는 식별자 상속과 캡처 범위를 드러냈다. 최종 P1/P2는0건이고 수면 캡슐 모양·좁은 타일의 긴 문구 줄바꿈·부상 메모 미리보기는 명시적 P3 절충으로 남겼다. 실제 VoiceOver, Watch 연결 상태, 모든 언어/테마, 전체 회귀와 물리 접힘 전환까지 검증한 것으로 확대하지 않는다.
