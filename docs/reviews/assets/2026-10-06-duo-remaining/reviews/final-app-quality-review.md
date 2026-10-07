# Duo 잔여 경로 최종 app-quality-gate 검토 — 증거 대조

**판정: 변경 범위의 선택 검증 통과, 제한 사항 명시.** `3a49f100` 이후 감사 소유 앱/UI 테스트 변경만 대상으로 하며 사용자 baseline 변경 6개는 제외했다. 기존 전문 리뷰와 [경로별 결과](/Users/shanks/.codex/worktrees/712d/Health/docs/reviews/2026-10-06-duo-remaining-route-coverage.md), [증거 인덱스](/Users/shanks/.codex/worktrees/712d/Health/docs/reviews/assets/2026-10-06-duo-remaining/evidence-index.json)를 대조했다. 이 최종 조정에서 코드·빌드·테스트·시뮬레이터·Git은 변경하거나 실행하지 않았다.

## P1/P2 판정

- **이전 P1(최종 native gate 보류): 해소.** Life 3자세 219.407초와 안쪽 축 109.675초, SubScore의 Readiness/Wellness/Condition 112.239/116.784/105.403초, 일반 iPhone 회전 137.723초, PR 103.838초, Share 218.467초가 각각 선택 testcase 1/1 및 runner exit 0을 기록했다. 대응 native 검토는 숫자·축·버튼/복귀를 확인했다. 근육 칩은 Closed/Open/Book 249.517초, 1/1·skip 0·exit 0 및 [세 자세 native 검토](/tmp/duo-remaining-20261006/custom-muscle-chip-all-poses-native-review.md)에서 전체 `Shoulders`와 Cancel 복귀가 확인됐다.
- **이전 P2(PR 끝점의 Y축 눈금 침범): 해소.** 최종 `x=.fit(to:.plot), y=.fit(to:.chart)` 변경 뒤 Book/maxAX의 103.838초 선택 gate와 native 캡처에서 끝점 `1'50"` 및 이웃한 `3'20"` 눈금이 겹치지 않았다.
- **현재 증거로 확정되는 새 P1/P2 앱 결함: 없음.** DEBUG fixture는 `--uitesting`/명시 플래그 경계 안에 있고 일반·release clock 경로를 바꾸지 않는다. UI 스크롤 선택은 전체 버튼 frame/window 교차를 확인하며, 회전용 host branch는 명시적 Duo visual-audit opt-in으로 제한된다. 최종 generic Simulator `scripts/build-ios.sh --no-regen` 빌드는 Xcode 27.1에서 exit 0이다.

## 결과 해석과 남은 한계

Template 전체 경로는 **testcase 1/1, 258.100초 통과**와 Book native 한 줄 칩을 확인했지만, 실행 후 SDK cleanup이 60초를 넘겨 wrapper가 1/−15로 끝났고 최종 UI receipt가 없다. 이를 깨끗한 runner 통과나 testcase 실패로 바꾸어 적지 않는다. 후속 칩 3자세 선택 gate는 별도로 runner exit 0이다. Share의 native 복귀 통과는 단수 `1 set` 문구 수정 이전 실행이다. 단수 분기와 en/ko/ja 카탈로그는 독립 소스 검토와 최종 컴파일로 확인됐으며, 그 문구의 수정 후 native 캡처는 없다. 선택 수치 assertion의 visual-audit 한정 guard는 일반 글자 크기·locale 실행에 강제 적용되지 않는다.

이번 결과는 전용 시뮬레이터의 선택 경로·fixture·폰 조건에 한정한다. 실제 기기 camera/live feed, 이전 OS의 저장 scene/session 업그레이드, VoiceOver 실제 음성, 모든 글자 크기·자세·빈/긴 데이터·테마 조합 및 전체 unit/watch/full UI suite는 미검증이다. 인벤토리 155개는 진입 선언 수로 전체 통과 수나 완료율이 아니다. 사용자 baseline 5파일 hash와 기존 MuscleMap 24+/9− 변경은 보존됐고, 전용 Duo 0도/portrait/large 복원 및 전용 iPhone 종료가 기록됐다. 사용자 iPad 조작은 없었다.
