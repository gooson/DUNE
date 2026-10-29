# Cardio Atlas 네이티브 화면 검증

현재 상태: 최종 UI 검증과 캡처 수집 차단. 이 문서는 네이티브 구현의 검증 대상을 기록하며 브라우저 시안을 실제 화면으로 사용하지 않는다.

## 영향 화면

- W27 로컬 유산소 상세, W28 HealthKit 운동 상세: 기존 분석과 제목 편집을 보존하고 Atlas 구역 추가.
- CA01 실제 경로, CA02 실내 장소, CA03 Journey, CA04 Passport.
- CA05 Atlas 공유, CA06 Pace Ribbon, CA07 Signature, CA08 위치 없는 상태.
- A01 최근 운동 및 운동 목록: HealthKit 대응 항목이 없는 세트 없는 로컬 유산소 행.
- Watch는 위치 수집·저장 서비스만 바뀌며 화면 배치·문구 변화가 없어 화면 재촬영 대상에서 제외한다.

## 기기·상태

| 기기 | 상태 | 현재 결과 |
|---|---|---|
| iPhone 18 Pro | 기본 글씨 | 테스트 시작 전 무응답. 전용 기기 종료 후 재검증도 preflight에서 기기 사용 불가로 종료 |
| iPhone 18 Pro | 한국어 최대 접근성 글씨 | Activity 진입의 AX 질의가 5분 실행 한도를 넘어 Atlas 진입·캡처 미완료 |
| iPad Pro 13-inch | 기본 글씨 | 미실행 |
| Duo 외부 | 접힘 0° | 미실행 |
| Duo 내부 | 펼침 180° | 미실행 |

첫 실행의 수정 전 진단 PNG와 기존 실제 화면 인덱스는 최신 구현의 완료 증거로 재사용하지 않는다. 최종 PNG를 확보한 상태만 출처·테스트 결과와 함께 이 갤러리에 추가한다.

[기능 구현 및 검증 기록](../../../../reviews/2026-10-29-cardio-atlas/README.md) · [레이아웃 계약](../../../layout-map/cardio-atlas-integrated-proposal.md) · [승인된 브라우저 시안](../../../theme-map/themes/dune-cardio-atlas-integrated.html)

재개 조건: 소유권을 확인한 전용 기기가 안정적으로 조회·부팅되고 AX 질의가 응답하는 환경. 아직 실행하지 않은 iPad·Duo를 완료로 표시하지 않는다. 다른 작업이 사용하는 시뮬레이터나 전역 CoreSimulator 서비스를 종료하지 않았다.
