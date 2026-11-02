/* Shared document navigation; source anchors and specimen controls stay intact. */
(() => {
  'use strict';
  const groups=['기준·공통','Today','Activity','Wellness','Life','Watch','위젯·실시간','Siri'];
  const rules=[['Siri',/siri/i],['위젯·실시간',/widget|live.activity|위젯|라이브/i],['Watch',/watch/i],['Today',/today|오늘|digest|notification/i],['Wellness',/wellness|stress|스트레스|수면/i],['Life',/\blife\b|habit|습관/i],['Activity',/activity|workout|cardio|running|exercise|운동|유산소|러닝/i]];
  const states=new WeakMap();
  const sectionObservers=new WeakMap();
  const text=node=>node.textContent.replace(/\s+/g,' ').trim();
  const make=(doc,tag,className,content)=>{const node=doc.createElement(tag);if(className)node.className=className;if(content!==undefined)node.textContent=content;return node;};
  const normalize=value=>value.normalize('NFKC').toLocaleLowerCase();
  function kind(href){return /\.md(?:[?#]|$)/i.test(href)?'설계 문서':/\.(png|jpe?g|webp)(?:[?#]|$)/i.test(href)?'화면 캡처':href.startsWith('#')?'본문 위치':'화면·맵';}
  function topic(label,href){const value=label+' '+href;return rules.find(([,pattern])=>pattern.test(value))?.[0]||groups[0];}
  function linkNavigator(doc,nav,links,index){
    const records=links.map(link=>({link,title:text(link),href:link.getAttribute('href'),group:topic(text(link),link.getAttribute('href'))}));
    const local=records.every(record=>record.href.startsWith('#'));
    nav.dataset.duneNavigation=local?'sections':links.length>12?'explorer':'quick';
    nav.classList.add('dune-document-nav');
    if(local){
      sectionObservers.get(nav)?.disconnect();
      const controller=new doc.defaultView.AbortController();
      let requested=null,observer;
      nav.setAttribute('aria-label',nav.getAttribute('aria-label')||'본문 바로가기');
      links.forEach(link=>link.classList.add('dune-section-link'));
      const targets=records.map(record=>{try{return doc.getElementById(decodeURIComponent(record.href.slice(1)));}catch{return null;}});
      const current=position=>links.forEach((link,i)=>{if(i===position)link.setAttribute('aria-current','location');else link.removeAttribute('aria-current');});
      const Observer=doc.defaultView?.IntersectionObserver;
      if(Observer){
        observer=new Observer(entries=>{
          if(requested){if(entries.some(entry=>entry.target===requested&&entry.isIntersecting)){current(targets.indexOf(requested));requested=null;}return;}
          const visible=entries.filter(entry=>entry.isIntersecting).sort((a,b)=>a.boundingClientRect.top-b.boundingClientRect.top);
          if(visible.length)current(targets.indexOf(visible[0].target));
        },{rootMargin:'-5% 0px -65% 0px'});
        targets.filter(Boolean).forEach(target=>observer.observe(target));
      }
      const cancel=()=>{requested=null;};
      doc.addEventListener('wheel',cancel,{passive:true,signal:controller.signal});
      doc.addEventListener('touchstart',cancel,{passive:true,signal:controller.signal});
      doc.addEventListener('keydown',event=>{if(['ArrowUp','ArrowDown','PageUp','PageDown','Home','End'].includes(event.key))cancel();},{signal:controller.signal});
      sectionObservers.set(nav,{disconnect:()=>{observer?.disconnect();controller.abort();}});
      links.forEach((link,i)=>link.addEventListener('click',event=>{
        if(event.button!==0||event.metaKey||event.ctrlKey||event.shiftKey||event.altKey||!targets[i])return;
        event.preventDefault();requested=targets[i];current(i);
        const view=doc.defaultView,offset=(doc.querySelector('.dune-document-toolbar')?.getBoundingClientRect().height||0)+16;
        view.scrollTo({top:Math.max(0,targets[i].getBoundingClientRect().top+view.scrollY-offset),behavior:view.matchMedia('(prefers-reduced-motion:reduce)').matches?'auto':'smooth'});
      },{signal:controller.signal}));
      return;
    }
    const large=links.length>12;
    const storageKey='dune-doc-navigation:'+doc.location.pathname+':'+index;
    let saved={};try{saved=JSON.parse(doc.defaultView.sessionStorage.getItem(storageKey)||'{}');}catch{}
    if(!saved||typeof saved!=='object'||Array.isArray(saved))saved={};
    let save=()=>{};
    const header=make(doc,'div','dune-nav-heading');
    const label=make(doc,'strong','',nav.getAttribute('aria-label')||'연결 문서');
    const count=make(doc,'span','dune-nav-total',links.length+'개');
    header.append(label,count);
    const panel=make(doc,'div','dune-nav-panel');panel.id='dune-nav-panel-'+index;
    let toggle;
    if(large){
      toggle=make(doc,'button','dune-nav-toggle','문서 찾기');toggle.type='button';toggle.setAttribute('aria-controls',panel.id);panel.hidden=saved.open!==true;toggle.setAttribute('aria-expanded',String(!panel.hidden));toggle.textContent=panel.hidden?'문서 찾기':'목록 접기';header.append(toggle);
      toggle.addEventListener('click',()=>{panel.hidden=!panel.hidden;toggle.setAttribute('aria-expanded',String(!panel.hidden));toggle.textContent=panel.hidden?'문서 찾기':'목록 접기';if(!panel.hidden)search.focus({preventScroll:true});save();});
    }
    const grid=make(doc,'div','dune-nav-grid');
    records.forEach(record=>{
      const label=make(doc,'span','dune-link-title',record.title);
      const detail=make(doc,'span','dune-link-kind',kind(record.href));
      record.link.replaceChildren(label,detail);record.link.classList.add('dune-document-link');record.link.title=record.title;grid.append(record.link);
    });
    let search,active=['전체',...groups].includes(saved.group)?saved.group:'전체',limit=Number.isInteger(saved.limit)?Math.max(6,Math.min(saved.limit,records.length)):6;
    if(large){
      const controls=make(doc,'div','dune-nav-controls');
      search=make(doc,'input','dune-nav-search');search.type='search';search.placeholder='제목 또는 경로로 찾기';search.setAttribute('aria-label','연결 문서 검색');search.setAttribute('aria-controls',panel.id+'-results');
      search.value=typeof saved.query==='string'?saved.query.slice(0,256):'';
      save=()=>{try{doc.defaultView.sessionStorage.setItem(storageKey,JSON.stringify({open:!panel.hidden,query:search.value,group:active,limit}));}catch{}};
      const tabs=make(doc,'div','dune-nav-groups');tabs.setAttribute('role','group');tabs.setAttribute('aria-label','연결 문서 주제');
      const status=make(doc,'span','dune-nav-status');status.setAttribute('role','status');
      const empty=make(doc,'div','dune-nav-empty');empty.hidden=true;
      empty.append(make(doc,'p','','일치하는 문서가 없습니다.'));
      const reset=make(doc,'button','','검색 초기화');reset.type='button';empty.append(reset);
      const more=make(doc,'button','dune-nav-more');more.type='button';
      grid.id=panel.id+'-results';
      const buttons=[];
      function render(){
        const terms=normalize(search.value).trim().split(/\s+/).filter(Boolean);
        const matches=records.filter(record=>(active==='전체'||record.group===active)&&terms.every(term=>normalize(record.title+' '+record.href).includes(term)));
        const shown=matches.slice(0,limit);
        records.forEach(record=>{record.link.hidden=!shown.includes(record);});
        status.textContent=matches.length+'개 중 '+shown.length+'개 표시';empty.hidden=matches.length>0;grid.hidden=!matches.length;
        more.hidden=matches.length<=limit;more.textContent='나머지 '+Math.max(0,matches.length-limit)+'개 더 보기';
        buttons.forEach(button=>button.setAttribute('aria-pressed',String(button.dataset.group===active)));
        save();
      }
      ['전체',...groups.filter(group=>records.some(record=>record.group===group))].forEach(group=>{
        const total=group==='전체'?records.length:records.filter(record=>record.group===group).length;
        const button=make(doc,'button','',group+' '+total);button.type='button';button.dataset.group=group;button.addEventListener('click',()=>{active=group;limit=6;render();});tabs.append(button);buttons.push(button);
      });
      search.addEventListener('input',()=>{limit=6;render();});
      search.addEventListener('keydown',event=>{
        if(event.key==='Escape'){event.preventDefault();event.stopPropagation();panel.hidden=true;toggle.setAttribute('aria-expanded','false');toggle.textContent='문서 찾기';toggle.focus({preventScroll:true});save();}
        if(event.key==='ArrowDown'){const first=records.find(record=>!record.link.hidden);if(first){event.preventDefault();first.link.focus({preventScroll:true});}}
      });
      reset.addEventListener('click',()=>{search.value='';active='전체';limit=6;render();search.focus({preventScroll:true});});
      more.addEventListener('click',()=>{const hidden=records.filter(record=>record.link.hidden);limit+=12;render();hidden.find(record=>!record.link.hidden)?.link.focus({preventScroll:true});});
      controls.append(search,tabs);panel.append(controls,grid,empty,make(doc,'div','dune-nav-footer'));panel.lastChild.append(status,more);
      render();
    }else panel.append(grid);
    nav.replaceChildren(header,panel);
  }
  function catalogue(doc,nav){
    nav.dataset.duneNavigation='catalogue';
    const search=make(doc,'input','dune-nav-search');search.type='search';search.placeholder='테마와 시안 찾기';search.setAttribute('aria-label','테마와 시안 검색');
    const storageKey='dune-doc-catalogue:'+doc.location.pathname+':'+(nav.id||nav.getAttribute('aria-label')||'themes');
    try{search.value=(doc.defaultView.sessionStorage.getItem(storageKey)||'').slice(0,256);}catch{}
    const result=make(doc,'span','dune-nav-status');result.setAttribute('role','status');
    const reset=make(doc,'button','dune-catalogue-reset','검색 초기화');reset.type='button';
    const empty=make(doc,'div','dune-nav-empty');empty.hidden=true;empty.append(make(doc,'p','','일치하는 테마나 시안이 없습니다.'));
    const filter=()=>{
      const terms=normalize(search.value).trim().split(/\s+/).filter(Boolean),cards=[...nav.querySelectorAll('.theme-card,.study')];
      let count=0;
      cards.forEach(card=>{card.hidden=!terms.every(term=>normalize(text(card)).includes(term));if(!card.hidden)count++;});
      result.textContent=count+'개 항목';empty.hidden=count>0;reset.hidden=!search.value;
      try{doc.defaultView.sessionStorage.setItem(storageKey,search.value);}catch{}
    };
    const clear=()=>{search.value='';filter();search.focus({preventScroll:true});};
    const meta=make(doc,'div','dune-catalogue-meta');meta.append(result,reset);
    const bar=make(doc,'div','dune-catalogue-search');bar.append(search,meta,empty);nav.querySelector('.catalog-title')?.after(bar);
    search.addEventListener('input',filter);reset.addEventListener('click',clear);
    search.addEventListener('keydown',event=>{if(event.key==='Escape'){event.preventDefault();event.stopPropagation();clear();}});
    filter();
    const Observer=doc.defaultView?.MutationObserver;
    if(Observer&&nav.querySelector('#theme-list'))new Observer(filter).observe(nav.querySelector('#theme-list'),{childList:true});
  }
  function enhance(doc,{selectors=[]}={}){
    if(!doc.body)return;
    // A viewport class on body (e.g. body.phone) must never exempt the whole document.
    [doc.documentElement,doc.body].forEach(node=>node.removeAttribute('data-dune-artifact'));
    if(selectors.length)doc.querySelectorAll(selectors.join(',')).forEach(node=>{if(node!==doc.body&&node!==doc.documentElement&&!node.hasAttribute('data-dune-artifact'))node.setAttribute('data-dune-artifact','');});
    let state=states.get(doc);if(!state){state={index:0,surfaces:new WeakSet()};states.set(doc,state);}
    doc.querySelectorAll('article,section,aside,header,footer,nav,main,div,li,table,thead,tbody,tr,td,th,figure,p,blockquote,details').forEach(node=>{
      if(state.surfaces.has(node)||node.hasAttribute('data-dune-surface')||node.closest('[data-dune-artifact]'))return;
      state.surfaces.add(node);
      const background=doc.defaultView.getComputedStyle(node).backgroundColor;
      if(background!=='transparent'&&background!=='rgba(0, 0, 0, 0)')node.setAttribute('data-dune-surface','');
    });
    doc.querySelectorAll('nav,.links,.nav-links,.related-links,.link-list').forEach(nav=>{
      if(nav.dataset.duneNavigation==='sections'&&[...nav.querySelectorAll('a[href]')].some(link=>!link.classList.contains('dune-section-link'))){sectionObservers.get(nav)?.disconnect();nav.removeAttribute('data-dune-navigation');}
      if(nav.dataset.duneNavigation||nav.closest('[data-dune-artifact]'))return;
      if(nav.matches('.catalog')){catalogue(doc,nav);return;}
      if(nav.querySelector('button,input,select,iframe,img'))return;
      const links=[...nav.querySelectorAll('a[href]')];
      if(!links.length||(links.length<3&&!links.every(link=>link.getAttribute('href').startsWith('#'))))return;
      linkNavigator(doc,nav,links,++state.index);
    });
    doc.querySelectorAll('.toolbar,.controls,.compare-controls').forEach(toolbar=>{
      if(!toolbar.closest('[data-dune-artifact]'))toolbar.classList.add('dune-document-toolbar');
    });
    doc.querySelectorAll('.capture-links').forEach(node=>{if(!node.closest('[data-dune-artifact]'))node.classList.add('dune-capture-links');});
  }
  window.DUNEDocumentUX={enhance};
})();
