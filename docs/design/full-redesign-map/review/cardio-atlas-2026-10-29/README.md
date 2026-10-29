# Cardio Atlas 네이티브 실제 화면

2026-10-29 18시 예약 재시도에서 전용 iPhone을 새로 생성해 정상 부팅과 AX 응답을 확인했다. [새 실제 화면](index.html)과 [출처·해시](capture-index.json)에 현재 확인된 상태만 보존한다. 모든 데이터는 opt-in 예시 기록과 공개 장소이며 실제 사용자 위치가 아니다.

## 현재 검증

- iPhone 기본 기능 6/6 통과. 네이티브 이미지에서 inspector 아래로 목적지가 이동하는 문제를 찾아 Atlas 전용 sheet + NavigationStack으로 수정했다. 고유 목적지의 존재뿐 아니라 실제 hittable 상태와 Done 후 원래 상세 복귀를 확인한다.
- 공유 카드 너비 및 실제 선택 상태 회귀 1/1 통과. Atlas·Pace Ribbon·Signature, 위치 기본 제외, 위치를 켠 뒤 다시 끄는 상태를 확인했다. 지도는 전체 종횡비를 유지하고, Pace는 구분되는 차트 팔레트와 기존 스타일 문구를 사용한다.
- 한국어 최대 접근성 글씨 1/1 통과. 장소·공유는 전체 너비 세로 버튼이며 음절별 줄바꿈 문제를 수정한 새 PNG를 보존한다.
- 시각 검토에서 위 최종 iPhone 수정 범위에 미해결 P1/P2 없음.
- Duo 접힘·펼침의 경로·Journey·Passport·공유 흐름은 정상 사례와 필요한 한정 회귀로 확인했다. 컴팩트 공유 화면의 닫기 툴바는 스크롤 후 다시 드러내고 탭한다. 펼침 Passport는 큰 스와이프가 목표를 지나치는 문제를 작은 양방향 드래그로 확인했다.
- 최종 장소 검색은 iPhone에서 상단 네이티브 검색창과 결과가 겹치지 않음을 새 PNG로 확인했다. Duo 펼침의 이전 하단 검색창 겹침을 수정했지만, 변경 후 해당 Duo 화면은 초기 내비게이션 준비 검사 실패로 재촬영하지 못했다. 기존 겹침 PNG는 최종 갤러리에서 제외했다.
- iPad27.0은 최초 앱 시작과 Activity 상호작용에서 각각5분 한도를 넘었고, 사이의 경로·Journey 사례는 통과했다. 결과 정리도300초 로그 무갱신으로 종료되어 최신 PNG를 추출하지 못했다. 대응 환경 복구로 설치된27.1 런타임에 전용 iPad를 생성하려 했으나 incompatible device(code403)로 실패했다. 추가 반복하지 않았다.
- 현재 새 원본39장. iPad와 최신 Duo 장소 편집 화면이 미검증이므로 UI 게이트와 Ship는 미완료이며 PR 머지를 진행하지 않았다.

## 영향 화면

A01 최근 유산소 행, 운동 목록의 세트 없는 로컬 유산소, W27 로컬 상세, W28 가져온 HealthKit 상세, CA01 경로·CA02 장소·CA03 Journey·CA04 Passport·CA05 Atlas 공유·CA06 Pace Ribbon·CA07 Signature·CA08 위치 없음. Watch는 위치 서비스만 바뀌어 화면 재촬영 대상에서 제외했다.

초기 실행의 잘못된 목적지 PNG와 수정 전 공유 폭·큰 글씨 PNG는 최종 증거로 재사용하지 않는다. 기본 상세·장소·빈 상태의 소스가 변하지 않은 캡처는 df3984ea, 최종 공유·접근성 수정 캡처는 8f58fe9b로 구분한다. 원본 bundle과 testIdentifier를 각 PNG 메타데이터에 남긴다.

실제 기기 GPS·HealthKit 경로 동기화·CloudKit 다른 기기 동기화는 이 시뮬레이터 검증의 범위 밖이다. [전체 검증 기록](../../../../reviews/2026-10-29-cardio-atlas/README.md) · [레이아웃 계약](../../../layout-map/cardio-atlas-integrated-proposal.md).

## Duo 자세와 실행 출처

전용 기기는 EC59D278-35C3-4158-856A-D96CE4D18698이다. [접힘 readback](evidence/duo-closed-displays.json)은 LCD 활성/LCD-1 비활성, [펼침 readback](evidence/duo-open-verified-displays.json)은 그 반대다. 검토한 hinge setter의 open 응답만으로 완료를 판단하지 않았고, 현재 worktree 잠금 아래 Device Hub에서 정확한 전용 기기만 Open으로 전환했다. 설치된 공식 CLI에는 motion 하위 명령이 없어 수치 각도를 측정했다고 주장하지 않는다. 활성 디스플레이·새 AX viewport·양쪽 native PNG를 대조했고 비활성 검은 화면은 갤러리에서 제외했다.

원본 실행 로그와 미완료 원인은 `.codex-checks/cardio-atlas/retry-1800/`에 보존한다. 다른 worktree·공용 기기를 종료하거나 전역 CoreSimulator를 재시작하지 않았다. UI 실행은 모두 종료했으며 원격 머지가 이루어지지 않아 전용 기기 등록과 복구 기록은 보존한다.
