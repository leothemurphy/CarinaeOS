# AtriumOS: menu dos apps GTK na barra de menus do alto
if [ -d /usr/lib/x86_64-linux-gnu/gtk-3.0/modules ] && ls /usr/lib/x86_64-linux-gnu/gtk-3.0/modules/libappmenu-gtk-module.so >/dev/null 2>&1; then
  case ":${GTK_MODULES:-}:" in *:appmenu-gtk-module:*) ;; *) export GTK_MODULES="${GTK_MODULES:+$GTK_MODULES:}appmenu-gtk-module";; esac
fi
