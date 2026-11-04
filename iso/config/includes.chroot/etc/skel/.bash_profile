# AtriumOS: ao entrar no primeiro terminal, abre a interface
[ -f "$HOME/.profile" ] && . "$HOME/.profile"
if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
  exec atrium-sessao
fi
