// AtriumOS — layout padrão: barra de menus no alto + Dock flutuante embaixo

// ---------- barra de menus (alto) ----------
var top = new Panel;
top.location = "top";
top.height = Math.round(gridUnit * 1.7);
top.hiding = "none";
top.floating = false;

var menu = top.addWidget("org.kde.plasma.kickoff");
menu.currentConfigGroup = ["General"];
menu.writeConfig("icon", "atriumos");

top.addWidget("org.kde.plasma.appmenu");
top.addWidget("org.kde.plasma.panelspacer");
top.addWidget("org.kde.plasma.systemtray");

var clock = top.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", true);
clock.writeConfig("dateDisplayFormat", "BesideTime");
clock.writeConfig("dateFormat", "custom");
clock.writeConfig("customDateFormat", "ddd d MMM");

// ---------- Dock (embaixo) ----------
var dock = new Panel;
dock.location = "bottom";
dock.height = Math.round(gridUnit * 3.4);
dock.alignment = "center";
dock.lengthMode = "fit";
dock.floating = true;
dock.hiding = "dodgewindows";

// Launchpad: usa o "Painel de aplicativos" (tela cheia); se não existir, o menu normal
var lpType = (typeof knownWidgetTypes !== "undefined" && knownWidgetTypes.indexOf("org.kde.plasma.kickerdash") >= 0)
  ? "org.kde.plasma.kickerdash" : "org.kde.plasma.kickoff";
var lp = dock.addWidget(lpType);
lp.currentConfigGroup = ["General"];
lp.writeConfig("icon", "view-app-grid-symbolic");

var tasks = dock.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", [
  "applications:org.kde.dolphin.desktop",
  "applications:portico.desktop",
  "applications:libreoffice-writer.desktop",
  "applications:libreoffice-calc.desktop",
  "applications:libreoffice-impress.desktop",
  "applications:org.kde.konsole.desktop",
  "applications:atrium-android.desktop",
  "applications:org.kde.discover.desktop",
  "applications:systemsettings.desktop"
]);
tasks.writeConfig("showOnlyCurrentDesktop", false);

dock.addWidget("org.kde.plasma.marginsseparator");
dock.addWidget("org.kde.plasma.trash");

// ---------- papel de parede ----------
var all = desktopsForActivity(currentActivity());
if (all.length === 0) all = desktops();
for (var i = 0; i < all.length; i++) {
  all[i].wallpaperPlugin = "org.kde.image";
  all[i].currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
  all[i].writeConfig("Image", "file:///usr/share/wallpapers/AtriumOS-Portal/");
}
