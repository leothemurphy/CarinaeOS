// AtriumOS — Palco: o app em uso fica no centro; os outros são guardados (minimizados)
// e voltam com um clique no Dock. Desligar o Palco devolve todas as janelas guardadas.
var ativo = false;
var guardadas = [];

function comum(w) {
    return w && w.normalWindow && !w.skipTaskbar && !w.specialWindow && w.resourceClass != "plasmashell";
}
function mesmoApp(a, b) {
    return a.resourceClass == b.resourceClass && a.pid == b.pid;
}
function aviso(txt) {
    callDBus("org.freedesktop.Notifications", "/org/freedesktop/Notifications",
             "org.freedesktop.Notifications", "Notify",
             "Palco", 0, "view-presentation", "Palco", txt, [], {}, 2500);
}
function arrumar(atual) {
    if (!ativo || !comum(atual)) return;
    var lista = workspace.windowList();
    for (var i = 0; i < lista.length; i++) {
        var w = lista[i];
        if (!comum(w) || w.minimized || mesmoApp(w, atual)) continue;
        if (w.output != atual.output) continue;
        w.minimized = true;
        if (guardadas.indexOf(w) < 0) guardadas.push(w);
    }
}
function alternar() {
    ativo = !ativo;
    if (ativo) {
        aviso("Ligado: só o app em uso fica na tela. Os outros ficam no Dock.");
        arrumar(workspace.activeWindow);
    } else {
        for (var i = 0; i < guardadas.length; i++) {
            try { guardadas[i].minimized = false; } catch (e) {}
        }
        guardadas = [];
        aviso("Desligado: todas as janelas voltaram.");
    }
}
workspace.windowActivated.connect(function (w) { arrumar(w); });
workspace.windowRemoved.connect(function (w) {
    var i = guardadas.indexOf(w);
    if (i >= 0) guardadas.splice(i, 1);
});
registerShortcut("AtriumPalco", "Palco: ligar/desligar", "Meta+Ctrl+P", alternar);
