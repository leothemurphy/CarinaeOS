# AtriumOS: ao entrar no primeiro terminal, abre a interface
[ -f "$HOME/.profile" ] && . "$HOME/.profile"
if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
  atrium-sessao
  echo
  echo "  A interface do AtriumOS fechou ou não conseguiu abrir."
  echo "  Registro: ~/.local/state/atriumos/sessao.log   (ver:  cat ~/.local/state/atriumos/sessao.log)"
  echo "  Para tentar de novo:  atrium-sessao"
  echo
fi
