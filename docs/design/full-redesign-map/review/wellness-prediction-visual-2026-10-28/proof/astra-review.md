---
tags: [wellness, prediction, astra, review]
date: 2026-10-28
category: solution
status: reviewed
---

# Astra 읽기 전용 더블 체크

- 모델: gpt-6-astra, high. 사용자 명시 요청에 따라 카드 범위로 한정했다.
- 대상: `WellnessSleepPredictionCard.swift`, 예측 모델·계획, 실제 iPhone37점 다크 전체 카드와0/78/100 PNG.
- 결과: P1/P2 발견 없음. 큰 점수·달 패널·게이지가 시선을 잡고, 신뢰도와 팁을 별도 영역으로 구분해 텍스트 중심의 휑한 느낌을 해결한다.
- 의미: 게이지와 신뢰도1/2/3칸이 모델값에 대응하며 가상 단계·추세·확률을 암시하지 않는다. 상세와 펼침은 코드상 분리되어 있다.
- 제한: 밝은 화면 일부는 스크롤로 상단이 가려져 전체 카드 증거로 부족하다. Astra는 큰 글씨의 실제 배치·VoiceOver를 확인하지 않았다. 이후 parent가 큰 글씨 캡처를 별도로 확인한다.
- 소스·문서 수정, 추가 테스트 실행 없음.
