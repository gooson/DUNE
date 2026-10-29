# Code Review Report

> Date: 2026-10-30
> Scope: 장소 검색/선택·공유 간격/모달·100회 업적 확장·운동명/기존 변형 마이그레이션
> Base: origin/main 25ebca1be35551f2799e6017f73cf06351d7b9f4. 시작 checkout은 detached이며 base와 동일했다. 이 대화 변경만 codex/cardio-atlas-polish에 포함한다.

## Summary

| Priority | Count | Status |
|---|---:|---|
| P1 | 1 | Resolved |
| P2 | 3 | Resolved |
| P3 | 1 | Resolved |

2255줄의 tracked diff와 관련 untracked 파일을 포함했다. review 스킬의 큰 diff 예외에 따라 주 에이전트가 보안/성능/구조/데이터/단순성을 폴더별로 직접 검토했다. UI 구현·Apple UX·테스트 범위는 별도 read-only 전문가가 검토했다. Agent-Native는 관련 변경이 없어 생략했다. 전체 finding은 findings.json에 기록한다. 리뷰 단계에서는 제품 코드를 수정하지 않았다.

## Findings · 최초 발견 이력

- **verify-001 / P1 / Open:** 빈 장소에서 긴 검색 목록 선택·재선택·저장/재열기 검증이 미완료. 키보드 추천 영역 밖의 실제 드래그/스크롤 정상화 근거 이후 해당 실패 selector만 재개한다.
- **verify-002 / P2 / Open:** 장소 검색·횟수 업적의 실제 소스 macOS 단위 통과를 iOS 실행으로 확대하지 않는다. 두 관련 suite의 native 실행을 보완한다.
- **data-001 / P2 / Open:** 기본값 기록은 canonical 대상 존재를 검사하지 않아 알 수 없는 ID가 잘릴 수 있다. 알려진 base만 변환하고 나머지는 보존한다.
- **ux-001 / P3 / Open:** 장소 편집 상단/하단 저장 중복. 하단 고정 저장과 상단 취소로 정리한다.

## Localization / Security / Performance / Architecture

변경된 카탈로그6개 항목은 지원 언어/기존 영어 키 호환을 확인했다. 일반 이름 정규화는 정확한 매치로 제한하며 사용자 제목은 보존한다. 위치 권한은 명시적 현재 위치 요청에만 새로 묻고 수동 선택 전 GPS를 운동 장소로 저장하지 않는다. 검색 취소·이전 쿼리 응답 guard와 결과 좌표 검증, 같은 거리 안정 정렬이 있다. 횟수 업적은 누적 세션마다 threshold 목록을 키우지 않고 해당 100배수에서 한 번 추가한다. 새 @Model/스키마 및 HealthKit 활동 매핑 변경은 없다. 별도 P1/P2 코드 결함은 확인하지 않았다.

## Verification / Remaining maps

전체 테스트 실행 요청은 없으므로 adapter에 따라 관련 selector만 확인한다. iPad/Duo/Watch 새 캡처의 미완료 상태는 각 갤러리 README를 유지하고 통과로 바꾸지 않는다. 같은 환경 실패에 정상화 근거 없는 반복 실행은 하지 않는다. 필수 긴 목록 검증/이전 P1/P2가 해소되기 전 PR 생성/머지를 진행하지 않는다.

## Resolve · 최종 상태

| ID | Final | Evidence |
|---|---|---|
| verify-001 | Resolved | 단일 드래그 AX/PNG/좌표로 복구 확인 후 원래 긴 목록 selector1회 재개·exit0. 먼18번/다른2번/동일2번 선택·저장·재열기 통과 |
| verify-002 | Resolved | 최종 native iOS59개 정의/162사례·exit0. 검색21, 진행15, 표시5, 수정 캐시12, 마이그레이션6 |
| data-001 | Resolved | 기본값 변환에 실제 base 존재 guard. 알려진 변형·unknown/custom ID·빈 catalog 보존 테스트 포함 |
| ux-001 | Resolved | 상단 저장 제거, 하단 고정 저장·상단 취소. 최종 선택 UI에서 중복 없는 저장 확인 |
| search-001 | Resolved | 지역+일반 시설 단어에서 시설 카테고리는 해당 단어만 충족. 강남/다른 지역/시설 아님/미분류 상호·초성/영문 gym 사례 포함 |

추가 P2 search-001은 Resolve 중 재검토에서 `강남 헬스`가 Gold Fitness를 잘못 제외하는 최소 재현을 확인해 보고한 뒤 수정했다. 기존 지역/이름 조건을 약화시키지 않았다.

최종 native 단위59개 정의와157→162개 매개변수 포함 사례가 정상 종료·통과했다. UI는 단일 드래그 복구 진단1건, 원래 긴 목록 전체 경로1건, 마지막 한글/초성 선택/저장1건이 통과했다. 마지막 한글 검사의 최초180초 제한 중단과 소유 프로세스/잠금/실제 화면 정상화 및 한 번의300초 재실행은 별도 기록한다. 전체 suite 또는 다른 기기의 통과로 확대하지 않는다.

현재 통합/crash 위험은 별도 최종 pr-reviewer/app-quality-gate read-only 검토에서 추가 actionable finding 없이 통과했다. 당시 조건이었던 최종 검색 단위 실행도59/162 통과로 충족했다. 기존 P1/P2를 현재 코드에서 재확인했고 Open finding은0건이다. L10N 포맷·manual 상태와 whitespace도 확인한다. MapKit의 기존 placemark API 및 SDK 메타데이터 deprecation/추출 경고는 남아 있으며 런타임 실패로 처리하지 않는다. 이번 PR에서 주소 API 의미를 바꾸는 별도 마이그레이션은 하지 않는다.

새 CA02 실제11원본은 [리뷰 후 갤러리](../../design/full-redesign-map/review/cardio-atlas-polish-2026-10-30/index.html)에 보존했다. 공유/업적/운동명 별도 갤러리는 해당 작업 시점의 source hash와 실행 범위를 유지한다. 이후 opt-in fixture/다른 테스트/계단 번역 변경을 이전 결과의 전체 앱 재실행으로 주장하지 않는다. 검증하지 못한 iPad/Duo/Watch 상태는 계속 미완료다.

Ship 사전 동기화: 원격 main의 Life 템플릿 PR#858(60bd7c4b)을 통합했다. 기능 소스는 겹치지 않았고 통합 실제 디자인맵 HTML의 링크 충돌만 양쪽 href 전부 보존해 해결했다. 원본 빌드/테스트 로그는 gzip으로 무손실 보존하며 raw SHA-256은 evidence/compressed-logs.json에 기록했다. CSV는 값 변경 없이 LF로 정렬했다.
