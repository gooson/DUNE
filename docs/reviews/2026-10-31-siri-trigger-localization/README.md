---
tags: [siri, app-shortcuts, localization, review]
date: 2026-10-31
category: review
status: reviewed
---

# Code Review Report

> Date: 2026-10-31
> Scope: Siri 호출 문구 다국어화. `origin/main` (`6a4edb99`) 대비 커밋·staged·unstaged·관련 untracked 전체 확인. 최초에는 브랜치/staged 변경 없음.
> Files reviewed: 6개. `codex-context-d332awdf` snapshot의 4개 tracked patch와 새 카탈로그·해결책 문서를 별도 확인.

## Summary

| Priority | Count | Status |
|----------|-------|--------|
| P1 - Critical | 0 | 없음 |
| P2 - Important | 1 | Resolved: 한국어 요청 문구 수정 |
| P3 - Minor | 0 | 없음 |

보안·성능·아키텍처·데이터 정합성·단순성을 독립 병렬 reviewer로 검토했다. 각 역할은 `.codex/agent-map.md`의 `gpt-6-sol`/`medium`을 사용했고 read-only로 수행했다. 에이전트·프롬프트 변경이 없어 Agent-Native는 생략했다. 부모가 사용자 대면 호출 문구의 localization을 직접 추가 검토했다.

## P1 Findings (Must Fix)

없음.

## P2 Findings (Should Fix)

### [Data Integrity / L10N] l10n-001: 건강 질문 한국어 문구의 요청 의미

- **File**: `DUNE/Resources/AppShortcuts.xcstrings:28`
- **Category**: data / localization
- **Issue**: `${applicationName}에서 내 건강에 대해 물어볼게`는 화자의 의향을 말하며, Siri에 앱에 질문하도록 하는 요청과 의미가 다르다.
- **Suggestion**: `${applicationName}에게 내 건강에 대해 물어봐`로 바꾸고 앱 이름 토큰을 보존한다.
- **Status**: Resolved. 현재 번역을 `${applicationName}에게 내 건강에 대해 물어봐`로 수정했고 토큰을 유지했다. 다른 언어와 source key는 변경하지 않았다.

## P3 Findings (Consider)

없음.

## Localization Verification

- 새 문구는 Apple 시스템 지정 `AppShortcuts` 테이블에 등록한다. 일반 UI `Localizable` 번역으로 호출 문구 번역을 대체할 수 없다.
- 10개 단축어·12개 source key에 en/ko/zh-Hans/zh-Hant/ja/es가 있고 각 번역에 `${applicationName}`이 한 번씩 있다. source phrase와 catalog key를 대조했다.
- 컨디션의 추가 문구는 동일한 `.condition` intent를 유지하며 기본 기간은 기존 서비스의 today다.
- View/helper/String 할당/enum displayName은 바뀌지 않아 일반 localization leak 다섯 패턴에 새로운 누출이 없다.
- 중국어·스페인어 전체 앱 UI/응답 번역과 Watch용 intent 추가는 범위 밖이다. 실제 Siri 인식·발음·실행·낭독은 미검증으로 유지한다.

## Positive Observations

- 인증·저장·건강 조회 로직과 민감 데이터 흐름은 변경하지 않는다.
- 시스템 전용 카탈로그가 iOS target에 포함되고 생성된 프로젝트에도 resource/knownRegions가 반영된다.
- formatter 검사와 Xcode sync 회귀 테스트가 전용 카탈로그도 확인한다.

## Validation and Quality Gate

- 이전 구현 검증: formatter 계약 11개·Xcode sync 검사·`xcstringstool compile`·Swift parse·포맷/manual·diff 검사가 통과했다. 같은 소스의 결과는 재사용한다.
- 앱 빌드: SDK 캐시 생성 완료를 확인해 재개한 `scripts/build-ios.sh`가 성공했다. 한국어 문구 수정 후 formatter 계약 테스트 11개와 리소스 증분 앱 빌드도 통과했다. 최종 로그: `/tmp/dune-siri-review-ship/catalog-tests.log`, `/tmp/dune-siri-review-ship/build-final.log` (모두 exit 0).
- 최종 빌드에서 `ValidateAppShortcutStringsMetadata`·Siri NL training 처리가 성공했다. 실제 앱 번들의 6개 언어 `AppShortcuts.strings`가 각 12개 source 번역과 일치하는지 확인했다.
- 앱 화면·레이아웃·조회 로직·Watch 소스가 바뀌지 않아 UI suite/실제 화면 디자인맵 재캡처를 생략한다. 판정기의 미매핑 full 경고를 이 영향 분석으로 좁혔으며 UI 통과를 주장하지 않는다.
- `app-quality-gate` 관점: 정적 검토에서 추가 크래시·보안·아키텍처 문제 없음. P2 1건 Resolved, 앱 빌드·리소스 계약 검증 통과. 실제 Siri 인식·낭독은 미검증으로 남는다. 최초 빌드의 기존 Swift 경고는 이번 diff 밖이어서 수정 범위를 넓히지 않았다.

## Next Steps

- l10n-001은 현재 diff에서 요청형 문구·토큰 보존을 재확인해 Resolved로 유지한다. 미해결 P1/P2는 0개다.
- 최종 `pr-reviewer` read-only 검토가 PASS다. 현재 base diff·새 파일 3개·이전 P2·최종 로그를 대조했고 신규 P1/P2/P3는 0개다. 실제 Siri 인식·낭독 미검증 범위를 유지한 채 Ship으로 진행한다. 이번 검증을 커밋 훅의 중복 앱 빌드로 반복하지 않는다.
