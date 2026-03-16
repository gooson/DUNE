# TODO System Conventions

## Directory Structure

```
todos/
├── active/          # 작업 대상 (pending, ready, in-progress)
│   ├── e2e/         # End-to-End 페이지 리뷰
│   ├── posture/     # 자세 분석 기능
│   ├── vision/      # visionOS 관련
│   └── general/     # 기타 (architecture, fix, refactor 등)
└── done/            # 완료된 항목 아카이브
```

## File Naming

`NNN-STATUS-PRIORITY-description.md`

- NNN: 3-digit sequential number (001, 002, ...)
- STATUS: pending | ready | in-progress | done
- PRIORITY: p1 (critical) | p2 (important) | p3 (minor)
- description: kebab-case short description

## Examples

- `active/e2e/032-ready-p2-e2e-dune-exercise-defaults-list-view.md`
- `active/posture/133-pending-p3-posture-realtime-video-analysis.md`
- `done/001-done-p2-healthkit-auth-check.md`

## Status Transitions

```
pending -> ready -> in-progress -> done
```

- **pending**: 아직 착수 조건이 갖춰지지 않음
- **ready**: 착수 가능, 필요한 정보와 계획이 있음
- **in-progress**: 현재 작업 중
- **done**: 완료 시 `done/` 폴더로 이동

## Category Assignment

새 TODO 생성 시 다음 기준으로 카테고리 폴더 선택:

| 카테고리 | 기준 |
|---------|------|
| `e2e/` | 페이지/화면 단위 End-to-End 리뷰 |
| `posture/` | 자세 분석 (PostureAnalysis) 관련 |
| `vision/` | visionOS, RealityKit, 공간 컴퓨팅 |
| `general/` | 위에 해당하지 않는 모든 항목 |

새 기능 영역이 5개+ TODO를 생성하면 전용 폴더 신설 가능.

## TODO File Content

```yaml
---
source: manual | review/{reviewer} | brainstorm/{topic}
priority: p1 | p2 | p3
status: pending | ready | in-progress | done
created: YYYY-MM-DD
updated: YYYY-MM-DD
---
```

## Numbering

새 TODO 생성 시:
1. `todos/active/` + `todos/done/` 전체에서 가장 높은 번호 확인
2. 그 다음 번호 사용
3. 번호는 전역 고유 (카테고리 간 공유)

## Priority Definitions

- **P1 (Critical)**: 즉시 수정 필요. 보안 취약점, 데이터 손실 위험, 서비스 중단
- **P2 (Important)**: 빠른 수정 권장. 성능 문제, 아키텍처 개선, 중요 버그
- **P3 (Minor)**: 시간 될 때 처리. 코드 정리, 마이너 개선, 문서화
