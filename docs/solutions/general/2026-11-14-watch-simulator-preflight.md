# Watch unit runner 사전 검증

## 문제

CI가 기기 목록에 남아 있지만 runtime bundle이 없는 Watch simulator를 선택했다.
clone 실패 이후 빈 destination ID가 출력되어 boot/test 단계까지 진행됐다.

## 변경

Watch unit 경로에서 clone 전과 boot 전 각각 simulator ID, 기기 가용성,
watchOS runtime 가용성 및 bundle 경로를 검증한다. name/OS 지정도 명확한
단일 기기로 해석하고 ID로 정규화한다. 조회 실패/timeout/모호한 선택은
즉시 실패한다. runtime 설치, 기기 삭제 또는 자동 복구는 하지 않는다.
iOS 실행 경로와 정상 boot retry 정책은 그대로 둔다.

## 검증 범위

fixture로 유효한 ID/name, 누락 runtime/bundle, 비가용 기기, 잘못된 ID,
query 실패/timeout, clone 이전 실패 시 boot/test 미실행을 검사했다.
실제 GitHub runner에서 Watch unit test 성공 여부는 이 로컬 검증에 포함되지 않는다.
유효한 destination으로 boot한 뒤 발생하는 nil native architecture/exit 65는
별개 문제이며 이 preflight로 해결됐다고 간주하지 않는다.
