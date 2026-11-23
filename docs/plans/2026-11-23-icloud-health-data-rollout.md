---
topic: iCloud 건강 데이터 저장 범위 축소와 기존 기능 보존
tags: [icloud, cloudkit, healthkit, swiftdata, watchconnectivity, migration, app-review]
date: 2026-11-23
category: plan
status: draft
confidence: medium
related_solutions:
  - ../solutions/architecture/2026-03-03-macos-healthkit-cloud-mirror-foundation.md
  - ../solutions/general/2026-03-03-watch-template-sync-watchconnectivity-fallback.md
  - ../solutions/architecture/2026-03-07-visionos-mirror-sync-gating-and-spatial-fallback.md
related_brainstorms:
  - ../brainstorms/2026-03-03-macos-healthkit-cloud-sync-internalization.md
---

# DUNE iCloud 저장 범위 단계별 전환 계획

[출시 계획의 저장 정책 항목](2026-10-16-launch-focus-visual-redesign.md)을 세분화한다. 기준 코드는 `86ae97321`이다. 아래 항목은 모두 **실행 전**이다.

현재 기기에서 기록·조회, Watch 단독 운동 후 iPhone 합류, 이미 저장된 기록, 다른 기기에서의 조회·복원까지 보존 대상으로 잡는다. 작은 변경부터 통합하되, 대체 경로가 실제로 동작하기 전에 기존 쓰기·읽기 경로를 끊는 일은 피한다. 심사 기준은 앱이 개인 건강 정보를 iCloud에 저장하는 것을 제한한다. 각 기기가 사용자 권한으로 Apple 건강을 읽는 방식과 앱 자체 CloudKit 저장은 별도 경로다. [Apple 심사 지침 5.1.3](https://developer.apple.com/app-store/review/guidelines/#health-and-health-research) · [Apple 건강 데이터 동기화](https://www.apple.com/kr/legal/privacy/data/ko/health-app/)

## 적용과 검증의 단위

- 표 한 행이 하나의 비교 단위다. 같은 테스트 계정·기기·고정된 과거 기록을 사용해 기존 빌드 결과를 먼저 기록하고 후보 빌드에서 같은 동작을 반복한다. 기능이 바뀌는 행은 영향받는 실기기에서 합격한 뒤 통합한다. 테스트만 추가하는 행은 해당 테스트가 기존 동작을 정확하게 구분하는지 확인한다.
- 내부 검증 빌드와 사용자 배포를 구분한다. 중간 빌드에는 기존 업로드 경로가 남아 있을 수 있다. 작은 변경의 통합 성공을 심사 제출 근거로 삼는 시점은 마지막 출시에 둔다. 검증에는 앱 기능으로 만든 합성 기록과 전용 계정을 사용한다.
- 증거 한 건에는 **변경 번호·커밋·기기/OS·계정과 권한 상태·재현 동작·기대값·실측값·로그 또는 화면·판정**을 남긴다. 합격, 실패, 미실행을 구분한다. 필드마다 비교하고 허용된 차이를 적는다. 두 앱에서 같은 합계를 보거나 테스트가 한 번 성공한 것만으로 데이터 보존을 판정하기 어렵다.
- CloudKit 검증은 대상 빌드의 컨테이너·환경·사용자 private DB·zone을 맞춘다. 변경 전후의 레코드 유형, 테스트 ID, 수정 버전, 첨부 변화를 독립적으로 읽는다. 같은 실행에서 허용된 테스트 변경이 서버나 두 번째 기기에 도달하는지도 확인한다. OFF처럼 모든 쓰기를 막는 경우는 같은 환경의 별도 대조 실행으로 관측 경로를 확인한다. 내보내기 오류·지연·계정 불일치로 확인할 수 없으면 미판정이다. 신규 생성뿐 아니라 기존 레코드 갱신·지연 전송도 검사한다. [Apple의 CloudKit 동기화 진단](https://developer.apple.com/documentation/technotes/tn3163-understanding-the-synchronization-of-nspersistentcloudkitcontainer)
- 실패하면 그 행의 적용을 멈추고 직전 검증 상태에서 원인을 격리한다. 원인에 맞춘 수정 후 해당 검사만 재실행한다. 데이터 전환 이후의 복구는 검증된 로컬 원본과 전환 후 새로 작성된 기록을 모두 보존해야 한다. 이전 바이너리로 낮춰 건강 데이터 업로드를 다시 켜는 동작은 복구 절차에 넣지 않는다.

## P0 · 앱 변경 없이 비교 기준 만들기

첫 작업 묶음은 01~05와 08~10이다. 06의 Watch 기준선은 11 전에, 07의 Vision 기준선은 21 전에 확보하면 된다. 10의 OFF→ON 비교에 필요한 Mac 이력만 07에서 앞당겨 확인한다. 이후 행에서도 관련 없는 기기 검증을 앞 단계의 선행 조건으로 추가하지 않는다.

| 순서 | 한 번에 할 일 | 확인할 결과 |
|---|---|---|
| 01 | 현재 빌드와 실제 배포 상태를 식별한다. 개발·TestFlight·App Store 버전의 존재, CloudKit 환경, 업그레이드할 최소 지원 스토어를 기록한다. | 업그레이드 기준 빌드와 관측할 환경이 정해진다. 운영 사용자나 원격 전용 기록이 있는지는 확인 결과로 남긴다. |
| 02 | 스키마 14종을 쓰는 곳, 읽는 곳, Apple 건강에서 재생성 가능한 필드를 표시한다. KVS 설정, App Group 위젯 파일, 삭제한 운동 ID, 자세 첨부도 나란히 목록화한다. | 각 필드가 Apple 건강·기기 전용·일반 iCloud 설정·별도 복원 중 어디로 가는지와 소비자가 정해진다. 미분류 필드는 일반 iCloud 허용 목록에 넣지 않는다. |
| 03 | 합성 표본을 한 번 만든다. 운동 1건에 세트 2개, 무게·반복·휴식·RPE, HealthKit ID가 없는 운동 1건, 체성분과 메모, 부상, 자세 앞뒤 사진, 습관과 로그, 위치, 시간별 점수, 운동 루틴을 넣는다. | 기준표에 모델별 건수·논리 ID·값·부모/자식 연결·첨부 길이와 해시를 보관한다. 시간별 점수처럼 앱 UUID가 없는 모델도 필드별로 대조한다. |
| 04 | iPhone 한 대에서 동기화 OFF로 Today를 갱신하고 기록을 저장한다. 종료 후 두 번 실행한다. | 화면 값, 로컬 기록, 생성된 미러 수를 기록한다. 사용자에게 보이는 값과 저장소 내부 변화가 구분된다. |
| 05 | 같은 테스트 계정의 두 기기에서 OFF→ON, ON→OFF를 별도로 관찰한다. A에만 있는 기록, B에만 있는 기록, 동기화 직전 오프라인 기록을 만든다. | 현재 어떤 이력까지 늦게 전달되는지, 일반 기기 간 동기화와 Apple 건강 동기화의 차이를 관측한다. 이 결과가 이후 보존 기준이다. |
| 06 | 실물 Watch에서 iPhone과 연결한 운동 1회, 연결을 끊고 종료한 운동 1회를 각각 기록한다. 재연결 후 iPhone을 다시 연다. | 각 운동이 1건이고 모든 세트 값이 일치한다. iPhone을 보지 않고 시작한 운동, 앱 재실행, 템플릿 수정·삭제가 어느 경로로 도착했는지도 구분한다. |
| 07 | Mac에서 iPhone의 새 점수와 운동 상세를 조회한다. 지원하는 Vision 구성에서 HealthKit 직접 조회와 운동·세트 이력도 따로 확인한다. | 각 화면이 미러·운동 DB·직접 조회 중 무엇에 의존하는지, 기존 폰이 꺼진 상태에서도 어떤 기록까지 보이는지 기록한다. 해당 기기 미확보 시 종속된 전환만 보류한다. |

## P1 · 첫 코드 변경은 iCloud OFF인 iPhone 한 경로

| 순서 | 한 번에 할 일 | 실제 합격 조건 |
|---|---|---|
| 08 | iPhone의 서비스 선택에 대한 테스트를 추가한다. 기존 `MirroringSharedHealthDataServiceTests`는 백그라운드 저장 시점을 검사하지만 앱 시작 시 선택되는 경로는 검사하지 않는다. | 현재 ON/OFF, HealthKit 미지원, 시드 UI 테스트의 서비스 선택을 구별한다. 검사용 분리만 했다면 기존 동작이 변하지 않는다. |
| 09 | 후보 빌드에서 **iCloud OFF이고 HealthKit을 읽을 수 있는 iPhone**의 조회를 기존 직접 조회 서비스에 연결한다. 별도 미러 쓰기만 생략한다. 기존 DB, 점수 이력, HealthKit 미지원 분기, ON 분기는 그대로 읽을 수 있어야 한다. | 04와 같은 기기·기록에서 Today·수면·체성분과 위젯 값이 같고 새 미러가 0건이다. 건강 권한 제한·기록 없음·재실행에도 빈 결과를 과거 기록 삭제로 처리하지 않는다. |
| 10 | 09의 후보를 설치한 상태에서 OFF→ON→OFF, 앱 전경 복귀와 외부 KVS 변경을 검사한다. | 기존 행·첨부가 그대로 있고 ON 이후의 새 갱신이 기존 계약대로 도착한다. **OFF 동안 누적된 과거 스냅샷이 Mac에서 실제 이력으로 쓰였다면 09를 독립 배포하지 않는다.** 대체 조회가 완성될 때까지 적용을 늦춘다. |

09의 효과는 동기화를 끈 기기에 전송 후보가 새로 쌓이는 범위를 줄이는 데 있다. iPhone 한 대에 후보를 설치해 먼저 비교한다. 같은 앱 초기화 코드를 쓰는 iPad에도 이 분기가 적용되므로, 내부 비교에서 일반 빌드로 승격할 때에는 실물 iPad 한 대에서 09의 조회·재실행을 확인한다. 기종별 상시 분기 추가는 필요하지 않다. 이미 쌓인 미러, 동기화 ON, Watch 자체 업로드는 뒤 단계에서 별도로 확인한다. 저장소를 연 뒤 토글을 바꾸는 경우에는 이전 서비스의 대기 중 쓰기까지 확인한다.

## P2 · Watch에서 기존 직접 전송을 먼저 증명

| 순서 | 한 번에 할 일 | 실제 합격 조건 |
|---|---|---|
| 11 | 현재 Watch 템플릿 직접 전송만 검증한다. 이전에 CloudKit으로 받은 로컬 템플릿이 있는 Watch에서 iPhone이 수정·삭제한 후 재연결한다. | 이름·운동 순서가 최신이고 삭제한 루틴이 되살아나지 않는다. 실패할 때만 병합 우선순위 또는 삭제 반영을 한 변경으로 수정한다. |
| 12 | 운동 종료 전송의 경계 하나씩 재현한다. WCSession 미활성 상태, 전송 직전 연결 끊김, Watch 재실행을 각각 시도한다. | Watch에 저장된 완료 운동이 재연결 후 iPhone에 온다. 현재 즉시 전송 오류는 로그만 남기는 분기가 있어, 누락이 확인되면 **완료 운동 한 종류**에 한해 내구성 있는 재전송을 보강한다. |
| 13 | 같은 완료 이벤트를 두 번 보내고, HealthKit ID 없이 같은 시간대에 끝난 서로 다른 운동 두 건도 보낸다. | 앞의 운동은 1건, 뒤의 운동은 2건이다. 필요할 때만 생성 시 부여한 안정 ID와 수신 저장의 중복 방지를 추가한다. 구버전 payload와 삭제한 운동 재전송도 검사한다. 재전송을 보강했다면 12·13이 함께 통과해야 활성화한다. |
| 14 | 합성 기록을 둔 실물 Watch 한 대의 후보에서 **기본 건강 DB만** 로컬로 연다. 기존 기기 업그레이드와 신규 페어링을 각각 검증한다. 일반 사용자 적용은 15~18의 보존·복원 검증 뒤로 둔다. | 06·11~13이 통과하고 iPhone 설정 ON/OFF 모두 Watch DB에서 건강 레코드의 신규·갱신 업로드가 없다. Watch 단독 사용, 최근 중량, 루틴, iPhone에 들어오는 세트가 유지된다. 공통 스키마에서 iPhone이 같은 데이터를 재전송하는 문제는 22에서 별도 확인한다. |

## P3 · 저장소 전환 전, 원본과 복원 수단 확보

| 순서 | 한 번에 할 일 | 실제 합격 조건 |
|---|---|---|
| 15 | 기존 파일의 **복제본**으로 동일 스키마·동일 위치에서 로컬 전용으로 다시 여는 최소안을 시험한다. V20과 실제 지원 구버전을 대상으로 기존 앱 위에 설치한다. | 두 번째 실행까지 03의 값·관계·첨부가 동일하다. 공간 부족·잠금·스키마 문제를 주입해 원본이 보존되는지 확인한다. 기존 자동 삭제나 메모리 fallback으로 빈 상태가 뜨면 실패다. 복제는 DB가 닫힌 일관된 시점에 WAL·첨부 등 모든 구성 파일을 포함한다. |
| 16 | 이전 직전에 A의 로컬에만 있는 기록과 B 또는 private DB에만 있는 기록을 서로 다른 ID로 표시한다. 이전 버전 클라이언트가 남는 조합도 재현한다. | 소유권이 확인된 이전 경로에서 원격 전용분을 가져온 뒤 기준표와 대조할 수 있다. 옛 미러 저장소를 쓰기 가능한 상태로 다시 붙여야만 읽히는 경우는 별도 복구 설계를 먼저 검증한다. 원격 회수 실패·기기 미접속을 0건으로 간주하지 않는다. |
| 17 | 전환 중 앱 강제 종료 후 재시작, 같은 전환 두 번 실행, 다른 기기에서 수정·삭제 중 전환을 시험한다. | 누락·중복·삭제 부활·첨부 손실이 0건이다. 15의 최소안으로 보존이 입증되면 모델별 복사는 생략한다. 실패한 경우에만 새 로컬 DB로 복사하고 대조 완료 후 읽기 대상을 바꾼다. 운동–세트, 습관–로그는 같은 단위로 옮긴다. |
| 18 | **원래 폰 없는 복원**과 **Mac의 자동 최신 조회**가 05·07의 기존 기능인지 확정하고 각각의 대체 경로를 고른다. | 기존 기능인 항목은 새 기기·Mac에서 기존 폰을 끈 상태로 동일 합성 기록을 읽어야 한다. 시험용 파일이나 직접 전송만으로 자동 복원까지 합격 처리하지 않는다. 아래 대체 경로의 해당 시험이 끝나기 전에는 관련 기존 동기화를 끊지 않는다. |

### 18에서 갈리는 작업

- **Apple 건강에서 복원하는 수치**는 권한을 받은 새 iPhone·iPad에서 실제로 다시 조회한다. 건강 동기화 꺼짐, 읽기 기간 제한과 지연을 별도로 시험한다. 과거 당시 점수, 수기 메모, 세트별 중량은 각각 원본과 대조한다. HealthKit 연결 키는 우선 현재 구현을 재사용한다. 앱 전용 건강 UUID 표를 iCloud에 올리는 안은 기본 범위에서 제외한다.
- **사용자가 직접 옮기는 상세 이력**이 필요한 경우는 ① 암호화된 파일로 내보내기 ② 빈 기기에 가져오기 ③ 기존 데이터가 있는 기기에 병합 ④ 잘못된 암호·훼손 파일·가져오기 중 종료 복구로 나눠 검증한다. 03의 모든 관계·사진까지 같아야 완료다. 기존 폰이나 사전 백업이 필요하다는 제품 차이를 기록한다.
- **기존 폰 없이 자동 복원 또는 Mac의 원격 최신 조회가 필수인 경우**는 이 작업만 별도 설계한다. 예를 들어 사용자가 선택한 건강 서비스 계정으로 ① 인증·기기 등록 ② 앱 전용 운동 1건 업로드와 신규 기기 복원 ③ 동일 운동 수정·삭제 전파 ④ 첨부·다른 기록 종류를 하나씩 추가 ⑤ 폰 오프라인 상태의 Mac·새 기기 조회 ⑥ 동의 철회·계정 삭제를 각각 시험한다. 어떤 지표를 서버로 보낼지와 보존 기간도 명시한다. 가까운 기기 직접 연결로 기존 사용 조건을 만족하는 기능은 서버 대상에서 뺀다. 자동 복원을 수동 백업으로 바꾸는 결정은 기능 변경으로 남긴다.

## P4 · 일반 iCloud 저장을 작게 열고 건강 저장을 닫기

| 순서 | 한 번에 할 일 | 실제 합격 조건 |
|---|---|---|
| 19 | 건강 스토어와 분리한 일반 설정 경로에서 실제 지원하는 일반 값 **한 개**만 왕복한다. 이미 있는 동기화 설정 KVS를 대조로 활용하고, 이것으로 SwiftData 동기화 성공까지 판정하지 않는다. | A→B 값 일치, OFF 상태에서 전송 없음, 누락된 설정은 기존 기본값 유지. 참조할 건강 기록이나 날짜가 payload에 없다. |
| 20 | 운동 계획 한 종류에만 허용 필드를 추가한다. 일반 카탈로그 운동 ID, 계획 순서·목표 반복부터 시험하고 실제 세트와 분리한다. | 계획 생성·수정·삭제가 다른 기기에 반영된다. 실제 중량·최근 사용일·메모·위치·건강 UUID가 원격에 없다. 자유 입력 루틴명·커스텀 종목명·카테고리에 재활·질병명이 들어간 사례는 별도 보존 경로로 이전되고 사용자 화면에서 원래 이름이 유지되어야 한다. |
| 21 | HealthKit 직접 조회가 되는 Vision에서 미러 저장소 연결 하나만 좁힌다. 직접 조회가 불가능한 모드와 운동·세트 이력 저장소는 각각 따로 시험한다. | 대시보드·공간 창, 시뮬레이터 시드와 설정이 동작한다. 18의 대체 경로가 필요한 모드에서는 최신 상태·운동 상세가 실제로 확인된 뒤 해당 연결을 바꾼다. |
| 22 | 15~20이 통과한 내부 iPhone·iPad 빌드에서 **기본 V20 DB 한 곳**을 로컬 전용으로 연다. 원본 파일 보존이 확인된 방식만 사용한다. | ON/OFF·KVS 변경·강제 동기화·전경 복귀·재시작 뒤에도 건강 DB를 클라우드로 재연결하지 않는다. 03의 모든 행을 조회·수정할 수 있고, 원격에는 19~20의 허용 필드만 생긴다. App Intents·시간별 점수·위젯에 새 값이 들어오는지도 확인한다. |
| 23 | 18에서 입증한 대체 경로를 아래 A→B→C 순으로 하나씩 활성화한다. | 각 소비자가 이전과 같은 기록과 갱신 시각을 읽는다. 마지막 수신 시각이 계속 과거인데 최신으로 보이거나 동기화 대기가 끝나지 않으면 그 변경만 보류한다. |
| 24 | 기기 전체 iCloud 백업에 들어갈 수 있는 로컬 DB·첨부·위젯 캐시·legacy defaults를 점검한다. 재생성 가능한 캐시 하나부터, 사용자 원본은 18의 복원 검증 뒤 처리한다. | 실제 백업·복원한 전용 기기에서 포함·제외 의도와 사용자 복원 결과를 대조한다. 파일 교체 뒤에도 제외 속성을 확인한다. 시스템의 제외 속성은 보장 수단이 아니므로 확인한 범위를 기록한다. [Apple 백업 지침](https://developer.apple.com/documentation/foundation/optimizing-your-app-s-data-for-icloud-backup) |

**동기화 범위를 모델 이름으로 판단하지 않는다.** 예컨대 `ExerciseDefaultRecord`에는 사용자가 정한 값과 `lastUsedDate`가 같이 있고, `HourlyScoreSnapshot`에는 점수와 실제 HRV·안정시 심박이 같이 있다. 19~20에서는 허용 필드로 만든 별도 표현만 보낸다. 다른 기기의 커스텀 루틴·습관·기록 복원이 필요하면 18에 포함시킨다.

23의 소비자 전환은 22를 일반 배포하기 전에 내부에서 준비한다. **A.** Mac 및 HealthKit 미지원 경로를 대체 데이터로 읽도록 하고 새 iPhone 갱신 한 건과 오프라인 마지막 수신 시각을 비교한다. **B.** Vision의 운동·세트 저장소만 전환하고 예전 운동의 세트와 신규 운동 상세를 대조한다. **C.** 마지막으로 iPhone의 ON 상태에서 기존 미러 쓰기를 중단하고, 실제 지원 기기의 조회와 새 수신 시각을 다시 확인한다. 22의 로컬 전환으로 이미 앱 클라우드 쓰기가 멈춘 조합은 C에서 그 사실을 확인하고 불필요한 코드 수정을 생략한다.

## P5 · 사용자 안내, 기존 사본 정리, 제출

| 순서 | 한 번에 할 일 | 실제 합격 조건 |
|---|---|---|
| 25 | 확정한 동작에 맞춰 온보딩, 설정의 iCloud/강제 동기화, Mac 대기 화면, 개인정보처리방침과 제출 답변을 맞춘다. | 사용자가 무엇이 자동 동기화되고 무엇을 직접 복원해야 하는지 실제 동작과 일치한다. 변경된 화면과 현지화만 검사하고 해당 기기의 디자인맵을 새로 캡처한다. |
| 26 | 기존 원격 사본 정리를 전용 계정에서 먼저 시험한다. 섞인 기존 zone에서 유형·소유자·필요한 보존본을 확인하고 오프라인 구버전 기기를 다시 연결한다. | 민감한 옛 레코드·첨부만 정리되고 일반 설정과 로컬 원본은 남는다. 구버전의 재업로드·삭제 전파가 없거나 이를 처리하는 절차가 입증돼야 한다. 운영 사본 삭제는 백업·복원과 대상 확인 후 별도의 적용 결정으로 남긴다. |
| 27 | 실제 제출 후보를 기존 설치 위에 올린 경우와 신규 설치한 경우로 나눠 마지막 대조를 한다. 혼합 버전 Watch/iPhone, 동기화 OFF→ON, 이전에 원격에만 있던 기록, 두 번째 실행을 포함한다. | ① 허용 데이터는 동기화 ② 건강 데이터 신규·수정 업로드 0건 ③ 보존 약속한 데이터 누락·중복·고아 첨부 0건 ④ 기존 핵심 흐름과 원격 복원 실측 ⑤ 기존 사본 처리 상태와 미해결 회귀를 확인한 뒤 제출 여부를 정한다. |

## 영향받는 파일

| 변경 영역 | 현재 진입점 | 연관 소비자 |
|---|---|---|
| 기본 컨테이너, 런타임 교체와 Watch 수신 | [DUNEApp.swift](../../DUNE/App/DUNEApp.swift), [스키마](../../DUNE/Data/Persistence/Migration/AppSchemaVersions.swift), [복구 정책](../../DUNE/Data/Persistence/Migration/PersistentStoreRecovery.swift) | SwiftData 조회, App Intents, KVS 알림, 재시작 |
| 스냅샷, 점수, 위젯 | [미러 쓰기](../../DUNE/Data/Services/MirroringSharedHealthDataService.swift), [미러 저장](../../DUNE/Data/Services/HealthSnapshotMirrorStore.swift), [미러 읽기](../../DUNE/Data/Services/CloudMirroredSharedHealthDataService.swift), [시간별 점수](../../DUNE/Data/Services/ScoreRefreshService.swift), [위젯 파일](../../Shared/WidgetScoreData.swift) | Today, Wellness, 수면, 위젯, Mac |
| Watch 저장·전송·루틴 | [Watch 앱](../../DUNEWatch/DUNEWatchApp.swift), [Watch 송신](../../DUNEWatch/WatchConnectivityManager.swift), [폰 수신](../../DUNE/Data/WatchConnectivity/WatchSessionManager.swift), [루틴 병합](../../DUNEWatch/Helpers/WatchExerciseHelpers.swift) | 완료 운동, 세트, 최근 운동, 루틴 생성·삭제 |
| Vision의 두 저장소 | [Vision 앱](../../DUNEVision/App/DUNEVisionApp.swift), [스냅샷과 설정](../../DUNE/Data/Persistence/HealthSnapshotMirrorContainerFactory.swift), [운동 이력](../../DUNEVision/App/VisionExerciseHistoryContainerFactory.swift) | 대시보드, 공간 창, 운동 이력 |
| 모델과 복원 | [V20 모델 목록](../../DUNE/Data/Persistence/Models), [체성분 식별자](../../DUNE/Data/HealthKit/BodyCompositionWriteService.swift), [운동 삭제 표식](../../DUNE/Data/Persistence/DeletedWorkoutTombstoneStore.swift) | 세트·습관의 관계, 위치 연결, 자세 첨부, 삭제 후 재수신 |
| 동의·설정·대기 | [동의 화면](../../DUNE/Presentation/Shared/CloudSyncConsentView.swift), [설정](../../DUNE/Presentation/Settings/SettingsDetailView.swift), [대기 화면](../../DUNE/Presentation/Shared/Components/CloudSyncWaitingView.swift) | 변경 시 해당 카탈로그와 실제 화면 디자인맵 |

## 좁게 실행할 테스트

한 행에서 바뀐 동작의 selector만 표준 실행기에 준다. 아래는 실제 존재하는 자동 검사의 예다. 아직 없는 정책 선택, 재전송, 혼합 버전 전환, 클라우드 필드 검사에는 위의 실측 또는 표적 테스트를 구현 단계에서 추가한다. 물리 기기 동기화가 필요한 행에서 시뮬레이터 성공은 보조 증거다. 현재 Watch 시뮬레이터는 CloudKit을 비활성화하고 iPhone XCTest 호스트도 일반 부팅 시 CloudKit을 우회한다.

| 검사 | 실행 예 또는 실기기 관찰 |
|---|---|
| OFF 설정과 미러 읽기 | `scripts/test-unit.sh --ios-only --only-testing DUNETests/HealthSnapshotMirrorContainerFactoryTests/disablesCloudKitWhenSyncIsOff`. 08~09의 신규 분기 테스트를 별도 실행한다. |
| Watch 전송 필드·하위 호환 | `scripts/test-unit.sh --ios-only --only-testing DUNETests/WatchConnectivityMetadataTests/metadataRoundTrip --only-testing DUNETests/WatchConnectivityMetadataTests/legacyPayloadsDecode`. 전송 성공은 실물 페어의 iPhone DB와 대조한다. |
| Watch 루틴 우선순위 | `scripts/test-unit.sh --watch-only --only-testing DUNEWatchTests/WatchExerciseHelpersTests/mergedRoutineTemplatesPrefersLocal`. 11에서 편집·삭제 동작에 맞는 회귀 사례를 추가한다. |
| 디스크 재오픈 | `scripts/test-unit.sh --ios-only --only-testing DUNETests/AppSchemaTests/v19LocationMigratesAndReopens`. V20의 실제 전환과 첨부 비교는 15~17에 추가한다. |
| 위젯 및 안내 화면 | `DUNETests/WidgetScoreDataTests/loadSharedDataMigratesLegacyDefaultsIntoFile`, `DUNEUITests/TodaySettingsRegressionTests/testCloudSyncConsentEnableChoiceDismissesSheet`. 선택 UI 테스트는 시트 동작만 검증하며 실제 계정 설정은 25에서 확인한다. |

## 판단이 남는 부분

좁은 iPhone OFF 분기와 기존 Watch 전송 경로는 소스에서 확인했다. **가장 큰 불확실성은 기존 원격 전용 데이터 회수, 구버전 기기의 재업로드, 원래 폰 없이 Mac·새 기기에서 상세 이력이 복원되는지**다. 이 세 항목은 기기와 구버전 데이터로 확인해야 한다. 대체 수단이 없는 기능은 '무영향'으로 처리하지 않고 해당 전환만 보류한다.
