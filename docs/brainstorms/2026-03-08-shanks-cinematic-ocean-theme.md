---
tags: [theme, shanks, one-piece, cinematic, ocean, shader, foam, caustics]
date: 2026-03-08
category: brainstorm
status: draft
---

# Brainstorm: 샹크스 시네마틱 오션 테마

## Problem Statement

현재 `shanksRed` 테마는 붉은 색감과 모티프 오버레이는 갖췄지만, 팬서비스형 세계관 테마로 보기에는 장면의 밀도와 재질감이 부족하다.

핵심 문제:
- 바다가 하나의 장면으로 읽히지 않고 장식 레이어가 따로 노는 느낌이 남아 있음
- 표면 거품, 수중 빛무늬, 배와 카무사리 같은 핵심 상징이 아직 시네마틱하게 연결되지 않음
- `Tab / Detail / Sheet` 전 화면에서 동일한 감정선이 유지되지 않음

이번 방향은 "무난한 고급 테마"가 아니라 원피스 팬 기준의 강한 세계관 테마다.

## Target Users

- 샹크스와 원피스 세계관을 좋아하는 팬
- 테마에서 단순 색상 변경보다 장면성, 상징성, 몰입감을 기대하는 사용자
- 설정 화면에서 테마를 바꾸는 순간 "세계가 바뀌었다"는 체감을 원하는 사용자

## Success Criteria

1. 샹크스 테마 선택 시 `Tab / Detail / Sheet` 모두가 같은 바다 장면 언어로 읽힌다.
2. 네비게이션 바 아래부터 이어지는 바다와 표면 거품이 즉시 인지된다.
3. 수중 빛무늬가 존재감을 가지되, 본문 가독성을 해치지 않는다.
4. 배 + 카무사리 연출이 샹크스 테마의 히어로 포인트로 작동한다.
5. 구현은 `Canvas`와 `.metal` 기반 고급 효과를 허용하되, 실패 시 안전한 fallback이 있다.

## Proposed Approach

### 1) 장면 중심 재설계

샹크스 테마를 "붉은 배경"이 아니라 "샹크스의 바다 장면"으로 재정의한다.

레이어 구조:
- Base: 심해로 가라앉는 abyss gradient
- Surface: 네비게이션 바 아래까지 이어지는 진청 바다 띠
- Foam: 표면 위를 따라 흐르는 백색 거품 crest
- Underwater Light: 수중 caustic / shimmer 패턴
- Hero: 배 실루엣 + 이를 감싸는 카무사리 energy field

### 2) 하이브리드 렌더링

- `Canvas`: 거품, 빛무늬, 부유 질감, 실루엣 패스를 그린다.
- `Metal shader`: 카무사리 왜곡, 수면 굴절, 수중 shimmer를 연결한다.
- `SwiftUI` 레이어: 탭/상세/시트별 강도 조절과 theme dispatch를 유지한다.

### 3) 전 화면 일관성

- `ShanksTabWaveBackground`: 가장 밀도 높은 시네마틱 버전
- `ShanksDetailWaveBackground`: 상징은 유지하되 장식 강도 절반 수준
- `ShanksSheetWaveBackground`: 배/카무사리 존재감만 남기고 텍스트 우선

### 4) Deferred Ideas 분리

이번 MVP에서 제외된 아이디어는 별도 todo로 관리한다.
- 심해 거대 물고기 패럴랙스
- 테마 첫 적용 시 1회성 cinematic intro
- 시간대/날씨 연동 바다 색 변화
- 사용자 강도 슬라이더
- Watch/vision 파생 연출

## Constraints

- 팬서비스형 강한 세계관 우선
- 주요 사용자 기준은 원피스 팬
- `.metal` 도입 허용
- `Reduce Motion`, iPad split view 최적화는 이번 MVP 우선순위가 아님
- 단, 렌더 실패/컴파일 실패/가독성 붕괴는 허용하지 않음

## Edge Cases

- 테마 전환 직후 애니메이션이 멈추거나 초기 phase가 깨지는 경우
- `Canvas`/shader 크기가 0일 때 비정상 path 또는 샘플링 오류가 나는 경우
- Weather atmosphere가 Today 탭 색을 덮어쓸 때 샹크스 정체성이 사라지는 경우
- Sheet/Detail에서 장식이 과해 텍스트가 묻히는 경우
- Preview/테스트 환경에서 shader 경로가 실패하는 경우

## Scope

### MVP (Must-have)

- [x] 배 + 카무사리 연출
- [x] 수중 빛무늬
- [x] 전 화면 일괄 적용 (`Tab / Detail / Sheet`)
- [x] 표면 거품

### Nice-to-have (Future)

- [ ] 심해 거대 물고기 패럴랙스
- [ ] 테마 1회성 cinematic intro
- [ ] 시간대/날씨 적응형 바다 색상
- [ ] 테마 강도 사용자 슬라이더
- [ ] Watch/vision 파생 테마

## Open Questions

- 배 실루엣을 어느 정도까지 직접적으로 묘사할지
- Weather atmosphere는 샹크스 테마에서 override할지, surface tint에만 제한할지
- 거품/카무사리의 최종 강도를 어느 수준까지 올려도 정보 가독성이 유지되는지

## Next Steps

- [ ] `/plan shanks-cinematic-ocean-theme` 으로 구현 계획 확정
- [ ] MVP 외 아이디어는 todo로 관리
