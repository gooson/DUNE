---
tags: [git, branch-cleanup, history-reconciliation, watchos]
date: 2026-11-15
category: solution
status: reviewed
---

# 남은 브랜치 통합 검토

기준: 2026-11-15, main `c67f9f1f76764cbd081461b40a441314add56422`.
사용자 요청에 따라 완료된 브랜치 삭제를 먼저 수행하고 남은 이력을 대조했다.

## 먼저 완료한 삭제

GitHub merged PR, 정확한 원격 head 또는 PR head까지의 조상 관계,
main에 포함된 merge commit을 확인했다. 로컬 4개·원격 47개를 삭제했다.
테마 중간 브랜치의 마지막 로컬 커밋 `973dea058`도 PR #993에 포함돼 있었다.
원격 삭제는 expected SHA lease를 사용했고 삭제 후 원격 ref를 다시 조회했다.
다른 채팅의 변경 중인 아이콘 폴더와 새 d134 폴더는 보호했다.

## 앱 코드와 최종 PR 대조

세 독립 조사에서 각 브랜치의 merge-base 이후 앱·테스트·문서 변경을
현재 main과 화면별 최종 PR에 대조했다. 이력에 없는 커밋 수를 기능 누락 수로
취급하지 않았다. 아래 13개는 추가로 옮길 앱 변경이 없었다.

| 브랜치 (`codex/` 생략) | 앱 변경 판단 | 최종 PR 근거 |
|---|---|---|
| exercise-library-b09-integration | 앱 파일 4개 동일 | #955–#958 |
| strength-b10-integration | 앱 파일 2개 동일 | #959–#961 |
| set-assistance-b11-integration | 앱 파일 3개 동일 | #962–#964 |
| template-authoring-b13-integration | 2개 동일; CreateTemplateView는 최종 AI 라벨 줄바꿈·접근성 ID 추가 | #970–#973, #988 |
| compound-cardio-b14b15-integration | 앱 파일 6개 동일 | #974–#981 |
| workout-records-b12-integration | 2개 동일; 나머지는 최종 공유 시트 크기·큰 글씨 chart·compact history 탐색으로 개선 | #965–#969, #990 |
| workout-metadata-b16b17-integration | UserCategoryManagementView 동일 | #982–#986 |
| posture-b05-integration | Capture/Realtime/Result 동일; picker는 최종 P03 닫기 터치 영역·번역 개선 | #941–#944 |
| posture-b06-integration | Comparison/Symmetry 동일; History는 최종 P08 메뉴 적용 | #944, #946, #947, #952 |
| settings-b07-integration | Settings/DefaultsList/PreferredList 동일; 최종 S03은 키보드 완료 처리 추가 | #948–#951 |
| whats-new-b08-integration | WhatsNewView 동일; 같은 smoke 검사의 위치만 변경 | #953, #954 |
| h08-injury-form-redesign | InjuryFormSheet 동일; 최종 MAX 검사 추가 | #991 |
| held-detail-completion | 변경 앱 파일 16개 전부 동일; UI 검사 6개 중 4개 동일, 2개는 main의 후속 검사 추가 | #951, #989–#991 등 완료 화면 47개 |

중간 UI 검사 파일에만 남은 `test*` 메서드는 없었다. 이전의 실패한 검사 초안,
검증 보류 계획, 오래된 맵 인덱스를 현재 최종본 위에 덮어쓰지 않는다.
47개 완료 화면의 기록된 merge OID 47개 모두 기준 main의 조상임을 확인했다.

`t06-original-meter-baseline`의 `f06d4a735`는 Swimming 1,314m를 잘못
`1,314 min`으로 표시하던 비교용 상태다. 현재 main에는 수정된 `1.3 km`
검사와 이후 ContentView 진입 경로들이 있다. 오류 상태를 앱에 적용하지 않고
비교 이력만 통합 그래프에 보존한다.

## 통합 방식

앱 변경이 이미 화면별 PR로 반영된 13개와 T06 비교 이력은 **현재 트리를
유지하는 명시적 이력 통합**으로 연결한다. 이 커밋은 기능 구현이나 새로운 UI
검증이 아니다. 원래 커밋을 Git에서 계속 조회할 수 있게 하며, 아래 실제 누락
수정과 함께 통상 GitHub PR로 머지한 뒤 이전 브랜치 ref를 정리한다.
옛 UI·실패 검사·보류 문서를 복원하지 않는 것이 명시적인 통합 판단이다.

## 실제 누락 수정

`watch-ci-preflight` 폴더의 미커밋 6개 파일은 main의 빌드 후 부팅·live
readiness 검사보다 먼저 작성됐다. 그 중 source runtime/clone 검증은 main에
없었다. 이를 최신 runner에 추가하되 build-before-boot 순서를 유지했다.

- source 기기·runtime·실제 bundle 경로를 clone 전에 검증한다.
- clone 결과 ID와 runtime을 boot 전에 다시 검증한다.
- 실패하면 clone/boot/test 다음 단계로 진행하지 않는다.
- 정상 경로와 빌드 후 부팅 경로를 모두 fixture로 검증한다.
- CI workflow의 변경 경로에도 helper를 등록한다.

P03의 일반 iPhone·iPad actual-map PNG는 최종본이었지만 인덱스의 출처가
10월 상태였다. 최종 #944 갤러리의 PNG·AX 해시, 앱 파일 해시와 캡처 시간을
대조해 해당 인덱스·갤러리·자세 보드를 동기화했다. 11월 15일 새 캡처나
앱 UI 검사로 제시하지 않는다.

## 검증

- `python3 -B -m unittest scripts.tests.test_watch_simulator_preflight scripts.tests.test_unit_test_runner scripts.tests.test_simulator_readiness`: 43개 통과, 28.575초.
- `bash -n scripts/test-unit.sh`, `git diff --check`: 통과.
- 설치된 Watch 기기의 `simctl list devices/runtimes -j`를 읽어 실제 runtime/bundle 검증 통과. 기기 생성·부팅·테스트 실행 없음.
- runtime preflight는 CLI fixture와 실패 전파·clone 전/후 중단·정상 boot 순서를 포함한다.
- 앱 Swift·문자열·프로젝트 설정 변경 없음: 앱 빌드·UI·새 캡처는 생략한다.
- 최종 PR diff 및 이력 통합 전후 tree equality를 별도로 확인한다.

실제 GitHub runner의 Watch unit 결과는 CI 실행 결과로 별도 확인하며, fixture
통과를 실제 기기·HealthKit·UI 검증으로 표현하지 않는다.
