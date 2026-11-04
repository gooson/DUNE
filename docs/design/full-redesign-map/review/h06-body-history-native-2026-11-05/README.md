---
tags: [body-composition, native-evidence, accessibility, design-map]
date: 2026-11-05
category: solution
status: implemented
---

# H06 실제 신체 기록 목록 검토

현행 소스 438d의 기존 검사 여섯 사례가 네 순차 실행에서 모두 통과했다. iPhone·iPad·Duo 접힘·펼침의 검토된 실제 PNG/AX 12쌍을 연결했다. 일반 Edit 목록 행은 네 기기·자세의 현재 H06 이미지이고, Duo 접힘 Add와 MAX Edit는 갤러리의 추가 상태다. Add의 체중만 기록된 행은 H06 목록의 부분 기록 증거이며 H05 입력 화면을 다시 설계했다는 뜻이 아니다.

수동 행의 세 번째 값은 `Muscle Mass (kg)`, Apple Health 행은 `Lean Body Mass`로 실제 AX에서 구분된다. 수동 더 보기와 Apple Health 심장은 관찰한 행에서 확인했다. 이전 H06 PNG 네 장은 소스·UID·자세·AX가 연결되지 않은 역사적 화면 정체성 참고다. 라벨 수정 전 12ecc의 Duo 접힘 3/3 통과도 별도 역사적 성공으로 보존하며 현행 소스의 여섯 사례에 합산하지 않는다.

## Lessons Learned

같은 `H06 body history rows` 이름은 일반 Edit와 MAX Edit에서 반복된다. SDK testIdentifier와 캡처 순서를 확인하고 활성 디스플레이 PNG/AX를 함께 고르면 다른 사례의 화면을 현재 목록 증거로 잘못 게시하지 않는다. 수동 Muscle Mass와 HealthKit Lean Body Mass는 저장 속성을 공유해도 화면과 AX에서 출처별로 구분한다.

[evidence.json](evidence.json)에서 원본 경로·기기·UID·해시를 확인한다. 어두운 외관, 영어 이외 앱 언어, VoiceOver 음성, 실사용 HealthKit 쓰기, iPhone/iPad MAX·Add와 Duo 펼침 MAX·Add는 이번 검증 범위가 아니다.
