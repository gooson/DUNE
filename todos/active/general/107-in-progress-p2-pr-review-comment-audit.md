---
source: manual
priority: p2
status: in-progress
created: 2026-03-09
updated: 2026-03-09
---

# PR 리뷰 코멘트 감사 및 후속 수정

## 범위

- 기준 시각: 2026-03-09
- open PR: 0건
- 감사 범위: 2026-03-08에 업데이트된 최근 merged PR 30건

## 코멘트 처리 목록

- [x] PR #423 P1: watch smoke가 `Recent` section을 필수로 요구하지 않도록 수정
- [x] PR #420 P1: `MuscleMap3DScene` muscle cache preload guard 추가
- [x] PR #420 P2: `MuscleMap3DScene` shell cache preload guard 추가
- [x] PR #402 P1: recommendation unresolved step drop 금지
- [x] PR #402 P2: strength recommendation activity fallback 허용
- [x] PR #400 P1: muscle map 3D navigation test를 deterministic selector로 교체
- [x] PR #401 P1: sleep prediction을 load 완료 후 재계산
- [x] PR #401 P2: active injury edit도 injury risk 재계산에 반영
- [x] PR #401 P2: record update 시 weekly report 재생성
- [x] PR #396 P1: `muscle_body.usdz` DUNEVision resources 누락은 현재 `main`에서 해소됨

## 메모

- 계획서: `docs/plans/2026-03-09-pr-review-comment-audit.md`
- 해결책 문서: `docs/solutions/general/2026-03-09-pr-review-comment-followups.md`
- `PR #396`은 `DUNE/project.yml`과 `DUNE.xcodeproj` 기준 stale after fix로 분류
- rerun review에서 `completedSets` 편집이 `recordsUpdateKey` fingerprint에 빠진 경로를 추가 발견했고, `ActivityRecordChangeFingerprint` + `ActivityViewModelTests`로 보강함
- `scripts/build-ios.sh`, targeted `DUNETests`, pre-commit build는 2026-03-09 실행 중 `SIGTERM`(exit 143/15)으로 중단됨
- simulator 재기동 후에도 `xcrun simctl bootstatus`가 `Waiting on System App`에 오래 머물러 런타임 검증 환경이 불안정했음
- 중단 전 로그 기준으로 이번 변경에서 발생한 Swift compile error는 아직 관측되지 않았지만, 검증 완료로 간주하지는 않음
