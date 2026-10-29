# Cardio Atlas 네이티브 실제 화면

2026-10-29 전용 시뮬레이터에서 촬영한 [새 실제 화면](index.html) 54장입니다. [출처·해시](capture-index.json)에 원본 bundle, 사례, 소스 커밋과 실제 PNG 크기를 보존합니다. 모든 기록·좌표는 opt-in 예시 데이터입니다.

## 최종 관련 UI 검증

- iPhone 기본6/6, 공유 스타일·위치·너비1/1, 한국어 최대 접근성 글씨1/1, 최종 지도·장소 delta2/2 통과. 중복 사례를 합산하지 않습니다.
- iPad 실내 장소·경로/Journey·Passport·공유4/4 통과. 테스트의 잘못된 `activity` 재정의를 제거하고 base의 유효한 `train` 시작 탭을 상속했습니다.
- Duo 접힘·펼침 경로/Journey/Passport/공유는 기존 유효 사례와 필요한 회귀로 확인했습니다. 변경된 상단 장소 검색 drawer와 취소 복귀는 이번 새 실행에서 각1/1 통과했습니다.
- 새 iPad16장과 Duo 편집4장을 직접 시각 검토했으며, 최신 iPhone 검토를 포함해 확인 범위의 미해결 P1/P2는 없습니다. 화면 밖으로 이어지는 정상 스크롤 콘텐츠와 실제 겹침·잘림을 구분합니다.
- 기기별 보존 장수: phone-normal 14, phone-large 4, duo-folded 12, duo-unfolded 12, ipad 12. 관련 UI 게이트는 통과했습니다. 전체 UI 테스트 실행 완료를 의미하지 않습니다.

## 영향 화면

A01 최근 유산소 행, 운동 목록의 세트 없는 로컬 유산소, W27 로컬 상세, W28 가져온 HealthKit 상세, CA01 경로·CA02 장소·CA03 Journey·CA04 Passport·CA05 Atlas 공유·CA06 Pace Ribbon·CA07 Signature·CA08 위치 없음. Watch는 위치 서비스만 변경되어 화면 재촬영 대상에서 제외했습니다.

Atlas 목적지는 inspector 위의 독립 sheet + NavigationStack이 소유하며 Done 후 같은 상세로 돌아옵니다. 공유 지도는 종횡비를 유지하고 Pace는 실제 속도 기반 색 띠를 사용합니다. 큰 글씨 행동은 세로로 배치하고, inline 지도는 펼치기 전 세로 스크롤을 방해하지 않습니다. 상단 검색 drawer는 두 Duo 자세와 iPad의 최신 실제 이미지로 확인했습니다.

## Duo 자세·복구·출처

현재 worktree 전용 EC59D278-35C3-4158-856A-D96CE4D18698만 사용했습니다. 최종 [접힘 readback](evidence/final-duo-closed-displays.json)은 LCD 활성, [펼침 readback](evidence/final-duo-open-displays.json)은 LCD-1 활성입니다. Device Hub에서 잠금 아래 전용 기기만 전환했고 활성 디스플레이·AX viewport·실제 PNG를 대조했습니다. 공식 devicectl651.13.5에 motion 하위 명령이 없어 수치 각도를 측정했다고 주장하지 않습니다. 비활성 검은 화면은 제외했습니다.

이전 iPad 준비 실패·호환되지 않은 런타임 생성·Duo 마이그레이션 오류는 [상태 이력](verification-status.json)에 남깁니다. Duo 복구 초기화는 예시 데이터만 든 소유 기기에 한정했습니다. 다른 작업의 기기나 전역 CoreSimulator를 종료하지 않았습니다. 로컬 원본은 `.codex-checks/cardio-atlas/retry-1800/` 및 `continue/`에 보존하며 최종 테스트 receipt는 evidence에 복사했습니다.

실제 기기 GPS·HealthKit 경로 동기화·CloudKit 다른 기기 동기화는 시뮬레이터 검증 범위 밖입니다. [전체 검증 기록](../../../../reviews/2026-10-29-cardio-atlas/README.md) · [레이아웃 계약](../../../layout-map/cardio-atlas-integrated-proposal.md).
