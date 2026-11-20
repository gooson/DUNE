# R02 native design evidence

XCTest manifest에 연결된 개별 성공 receipt와 정확한 selector·첨부 이름으로 15개 PNG를 수집했다. PNG는 실제 화면 첨부 원본이다. 육안 검토: 원본 화면 검토 완료.

- Source revision: `772b22affeb78f970d3b31b388e2db6bb31e73f4`; build revision: `9d56a10d504b9970029186331187604a962cf472,1df57fcfd77f4a6a385fb80f626a872956185f3c,676e10da12b4cc957e8cb6eb516fbee14af5035f,dfea466897aefd82e290e29b81531b027a2b2258,0a266b6ad3dedb4b8cb2e990f9e27cb77a54a871`.
- Combined build: `true`. Combined build: feature-specific source attribution requires separate verification. 기능별 PR의 변경을 합친 검증 빌드에서 촬영했습니다. 각 이미지의 정확한 빌드와 실행 근거는 evidence.json에 있습니다.
- Fixture: `최근 7일의 수면 기록 1·2·4·7일과 선택한 누락일`; locale: `화면별 테스트 언어`; appearance: `화면별 테스트 설정`.
- Unverified devices: none by device; states still require review; screen IDs: none by screen ID.
- Uncaptured named states: ipad: H01-sleep-0-records, H01-sleep-1-records, H01-sleep-2-records, H01-sleep-2-records-MaxAX, H01-sleep-2-records-dark, H01-sleep-4-records, H01-sleep-7-records; duo: H01-sleep-0-records, H01-sleep-1-records, H01-sleep-2-records, H01-sleep-2-records-MaxAX, H01-sleep-2-records-dark, H01-sleep-4-records, H01-sleep-7-records; duo-open: H01-sleep-0-records, H01-sleep-1-records, H01-sleep-2-records, H01-sleep-2-records-MaxAX, H01-sleep-2-records-dark, H01-sleep-4-records, H01-sleep-7-records. Other states not present in evidence.json are unverified.
- Per-asset selector, device, timestamp, SHA-256 and dimensions: `evidence.json`.

## 원본 화면 검토

- 최근 수면 시간·날짜와 관측일 수가 보인다. 기록 수에 따라 일곱 날짜 중 측정한 날에만 막대가 있고, 누락일을 선택하면 한국어·영어에서 날짜와 기록 부재가 함께 표시된다.
- 기록이 없을 때 Need More Data와 Recorded 0 of 7 nights가 표시된다.
- 어두운 테마의 최대 접근성 글씨에서 시간과 평균이 줄바꿈되고 15·18·21 날짜 및 두 막대가 보인다.
- 어두운 테마 기본 글씨의 원본에는 최근 수면 카드 상단과 최신 시간이 보인다. 아래 그래프는 이 캡처의 화면 밖에 있다.
- iPad mini 영어·한국어 원본 캡처: 최근 수면 7시간 54분과 7일 평균 7시간 30분이 큰 값으로 보이고, 2/7 기록·선택한 11월 18일 기록 없음·7일 막대 두 개가 카드 안에 온전히 보인다.
- Duo 접힘 LCD 1398×2034 원본 영어·한국어 캡처: 최근 수면과 7일 평균이 큰 값으로 읽히고 2/7 관측, 선택한 18일 기록 없음, 17·21일 막대가 표시된다. 오른쪽 도킹 영역과 겹침은 없으며 하단 날짜 일부는 스크롤 범위 밖에 있다.
- Duo 펼침 활성 LCD-1 2853×2007 물리 프레임 영어·한국어 원본: 두 언어 모두 최근 7시간 54분, 7일 평균 7시간 30분, 관측 2/7, 선택한 18일 기록 없음과 실제 두 막대가 두 열 카드에서 잘림 없이 읽힌다.
