// CarinaeOS — mesa
// 1) Clicar no papel de parede afasta as janelas para os lados, como no macOS
//    ("clicar no papel de parede para mostrar a mesa"). Clicar numa janela ou na Dock traz tudo de volta.
// 2) A nuvem da Eta fica sempre no canto inferior direito, por cima de tudo, sem roubar o foco.

function opcao(nome, padrao) {
    var v = readConfig(nome, padrao);
    return v === true || v === "true" || v === 1;
}

function janelaNormal(w) {
    return w && w.normalWindow && !w.minimized && !w.skipTaskbar && w.onCurrentDesktop !== false;
}

function cursorSobreJanela() {
    var p = workspace.cursorPos;
    var lista = workspace.stackingOrder;
    for (var i = 0; i < lista.length; i++) {
        var w = lista[i];
        if (!w || w.desktopWindow || w.minimized || w.hidden) continue;
        var g = w.frameGeometry;
        if (p.x >= g.x && p.x < g.x + g.width && p.y >= g.y && p.y < g.y + g.height) return true;
    }
    return false;
}

// No Plasma 6, clicar no papel de parede nao ativa a janela da mesa: a ativacao passa para
// "nenhuma janela" (null). E a propriedade workspace.showingDesktop nao existe no script, por isso
// usa-se o atalho "Mostrar a area de trabalho" do KWin (com o efeito que afasta as janelas).
var mostrando = false;
workspace.windowActivated.connect(function (w) {
    if (w && (w.normalWindow || w.dialog)) { mostrando = false; return; }
    if (!opcao("mostrarMesaAoClicar", true) || mostrando) return;
    if (w && !w.desktopWindow) return;
    var tem = false;
    var lista = workspace.stackingOrder;
    for (var i = 0; i < lista.length; i++) if (janelaNormal(lista[i])) { tem = true; break; }
    // so quando foi mesmo um clique no papel de parede (o cursor nao esta sobre nenhuma janela nem na Dock)
    if (tem && !cursorSobreJanela()) {
        mostrando = true;
        callDBus("org.kde.kglobalaccel", "/component/kwin", "org.kde.kglobalaccel.Component",
                 "invokeShortcut", "Show Desktop");
    }
});

// ---- nuvem da Eta ----------------------------------------------------------------------
function encaixarNuvem(w) {
    var area = workspace.clientArea(KWin.MaximizeArea, w);
    var g = w.frameGeometry;
    var x = area.x + area.width - g.width - 12;
    var y = area.y + area.height - g.height - 12;
    if (Math.abs(g.x - x) > 1 || Math.abs(g.y - y) > 1)
        w.frameGeometry = { x: x, y: y, width: g.width, height: g.height };
}

function talvezNuvem(w) {
    if (!w || w.caption !== "Eta — atividade") return;
    w.keepAbove = true;
    w.skipTaskbar = true;
    w.skipSwitcher = true;
    w.skipPager = true;
    w.onAllDesktops = true;
    encaixarNuvem(w);
    w.frameGeometryChanged.connect(function () { encaixarNuvem(w); });
}

workspace.windowAdded.connect(talvezNuvem);
var todas = workspace.windowList();
for (var i = 0; i < todas.length; i++) talvezNuvem(todas[i]);
