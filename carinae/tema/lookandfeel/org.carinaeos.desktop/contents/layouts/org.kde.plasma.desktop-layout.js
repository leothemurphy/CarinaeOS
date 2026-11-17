// CarinaeOS — disposição da área de trabalho
//   barra em cima: estrela (lançador em ecrã inteiro), menu global da app,
//                  bandeja do sistema e relógio
//   Dock em baixo: apps com ampliação, estrela no centro e lixeira
//   mesa: ícones da pasta ~/Desktop e o papel de parede Ameixa

// ---- mesa ----------------------------------------------------------------
var mesas = desktopsForActivity(currentActivity());
for (var j = 0; j < mesas.length; j++) {
    // o papel de parede padrão do CarinaeOS (Ameixa)
    mesas[j].wallpaperPlugin = "org.kde.image";
    mesas[j].currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    mesas[j].writeConfig("Image", "file:///usr/share/wallpapers/CarinaeOS/");
    mesas[j].writeConfig("FillMode", 2);   // recortar para preencher
    // icones da mesa como no Mac: em colunas, encostados a direita
    mesas[j].currentConfigGroup = ["General"];
    mesas[j].writeConfig("arrangement", 1);
    mesas[j].writeConfig("alignment", 1);
    mesas[j].writeConfig("iconSize", 3);
}

// ---- barra de cima ---------------------------------------------------------
var barra = new Panel;
barra.location = "top";
barra.height = 2 * Math.ceil(gridUnit * 1.4 / 2);   // fina, como a barra do Mac
barra.floating = false;
barra.opacity = "opaque";      // fundo escuro sempre (lê-se sobre qualquer papel de parede)

barra.addWidget("org.carinaeos.menuestrela");   // menu estrela (como o da maca)

barra.addWidget("org.carinaeos.nomeapp");
barra.addWidget("org.kde.plasma.appmenu");
barra.addWidget("org.kde.plasma.panelspacer");
barra.addWidget("org.carinaeos.agoratoca");    // a música do MPD (só aparece enquanto toca)
barra.addWidget("org.carinaeos.pesquisa");     // lupa: a Pesquisa (Ctrl+Espaço)
barra.addWidget("org.kde.plasma.systemtray");

var relogio = barra.addWidget("org.kde.plasma.digitalclock");
relogio.currentConfigGroup = ["Appearance"];
relogio.writeConfig("showDate", true);
relogio.writeConfig("dateFormat", "custom");
relogio.writeConfig("customDateFormat", "ddd d MMM");
// eventos do Calendário (inclui a conta Google ligada no Calendário) ao clicar no relógio
relogio.currentConfigGroup = ["General"];
relogio.writeConfig("enabledCalendarPlugins", "pimevents,holidaysevents");
relogio.currentConfigGroup = ["General", "PlasmaCalendarHolidaysEvents"];
relogio.writeConfig("selectedRegions", "br_pt,pt_pt");

// ---- Dock de baixo -----------------------------------------------------------
var dock = new Panel;
dock.location = "bottom";
dock.height = Math.round(48 * 0.14) + 48 + 2 * Math.round(48 * 0.16);  // só o vidro: a Dock cresce sozinha com o rato por cima
dock.floating = false;
dock.alignment = "center";
dock.lengthMode = "fit";
dock.opacity = "translucent";
dock.hiding = "none";   // o carinaeos-ambiente-inicio passa-a a "as janelas passam por baixo" e cria o espaçador (como no Mac)
dock.addWidget("org.carinaeos.dock");
