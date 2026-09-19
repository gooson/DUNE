---
tags: [whats-new, localization, xcstrings, version-bump, 0.8.0]
date: 2026-09-19
category: general
status: implemented
---

# What's New 카탈로그 업데이트 (0.8.0)

## Problem

0.7.0 이후 추가된 건강 지표 과거 탐색, 연속 그래프 스크롤 개선, 누적 스트레스 상세 화면과 섹션 이동 개선이 앱의 새로운 기능 목록에 반영되지 않았다.

## Solution

- 기존 0.7.0 업데이트 방식에 따라 `DUNE/project.yml`의 공유 MARKETING_VERSION을 0.8.0으로 변경했다. 빌드 번호는 기존 정책대로 1을 유지했다.
- `DUNE/Data/Resources/whats-new/0.8.0.json`에 iOS 27 지원 안내를 포함한 5개 기능을 추가하고 `catalog.json` 최상단에 등록했다.
- `Shared/Resources/Localizable.xcstrings`에 소개·제목·설명 11개 키를 manual 상태로 추가했다. en/ko/ja 번역을 모두 포함했다.
- 빌드 스크립트로 프로젝트를 재생성해 새 JSON의 번들 포함과 모든 타깃 버전을 반영했다.
- `WhatsNewManagerTests`에 새 버전의 기능 ID·개수·문자열 확인을 추가하고 전체 릴리스 개수를 8개로 갱신했다.

## Prevention

버전 변경 시 공유 버전 값, 버전별 JSON, 최상위 카탈로그, 번역, 번들 리소스와 로딩 테스트를 함께 갱신한다. 생성된 프로젝트는 빌드 스크립트로 갱신하고 문자열 카탈로그는 기존 항목의 포맷을 보존한다.

## Lessons Learned

기존 버전 업데이트 커밋을 확인하면 버전 숫자뿐 아니라 앱에서 자동으로 보여 주는 새로운 기능 목록까지 일관되게 갱신할 수 있다. 릴리스 문구는 확인된 사용자 기능에 한정하며 실기기 응답 시간이나 데이터 완전성을 보장하지 않는다.
