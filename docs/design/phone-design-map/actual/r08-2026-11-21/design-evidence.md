# R08 native design evidence

XCTest manifest에 연결된 개별 성공 receipt와 정확한 selector·첨부 이름으로 8개 PNG를 수집했다. PNG는 실제 화면 첨부 원본이다. 육안 검토: 원본 화면 검토 완료.

- Source revision: `09afc8f23f743768c82730672f4e2abefa7de052`; build revision: `47781c2d49de3f1c1ea54aef44a457ea8bb99b20,9d56a10d504b9970029186331187604a962cf472,dfea466897aefd82e290e29b81531b027a2b2258,0a266b6ad3dedb4b8cb2e990f9e27cb77a54a871`.
- Combined build: `true`. Combined build: feature-specific source attribution requires separate verification. 기능별 PR의 변경을 합친 검증 빌드에서 촬영했습니다. 각 이미지의 정확한 빌드와 실행 근거는 evidence.json에 있습니다.
- Fixture: `A01 준비도 근거 일부 및 없음`; locale: `화면별 테스트 언어`; appearance: `화면별 테스트 설정`.
- Unverified devices: none by device; states still require review; screen IDs: none by screen ID.
- Uncaptured named states: none by named artifact. Other states not present in evidence.json are unverified.
- Per-asset selector, device, timestamp, SHA-256 and dimensions: `evidence.json`.

## 원본 화면 검토

- 근거 일부 상태에는 Recovery가 표시되고, 근거 없음 상태에는 점수 대신 안내가 보인다. 빈 기록 테스트 기기에서는 권한 확인 안내도 함께 보인다.
- iPad mini 실기기 캡처: 부분 입력은 점수 없이 Available Data와 Recovery를 표시한다. 무입력은 Need More Data로 표시되지만 상단에 HealthKit 권한 오류 배너가 겹쳐 별도 원인 확인이 필요하다.
- Duo 접힘 LCD 1398×2034 원본: 부분 입력은 점수 없이 Available Data/Recovery를, 무입력은 Need More Data를 표시한다. 무입력에서는 기존 활동 오류 분류로 HealthKit 권한 배너가 readiness 제목 상단을 덮는다.
- 펼친 Duo의 준비도 카드에 Need More Data가 보이고 점수는 표시되지 않는다.
- 펼친 Duo의 준비도 카드에 추가 기록 안내와 Available Data, Recovery가 보인다.
