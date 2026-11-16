// CarinaeOS — mesa
// 1) Clicar no papel de parede afasta as janelas para os lados, como no macOS
//    ("clicar no papel de parede para mostrar a área de trabalho"). Clicar numa janela ou na Dock traz tudo de volta.
//    Desligado de origem; liga-se no Supernova › Clicar no papel de parede.

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
// minimizar ou fechar uma janela também passa a ativação para "nenhuma janela": nesse caso NÃO foi um
// clique no papel de parede (sem isto, minimizar uma janela num ecrã escondia as do outro ecrã)
var ultimaSaida = 0;
function vigiar(w) {
    if (!w || !w.minimizedChanged) return;
    w.minimizedChanged.connect(function () { if (w.minimized) ultimaSaida = Date.now(); });
}
workspace.windowAdded.connect(vigiar);
workspace.windowRemoved.connect(function () { ultimaSaida = Date.now(); });
var todasAbertas = workspace.windowList();
for (var k = 0; k < todasAbertas.length; k++) vigiar(todasAbertas[k]);

var anterior = null;      // a última janela normal que teve o foco
workspace.windowActivated.connect(function (w) {
    if (w && (w.normalWindow || w.dialog)) { mostrando = false; anterior = w; return; }
    // (não se esquece a anterior: depois de minimizar, o foco passa primeiro para "nenhuma" e depois para a mesa)
    var antes = anterior;
    if (!opcao("mostrarMesaAoClicar", false) || mostrando) return;
    if (Date.now() - ultimaSaida < 1500) return;
    // o KWin tira o foco antes de avisar que a janela foi minimizada ou fechada: se a janela que
    // tinha o foco está agora minimizada ou já não existe, foi isso, e não um clique no papel de parede
    if (antes && (antes.minimized || workspace.windowList().indexOf(antes) === -1)) return;
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

// ---- Pesquisa (Ctrl+Espaço / lupa): por cima de tudo, ao centro, encostada à Dock (como no Windows) -----------------
function talvezComando(w) {
    if (!w || (w.resourceClass !== "carinaeos-comando" && w.caption !== "CarinaeOS — Comando")) return;
    w.keepAbove = true;
    w.skipTaskbar = true;
    w.skipSwitcher = true;
    w.skipPager = true;
    w.onAllDesktops = true;
    var centrar = function () {
        var area = workspace.clientArea(KWin.MaximizeArea, w);
        var g = w.frameGeometry;
        var x = Math.round(area.x + (area.width - g.width) / 2);
        var y = Math.round(area.y + area.height - g.height - 92);   // por cima da Dock (as janelas passam por baixo dela)
        if (Math.abs(g.x - x) > 1 || Math.abs(g.y - y) > 1)
            w.frameGeometry = { x: x, y: y, width: g.width, height: g.height };
    };
    centrar();
    w.frameGeometryChanged.connect(centrar);
    workspace.activeWindow = w;   // recebe logo o teclado
}
workspace.windowAdded.connect(talvezComando);
var jaAbertas = workspace.windowList();
for (var j = 0; j < jaAbertas.length; j++) talvezComando(jaAbertas[j]);
