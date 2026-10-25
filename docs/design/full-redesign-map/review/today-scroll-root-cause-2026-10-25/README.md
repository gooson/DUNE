# Today 스크롤 수정 검증 — 2026-10-25

[실제 화면 갤러리](index.html) · [소스·캡처 manifest](manifest.json) · [원인과 해결책](../../../../solutions/performance/2026-10-24-today-scroll-root-cause.md)

## 적용 소스와 범위

- 앱·테스트 소스: `ef42c58ef8d5ae03eb43c45e5266a8c65c487dd6`. 최신 main `6359129e` 통합 후 검증했다. 후속 커밋은 문서·캡처·잘못 갱신했던 기존 보드 복구이며, manifest의 SHA-256으로 소스 동일성을 확인한다.
- iPhone18ProMax/iOS27.0: UI10/10. manual/full/partial 복귀, 실제 held/no-hold 새로고침, 탭 재선택, metric Done/reopen/All Data, QA 열기, 탭 round-trip, Activity refresh.
- iPad13M5/iOS27.0: UI4/4. manual/full 복귀, metric 경로, QA 열기.
- Duo/iOS27.1: 외부 화면2/2, 내부 화면2/2. manual 복귀와 metric 경로. 내부 화면 캡처만 같은 manual 테스트를 추가1회 실행해 통과했다.
- 정상 pre-commit의 iOS generic build 성공. 순수 coordinator 소스·테스트와 바이트가 같은 Foundation macOS host Swift Testing4/4 성공. iOS unit/full suite 성공으로 확대하지 않는다.
- 고정 fixture·기본 글씨·밝은 화면 범위다. 실제 HealthKit 조회 성공, 모든 테마·VoiceOver·물리 기기, QA 닫기나 새로고침 중 화면 이탈의 UI 검증은 포함하지 않는다.

## 실제 화면 출처

각 PNG는 변형하지 않은 원본이다. iPhone·iPad·Duo 외부는 XCTest 첨부, Duo 내부는 활성 디스플레이3에 대한 `simctl io ... screenshot --display=3` 결과다. 내부 화면의 XCTest 첨부는 전부 검게 저장되어 `evidence/duo-open-xctest-black.png`로 보존하고 갤러리 증거에서 제외했다. 추가 통과 테스트의 initial/settled attachment 로그 직후 직접 캡처한 시각·명령은 `evidence/duo-open-native-captures.json`에 있다. 캡처가 다음 짧은 pull 입력과 근접할 수 있으므로 정확한 XCTest 첨부와 동일 프레임이라고 주장하지 않는다.

`devicectl651.13.5`는 기존 `device motion hinge-angle` 명령을 제공하지 않는다. helper7acb090의 close/open 입력 후 공식 `device info displays`로 외부1(1398×2034) / 내부3(2007×2853, rot90)의 활성화를 확인했다. 각도 값 자체의 readback은 하지 못했다. 내부 native PNG는2853×2007 가로 화면이다. 첫 bootstatus의 Data Migration Failed 문구도 있었으나 이후 Booted 상태와 실제 앱 테스트4건의 성공으로 실행 가능 상태를 확인했다.

이전 일반 인덱스는 다른 UDID와 검증 이력을 가지므로 덮어쓰지 않는다. 이 갤러리가 이번 소스의 범위별 근거다. 정적 PNG는 모든 애니메이션 프레임의 부드러움을 인증하지 않는다. inspector 격리의 AX 위치 로그, native trace 분석, 원래 실패했던 회귀 검사를 함께 사용했다.

## 리뷰

| 관점 | 도입된 P1/P2/P3 |
|---|---|
| Security | 0/0/0 |
| Performance | 0/0/0 |
| Architecture | 0/0/0 |
| Data Integrity | 0/0/0 |
| Simplicity | 0/0/0 |
| SwiftUI | 0/0/0 |
| Apple UX | 0/0/0 |
| App quality | 0/0/0 |
| Pre-ship PR reviewer | 0/0/0 |

별도 reviewer 프로세스가 각각 실행됐다. 리뷰 당시 pending으로 표시한 통합 실행·Duo 내부 캡처는 최종 영수증과 갤러리로 완료를 확인했다. Agent-Native는 agent 파일 변경이 없어서, perf-optimizer는 대량 데이터 처리 변경이 없어서 제외했다. Localization은 기존 Done 이동뿐이며 번역을 유지한다. 리뷰 기록은 `evidence/review-findings.json` 및 역할별 텍스트에 보존한다. 전역 CLAUDE/규칙 변경은 하지 않았다. 이 결함의 재현 조건과 예방은 연결한 solution 문서로 충분하며 모든 inspector 배치를 금지하는 일반 규칙으로 확대하지 않는다.

## 직접 확인

1. Today에서 아래로 깊게 이동한 뒤 다시 맨 위로 돌아온다. 큰 제목 아래 첫 카드가 초기 간격을 유지해야 한다.
2. 상단 근처에서 조금 올렸다 내리고 손을 뗀다. 사용자가 멈춘 위치를 갑자기 맨 위로 바꾸지 않아야 한다.
3. 실제 pull-to-refresh 뒤 다시 스크롤하고 Today 탭을 재선택한다. 새로고침은 정상 종료되고 명시적 재선택은 상단으로 이동해야 한다.
4. 수면 지표 → Done → 다시 열기 → All Data를 확인한다. iPad와 Duo 내부에서는 옆 패널에서도 동일 경로가 동작해야 한다.
