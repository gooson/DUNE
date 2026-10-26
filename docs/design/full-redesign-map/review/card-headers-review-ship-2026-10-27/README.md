---
tags: [card-navigation, disclosure, design-map]
date: 2026-10-27
category: review
status: reviewed
---

# 카드 헤더 후속 실제 검증 · 2026-10-27

[새 XCTest 원본 12장](index.html) · [출처와 해시](manifest.json)

전용 iPhone `02CE1F65-F721-44A3-9BBF-523AE138F678`, 한국어·밝음·기본 글씨·Desert Warm에서 네 탭의 초기 viewport, 실제 누른 헤더, 열린 상세를 새로 촬영했다. T03 회복·수면, A01 근육 지도, H01 수면 예측, L01 주간 보고서가 대상이다. 테스트 fixture 값이며 실제 사용자 건강 기록이 아니다.

관련 UI는 6개 실행·6개 통과·0실패로 정상 종료했다. 네 헤더의 오른쪽 빈 영역 터치→기존 목적지 4건, 최대 접근성 글씨 훈련량 카드→상세, 준비도 히어로 기록→기존 상세를 검사했다. 최대 글씨 테스트는 화면 첨부 없이 assertion으로 확인했다. XCTest의 `DUNE_VISUAL_AUDIT_STATIC=1`로 애니메이션을 끄고 실행했다.

이전 900초 종료 기록은 별도의 실패 이력으로 유지한다. 전용 기기 재부팅 후 설치·직접 실행이 복구됐다는 근거로 한 번 재개한 결과다. SDK 버전 경고는 이번에도 있었지만 테스트가 정상 종료됐으므로 이전 정체의 확정 원인으로 주장하지 않는다.

앱 소스는 `f92af99a` 이후 바뀌지 않았다. 후속 테스트 수정은 삭제된 준비도 footer 대신 기존 히어로 헤더를 검증한다. 전체 회귀와 모든 하단 카드, 어두움·다른 테마·수면 부채 양수/10시간 초과는 이 6개 검사의 범위가 아니다. 이전 캡처를 이 상태들의 완료 증거로 사용하지 않는다.


## 추가 기기 실제 캡처

iPad 전용 `017D4D66-71CC-455F-AA79-D1A07A494A74`와 Duo 전용 `EE2058F4-D910-4CF1-A453-DFAF5F16768D`에서 T03/A01/H01/L01 대표 viewport를 각각 새로 캡처했다. [추가 출처](additional-device-captures.json)의 12장은 수정하지 않은 native PNG이고 비교 보드 3장은 축소 파생본이다. 앱은 위 UI 테스트가 빌드한 동일 바이너리다. 기본 글씨·한국어·밝음·Desert Warm만 확인했다. iPad T03에서 수면 링도 보인다. 화면 아래에 있는 카드의 새 모습이나 조작은 이 viewport로 증명하지 않는다.

Duo 외부 LCD와 내부 LCD-1은 각 수집 전후의 공식 `device info displays` 결과를 저장했다. 핀한 hinge source `7acb090dd7d28fb0aea8e1907211ceff15aa450e`의 helper를 검토·빌드해 전용 기기에서만 사용했다. 기존 소스의 각도 조회 `device motion hinge-angle`은 현재 CLI에서 지원되지 않는다. `device --help`, `device simulate --help`에도 대체 힌지 조회가 없어 물리 각도는 미검증이다. 최초 내부 캡처 시도는 설치 후 활성 LCD가 바뀌어 assertion에서 중단했고, 확인된 외부 LCD를 먼저 수집한 다음 실제 내부 활성 readback을 얻은 뒤 내부를 수집했다. setter 성공 응답만으로 성공 표시하지 않았다.

내부 PNG는 2853×2007, 외부는 1398×2034이다. 공식 orientation 정보와 원본 viewport의 가로/세로 표현이 일치하지 않아 회전 검증으로 사용하지 않는다. 해당 스크린샷은 **현재 활성 패널의 앱 배치**만 증명한다. Duo 자세 전환·입력 보존·fresh XCTest AX 검증은 실행하지 않았다. 모든 하단 카드, 수면 부채 양수·10시간 초과, 어두움·다른 테마·추가 큰 글씨 캡처는 미갱신이다. Watch는 이 View를 사용하지 않는다.
