// CarinaeOS - Dock como no Mac.
// A Dock está no modo "as janelas passam por baixo" (não reserva espaço) e muda de altura sozinha:
// em repouso tem só a altura do vidro; com o rato por cima cresce para caber a ampliação.
// Este painel-espaçador (1 px, invisível) é que reserva para as janelas maximizadas a altura do vidro:
// elas param na borda de cima da Dock e a ampliação passa por cima delas, como no macOS.
// Corre a cada entrada (carinaeos-ambiente-inicio) e quando se muda a Dock nas Configurações.
var dock = null, esp = [];
var ps = panels();
for (var i = 0; i < ps.length; i++) {
    var p = ps[i], ws = p.widgets();
    for (var j = 0; j < ws.length; j++) {
        if (ws[j].type == "org.carinaeos.dock") dock = { p: p, w: ws[j] };
    }
    p.currentConfigGroup = ["CarinaeOS"];
    if (p.readConfig("espacador", "") == "sim") esp.push(p);
}
if (dock) {
    dock.w.currentConfigGroup = ["General"];
    var b = Number(dock.w.readConfig("iconSize", 48));
    var h = Number(dock.w.readConfig("glassHeight", 0));             // a Dock guarda a altura do vidro do estilo atual
    if (!(h > 0)) h = Math.round(b * 0.14) + b + 2 * Math.round(b * 0.16);
    if (dock.p.hiding == "autohide") {
        for (var k = 0; k < esp.length; k++) esp[k].remove();
        print("dock escondida: sem espacador");
    } else {
        var s = esp.length ? esp[0] : new Panel;
        for (var k = 1; k < esp.length; k++) esp[k].remove();
        s.currentConfigGroup = ["CarinaeOS"];
        s.writeConfig("espacador", "sim");
        s.location = dock.p.location;
        s.floating = false;
        s.lengthMode = "custom";
        s.alignment = "center";   // fica escondido por trás do meio da Dock (num canto, apanhava cliques e abria o modo de edição)
        s.minimumLength = 1;
        s.maximumLength = 1;
        s.length = 1;
        s.hiding = "none";
        s.height = h;
        s.opacity = "transparent";
        // uma barra vazia mostra um símbolo para a configurar: com um espaçador (que não desenha nada) fica invisível
        // (o modo de edição está no menu da estrela, na barra de cima: «Editar barras e widgets…»)
        if (s.widgets().length == 0) s.addWidget("org.kde.plasma.panelspacer");
        print("espacador " + s.id + " altura " + h);
    }
    dock.p.floating = false;
}
