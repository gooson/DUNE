(() => {
  'use strict';
  const root=document.documentElement;
  const $=id=>document.getElementById(id);
  const system=matchMedia('(prefers-color-scheme:dark)');
  const mobile=matchMedia('(max-width:950px)');
  const appearance=[...document.querySelectorAll('[data-appearance]')];
  const store=(key,value)=>{try{localStorage.setItem(key,value);}catch{}};
  function applyAppearance(preference, persist=true){
    if(!['system','light','dark'].includes(preference))preference='system';
    root.dataset.themePreference=preference;
    root.dataset.theme=preference==='system'?(system.matches?'dark':'light'):preference;
    appearance.forEach(button=>button.setAttribute('aria-pressed',String(button.dataset.appearance===preference)));
    if(persist)store('dune-dashboard-appearance',preference);
    document.dispatchEvent(new Event('dune:appearance'));
  }
  appearance.forEach(button=>button.addEventListener('click',()=>applyAppearance(button.dataset.appearance)));
  system.addEventListener('change',()=>{if(root.dataset.themePreference==='system')applyAppearance('system',false);});
  window.addEventListener('storage',event=>{if(event.key==='dune-dashboard-appearance')applyAppearance(event.newValue||'system',false);});
  applyAppearance(root.dataset.themePreference||'system',false);

  function drawer(open){
    document.body.classList.toggle('sidebar-open',open);
    $('menu-scrim').hidden=!open;
    $('mobile-menu').setAttribute('aria-expanded',String(open));
    $('docs-sidebar').setAttribute('aria-hidden',String(mobile.matches&&!open));
    if(open){document.querySelector('.workspace').inert=true;$('docs-sidebar').querySelector('a').focus();}
    else{document.querySelector('.workspace').inert=false;}
  }
  function sidebarState(){
    const collapsed=root.dataset.sidebar==='collapsed';
    $('sidebar-fold').setAttribute('aria-label',mobile.matches?'메뉴 닫기':collapsed?'사이드바 펼치기':'사이드바 접기');
    $('sidebar-fold').title=mobile.matches?'메뉴 닫기':collapsed?'사이드바 펼치기':'사이드바 접기';
    document.querySelectorAll('.sidebar nav a').forEach(a=>a.title=a.textContent.trim());
    $('docs-sidebar').setAttribute('aria-hidden',String(mobile.matches&&!document.body.classList.contains('sidebar-open')));
  }
  $('sidebar-fold').addEventListener('click',()=>{
    if(mobile.matches){drawer(false);$('mobile-menu').focus();return;}
    root.dataset.sidebar=root.dataset.sidebar==='collapsed'?'expanded':'collapsed';
    store('dune-dashboard-sidebar',root.dataset.sidebar);sidebarState();
  });
  $('mobile-menu').addEventListener('click',()=>drawer(!document.body.classList.contains('sidebar-open')));
  $('menu-scrim').addEventListener('click',()=>{drawer(false);$('mobile-menu').focus();});
  $('docs-sidebar').addEventListener('click',event=>{if(mobile.matches&&event.target.closest('a'))drawer(false);});
  mobile.addEventListener('change',()=>{drawer(false);sidebarState();});
  document.addEventListener('keydown',event=>{
    if(event.key==='Escape'&&document.body.classList.contains('sidebar-open')){drawer(false);$('mobile-menu').focus();}
    if(event.key==='Tab'&&document.body.classList.contains('sidebar-open')){
      const focusable=[...$('docs-sidebar').querySelectorAll('a,button,summary')].filter(node=>node.getClientRects().length);
      const first=focusable[0],last=focusable.at(-1);
      if(event.shiftKey&&document.activeElement===first){event.preventDefault();last.focus();}
      else if(!event.shiftKey&&document.activeElement===last){event.preventDefault();first.focus();}
    }
  });
  sidebarState();

  const palette=$('command-palette'),input=$('command-search'),results=$('command-results');
  const documents=JSON.parse($('document-data').textContent);
  const normalize=value=>value.normalize('NFKC').toLocaleLowerCase().trim();
  let options=[],active=0,trigger;
  const icon='<svg viewBox="0 0 20 20" aria-hidden="true"><path d="M4 3h9l3 3v11H4V3Zm9 0v4h3M7 10h6m-6 3h6"/></svg>';
  function select(position){
    if(!options.length)return;
    active=(position+options.length)%options.length;
    options.forEach((option,index)=>option.setAttribute('aria-selected',String(index===active)));
    input.setAttribute('aria-activedescendant',options[active].id);
    options[active].scrollIntoView({block:'nearest'});
  }
  function search(){
    const terms=normalize(input.value).split(/\s+/).filter(Boolean);
    const matches=documents.filter(doc=>terms.every(term=>normalize(doc.title+' '+doc.topic+' '+doc.path+' '+doc.group).includes(term)));
    const shown=matches.slice(0,14);results.replaceChildren();options=[];
    $('command-count').textContent=terms.length?matches.length+'개 문서': '문서 바로가기';
    input.removeAttribute('aria-activedescendant');
    shown.forEach((doc,index)=>{
      const a=document.createElement('a');a.className='command-result';a.href=doc.href;a.id='command-result-'+index;a.role='option';a.tabIndex=-1;
      const symbol=document.createElement('span');symbol.innerHTML=icon;
      const copy=document.createElement('span'),title=document.createElement('strong'),detail=document.createElement('small'),kind=document.createElement('span');
      title.textContent=doc.title;detail.textContent=doc.topic;copy.append(title,detail);kind.textContent=doc.group;kind.className='result-kind';
      a.append(symbol,copy,kind);a.addEventListener('pointermove',()=>select(index));a.addEventListener('click',()=>palette.close());results.append(a);options.push(a);
    });
    if(!shown.length){const empty=document.createElement('p');empty.className='command-empty';empty.textContent='일치하는 문서가 없습니다.';results.append(empty);}
    active=0;select(0);
  }
  function open(){
    if(palette.open)return;
    trigger=document.activeElement;if(mobile.matches)drawer(false);
    input.value='';palette.showModal();input.setAttribute('aria-expanded','true');search();input.focus();
  }
  $('open-command').addEventListener('click',open);
  document.addEventListener('dune:command',open);
  $('command-close').addEventListener('click',()=>palette.close());
  palette.addEventListener('keydown',event=>{if(event.key==='Escape'){event.preventDefault();palette.close();}});
  palette.addEventListener('close',()=>{input.setAttribute('aria-expanded','false');trigger?.focus?.();});
  input.addEventListener('input',search);
  input.addEventListener('keydown',event=>{
    if(event.key==='ArrowDown'){event.preventDefault();select(active+1);}
    if(event.key==='ArrowUp'){event.preventDefault();select(active-1);}
    if(event.key==='Enter'&&options[active]){event.preventDefault();options[active].click();}
  });
  document.addEventListener('keydown',event=>{if((event.metaKey||event.ctrlKey)&&event.key.toLowerCase()==='k'){event.preventDefault();if(palette.open)palette.close();else open();}});
})();
