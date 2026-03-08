---
tags: [visionos, todo, backlog, roadmap, reconciliation]
date: 2026-03-08
category: solution
status: implemented
---

# Vision Pro TODO 상태 정합성 복구

## Problem

Vision Pro backlog에서 `todos/021`과 `todos/022`가 모두 `ready`로 남아 있었다.
하지만 실제 저장소 기준으로는 `021`은 shipped 상태였고, `022`는 일부 하위 범위만 반영된 채 다음 실행 대상으로 남아 있었다.
이 때문에 backlog만 보고는 지금 닫아야 할 항목과 계속 진행해야 할 항목을 구분하기 어려웠다.

## Solution

### shipped 근거를 먼저 확인했다

- `feat(visionOS): connect real health data pipeline to all Vision views`
- `docs/solutions/architecture/2026-03-08-visionos-real-data-pipeline.md`
- `docs/solutions/architecture/2026-03-08-visionos-volumetric-ux-polish.md`

이 근거를 바탕으로 `021`은 완료 TODO로 닫고, `022`는 진행 중 TODO로 올리는 방식으로 backlog를 재분류했다.

### TODO 상태를 파일명과 함께 맞췄다

- `todos/021-ready-p1-vision-real-data-pipeline.md` → `todos/021-done-p1-vision-real-data-pipeline.md`
- `todos/022-ready-p2-vision-ux-polish.md` → `todos/022-in-progress-p2-vision-ux-polish.md`

`021`에는 `완료 메모`를 추가해서 왜 닫혔는지와 어떤 solution 문서를 보면 되는지 바로 알 수 있게 했다.
`022`에는 `진행 메모`를 추가해서 이미 반영된 범위와 남은 closure 항목을 같이 보이게 했다.

### 다음 작업을 문서 안에서 명시했다

- umbrella tracker인 `todos/020-in-progress-p3-vision-pro-phase4-social-advanced.md`에 5A 완료와 5B 진행 사실을 추가했다.
- `todos/023-ready-p2-vision-phase4-remaining.md`에 5B 완료 이후 착수하는 후속 phase라는 메모를 추가했다.

## Prevention

- Vision Pro TODO를 ship할 때는 solution doc 생성과 같은 배치에서 TODO 파일명/status도 함께 갱신한다.
- umbrella TODO와 phase TODO를 같이 운영할 때는 umbrella 문서에 분기 관계와 다음 실행 대상을 남긴다.
- "다음 TODO"를 묻는 요청에 대비해, 완료된 phase는 `완료 메모`, 진행 중 phase는 `진행 메모 + 남은 범위`까지 남겨 backlog만 읽어도 현재 상태를 추론할 수 있게 유지한다.

## Lessons Learned

Backlog는 구현 코드만큼 최신 상태를 유지해야 한다.
특히 Vision Pro처럼 phase가 빠르게 분기되는 트랙에서는 shipped 근거와 TODO 상태가 어긋나면, 실제 개발보다 "무엇이 다음인지"를 판별하는 비용이 더 커진다.
