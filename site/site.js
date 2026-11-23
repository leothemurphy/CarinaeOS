// CarinaeOS — a área de trabalho do site: janelas que se arrastam, a Dock com a luz e o menu da estrela
(() => {
  "use strict";
  const $ = (s, r = document) => r.querySelector(s);
  const $$ = (s, r = document) => [...r.querySelectorAll(s)];
  const mesa = $("#mesa");
  const telemovel = () => matchMedia("(max-width: 760px)").matches;
  let topo = 10;

  // ---------- relógio da barra ----------
  const relogio = $("#relogio");
  const dia = new Intl.DateTimeFormat("pt-PT", { weekday: "short", day: "numeric", month: "short" });
  const hora = new Intl.DateTimeFormat("pt-PT", { hour: "2-digit", minute: "2-digit" });
  const tic = () => { const d = new Date(); relogio.textContent = `${dia.format(d)}   ${hora.format(d)}`; relogio.dateTime = d.toISOString(); };
  tic(); setInterval(tic, 15000);

  // ---------- janelas ----------
  const janelas = Object.fromEntries($$(".janela").map(j => [j.id, j]));
  // onde cada janela abre pela primeira vez (fração da área livre)
  const posicoes = { sobre: [.62, .16], raiz: [.56, .08], capturas: [.40, .05], novidades: [.66, .26],
                     requisitos: [.60, .30], baixar: [.46, .06], distros: [.42, .14] };
  const colocadas = new Set();

  function colocar(j) {
    if (telemovel() || colocadas.has(j.id)) return;
    const [fx, fy] = posicoes[j.id] || [.5, .1];
    const W = mesa.clientWidth, H = mesa.clientHeight - 92;
    const w = j.offsetWidth, h = Math.min(j.offsetHeight, H - 20);
    j.style.left = Math.max(12, Math.min(W - w - 12, fx * W - w / 2 + (W > 1100 ? w * .25 : 0))) + "px";
    j.style.top = Math.max(12, Math.min(H - h - 8, fy * H)) + "px";
    colocadas.add(j.id);
  }

  function ativar(j) {
    $$(".janela.ativa").forEach(x => x.classList.remove("ativa"));
    j.classList.add("ativa");
    j.style.zIndex = ++topo;
    $("#app-ativa").textContent = j.querySelector(".janela-titulo").textContent;
  }

  function abrir(id, { focar = true, historico = true } = {}) {
    const j = janelas[id]; if (!j) return;
    if (telemovel()) $$(".janela.aberta").forEach(x => x !== j && fechar(x, false));
    j.classList.remove("a-fechar");
    if (!j.classList.contains("aberta")) { j.classList.add("aberta"); colocar(j); }
    ativar(j);
    marcarDock();
    if (historico) history.replaceState(null, "", "#" + id);
    if (focar) j.querySelector(".janela-corpo").focus({ preventScroll: true });
    $("#dica-mesa").hidden = true;
  }

  function fechar(j, animar = true) {
    if (!j.classList.contains("aberta")) return;
    const fim = () => { j.classList.remove("aberta", "a-fechar", "ativa", "maximizada"); marcarDock();
      const outra = $$(".janela.aberta").sort((a, b) => b.style.zIndex - a.style.zIndex)[0];
      if (outra) ativar(outra); else { $("#app-ativa").textContent = "CarinaeOS"; history.replaceState(null, "", location.pathname); } };
    if (animar && !matchMedia("(prefers-reduced-motion: reduce)").matches) {
      j.classList.add("a-fechar"); j.addEventListener("animationend", fim, { once: true });
    } else fim();
  }

  function marcarDock() {
    $$(".icone[data-abrir]").forEach(i => i.classList.toggle("aberto", !!janelas[i.dataset.abrir]?.classList.contains("aberta")));
  }

  $$(".janela").forEach(j => {
    j.querySelector(".janela-corpo").tabIndex = -1;
    j.addEventListener("pointerdown", () => ativar(j));
    j.querySelector(".s-fechar").addEventListener("click", () => fechar(j));
    j.querySelector(".s-min").addEventListener("click", () => fechar(j));
    j.querySelector(".s-max").addEventListener("click", () => j.classList.toggle("maximizada"));
    // arrastar pela barra do título
    const t = j.querySelector(".janela-topo");
    t.addEventListener("dblclick", e => { if (!e.target.closest(".semaforo")) j.classList.toggle("maximizada"); });
    t.addEventListener("pointerdown", e => {
      if (e.target.closest(".semaforo") || telemovel() || j.classList.contains("maximizada")) return;
      const x0 = e.clientX - j.offsetLeft, y0 = e.clientY - j.offsetTop;
      t.setPointerCapture(e.pointerId);
      const mover = ev => {
        const W = mesa.clientWidth, H = mesa.clientHeight;
        j.style.left = Math.max(-j.offsetWidth + 120, Math.min(W - 120, ev.clientX - x0)) + "px";
        j.style.top = Math.max(0, Math.min(H - 60, ev.clientY - y0)) + "px";
      };
      t.addEventListener("pointermove", mover);
      t.addEventListener("pointerup", () => t.removeEventListener("pointermove", mover), { once: true });
    });
  });

  // links e ícones que abrem janelas
  document.addEventListener("click", e => {
    const a = e.target.closest("[data-abrir]");
    if (!a) return;
    e.preventDefault();
    const j = janelas[a.dataset.abrir];
    // clicar no ícone de uma janela já ativa minimiza-a, como na Dock da Aurora
    if (a.classList.contains("icone") && j.classList.contains("ativa") && j.classList.contains("aberta")) fechar(j);
    else abrir(a.dataset.abrir);
    fecharMenu();
  });

  document.addEventListener("keydown", e => {
    if (e.key !== "Escape") return;
    if (!$("#menu-estrela").hidden) return fecharMenu(true);
    const j = $(".janela.ativa"); if (j) fechar(j);
  });

  // ---------- menu da estrela ----------
  const btn = $("#estrela-btn"), menu = $("#menu-estrela");
  function fecharMenu(focar) { menu.hidden = true; btn.setAttribute("aria-expanded", "false"); if (focar) btn.focus(); }
  btn.addEventListener("click", e => {
    e.stopPropagation();
    const abrirMenu = menu.hidden; menu.hidden = !abrirMenu; btn.setAttribute("aria-expanded", String(abrirMenu));
    if (abrirMenu) menu.querySelector("a").focus();
  });
  document.addEventListener("click", e => { if (!menu.hidden && !e.target.closest("#menu-estrela")) fecharMenu(); });
  menu.addEventListener("keydown", e => {
    const itens = $$("a", menu), i = itens.indexOf(document.activeElement);
    if (e.key === "ArrowDown") { e.preventDefault(); itens[(i + 1) % itens.length].focus(); }
    if (e.key === "ArrowUp") { e.preventDefault(); itens[(i - 1 + itens.length) % itens.length].focus(); }
  });

  // ---------- a Dock e a luz dourada ----------
  const vidro = $(".dock-vidro"), luz = $("#luz"), rotulo = $("#rotulo");
  function luzEm(x) {
    luz.style.transform = `translateX(${x}px)`; luz.style.opacity = 1;
    vidro.style.setProperty("--luz-x", x + "px"); vidro.style.setProperty("--luz-o", 1);
  }
  function apagarLuz() { luz.style.opacity = 0; vidro.style.setProperty("--luz-o", 0); rotulo.classList.remove("visivel"); }
  vidro.addEventListener("pointermove", e => {
    const r = vidro.getBoundingClientRect();
    // a luz prende-se ao centro do ícone mais próximo, e desliza entre eles
    const ic = e.target.closest(".icone");
    luzEm(ic ? ic.offsetLeft + ic.offsetWidth / 2 - vidro.scrollLeft : e.clientX - r.left);
  });
  vidro.addEventListener("pointerleave", apagarLuz);
  $$(".icone").forEach(ic => {
    const mostrar = () => {
      const r = ic.getBoundingClientRect(), d = $("#dock").getBoundingClientRect();
      rotulo.textContent = ic.dataset.nome; rotulo.style.left = (r.left + r.width / 2 - d.left) + "px";
      rotulo.classList.add("visivel");
    };
    ic.addEventListener("pointerenter", mostrar);
    ic.addEventListener("focus", () => { mostrar(); luzEm(ic.offsetLeft + ic.offsetWidth / 2 - vidro.scrollLeft); });
    ic.addEventListener("blur", apagarLuz);
  });

  // ---------- galeria ----------
  $$("#tiras button").forEach(b => b.addEventListener("click", () => {
    $("#foto-grande").src = `img/${b.dataset.img}.webp`;
    $("#foto-grande").alt = b.querySelector("img").alt;
    $("#foto-legenda").textContent = b.dataset.leg;
    $$("#tiras button").forEach(x => x.removeAttribute("aria-current"));
    b.setAttribute("aria-current", "true");
  }));

  // ---------- abas (Windows / macOS / Linux) ----------
  const abas = $$('.abas [role="tab"]');
  function escolherAba(a) {
    abas.forEach(x => { const sel = x === a; x.setAttribute("aria-selected", sel); x.tabIndex = sel ? 0 : -1;
      document.getElementById(x.getAttribute("aria-controls")).hidden = !sel; });
  }
  abas.forEach(a => {
    a.addEventListener("click", () => escolherAba(a));
    a.addEventListener("keydown", e => {
      const i = abas.indexOf(a), d = e.key === "ArrowRight" ? 1 : e.key === "ArrowLeft" ? -1 : 0;
      if (d) { const n = abas[(i + d + abas.length) % abas.length]; escolherAba(n); n.focus(); }
    });
  });
  const so = (navigator.userAgentData?.platform || navigator.platform || navigator.userAgent).toLowerCase();
  escolherAba(so.includes("mac") ? $("#a-mac") : so.includes("linux") ? $("#a-lin") : $("#a-win"));

  // ---------- copiar ----------
  $$(".copiar").forEach(b => b.addEventListener("click", async () => {
    const texto = b.dataset.texto || b.parentElement.querySelector("code").textContent;
    try { await navigator.clipboard.writeText(texto); b.textContent = "Copiado"; b.classList.add("copiado"); }
    catch { b.textContent = "Selecione e copie"; }
    setTimeout(() => { b.textContent = "Copiar"; b.classList.remove("copiado"); }, 1800);
  }));

  // ---------- a versão mais recente, direto das Releases do GitHub ----------
  const tam = n => n >= 1e9 ? (n / 1073741824).toLocaleString("pt-PT", { maximumFractionDigits: 1 }) + " GB"
                             : Math.round(n / 1048576) + " MB";
  fetch("https://api.github.com/repos/leothemurphy/CarinaeOS/releases?per_page=30")
    .then(r => r.ok ? r.json() : Promise.reject())
    .then(lista => {
      const v = lista.find(r => r.tag_name.startsWith("carinaeos-v") && r.assets.some(a => a.name.endsWith(".parte00")));
      if (!v) return;
      const partes = v.assets.filter(a => /\.parte\d+$/.test(a.name)).sort((a, b) => a.name.localeCompare(b.name));
      const nome = v.tag_name.replace("carinaeos-v", "").replace(/-beta/, " beta").replace(/-teste-(\d+)/, " (teste $1)");
      $("#versao").textContent = nome;
      $("#pagina-versao").href = v.html_url;
      $("#tamanho").textContent = tam(partes.reduce((s, a) => s + a.size, 0)) + (partes.length > 1 ? ` em ${partes.length} partes` : "");
      $("#tamanho").nextSibling && ($("#tamanho").nextSibling.textContent = "");
      partes.slice(0, 2).forEach((a, i) => {
        const el = $("#parte0" + i); if (!el) return;
        el.href = a.browser_download_url; $("#t-parte0" + i).textContent = tam(a.size);
      });
      if (v.tag_name !== "carinaeos-v1.0-beta") {
        // a soma de controlo muda com a versão: aponta para o arquivo .sha256 da versão nova
        const sha = v.assets.find(a => a.name.endsWith(".sha256"));
        $("#sha").textContent = sha ? "Veja o arquivo " + sha.name + " na página da versão." : "Veja a página da versão.";
      }
    })
    .catch(() => {});

  // ---------- arranque ----------
  const inicial = location.hash.slice(1);
  if (janelas[inicial]) abrir(inicial, { focar: false });
  else if (!telemovel()) setTimeout(() => abrir("sobre", { focar: false, historico: false }), 450);
  addEventListener("hashchange", () => { const id = location.hash.slice(1); if (janelas[id]) abrir(id); });
})();
