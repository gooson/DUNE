# R08 · 준비도 근거 부족 상태 native evidence

8 native captures linked to passed XCTest cases were copied without altering the historical per-device map. Every device, selector, artifact, original image name, SHA-256, and dimension is in [evidence.json](evidence.json).

- Source revision: `09afc8f23f743768c82730672f4e2abefa7de052`; build revision: `47781c2d49de3f1c1ea54aef44a457ea8bb99b20,9d56a10d504b9970029186331187604a962cf472,dfea466897aefd82e290e29b81531b027a2b2258,0a266b6ad3dedb4b8cb2e990f9e27cb77a54a871`; combined build: `true`.
- Fixture: `A01 준비도 근거 일부 및 없음`; locale: `화면별 테스트 언어`; appearance: `화면별 테스트 설정`.
- Visual inspection recorded in evidence.json: 원본 화면 검토 완료 · 근거 일부 상태에는 Recovery가 표시되고, 근거 없음 상태에는 점수 대신 안내가 보인다. 빈 기록 테스트 기기에서는 권한 확인 안내도 함께 보인다. iPad mini 실기기 캡처: 부분 입력은 점수 없이 Available Data와 Recovery를 표시한다. 무입력은 Need More Data로 표시되지만 상단에 HealthKit 권한 오류 배너가 겹쳐 별도 원인 확인이 필요하다. Duo 접힘 LCD 1398×2034 원본: 부분 입력은 점수 없이 Available Data/Recovery를, 무입력은 Need More Data를 표시한다. 무입력에서는 기존 활동 오류 분류로 HealthKit 권한 배너가 readiness 제목 상단을 덮는다. 펼친 Duo의 준비도 카드에 Need More Data가 보이고 점수는 표시되지 않는다. 펼친 Duo의 준비도 카드에 추가 기록 안내와 Available Data, Recovery가 보인다.
- Unverified devices: none. Uncaptured named states: none.
- This scope does not imply other devices, text sizes, languages, or states.
