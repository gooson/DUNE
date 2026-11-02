(() => {
  'use strict';
  const byID = id => document.getElementById(id);
  const pages = [...document.querySelectorAll('.page')];
  const names = { overview: '개요', siri: 'Siri 연동', library: '전체 문서 색인', document: '문서' };
  const scrollPositions = new Map();
  let activePage;
  if ('scrollRestoration' in history) history.scrollRestoration = 'manual';
  function showPage() {
    const anchor = location.hash.slice(1) || 'overview';
    const selected = anchor.startsWith('doc=') ? 'document' : (anchor === 'maps' ? 'overview' : (names[anchor] ? anchor : 'overview'));
    if (activePage === 'library' && activePage !== selected) scrollPositions.set(activePage, window.scrollY);
    pages.forEach(page => { page.hidden = page.id !== selected; });
    document.querySelectorAll('nav [data-view]').forEach(link => {
      if (link.dataset.view === (selected === 'document' ? 'library' : selected)) link.setAttribute('aria-current', 'page');
      else link.removeAttribute('aria-current');
    });
    byID('breadcrumb-current').textContent = names[selected];
    document.title = `DUNE · ${names[selected]}`;
    if (anchor === 'maps') byID('maps').scrollIntoView();
    else if (selected !== 'document') window.scrollTo(0, scrollPositions.get(selected) || 0);
    activePage = selected;
  }
  window.addEventListener('hashchange', showPage);
  showPage();

  const routes = {
    typed: {
      title: '정형 요청을 직접 조회',
      description: 'QueryHealthInformationIntent → HealthQueryService',
      context: '단축어에서 조회 종류·기간·운동·검색어를 지정합니다. 14종 중 7종은 개별 앱 단축어로도 등록되어 있습니다.',
      source: 'DUNE/App/Intents/HealthQueryIntent.swift',
      steps: [['접근 확인', '기기 인증 및 보호 데이터 접근 여부 확인'], ['요청 구성', '종류·기간·비교 기간·운동 ID·검색어 전달'], ['조회·집계', 'HealthKit·SwiftData 원본 검증 및 계산'], ['응답 반환', '구조화된 값·낭독 요약·결과 카드 제공']],
      note: '응답 전 보호 데이터 접근을 재확인합니다. 결과는 메모리에 최대 8개 보관하며 보호 데이터 잠금 시 삭제합니다.'
    },
    ask: {
      title: '자연어 해석과 데이터 조회를 분리',
      description: 'AskDUNEHealthIntent → HealthQueryAssistant → HealthQueryService',
      context: '질문은 앞뒤 공백 제거 후 1–500자로 제한합니다. 고정 문구에 해당하지 않으면 기기 내 모델 사용 가능 여부와 언어 지원을 확인합니다.',
      source: 'DUNE/Data/Services/HealthQueryAssistant.swift',
      steps: [['질문 입력', '인증·보호 데이터 확인 후 질문 전달. 앱 화면 문맥은 nil'], ['조건 해석', '모델이 조회 종류·기간·검색어를 해석. SDK 27에서 도구 호출 1회 허용'], ['검증·조회', '허용된 기간·ID·비교 조건을 검증하고 원본 기록 조회'], ['실제 결과 반환', '모델의 자유 답변 대신 앱이 구성한 결과와 요약 반환']],
      note: '모델 미지원·해석 불가 상태를 구분합니다. PCC는 비활성이며 긴 작업은 지원 OS에서 background task로 처리합니다.'
    },
    fallback: {
      title: '정확히 일치하는 고정 문구를 직접 처리',
      description: 'AskDUNEHealthIntent → fallbackRequest → HealthQueryService',
      context: '최근 운동 · 최근 신체 기록 · 오늘 컨디션 · 어젯밤 수면. 영어·한국어·일본어의 정해진 표현에 정확히 일치할 때 사용합니다.',
      source: 'DUNE/Data/Services/HealthQueryAssistant.swift',
      steps: [['문구 정리', '앞뒤 공백 제거 및 영문 소문자 변환'], ['정확한 매칭', '네 종류의 고정 표현과 일치 여부 확인'], ['기간 확정', '최근 기록은 365일, 컨디션·어젯밤 수면은 오늘에 귀속'], ['직접 조회', '정형 조회와 같은 서비스에서 실제 기록을 읽어 결과 반환']],
      note: '“오늘 컨디션”은 고정 표현입니다. “오늘 컨디션 어때?”처럼 다른 문장은 자연어 해석이 필요할 수 있습니다.'
    },
    template: {
      title: '저장한 운동 템플릿으로 이동',
      description: 'OpenWorkoutTemplateIntent → onAppIntentExecution → 앱 내 이동',
      context: 'WorkoutTemplateEntity가 실제 저장된 템플릿의 ID와 이름을 제공합니다. 운동 자동 시작이 아닌 템플릿 열기 동작입니다.',
      source: 'DUNE/App/Intents/DUNEShortcuts.swift',
      steps: [['대상 선택', 'EntityQuery가 저장소의 실제 템플릿을 제안'], ['대상 검증', '실행 직전 템플릿 ID의 유효성 재확인'], ['앱 전달', 'OpenIntent가 앱 콘텐츠 열기 경로 사용'], ['화면 이동', '앱이 Intent 실행을 받아 선택된 템플릿으로 이동']],
      note: '삭제된 템플릿은 찾을 수 없는 상태로 처리합니다. 템플릿 열기는 운동 시작·기록 저장 완료를 의미하지 않습니다.'
    },
    habit: {
      title: '수동 체크 습관을 오늘 완료로 저장',
      description: 'CompleteHabitIntent → DUNEAppIntentStore.completeHabit',
      context: '수동 체크형 습관만 대상입니다. 이미 완료한 습관을 재실행해도 완료를 취소하지 않는 멱등 동작입니다.',
      source: 'DUNE/App/Intents/DUNEAppIntentStore.swift',
      steps: [['인증·선택', '기기 인증 후 수동 체크 습관 Entity 전달'], ['습관 검증', '저장소 ID와 수동 체크 가능 여부 재확인'], ['저장', '오늘 완료 로그가 없으면 생성·save. 오류 시 rollback'], ['상태 응답', '새 완료와 오늘 이미 완료된 상태를 구분하여 안내']],
      note: '건강 조회와 달리 데이터를 쓰는 경로입니다. 같은 날 반복 실행해도 완료 로그를 중복 생성하거나 완료를 취소하지 않습니다.'
    }
  };
  byID('route').disabled = false;
  byID('route').addEventListener('change', event => {
    const route = routes[event.target.value];
    for (const key of ['title', 'description', 'context', 'note']) byID('route-' + key).textContent = route[key];
    byID('route-source').href = route.source;
    byID('route-source').textContent = route.source.split('/').pop() + ' →';
    byID('route-flow').replaceChildren(...route.steps.map(([title, body]) => {
      const item = document.createElement('li');
      const heading = document.createElement('b'); heading.textContent = title;
      const detail = document.createElement('span'); detail.textContent = body;
      item.append(heading, detail); return item;
    }));
  });

  const rows = [...document.querySelectorAll('.doc-row')];
  const search = byID('search');
  const group = byID('group-filter');
  const topic = byID('topic-filter');
  const normalize = text => text.normalize('NFKC').toLocaleLowerCase().trim();
  const index = rows.map((row, position) => ({row, position, text: normalize(row.textContent + ' ' + row.dataset.path)}));
  function filter() {
    const terms = normalize(search.value).split(/\s+/).filter(Boolean);
    let count = 0;
    index.forEach(({row, text}) => {
      const visible = (group.value === 'all' || row.dataset.group === group.value) && (topic.value === 'all' || row.dataset.topic === topic.value) && terms.every(term => text.includes(term));
      row.hidden = !visible;
      if (visible) count++;
    });
    byID('result-count').textContent = `${count}개 표시 / 전체 ${rows.length}개`;
    byID('empty').hidden = count > 0;
  }
  function sort() {
    const mode = byID('sort').value;
    const ordered = [...index].sort((a, b) => {
      if (mode === 'date') return b.row.dataset.date.localeCompare(a.row.dataset.date) || a.position - b.position;
      if (mode === 'title') return a.row.querySelector('.document-title').textContent.localeCompare(b.row.querySelector('.document-title').textContent, 'ko') || a.position - b.position;
      return a.position - b.position;
    });
    byID('catalog').append(...ordered.map(entry => entry.row));
  }
  function reset() {
    search.value = ''; group.value = 'all'; topic.value = 'all'; byID('sort').value = 'system';
    sort(); filter(); search.focus();
  }
  search.disabled = false;
  byID('library-controls').hidden = false;
  search.addEventListener('input', filter);
  group.addEventListener('change', filter);
  topic.addEventListener('change', filter);
  byID('sort').addEventListener('change', sort);
  byID('reset').addEventListener('click', reset);
  byID('empty-reset').addEventListener('click', reset);
  filter();

})();
