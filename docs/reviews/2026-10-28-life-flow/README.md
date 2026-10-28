# Life Flow 네이티브 구현 · 검증 진행 기록

기준 브랜치 `codex/life-flow`, PR base `origin/main`. 구현 소스는 `62d3c097`, 최신 main 통합은 `1b3805f6`이다. **필수 UI 게이트 미완료이며 머지하지 않는다.**

## 변경과 근거

- 104pt 링·능선·습관 메달을 사용하는 짧은 히어로, 개별 오늘 카드, 완료 접기, 오늘/주간/예정 분리, 4개 표시용 목적 필터.
- 지난 날짜 총합 입력·교체·0 표식, 입력 전 검증, 주기 미리보기, 늦은 기록 표시, 동기화 총합 해석 및 undo 충돌 방지.
- 실제 수동 실천에서 계산하는 7일·28일 시각화, 자동 목표 우선 순서, 기존 이력·완료율·주간 보고 상세 유지.
- 원래 브라우저 시안의 QA는 네이티브 검증 증거로 사용하지 않는다.

## 실행 증거

| 범위 | 결과 | 출처 |
|---|---|---|
| 최종 통합 iOS build | 성공, 실제 BUILD SUCCEEDED | ios-build-final.log.gz |
| 관련 단위 9개 suite | 113개 통과; 전체 iOS suite 아님 | unit-targeted.log.gz |
| 최초 선택 UI | 49개 실행:36통과·3skip·10실패, exit65 | ui-phone-initial.result.json / log.gz |
| 실패 Life 선택 재검증 | 7개 실행:4통과·3실패, exit65 | ui-phone-corrections.result.json / log.gz |
| 테마 맵·카탈로그 포맷 | check 통과 | 표준 builder --check / formatter --check |

넓은 unit 실행은 무관한 AI 평가 진행 중 중단됐으며 통과로 집계하지 않는다. 타깃 unit은 수정된 조회 그래프 fixture로 1회 재검증해 성공했다. source19의 UI 재검증에서 링104, 편집 이름 저장, 기본/다크/최대글씨 히어로, 빈 이름 저장 시 폼 유지가 통과했다.

## 남은 UI 항목과 재개 조건

| 항목 | 확인한 원인 | 준비한 수정 | 상태 |
|---|---|---|---|
| L07 차트 제목 AXID | 부모 chart ID가 제목·선택기·플롯에 전파됨. 실제 AX 텍스트에서 확인 | 차트 컨테이너 children contain | 같은 원인 재시도1회 소진, 추가 실행 전 사용자 예외 필요 |
| 주간/예정 소속 확인 | 화면 밖 Weekly Swim 조회 및 컨테이너 경계 불명확 | 주간/예정 AX 그룹 명시, 별도 예정 toggle ID, 각 행 스크롤 후 확인 | 수정 후 미검증 |
| 주간 비교 문구 | 한국어 기본 실행에서 영문 Last Week 조회 | 해당 검사 en/en_US 명시 | 수정 후 미검증 |

초기 공통 smoke의 Today 추세/알림 허브3건은 Life diff 외부 실패로 보존한다. 이 작업에서 Today 소스를 변경하지 않으며 최신 main 통합만 반영했다. 최신 상태에서 통과했다고 승격하지 않는다.

`.codex/skill-compat.md`는 “같은 원인에 대한 자동 재시도는 최대 1회”와 재시도 후 같은 원인이 남으면 실행 경로 중단을 요구한다. 차트 검사 경로를 다른 명령·phase·모델로 반복하지 않는다. 추가 실행 승인 시 남은3개 selector부터 확인한다.

## 실제 화면과 기기 범위

[실제 화면 갤러리](../../design/full-redesign-map/review/life-flow-2026-10-28/index.html)에는19f43ee3의 새 iPhone 캡처와 개별 테스트 결과를 기록한다. 이후 AX 수정본의 최종 캡처가 아니다. L01·L02·L07 히트맵 일부·L09 밝음 단계가 수집됐고, capture-test가 나중에 실패한 이미지는 부분 증거로 분류한다.

전용 iPhone18Pro UDID E31D1A6A-8649-4FCF-9DAE-76DD59DE0192, iOS27.0. iPad·Duo 접힘/펼침은 아직 미실행·미갱신이다. L07 완료율 및 L08/L09 어두움·최대글씨 등 누락 상태를 완료 처리하지 않는다. Watch UI는 이번 PR 변경 대상이 아니다.

## 사전 리뷰

기존 diff의 security/performance/architecture/data/simplicity와 UX/SwiftUI/app-quality/pr-reviewer 검토를 보존한다. 초기 finding은 코드 수정으로 해결했으나, 정적 해결 판정은 UI 통과를 뜻하지 않는다. 최신 delta review를 별도 보존한다. Agent Native는 지침 변경이 없어 해당 없음이다.

## 파이프라인

0 Init·1 Plan·2 Work는 완료.2.5 UI는 실패/재개 조건 대기.3 Review·3.5 Quality는 선행 정적 검토만 보존.4 Resolve는 최종 UI 확인 전.5 Compound 문서는 준비.5.5 Pre-Ship·6 Ship은 미완료. 초안 PR 생성은 검토용 산출물이며 Ship 완료가 아니다.

## 확인 경로

Life → 오늘 ±/시간 입력 → 취소 → 지난 기록에서 어제 총합 변경 → 이력의 늦은 기록 → 주간·예정 → 리듬 → 주간 보고를 확인한다. 저장 후 오늘 수치가 과거 기록으로 증가하지 않고, 잘못된 입력은 폼과 기존 기록을 보존해야 한다. 기본/다크/최대글씨와 iPad/Duo의 영향 상태는 새 실행으로 확인한다.
