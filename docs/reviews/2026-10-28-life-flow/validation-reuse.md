# Life 검증 재사용 범위

앱 구현은62d3c097 이후 바뀌지 않았다. 그 이후 변경은 실행 증거·지침과 UI 테스트 전용 키보드 후보 guard, 보이는 Form CollectionView 선택, 반복 안내문 스크롤, 같은 캡처 본문의 외관별 host selector 분리다. 이전113개/9suite 단위 검증의 VM·resolver·테스트 코어는 변경되지 않았으며 UI helper는 unit target에 포함되지 않는다. 이 unit 결과를 full iOS 결과로 승격하지 않는다.

이전 generic iOS build는62d3c097 통합본에서 성공했다. helper 수정은 precommit의 DUNEUITests targeted build-for-testing으로 별도 확인한다. 앱 소스 해시와 기존 source-sha256.json을 비교하며 다른 simulator 검증을 iPhone 증거로 대신하지 않는다.

두 개 통과 selector의 capture·주간 비교 코드는 새 keyboard dismiss helper를 직접 호출하지 않는다. 이전 source의 캡처 출처를 그대로 보존하고 새 source에서 재촬영했다고 표시하지 않는다. 이번 변경을 검증하는 실제 동작은 원래 실패한 주간/예정 selector로 수행한다.

최종 소스791b8bf4까지 DUNE/DUNETests/Shared diff가 비어 있음을 확인했다. c80b5f1e 주간/예정1/1과 helper소비자3개가 통과했으며, 외관별 캡처 split은 별도의 UI build-for-testing으로 컴파일했다. 소스 일치와 실행별 원본 receipt를 보존하고 repository 전체 fingerprint가 문서 추가로 stale된 과거 자동 결과를 임의 갱신하지 않는다.
