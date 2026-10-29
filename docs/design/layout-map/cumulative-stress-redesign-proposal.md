# T05 누적 스트레스 상세 개편 계약

대상은 iPhone·iPad·Duo 접힘/펼침의 기존 CumulativeStressDetailView다. 원본 사용자 검토 T05 JSON은 theme assets에 보존한다. 시안의38점/고정7일 값은 앱 seed로 사용하지 않는다.

1. 동일 ScoreHeroPalette·104pt 링·실제 현재 점수·원래 level icon/이름·guide·windowDays·평가 시각. 큰 글씨는 숫자/상태 세로 배치.
2. 기존 해석/가이드 전체 유지, 요인3개는 원래 icon/color/detail·원점수·0–100 막대. 표시는 가용 요인의 실제 반영 비중이며 기본40/35/25 설명과 구분한다. 기록 없는 요인을 만들어 넣지 않는다.
3. 기존4단계 의미/현재 위치 보존.
4. 한 추세 카드: 제목/추세 →5기간 →44pt 이전/날짜/다음 →chart →같은 가시 구간 평균/최저/최고/이전 비교. 날짜 반복 없음. chart 내부 ScaledMetric 높이를 더 작은 frame으로 감싸지 않는다.
5. 실제 가시 구간 high/low/trend. day는 hour/minute를 함께 표시해 같은 날 구분. 스트레스 높은 값은 성취/좋은 변화로 꾸미지 않는다.
6. 하나의 native DisclosureGroup에서 현재 실제 반영 비중과 기본 모델40/35/25, 기존4개 전체 설명을 함께 읽는다. 중첩 펼침 없음.

카드 간격은 기본 DS.Spacing.xl, 내부 DS.md/lg로 명시한다. regular는 읽기 폭 안에서 hero/해석과 요인 카드가 자연스럽게 분리되며 AX는 한 열로 전환한다. 색만으로 의미를 전달하지 않고 실제 상태/점수를 남긴다. 장식은 비인터랙티브·접근성 숨김이며 Reduce Motion에서는 불필요한 반복 움직임이 없다.

가시 범위는 shared fixed duration, 통계는 실제 hour/day source, long chart bucket은 통계가 아니다. loading/empty/error를 구분하고 retry는 현재 기간 재조회다. 새 실제 캡처는 T05만 갱신하며 다른 화면·포털 링크를 보존한다. 기존 PNG는 이전 비교이며 새 증거로 사용하지 않는다.

검증 계획/데이터 정책은 ../../plans/2026-10-30-t05-cumulative-stress-redesign.md를 따른다. 이 계약과 theme HTML은 앱 실제 캡처가 아니다.
