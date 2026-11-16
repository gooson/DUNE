'use strict';
window.DuneColorLab = (() => {
  let context;
  const palettes = window.dunePaletteData.palettes;
  const byId = id => palettes.find(p => p.id === id) || palettes[0];
  const element = id => document.getElementById(id);
  const hex = value => value.match(/[a-f\d]{2}/gi).map(v => parseInt(v, 16) / 255);
  const invert = matrix => {
    const rows = matrix.map((row, i) => [...row, ...row.map((_, j) => i === j ? 1 : 0)]);
    for (let column = 0; column < 4; column++) {
      let pivot = column;
      for (let i = column + 1; i < 4; i++) if (Math.abs(rows[i][column]) > Math.abs(rows[pivot][column])) pivot = i;
      [rows[column], rows[pivot]] = [rows[pivot], rows[column]];
      const divisor = rows[column][column];
      if (Math.abs(divisor) < 1e-9) throw new Error('Palette anchors are not independent');
      rows[column] = rows[column].map(v => v / divisor);
      for (let i = 0; i < 4; i++) if (i !== column) {
        const factor = rows[i][column];
        rows[i] = rows[i].map((v, j) => v - factor * rows[column][j]);
      }
    }
    return rows.map(row => row.slice(4));
  };
  const anchors = window.dunePaletteData.sourceAnchors;
  const inverse = invert([anchors.background, anchors.a, anchors.b, anchors.highlight].map(c => [...hex(c), 1]));
  function active() { return context?.getTab() === 'lab'; }
  function palette(id = context.saved.paletteId) { return byId(id); }
  function colors(id) {
    const p = palette(id), saved = context.saved;
    const background = saved.paletteBackground === 'charcoal' ? '#302b2a' : saved.paletteBackground === 'ivory' ? '#f4f0eb' : p.background;
    return { a: saved.paletteSwap ? p.b : p.a, b: saved.paletteSwap ? p.a : p.b, background };
  }
  function matrix(id) {
    const { a, b, background } = colors(id);
    const ca = hex(a), cb = hex(b);
    const highlight = ca.map((v, i) => ((v + cb[i]) / 2) * 0.55 + 0.45);
    const targets = [hex(background), ca, cb, highlight];
    const values = [];
    for (let channel = 0; channel < 3; channel++) {
      const coefficients = inverse.map(row => row.reduce((sum, v, i) => sum + v * targets[i][channel], 0));
      values.push(...coefficients.slice(0, 3), 0, coefficients[3]);
    }
    return [...values, 0, 0, 0, 1, 0].map(v => Number(v.toFixed(7))).join(' ');
  }
  const filterId = id => 'dune-lab-' + palette(id).id;
  const filter = id => `url(#${filterId(id)})`;
  function buildFilters() {
    element('palette-filter-defs').innerHTML = palettes.map(p => `<filter id="${filterId(p.id)}" x="0%" y="0%" width="100%" height="100%" color-interpolation-filters="sRGB"><feColorMatrix type="matrix" values="${matrix(p.id)}"/></filter>`).join('');
  }
  function key(concept) {
    const s = context.saved;
    return `${concept.sourceNumber}:${s.paletteId}:${s.paletteSwap ? 'BA' : 'AB'}:${s.paletteBackground}`;
  }
  function isFavorite(concept) { return context.saved.paletteFavorites.includes(key(concept)); }
  function toggleFavorite(concept) {
    const favorites = context.saved.paletteFavorites, value = key(concept), index = favorites.indexOf(value);
    if (index < 0) favorites.push(value); else favorites.splice(index, 1);
  }
  function refresh() {
    element('palette-panel').hidden = !active();
    const targets = document.querySelectorAll('#hero-icon,.selected-size,.selected-home,#gallery .choice img');
    targets.forEach(img => img.style.filter = active() ? filter() : '');
    element('palette-compare-control').hidden = !active() || element('compare-source').value !== 'palette';
    if (!active()) return;
    const s = context.saved, p = palette(), selected = context.concepts.find(c => c.id === s.selected);
    buildFilters();
    element('palette-select').value = p.id;
    element('palette-background').value = s.paletteBackground;
    element('palette-compare').value = s.paletteCompareId;
    element('palette-swap').setAttribute('aria-pressed', s.paletteSwap);
    element('palette-current').textContent = `P${String(p.number).padStart(2, '0')} · ${p.name} · ${p.desc}`;
    const current = colors();
    element('palette-colors').innerHTML = [['A', current.a], ['B', current.b], ['배경', current.background]].map(([name, color]) => `<span><i style="background:${color}"></i>${name} ${color.toUpperCase()}</span>`).join('');
    element('palette-grid').innerHTML = palettes.map(option => `<button class="palette-choice" data-palette="${option.id}" aria-pressed="${option.id === p.id}" aria-label="P${option.number} ${option.name}"><img src="${context.imageSource(selected.image)}" width="64" height="64" alt="" style="filter:${filter(option.id)}"><strong>P${String(option.number).padStart(2, '0')}</strong><span>${option.name}</span><small>${option.category}</small></button>`).join('');
    const favorite = isFavorite(selected);
    element('favorite').setAttribute('aria-pressed', favorite);
    element('favorite').textContent = favorite ? '★ 조합 후보에서 빼기' : '☆ 이 형태·컬러 후보에 추가';
    element('note').value = typeof s.paletteNotes[key(selected)] === 'string' ? s.paletteNotes[key(selected)] : '';
    element('note-title').textContent = `${selected.sourceNumber}번 · P${String(p.number).padStart(2, '0')} 조합 메모`;
    element('download').textContent = '현재 형태·컬러 PNG 저장 ↗';
  }
  function onTabChange() {
    element('palette-compare-option').hidden = !active();
    if (active()) element('compare-source').value = 'palette';
    else if (element('compare-source').value === 'palette') element('compare-source').value = 'parent';
  }
  function choose(id) {
    context.saved.paletteId = byId(id).id;
    context.selectConcept(context.saved.selected);
  }
  function sourceFor(id) {
    const current = context.concepts.find(c => c.id === id);
    if (current?.version === 'v6') return id;
    return context.concepts.find(c => c.version === 'v6' && c.parentId === id)?.id || '104-duo-86';
  }
  function sourceData(concept) {
    if (window.duneLabExportSources?.[concept.id]) return Promise.resolve(window.duneLabExportSources[concept.id]);
    return new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = context.base + 'color-lab/export-sources/' + concept.id + '.js';
      script.onload = () => { script.remove(); resolve(window.duneLabExportSources[concept.id]); };
      script.onerror = () => { script.remove(); reject(new Error('내보내기 원본을 읽지 못했어요.')); };
      document.head.appendChild(script);
    });
  }
  async function exportSVG() {
    const concept = context.concepts.find(c => c.id === context.saved.selected);
    const transform = matrix();
    const original = await sourceData(concept);
    return `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024"><defs><filter id="palette" x="0%" y="0%" width="100%" height="100%" color-interpolation-filters="sRGB"><feColorMatrix type="matrix" values="${transform}"/></filter></defs><image width="1024" height="1024" href="${original}" filter="url(#palette)"/></svg>`;
  }
  async function download() {
    const link = element('download');
    if (link.dataset.busy) return;
    link.dataset.busy = 'true';link.textContent = 'PNG 준비 중…';
    try {
      const s = context.saved, concept = context.concepts.find(c => c.id === s.selected);
      const filename = `dune-${concept.sourceNumber}-${s.paletteId}-${s.paletteSwap ? 'BA' : 'AB'}-${s.paletteBackground}.png`;
      const svg = await exportSVG(), url = URL.createObjectURL(new Blob([svg], { type: 'image/svg+xml' }));
      try {
        const img = new Image();img.src = url;await img.decode();
        const canvas = document.createElement('canvas');canvas.width = 1024;canvas.height = 1024;
        canvas.getContext('2d').drawImage(img, 0, 0);
        const blob = await new Promise(resolve => canvas.toBlob(resolve, 'image/png'));
        if (!blob) throw new Error('PNG를 만들지 못했어요.');
        const output = URL.createObjectURL(blob), a = document.createElement('a');
        a.href = output;a.download = filename;a.click();setTimeout(() => URL.revokeObjectURL(output), 1500);
        element('saved').textContent = '현재 형태·컬러의 1024px PNG를 저장했어요.';
      } finally { URL.revokeObjectURL(url); }
    } catch (error) { element('saved').textContent = `${error.message} 다시 시도해 주세요.`; }
    finally { delete link.dataset.busy;link.textContent = '현재 형태·컬러 PNG 저장 ↗'; }
  }
  function init(value) {
    context = value;
    const options = palettes.map(p => `<option value="${p.id}">P${String(p.number).padStart(2, '0')} · ${p.name}</option>`).join('');
    element('palette-select').innerHTML = options;element('palette-compare').innerHTML = options;
    element('palette-select').addEventListener('change', event => choose(event.target.value));
    element('palette-grid').addEventListener('click', event => { const button = event.target.closest('[data-palette]');if (button) { const id = button.dataset.palette;choose(id);element('palette-grid').querySelector(`[data-palette="${id}"]`).focus({preventScroll:true}); } });
    for (const [id, direction] of [['palette-prev', -1], ['palette-next', 1]]) element(id).addEventListener('click', () => choose(palettes[(palettes.indexOf(palette()) + direction + palettes.length) % palettes.length].id));
    element('palette-swap').addEventListener('click', () => { context.saved.paletteSwap = !context.saved.paletteSwap;context.selectConcept(context.saved.selected); });
    element('palette-background').addEventListener('change', event => { context.saved.paletteBackground = event.target.value;context.selectConcept(context.saved.selected); });
    element('palette-compare').addEventListener('change', event => { context.saved.paletteCompareId = byId(event.target.value).id;context.updateComparison();context.persist(); });
    element('download').addEventListener('click', event => { if (active()) { event.preventDefault();download(); } });
  }
  return { init, active, palette, colors, filter, matrix, key, isFavorite, toggleFavorite, refresh, onTabChange, sourceFor, exportSVG, choose };
})();
