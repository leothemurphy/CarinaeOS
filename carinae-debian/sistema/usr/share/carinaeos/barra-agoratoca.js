// CarinaeOS - junta o «A tocar» (música do MPD) à barra de cima, antes da lupa da Pesquisa (uma vez).
var ps = panels();
for (var i = 0; i < ps.length; i++) {
    var p = ps[i];
    if (p.location != "top") continue;
    var ws = p.widgets(), tem = false, lupa = -1;
    for (var j = 0; j < ws.length; j++) {
        if (ws[j].type == "org.carinaeos.agoratoca") tem = true;
        if (ws[j].type == "org.carinaeos.pesquisa") lupa = ws[j].id;
    }
    if (tem) { print("ja existe"); continue; }
    var novo = p.addWidget("org.carinaeos.agoratoca");
    p.currentConfigGroup = ["General"];
    var ordem = String(p.readConfig("AppletOrder", "")).split(";").filter(function (x) { return x != "" && x != String(novo.id); });
    var k = ordem.indexOf(String(lupa));
    if (k >= 0) ordem.splice(k, 0, String(novo.id)); else ordem.push(String(novo.id));
    p.writeConfig("AppletOrder", ordem.join(";"));
    print("juntado " + novo.id + " ordem " + ordem.join(";"));
}
