---
tags: [design, dashboard, actual-capture, spacing]
date: 2026-10-24
category: design
status: implemented-pending-device-validation
---

# Today 보조 카드 수정 후 실제 화면

[새 실제 화면 6장](index.html) · [캡처 출처](capture-index.json) · [구현 계획](../../../../plans/2026-10-24-today-support-card-fidelity.md)

제품 소스 `29e54f9a`를 빌드한 전용 iPhone 18 Pro에서 촬영했다. XCTest의 명시된 mock 자료로 실행한 실제 SwiftUI PNG이며 HTML 시안·합성 이미지가 아니다. 밝음·어두움 각각 진행·브리핑 상단과 회복·수면, 최대 접근성 글씨의 진행 타일 두 영역을 보존했다. 스크롤 위치가 달라 하나의 이어진 화면으로 합성하지 않았다. 브리핑 전체를 한 PNG에 담지는 않았으며 회복 캡처 상단에서 하단 행동을 볼 수 있다.

전용 기기 UDID는 `B52BB289-B70B-46C6-9E57-C6C0D5D11D60`이다. 기기 이름·캡처 시각·실제 테스트·결과 번들은 인덱스에 보존한다. 제품 소스는 해당 커밋과 같고, 최초 검토 문서가 미추적 상태여서 전체 worktree의 dirty 여부는 true로 기록했다.

## 확인

- `TodaySupportCardsUITests/testDesertTodaySupportCardsAtBothAppearances`: 통과. 같은 폭의 두 타일, 텍스트·목표가 타일 안에 있는지, 세 카드의 좌우 정렬, 회복 카드와 차트의 화면 내 배치를 검사했다.
- `TodaySupportCardsUITests/testDesertTodayProgressAtMaximumAccessibilityTextSize`: 통과. 타일 세로 배치·겹침·글자·가로 경계를 확인했다.
- 두 테스트 실행, 두 테스트 통과, 실패 0. 실행 로그는 `.codex-checks/today-support-ui-v2.log`, 결과 집계는 같은 경로의 `.result.json`이다.
- 육안으로 밝음·어두움의 수면 10 눈금 전체와 날짜 범위, 지난 수면 요약·단계 타임라인, 보조 표면·모서리와 내부 여백을 확인했다. 최대 글씨에서는 목표가 줄바꿈하고 타일이 쌓인다.

## 남은 검증

iPad·Duo 접힘/펼침의 이번 T03 변경은 새 캡처 미완료다. 기존 Duo 펼침 Today의 보류를 해제하지 않는다. 추가 단위 검사 두 개는 저장소 공통 시뮬레이터 잠금을 다른 실행이 점유해 60초 후 시작 전에 중단됐다. 잠금이 해제된 후 동일 최종 소스·선택 범위로 재개해야 한다. 이를 테스트 실패나 통과로 바꾸지 않는다. iPhone UI 결과를 다른 기기·모든 상태의 통과로 사용하지 않는다.

첫 캡처 실행은 커밋 훅 정리가 활성 로그를 삭제해 중단했다. 최종 실행은 로그를 `.codex-checks/`에 보존하고 완료 후 추출했다. 초기 pre-commit 빌드는 새 Swift 파일이 아직 프로젝트에 생성되지 않아 실패했으며 재생성 후 최종 UI 통합 빌드에서 해결됐다. 동일한 환경 실패를 반복 실행하지 않았다.
