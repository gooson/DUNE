# 운동명·계단 분류 전수 검토 · 2026-10-30

## 변경

- HealthKit 수정 제목 캐시에 backfill된 `Running`/`Stair Climbing` 같은 정확한 일반 종목명이 번역을 건너뛰던 경로를 목록·상세·공통 summary에서 수정했다. 문자열을 부분 검색해 사용자 제목을 일반 이름으로 바꾸지 않는다. `Bench Press`, `My Running Intervals`, 인터벌 등 사용자 세부 제목과 저장된 캐시 원문은 보존한다.
- 계단 기구는 **천국의 계단 / Stair Climber / ステアクライマー**, 실제 계단은 **계단 오르기 / Stairs / 階段昇降**로 구분한다. 내부 `stairClimbing`↔HK44와 과거 이름 `stairStepper`↔HK68, 영어 typeName과 모든 rawValue를 유지한다. 기존 `Stair Stepper` 문자열 키는 호환 키로 유지하고 표시 번역만 고친다. 근거는 [Apple 기구 운동](https://developer.apple.com/documentation/healthkit/hkworkoutactivitytype/stairclimbing)과 [실제 계단 운동](https://developer.apple.com/documentation/healthkit/hkworkoutactivitytype/stairs) 정의다. 옛 한글 기구 이름은 실제 활동 코드가 기구일 때만 새 기구 레이블로 표시한다.
- 라이브러리 `running`의 표시를 달리기로 통일하고 러닝 검색어는 별칭으로 보존했다. `stair-climber`는 천국의 계단으로 표시하며 스텝 클라이머·스텝밀·StairMaster 등 기존 별칭을 유지한다. Rowing Machine·Stationary Bike 같은 구체적 기구 운동명은 일반 유산소 이름으로 뭉개지 않는다.
- 레거시 수동 기록은 이름 추론 전에 정확한 저장 rawValue를 우선해 실제 계단 코드가 기구로 추론되지 않게 한다. `other` 등 알려진 기본 코드도 일반 이름으로 표시한다.
- 예전 변형 ID 마이그레이션은 모든 조회를 성공한 뒤 변환하고 저장 성공 후에만 기존 완료 플래그를 설정한다. 저장 실패 뒤 메모리에 이미 변환이 남은 재시도도 0건 변경이라고 저장을 생략하지 않는다. 템플릿 항목 UUID를 보존한다. 완료 플래그 초기화·새 스키마·새 데이터 마이그레이션 버전은 없다.

## 전수 검사와 보존 범위

[82종 전체 이름 대응표](evidence/activity-name-matrix.csv), [기계 검사 결과](evidence/dataset-audit.json)를 보존했다. iOS 일반 표시 키82개와 실제 Watch 소비자가 사용하는 영어 typeName 키80개 모두 ko/ja 번역이 있다. 두 개의 중복 영어 이름 Strength/Dance는 실제 활동 subtype을 우선한다. 운동 정의133개는 ID와 순서가 그대로이며 이름·별칭1086개에서 서로 다른 운동 ID의 충돌은 없다(기존1085개에 달리기 별칭1개 추가). JSON 변경은 두 운동의 localizedName과 달리기 별칭뿐이다. HealthKit 읽기/쓰기 매핑과 SwiftData 모델·스키마는 변경하지 않았다. 개인 기기의 실제 HealthKit/CloudKit 데이터를 열거나 일괄 수정하지 않았다.

## 과거 이력

- `16a6e0e9` (2026-03-15): 일반 activity fallback이 Bench Press 같은 사용자/개별 운동명을 덮어쓰던 회귀 수정. 이번에도 exact generic match만 사용한다. `docs/solutions/healthkit/2026-03-15-localized-title-custom-name-regression.md` 참조.
- `dff64698`·`a0077a72`: stair-climber의 기구 유산소 분류와 한글 별칭 보완. 이번에 기존 종목 연결을 뒤집지 않는다.
- `6dcdabc1`·`cd54bf80` (2026-03-29): 529→133개, 변형396개 통합 및 이전 ID 호환. canonical resolver와 기존 alias를 유지한다.

## 검증 상태

실제 Foundation 도메인/표시명 파일을 그대로 복사한 macOS 패키지에서 표시명5개 테스트 정의(매개변수 포함92사례)가 통과했다. 이어 iOS에서 표시명5개와 마이그레이션4개 Swift Testing 정의(98사례), 기존·새 제목 캐시 XCTest11개가 통과했다. 전체 앱 단위 스위트를 실행하거나 통과한 것으로 확대하지 않는다. 신규 rawValue 검사와 관련 UI 결과는 아래 후속에 기록한다.

영향 화면은 A01 최근 운동, W26 운동 목록, W28 HealthKit 상세와 Watch C10/F07의 일반 종목 레이블이다. 새 실제 캡처는 통과한 기기·상태만 완료로 기록한다. iPad는 직전 검사에서 테스트 본문 진입 전 300초/124, Duo 접힘·펼침은 기존 AX/러너 기동 장애가 복구되지 않아 이번 새 캡처 미완료다. Watch는 이번 worktree에 전용 등록 기기가 없어 새 C10/F07 캡처 미수행이며 리소스 번역과 iOS 검증에 포함된 Watch 타깃 컴파일만 확인한다. 이전 PNG로 대체하지 않는다.

추가 iOS 단일 테스트에서82개 수동 저장 코드의 분류·표시와 원문 보존을 확인했다. 첫 실행은 other가 원문으로 보이는 한 건 실패 후 결과 정리 중300초/124로 종료됐고, 정확한 일반 이름 표시를 적용한 뒤 한 번 재실행해 정상 종료·통과했다. 기존20개 정의와 이1개를 합쳐 관련21개 단위 테스트 정의가 통과했다. 실패·재검증 원본은 evidence에 별도 보존한다.

첫 UI 실행은 목록의4개 이름·기구 상세 표시까지 확인한 뒤, 이 inspector 경로에 없는 제목 편집 toolbar를 테스트가 가정해 실패했다. 실제 원본/AX에서 상단 완료만 제공됨을 확인했다. 관련 없는 내비게이션을 수정하지 않고 실제 완료 복귀와 실제 계단·사용자 제목 상세를 검사하도록 테스트를 보정해1회 재실행한다. 캐시 원문 보존은 실제 iOS 단위 테스트에서 검증한다. 최초 실패 영수증을 별도 보존하며 해당 실행의 PNG를 통과 증거로 쓰지 않는다.

1차 결과: 수동 보조 제목 보완 전 iPhone UI1건이 입력 경로 보정 뒤 통과했다. 당시 원본4장은 뒤의 최신 캡처로 대체했으며 이전 실행 영수증과 소스 해시는 evidence/primary-before-secondary-*에 보존한다. [갤러리](index.html)와 [원본 출처/해시](capture-index.json), [집계 결과](evidence/validation.json)를 따른다. 캐시 원문과 종목·수치 보존은 실제 iOS 단위 검사에서 확인했다. 카탈로그 포맷/수동 추출 상태를 빌드 뒤 다시 검사했고 diff/source/PNG 해시를 확인했다. A01 최근 목록의 새 캡처는 이번 W26/W28 중심 selector에 포함하지 않아 미갱신으로 남겼다. iPad/Duo/Watch 미갱신 범위와 이유는 위 검증 상태를 따른다.

최초 통과 캡처의 수동 행에서 `strength` 일반 코드가 보조 제목으로 반복되는 경로도 발견했다. `secondaryDisplayName`으로 정확한 일반 종목명/코드는 숨기고 Bench Press 같은 별도 사용자/개별 이름은 보존한다. 기존 단일 rawValue 테스트를82종의 보조 제목 검사와 사용자 이름 보존까지 확장해 정상 종료·통과했다. 이 변경 뒤 해당 수동 행과 기존 목록/상세의 UI만 다시 검사하며 앞선 캡처를 최신 수동 행 증거로 사용하지 않는다.

최신 UI 결과: 수동 보조 제목 수정 뒤 관련2건이 모두 정상 종료·통과했다. 최신 원본은 W26 목록2장과 W28 기구/실제 계단/사용자 제목 상세3장으로 총5장이다. 앞선 구현의 PNG는 현재 갤러리에 재사용하지 않았다.

최종 동일 소스 검증: 수동 보조 이름 보완까지 포함해 세 관련 단위 suite를180초 제한으로 다시 실행하고21개 정의(매개변수 포함110사례)가 모두 정상 종료·통과했다. 최신 UI2건과5개 PNG도 동일한16개 소스/리소스/테스트 해시에서 확보했다. 전체 테스트나 다른 기기의 통과로 확대하지 않는다. 최종 native 로그와 실행 스크립트는 evidence에 보존한다.
