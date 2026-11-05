---
tags: [h04, design-map, native-evidence, documentation]
date: 2026-11-05
category: plan
status: implemented
---

# H04 검증 상태 문서 정합성

## 배경과 범위

기준 HEAD는 `c9aadf8cc3eff075606352ec99cbc8d5d01a52d7`이다. H04 앱 소스 `MetricComparisonView.swift` SHA-256 `106c95c56d656ab55ce56377e5dc3f4ab6ed365b31918539cc2a73ee470eb28a`는 병합된 PR #918의 근거와 같다. H04 정적 배치·테마 문서의 “네이티브 대비 확인이 남았다”는 문구만 실제 발행 근거에 맞춘다. 유효 사례 5건과 PNG/AX 31쌍, 밝은 화면 필수 선·점 대비 6.99:1 및 선택 글자 6.49:1을 명시한다. 과거 10개 아카이브의 13 실행/6 통과/7 실패, 역사적 PNG 네 장의 식별 목적, 전체 지표·기간·언어·실사용 HealthKit 미검증 범위도 그대로 구분한다. 정적 시안의 예시 수치·SVG는 실제 앱 캡처가 아니다.

## Affected Files

| 파일 | 변경 |
| --- | --- |
| `docs/design/layout-map/wellness-metric-comparison-h04.html` | 검증 대기 문구를 실제 사례·대비 결과와 범위 제한으로 교체 |
| `docs/design/layout-map/README.md` | H04 실제 화면 링크와 5건/31쌍 추가 |
| `docs/design/theme-map/themes/dune-metric-comparison-h04.html` | 정적 시안 표기 유지, 실제 화면 링크와 미검증 범위 명시 |
| `docs/design/theme-map/README.md` | H04 대비 결과·과거 실패 이력 명확화 |
| `docs/design/theme-map/manifest.json` | H04 study만 `implemented-native-reviewed`로 변경 |
| `docs/design/theme-map/index.html` | manifest에서 표준 빌더로 재생성 |
| `docs/solutions/testing/2026-11-05-shared-metric-dates-and-native-menu-evidence.md` | 발행 뒤 정적 문서 상태를 함께 대조하는 예방 기록 |

## Implementation Steps

1. H06 PR #920 병합 뒤 실제 병합 HEAD에서 이 private patch의 기준 파일 해시와 `git apply --check`를 다시 확인한다. 앱·테스트·캡처는 수정하지 않는다.
2. H04 문서 변경을 적용하고 `python3 docs/design/theme-map/build-theme-map.py` 및 `--check`로 생성 인덱스를 동기화한다. H05와 H06을 포함한 다른 study 항목을 보존한다.
3. `git diff --check`, 문서 링크, H04 공개 갤러리·계획·해결 문서의 근거를 점검한 뒤 별도 문서 PR로 제출한다. 새 네이티브 실행으로 표시하지 않는다.

## 검증과 위험

실제 H06 병합 HEAD `c9aadf8cc3eff075606352ec99cbc8d5d01a52d7`에서 문서 여덟 파일만 수정했다. 표준 테마 빌더와 `--check`, diff 공백 검사, 앱 소스 해시 및 문서 전용 변경 범위 검사를 통과했다. Manifest의 50 study 중 H04만 바뀌고, H06의 `implemented-native-reviewed` 상태와 기존 갤러리 연결을 포함한 다른 49 study 및 열 개 theme은 보존됐다. 앱·테스트·기존 캡처가 바뀌지 않아 새 네이티브 검사나 빌드는 실행하지 않았다. 기존 PR #918의 실제 근거와 과거 실패·미검증 범위는 유지하며, 이 문서 정정을 새 앱 검증으로 표시하지 않는다.
