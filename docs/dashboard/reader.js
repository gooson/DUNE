(() => {
  'use strict';
  const $ = id => document.getElementById(id);
  const documents = JSON.parse($('document-data').textContent);
  const byPath = new Map(documents.map(doc => [doc.path, doc]));
  const root = new URL('.', location.href);
  const supported = /\.(html?|md|swift|json|txt|py|sh|css|js|png|jpe?g|webp|gif|svg|pdf)$/i;
  let current = null;
  let returnHash = '#library';
  let request = null;
  let loadTimer;
  let loadRevision = 0;
  let trail = [location.hash || '#overview'];
  let trailCursor = 0;

  function replaceFrame(url) {
    const frame = $('document-frame');
    frame.dataset.documentUrl = url;
    // Replacing the child entry keeps browser Back/Forward on document routes.
    try { frame.contentWindow.location.replace(url); }
    catch { frame.src = url; }
  }

  function localFile(value, base = root) {
    try {
      let url = new URL(value, base);
      url.searchParams.delete('_dune');
      if (url.origin !== root.origin || url.protocol !== root.protocol || !url.pathname.startsWith(root.pathname)) return null;
      let path = decodeURIComponent(url.pathname.slice(root.pathname.length));
      if (!supported.test(path) || path.split('/').some(part => part.startsWith('.') || part === '..')) return null;
      for (let hop=0;hop<4 && byPath.get(path)?.redirect;hop++) {
        path=byPath.get(path).redirect;url=new URL(path,root);
      }
      return {url, path, query:url.search, anchor:decodeURIComponent(url.hash.slice(1))};
    } catch { return null; }
  }
  function hashFor(file) {
    const params = new URLSearchParams({doc:file.path});
    if (file.query) params.set('query', file.query);
    if (file.anchor) params.set('anchor', file.anchor);
    return '#' + params.toString();
  }
  function metaFor(path) {
    const subject = path.includes('siri') ? 'Siri · 건강 조회' : parentFor(path)?.topic || '';
    return byPath.get(path) || {path, href:path, title:decodeURIComponent(path.split('/').pop()).replace(/\.(md|swift|json|txt)$/i, ''), group:path.endsWith('.md') ? '기술 문서' : '원본 자료', topic:subject, links:[]};
  }
  function openDocument(value, base = root) {
    const file = localFile(value, base);
    if (!file) return false;
    if (!location.hash.startsWith('#doc=')) returnHash = location.hash || '#overview';
    const hash = hashFor(file);
    if (location.hash === hash) return true;
    location.hash = hash;
    return true;
  }
  function internalLink(path, label, detail) {
    const a = document.createElement('a');
    a.href = new URL(path, root).href;
    a.textContent = label;
    if (detail) { const small = document.createElement('small'); small.textContent = detail; a.append(small); }
    return a;
  }
  function parentFor(path) {
    let directory = path.slice(0, path.lastIndexOf('/'));
    if (path.endsWith('/index.html')) directory = directory.slice(0, directory.lastIndexOf('/'));
    while (directory) {
      const candidate = directory + '/index.html';
      if (byPath.has(candidate)) return byPath.get(candidate);
      directory = directory.slice(0, directory.lastIndexOf('/'));
    }
    if (path.startsWith('docs/reviews/')) return byPath.get('docs/design/full-redesign-map/index.html');
    return null;
  }
  function fillLinks(container, entries, message) {
    container.replaceChildren();
    if (!entries.length) { const p = document.createElement('p'); p.textContent = message; container.append(p); return; }
    entries.forEach(doc => container.append(internalLink(doc.path, doc.title, doc.group)));
  }
  function navigation(meta) {
    $('document-title').textContent = meta.title;
    $('document-category').textContent = meta.group;
    $('document-category').dataset.kind = meta.group;
    $('document-path').textContent = meta.path;
    $('document-original').href = new URL(meta.path, root).href;
    $('reader-error-original').href = new URL(meta.path, root).href;
    $('reader-return').href = returnHash;
    $('reader-return').textContent = returnHash === '#siri' ? 'Siri 연동' : returnHash === '#overview' || returnHash === '#maps' ? '프로젝트 문서' : '문서 색인';
    $('breadcrumb-current').textContent = '문서 보기';
    document.title = 'DUNE · ' + meta.title;
    const parent = parentFor(meta.path);
    $('document-parent').textContent = parent?.title || '전체 문서';
    $('document-parent').href = parent ? new URL(parent.path, root).href : '#library';
    const linked = (meta.links || []).filter(path => /\.(html?|md|swift|json)$/i.test(path) && path !== meta.path).map(metaFor);
    fillLinks($('document-links'), linked.slice(0, 14), '본문의 원본 링크를 이용할 수 있습니다.');
    const related = documents.filter(doc => doc.path !== meta.path && !linked.some(item => item.path === doc.path) && doc.topic === meta.topic).sort((a,b) => Number(b.group !== meta.group) - Number(a.group !== meta.group) || b.date.localeCompare(a.date));
    fillLinks($('document-related'), related.slice(0, 6), '문서 색인에서 다른 자료를 탐색할 수 있습니다.');
    const siblings = documents.filter(doc => doc.topic === meta.topic);
    const position = siblings.findIndex(doc => doc.path === meta.path);
    [['document-previous', siblings[position - 1], '← 이전 문서'], ['document-next', position >= 0 ? siblings[position + 1] : null, '다음 문서 →']].forEach(([id,doc,label]) => {
      const a = $(id); a.hidden = !doc;
      if (doc) { a.href = new URL(doc.path,root).href; const small = document.createElement('small'); small.textContent = label; a.replaceChildren(small, document.createTextNode(doc.title)); }
    });
  }
  function setOutline(headings, scrollTo) {
    const nav = $('document-outline'); nav.replaceChildren();
    if (!headings.length) {const p=document.createElement('p');p.textContent='문서 본문에서 내용을 확인할 수 있습니다.';nav.append(p);return;}
    headings.slice(0, 16).forEach((heading, i) => {
      if (!heading.id) heading.id = 'dune-section-' + i;
      const a = document.createElement('a'); a.href = '#' + heading.id; a.textContent = heading.textContent.trim();
      a.addEventListener('click', event => {event.preventDefault();scrollTo(heading);}); nav.append(a);
    });
  }
  function intercept(event, base) {
    if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    const anchor = event.target.closest?.('a[href]');
    if (!anchor || anchor.hasAttribute('download') || anchor.id === 'document-original' || anchor.id === 'reader-error-original') return;
    const raw = anchor.getAttribute('href');
    if (!raw || raw.startsWith('#')) return;
    try {
      const target = new URL(raw, base);
      if (target.origin === root.origin && target.pathname === new URL('index.html', root).pathname) {
        event.preventDefault(); location.hash = target.hash || '#overview'; return;
      }
    } catch { return; }
    if (openDocument(raw, base)) event.preventDefault();
  }
  document.addEventListener('click', event => intercept(event, root));

  function bindFrame(frame, revision, primary = false) {
    if (revision !== loadRevision) return;
    try {
      const doc = frame.contentDocument;
      if (!doc) return;
      const base = new URL(frame.contentWindow.location.href);
      if (base.href === 'about:blank') return;
      const file=localFile(base);
      window.DUNEDesignSystem.apply(doc, file ? metaFor(file.path) : {});
      doc.addEventListener('click', event => intercept(event, base));
      doc.addEventListener('keydown',event=>{if((event.metaKey||event.ctrlKey)&&event.key.toLowerCase()==='k'){event.preventDefault();document.dispatchEvent(new Event('dune:command'));}});
      let outlineHeadings=[],outlineLabels=[];
      const refreshOutline=()=>{
        if(!primary)return;
        const headings=[...doc.querySelectorAll('h1,h2,h3')].filter(heading=>heading.textContent.trim()&&!heading.closest('[data-dune-artifact],[data-dune-navigation]'));
        if(headings.length===outlineHeadings.length&&headings.every((heading,i)=>heading===outlineHeadings[i]&&heading.textContent===outlineLabels[i]))return;
        outlineHeadings=headings;outlineLabels=headings.map(heading=>heading.textContent);
        setOutline(headings,heading=>heading.scrollIntoView({behavior:matchMedia('(prefers-reduced-motion:reduce)').matches?'auto':'smooth',block:'start'}));
      };
      const attach = child => {
        child.addEventListener('load', () => bindFrame(child, revision));
        bindFrame(child, revision);
      };
      doc.querySelectorAll('iframe').forEach(attach);
      new MutationObserver(changes => {window.DUNEDesignSystem.apply(doc,file ? metaFor(file.path) : {});changes.forEach(change => change.addedNodes.forEach(node => {
        if (node.nodeType !== 1) return;
        if (node.tagName === 'IFRAME') attach(node);
        node.querySelectorAll?.('iframe').forEach(attach);
      }));refreshOutline();}).observe(doc.body, {childList:true,subtree:true});
      if (primary) {
        refreshOutline();
        if (current.anchor) doc.getElementById(current.anchor)?.scrollIntoView();
      }
    } catch { if (primary) setOutline([], () => {}); }
  }

  // Markdown is rendered with DOM nodes; raw HTML and event attributes are never evaluated.
  function inline(text, parent, base) {
    const pattern = /(!?\[[^\]]*\]\([^\n]*?\)|`[^`]+`|\*\*[^*]+\*\*)/g;
    let cursor = 0;
    for (const match of text.matchAll(pattern)) {
      parent.append(document.createTextNode(text.slice(cursor, match.index)));
      const fragment = match[0];
      if (fragment.startsWith('`')) {const code=document.createElement('code');code.textContent=fragment.slice(1,-1);parent.append(code);}
      else if (fragment.startsWith('**')) {const strong=document.createElement('strong');strong.textContent=fragment.slice(2,-2);parent.append(strong);}
      else {
        const link = fragment.match(/^(!?)\[([^\]]*)\]\((.+)\)$/);
        let href = link?.[3]?.replace(/^<|>$/g, '');
        try {
          const url = new URL(href, base);
          if (!['http:','https:','file:'].includes(url.protocol)) throw new Error('Unsupported link');
          if (link[1]) {const image=document.createElement('img');image.src=url.href;image.alt=link[2];image.loading='lazy';parent.append(image);}
          else {const a=document.createElement('a');a.href=url.href;a.textContent=link[2];if (url.origin !== root.origin) {a.target='_blank';a.rel='noopener';}parent.append(a);}
        } catch {parent.append(document.createTextNode(fragment));}
      }
      cursor = match.index + fragment.length;
    }
    parent.append(document.createTextNode(text.slice(cursor)));
  }
  function renderMarkdown(text, base) {
    const lines = text.replace(/^---\r?\n[\s\S]*?\r?\n---\r?\n/, '').split(/\r?\n/);
    const output = document.createDocumentFragment();
    const headingIDs = new Map();
    let i = 0;
    while (i < lines.length) {
      const line = lines[i];
      if (!line.trim()) {i++;continue;}
      if (/^\s*```/.test(line)) {
        const pre=document.createElement('pre'),code=document.createElement('code');const content=[];i++;
        while(i<lines.length&&!/^\s*```/.test(lines[i]))content.push(lines[i++]);i++;code.textContent=content.join('\n');pre.append(code);output.append(pre);continue;
      }
      const heading = line.match(/^(#{1,6})\s+(.+)/);
      if (heading) {
        const node=document.createElement('h'+heading[1].length);inline(heading[2],node,base);
        const slug=node.textContent.toLowerCase().normalize('NFC').replace(/[^\p{L}\p{N}\s_-]/gu,'').replace(/\s/g,'-');
        const count=headingIDs.get(slug)||0;headingIDs.set(slug,count+1);node.id=slug+(count?'-'+count:'');
        output.append(node);i++;continue;
      }
      if (line.includes('|') && /^\s*\|?\s*:?-{3,}/.test(lines[i+1] || '')) {
        const table=document.createElement('table'),thead=document.createElement('thead'),tbody=document.createElement('tbody');
        const cells=value=>value.trim().replace(/^\||\|$/g,'').split('|').map(cell=>cell.trim());
        const row=(value,tag)=>{const tr=document.createElement('tr');cells(value).forEach(cell=>{const td=document.createElement(tag);if(tag==='th')td.scope='col';inline(cell,td,base);tr.append(td);});return tr;};
        thead.append(row(line,'th'));i+=2;while(i<lines.length&&lines[i].includes('|')&&lines[i].trim())tbody.append(row(lines[i++],'td'));
        table.append(thead,tbody);output.append(table);continue;
      }
      if (/^\s*>/.test(line)) {const quote=document.createElement('blockquote');const content=[];while(i<lines.length&&/^\s*>/.test(lines[i]))content.push(lines[i++].replace(/^\s*>\s?/,''));inline(content.join('\n'),quote,base);output.append(quote);continue;}
      if (/^\s*(?:[-*+] |\d+\. )/.test(line)) {const list=document.createElement(/^\s*\d+\./.test(line)?'ol':'ul');while(i<lines.length&&/^\s*(?:[-*+] |\d+\. )/.test(lines[i])){const li=document.createElement('li');inline(lines[i++].replace(/^\s*(?:[-*+] |\d+\. )/,''),li,base);list.append(li);}output.append(list);continue;}
      if (/^\s*---+\s*$/.test(line)) {output.append(document.createElement('hr'));i++;continue;}
      const paragraph=document.createElement('p'),content=[line];i++;
      while(i<lines.length&&lines[i].trim()&&!/^(?:#{1,6}\s|\s*```|\s*>|\s*[-*+] |\s*\d+\. )/.test(lines[i])&&!(lines[i].includes('|')&&/^\s*\|?\s*:?-{3,}/.test(lines[i+1]||'')))content.push(lines[i++]);
      inline(content.join('\n'),paragraph,base);output.append(paragraph);
    }
    return output;
  }
  function error(message, revision) {
    if(revision!==loadRevision)return;
    clearTimeout(loadTimer);$('reader-loading').hidden=true;$('reader-error').hidden=false;$('reader-error-detail').textContent=message;
  }
  async function display(file) {
    const meta=metaFor(file.path);navigation(meta);
    const revision=++loadRevision;
    if(request)request.abort();request=new AbortController();clearTimeout(loadTimer);
    const surface=$('reader-loading');surface.hidden=false;$('reader-error').hidden=true;
    $('document-frame').hidden=true;$('document-frame').onload=null;$('document-article').hidden=true;$('document-media').hidden=true;
    $('document-article').replaceChildren();$('document-media').replaceChildren();setOutline([],()=>{});
    window.scrollTo(0,0);
    loadTimer=setTimeout(()=>{request?.abort();error('읽기가 지연되고 있습니다. 원본 파일에서 내용을 확인할 수 있습니다.',revision);},15000);
    const url=new URL(file.path,root);if(file.query)url.search=file.query;if(file.anchor)url.hash=file.anchor;
    $('document-original').href=url.href;
    if(/\.(html?|pdf)$/i.test(file.path)) {
      const frameURL=new URL(url);
      if(/\.html?$/i.test(file.path))frameURL.searchParams.set('_dune','1');
      $('document-original').href=frameURL.href;
      const frame=$('document-frame');
      frame.onload=()=>{
        if(revision!==loadRevision)return;
        try {
          if(frame.contentWindow.location.href === 'about:blank')return;
          const redirected = localFile(frame.contentWindow.location.href);
          if(redirected && redirected.path !== file.path){location.hash=hashFor(redirected);return;}
        } catch {}
        clearTimeout(loadTimer);surface.hidden=true;frame.hidden=false;if(!file.path.endsWith('.pdf'))bindFrame(frame,revision,true);
      };
      frame.hidden=false;
      try {
        if(frame.contentWindow.location.href===frameURL.href && frame.contentDocument?.readyState==='complete'){frame.onload();return;}
      } catch {}
      replaceFrame(frameURL.href);
      return;
    }
    replaceFrame('about:blank');
    if(/\.(png|jpe?g|gif|webp|svg)$/i.test(file.path)) {
      const image=document.createElement('img');image.alt=meta.title;
      image.onload=()=>{if(revision!==loadRevision)return;clearTimeout(loadTimer);surface.hidden=true;};image.onerror=()=>error('이미지 파일을 읽을 수 없습니다.',revision);image.src=url.href;
      $('document-media').append(image);$('document-media').hidden=false;return;
    }
    try {
      const response=await fetch(url,{signal:request.signal});
      if(!response.ok)throw new Error('HTTP '+response.status);
      const text=await response.text();if(revision!==loadRevision)return;
      const article=$('document-article');
      if(file.path.endsWith('.md')) article.append(renderMarkdown(text,url));
      else {const pre=document.createElement('pre');pre.textContent=text;article.append(pre);}
      article.hidden=false;surface.hidden=true;clearTimeout(loadTimer);
      const heading=article.querySelector('h1');
      if (heading) meta.title = heading.textContent;
      meta.links = [...new Set([...article.querySelectorAll('a[href]')].map(a=>localFile(a.href)).filter(Boolean).map(link=>link.path))];
      byPath.set(meta.path, meta);navigation(meta);
      setOutline([...article.querySelectorAll('h1,h2,h3')],heading=>heading.scrollIntoView({behavior:matchMedia('(prefers-reduced-motion:reduce)').matches?'auto':'smooth'}));
      if(file.anchor)article.querySelectorAll('[id]').forEach(heading=>{if(heading.id===file.anchor)heading.scrollIntoView();});
    } catch (exception) {if(exception.name!=='AbortError')error('파일을 읽을 수 없습니다. '+exception.message,revision);}
  }
  function route() {
    const hash=location.hash||'#overview';
    if(hash!==trail[trailCursor]) {
      if(trail[trailCursor-1]===hash)trailCursor--;
      else if(trail[trailCursor+1]===hash)trailCursor++;
      else{trail=trail.slice(0,trailCursor+1);trail.push(hash);trailCursor++;}
    }
    $('reader-back').disabled=trailCursor===0;$('reader-forward').disabled=trailCursor===trail.length-1;
    if(!hash.startsWith('#doc=')) {
      if(current){loadRevision++;request?.abort();clearTimeout(loadTimer);$('document-frame').onload=null;replaceFrame('about:blank');current=null;}
      document.body.classList.remove('reader-expanded');$('reader-focus').setAttribute('aria-pressed','false');$('reader-focus').textContent='넓게 보기';return;
    }
    const params=new URLSearchParams(hash.slice(1));const file=localFile(params.get('doc')||'');
    if(!file){
      loadRevision++;request?.abort();clearTimeout(loadTimer);$('document-frame').onload=null;replaceFrame('about:blank');
      $('document-frame').hidden=true;$('document-article').hidden=true;$('document-media').hidden=true;
      $('document-title').textContent='유효하지 않은 문서 경로';$('document-path').textContent='';$('document-category').textContent='경로 확인';
      $('reader-error-original').href='#library';error('문서 색인에서 지원되는 저장소 파일을 선택하십시오.',loadRevision);current=null;return;
    }
    file.anchor=params.get('anchor')||'';
    file.query=params.get('query')||'';
    if(current?.path===file.path&&current?.anchor===file.anchor&&current?.query===file.query)return;
    current=file;display(file);
  }
  $('reader-back').addEventListener('click',()=>{if(trailCursor>0)history.back();});
  $('reader-forward').addEventListener('click',()=>{if(trailCursor<trail.length-1)history.forward();});
  $('reader-focus').addEventListener('click',()=>{const expanded=document.body.classList.toggle('reader-expanded');$('reader-focus').setAttribute('aria-pressed',String(expanded));$('reader-focus').textContent=expanded?'기본 보기':'넓게 보기';});
  document.querySelectorAll('[data-preview]').forEach(button=>{button.hidden=false;button.addEventListener('click',()=>openDocument(button.dataset.preview));});
  window.addEventListener('hashchange',route);route();
  document.addEventListener('dune:appearance',()=>{
    const update=frame=>{try{const doc=frame.contentDocument;if(!doc)return;const file=localFile(frame.contentWindow.location.href);if(file)window.DUNEDesignSystem.apply(doc,metaFor(file.path));doc.querySelectorAll('iframe').forEach(update);}catch{}};
    update($('document-frame'));
  });
  window.addEventListener('message',event=>{
    const frame=$('document-frame');
    if(event.source!==frame.contentWindow||!event.data)return;
    if(event.data.type==='dune:document'&&typeof event.data.url==='string')openDocument(event.data.url);
    if(event.data.type==='dune:command')document.dispatchEvent(new Event('dune:command'));
    if(event.data.type==='dune:ready')frame.contentWindow.postMessage({type:'dune:appearance',mode:document.documentElement.dataset.theme,preference:document.documentElement.dataset.themePreference},'*');
  });
})();
