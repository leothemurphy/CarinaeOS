// AtriumOS — barra de menus no alto + Dock flutuante embaixo

// ---------- barra de menus (alto) ----------
var top = new Panel;
top.location = "top";
top.height = Math.round(gridUnit * 1.6);
top.hiding = "none";
top.floating = false;

var menu = top.addWidget("org.kde.plasma.kickoff");
menu.currentConfigGroup = ["General"];
menu.writeConfig("icon", "atriumos");
menu.writeConfig("favoritesPortedToKAstats", true);

top.addWidget("org.kde.plasma.appmenu");
top.addWidget("org.kde.plasma.panelspacer");
top.addWidget("org.kde.plasma.systemtray");


var clock = top.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", true);
clock.writeConfig("dateDisplayFormat", "BesideTime");
clock.writeConfig("dateFormat", "custom");
clock.writeConfig("customDateFormat", "ddd d MMM");

// ---------- Dock (embaixo, flutuante, centralizado) ----------
var dock = new Panel;
dock.location = "bottom";
dock.height = Math.round(gridUnit * 3.2);
dock.alignment = "center";
dock.lengthMode = "fit";
dock.floating = true;
dock.hiding = "dodgewindows";

var lp = dock.addWidget("org.kde.plasma.kickerdash");   // Launchpad
lp.currentConfigGroup = ["General"];
lp.writeConfig("icon", "appgrid");

var tasks = dock.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("launchers", [
  "applications:org.kde.dolphin.desktop",
  "applications:chromium.desktop",
  "applications:org.kde.elisa.desktop",
  "applications:libreoffice-writer.desktop",
  "applications:libreoffice-calc.desktop",
  "applications:libreoffice-impress.desktop",
  "applications:io.github.kolunmi.Bazaar.desktop",
  "applications:atrium-android.desktop",
  "applications:org.kde.konsole.desktop",
  "applications:systemsettings.desktop"
]);
tasks.writeConfig("showOnlyCurrentDesktop", false);
tasks.writeConfig("indicateAudioStreams", true);

dock.addWidget("org.kde.plasma.marginsseparator");
dock.addWidget("org.kde.plasma.trash");

// ---------- papel de parede ----------
var all = desktops();
for (var i = 0; i < all.length; i++) {
  all[i].wallpaperPlugin = "org.kde.image";
  all[i].currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
  all[i].writeConfig("Image", "file:///usr/share/wallpapers/AtriumOS-Portal/");
}
