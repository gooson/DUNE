# T04 컨디션 상세 개편 계약

검토 시안: 원본 detail-redesign-map의 T04. 원본 데이터는 이 작업의 테마 assets에 화면 단위로 보존하며 native 예시 데이터로 사용하지 않는다.

1. 평가 점수: 탭과 같은 CompactConditionRing, 원래 상태 심볼/상태, 실제 평가 시점과 narrative. 접근성 글씨에서는 읽을 수 있는 숫자/상태를 우선한다.
2. 기여 요인: HRV·RHR 기존 심볼, 실제 단위, 모델의 영향 상태와 원래 설명. 이전 RHR이면 별도 측정 날짜를 표시한다.
3. 점수 해석과 시간대 projection은 의미를 유지한다. projection은 unclamped rawScore에서 현재 시간 조정만 제거해 산출한다.
4. 한 추세 카드: 제목·추세 전환 →5개 기간 → 이전/날짜/다음 → 차트 → 같은 가시 구간의 평균/최저/최고/이전 비교. 날짜는 한 곳에 표시한다. 스크롤·선택·기간 이동을 유지한다.
5. 하이라이트와 일간 외 하위 HRV/RHR 추세.
6. 실제 점수 구성: HRV Z-score·RHR/time 조정. 근거 없는70/30 비율과 이중 RHR 합산은 표시하지 않는다.
7. native 단일 설명 펼침: 계산 전체 행과 기존4개 설명 항목. 펼침/접힘 chevron과44pt 조작 영역.

가용 폭과 Dynamic Type으로 배치하며 iPad/Duo에서도 필요한 텍스트를 생략하지 않는다. 새 실제 캡처는 일반 iPhone/iPad/Duo 접힘·펼침의 T04만 갱신하고 기존 다른 화면/포털 링크를 보존한다.

## Native Resolve 배치 계약

- 고정 길이의 가시 구간과 한 번 캡처한 참조 시점을 공유해 날짜·차트·요약을 맞춘다. 월말/DST에서도 이전·다음은 완전한 구간 하나씩만 이동한다.
- 날짜는 locale-aware interval formatter로 한 번 표시하고 요약 행에서 반복하지 않는다.
- 차트의 높이는 `DotLineChartView`의 ScaledMetric이 결정한다. 소비 화면이 더 작은 고정 frame으로 감싸 AX 차트를 주변 조작 영역에 넘치게 하지 않는다.
- 이전·다음 및 추세 전환은 최소44pt frame 안에 Rectangle contentShape를 둔다.
- 계산·기존 설명은 하나의 native DisclosureGroup에 보존한다.
