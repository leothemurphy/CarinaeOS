// CarinaeOS — estilo Windows 11: barra de tarefas em baixo com os ícones ao centro,
// menu Iniciar com a estrela do CarinaeOS, ícones do sistema e relógio à direita.
var desktopsArray = desktopsForActivity(currentActivity());
for (var j = 0; j < desktopsArray.length; j++) {
    var d = desktopsArray[j];
    d.wallpaperPlugin = "org.kde.image";
    d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    d.writeConfig("Image", "file:///usr/share/wallpapers/CarinaeOS");
}

var barra = new Panel;
barra.location = "bottom";
barra.height = 2 * Math.ceil(gridUnit * 2.4 / 2);
barra.floating = false;
barra.lengthMode = "fill";
barra.hiding = "none";                                   // sempre visível

barra.addWidget("org.kde.plasma.panelspacer");

var iniciar = barra.addWidget("org.kde.plasma.kickoff"); // menu Iniciar com a estrela
iniciar.currentConfigGroup = ["General"];
iniciar.writeConfig("icon", "carinaeos-estrela");
iniciar.writeConfig("favoritesDisplay", 0);              // grelha, como no Windows 11
iniciar.writeConfig("applicationsDisplay", 0);
iniciar.writeConfig("alphaSort", true);
iniciar.writeConfig("favoritesPortedToKAstats", true);

var busca = barra.addWidget("org.kde.milou");            // pesquisa ao lado do Iniciar

var tarefas = barra.addWidget("org.kde.plasma.icontasks");
tarefas.currentConfigGroup = ["General"];
tarefas.writeConfig("launchers", ["applications:org.kde.dolphin.desktop", "applications:firefox-esr.desktop",
    "applications:carinaeos-orbita.desktop", "applications:carinaeos-eta.desktop", "applications:carinaeos-supernova.desktop",
    "applications:systemsettings.desktop"]);
tarefas.writeConfig("indicateAudioStreams", true);
tarefas.writeConfig("iconSpacing", 2);

barra.addWidget("org.kde.plasma.panelspacer");
barra.addWidget("org.kde.plasma.systemtray");
var relogio = barra.addWidget("org.kde.plasma.digitalclock");
relogio.currentConfigGroup = ["Appearance"];
relogio.writeConfig("showDate", true);
relogio.writeConfig("dateDisplayFormat", "BelowTime");
relogio.currentConfigGroup = ["General"];
relogio.writeConfig("enabledCalendarPlugins", "pimevents,holidaysevents");
barra.addWidget("org.kde.plasma.showdesktop");
