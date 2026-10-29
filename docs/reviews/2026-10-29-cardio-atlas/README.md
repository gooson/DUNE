# Cardio Atlas 검증 기록

상태: 코드 구현·집중 단위 검증 완료. 최종 네이티브 UI 게이트는 환경 장애로 미완료. 브라우저 시안과 실제 앱 화면은 구분한다.

## 구현 범위

- 실외 실제 경로, 실내·고정형 운동의 선택 장소, 없는 위치의 빈 상태.
- Atlas / Pace Ribbon / Signature 공유, 위치 기본 제외, 경로 양끝 300 m 숨김, 저니·패스포트 선택.
- 실제 종목별 이력의 거리·시간 목표와 거리·시간·횟수 업적. 계단·레벨을 거리로 만들지 않는다.
- 별도 `WorkoutLocationRecord`와 V20 추가 마이그레이션, 로컬·HealthKit 연결 ID.
- iPhone·DUNE Watch 실외 경로 수집과 중단 구간 분리. Watch 실제 HK 저장 후 별도 제한 작업으로 경로 저장.
- HealthKit에 대응하는 항목이 없어도 세트 없는 로컬 유산소를 두 목록에서 열 수 있다.

## 코드 검토

앱 변경 diff가 2,000줄을 초과해 review 스킬의 대규모 diff 규칙에 따라 부모가 폴더별로 다섯 관점을 검토했다. SwiftUI, Apple UX, 성능, 앱 품질 게이트의 독립 검토를 함께 수행했다. 에이전트·프롬프트 변경이 없어 Agent-Native는 해당 스킬의 조건에 따라 제외했다.

| 관점 | 확인·해소 내용 |
|---|---|
| Security | 좌표·시간·정확도·용량 검증, 위치 제외 시 지형·경로·장소 모두 제거. 이미지 게시 입력 키가 현재 설정과 일치할 때만 지도·내보내기를 공개해 이전 위치 이미지가 남는 구간을 막는다. |
| Data integrity | V19 모델을 바꾸지 않고 별도 V20 모델 추가. 운동과 메타데이터 저장·삭제 연결. HK 삭제 실패의 Watch 대체 경로도 로컬 위치를 함께 정리. 정확한 연결 ID가 다른 Watch 항목을 시간 유사성으로 지우지 않는다. |
| Architecture | Domain은 순수 값·계산, Data는 위치·HealthKit·저장, View는 모델 변경. 기존 두 상세의 분석·제목 편집을 보존하고 독립 Atlas 구역을 삽입. |
| Performance | 경로 4,000점 제한, 이력·위치 입력 변경 시 계산, 목표 변경은 O(1), Pace 선택에서만 속도 범위 계산. |
| Simplicity | 단일 상세 + 공유 스타일 + 두 진행 화면. 실제 측정하지 않은 길·영토 업적과 가상 거리 생성 제외. |

독립 검토에서 발견한 실내 실측 경로 삭제, 로딩 중 빈 상태, 장소 저장 실패 후 입력 손실, 이미지 실패 무응답, 내보내기 환경 누락, 1초 GPS의 Pace 비활성, 위치 삭제 누락, 다른 Watch ID 소실, Watch 취소 후 작업 객체 유지 문제를 해소했다. Watch 실제 HK 콜백은 취소 시 한 번만 재개되는 gate를 사용한다. 임의의 비협조적 테스트 writer 내부 프레임까지 강제로 종료한다는 의미는 아니다.

최종 `pr-reviewer`의 변경분 재검토에서도 조치가 필요한 P1/P2는 없었다. 이 판정은 코드 검토이며 진행 중인 UI 게이트 통과를 뜻하지 않는다.

## 확인된 실행

| 검증 | 결과·근거 |
|---|---|
| iOS·Watch 네이티브 빌드 | 표준 build-ios 최초 MainActor 오류 수정 후 성공. 이후 변경도 단위/UI 대상 빌드로 검증. |
| 핵심 단위 | 73개 / 10개 suite 통과. `.codex-checks/cardio-atlas/unit-verified.log` |
| 목록·ID 회귀 | 31개 / 5개 suite 통과. `.codex-checks/cardio-atlas/unit-list-visibility-retry.log` |
| Watch 새 경로 | `Watch workout routes` 12개 통과. `.codex-checks/cardio-atlas/watch-unit.log` |
| Watch 전체 단위 | 209개 실행 중 기존 Running voice feedback의 언어 고정 기대값에서 21개 assertion issue. 변경하지 않은 음성 로직은 별도 범위로 기록. |
| 첫 iPhone UI | Activity 기본 진입·HealthKit 상세 통과. 실내 실제 지도 PNG 확보. 상위 식별자 상속으로 실내 검사 실패, 대형 글씨의 재기동에서 AX 응답 정체로 이후 중단. |
| 수정 후 큰 글씨 UI | 단일 기동 뒤 Activity의 기존 `activity-recent-seeall` 진입에서 AX 질의가 지연되어 테스트 5분 한도 초과. Atlas 진입·큰 글씨 배치 검증은 미완료. 결과 기록도 정체되어 확인된 해당 실행만 종료. |
| 수정 후 기본 크기 UI·캡처 | 분리 실행은 테스트 시작 전 무응답 180초로 종료. 전용 iPhone·Watch 종료 성공 뒤 한 번 복구 검증했으나 preflight에서 기기 사용 불가로 종료. 추가 반복하지 않음. |

전체 iOS 단위 시도에서는 기존 AI 평가 `AIFeatureEvaluationTests.swift:193`의 의료 안전 0/3 기대값 문제가 발생했다. 해당 AI 소스는 변경하지 않았고, 관련 집중 검증으로 범위를 확정했다. 분류기의 iOS/Watch full 권고는 보존하되 사용자 명시 요청 없는 전체 UI 실행을 제한하는 Codex adapter를 적용했다.

## 실제 화면과 남은 확인

[최종 실제 화면 검증 상태](../../design/full-redesign-map/review/cardio-atlas-2026-10-29/index.html)에 미완료 화면·기기·재개 조건을 등록했다. UI 게이트가 통과하지 않아 Ship와 PR 머지는 진행하지 않았다. 이전 시안 PNG나 실패 실행 PNG를 새 구현의 완료 근거로 재사용하지 않는다.

실제 기기의 GPS 수신·권한 선택, Apple Health 경로 동기화 지연, CloudKit 다른 기기 동기화는 시뮬레이터 결과만으로 확인했다고 주장하지 않는다. 실내 계단 이탈 감지의 기존 위치 권한 동작은 유지하며 새 경로 수집기는 실외 유산소에서만 시작한다.
