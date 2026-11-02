(() => {
  'use strict';
  const styles = JSON.parse(document.getElementById('design-styles').textContent);
  const config=JSON.parse(document.getElementById('design-configuration').textContent);
  const protectedSelectors=config.protection.selectors;
  const perDocument=config.protection.documents;
  function apply(doc, meta = {}) {
    if (!doc?.head || !doc.body) return;
    const candidates = [...protectedSelectors, ...(perDocument[meta.path] || [])];
    (doc.defaultView?.DUNEDocumentUX||window.DUNEDocumentUX).enhance(doc,{selectors:candidates});
    const mode=document.documentElement.dataset.theme;
    doc.documentElement.dataset.theme=mode;
    doc.documentElement.dataset.themePreference=document.documentElement.dataset.themePreference;
    doc.documentElement.dataset.duneDocumentSystem='1';
    doc.documentElement.dataset.duneProfile=meta.profile||'document';
    let style=doc.getElementById('dune-document-system');
    if(!style){style=doc.createElement('style');style.id='dune-document-system';style.textContent=styles;doc.head.append(style);}
    // Existing CSP permits inline styles; its policy remains unchanged.
    const old=doc.getElementById('dune-document-surface');if(old)old.remove();
  }
  window.DUNEDesignSystem={apply};
})();
