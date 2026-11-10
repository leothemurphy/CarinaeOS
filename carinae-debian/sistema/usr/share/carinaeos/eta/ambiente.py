# CarinaeOS - Eta: os comandos da Eta foram escritos para o KDE Plasma; aqui sao traduzidos
# para o ambiente em uso (GNOME ou XFCE), para que "abre as configuracoes de som" ou
# "liga o modo claro" funcionem em qualquer um.
import os
import re


def ambiente():
    d = (os.environ.get('XDG_CURRENT_DESKTOP', '') + ':' + os.environ.get('DESKTOP_SESSION', '')).lower()
    if 'gnome' in d or 'ubuntu' in d:
        return 'gnome'
    if 'xfce' in d:
        return 'xfce'
    return 'plasma'


AMB = ambiente()
NOME = {'plasma': 'KDE Plasma', 'gnome': 'GNOME', 'xfce': 'XFCE'}[AMB]

# kcmshell6 <modulo>  ->  (GNOME, XFCE)
PAINEIS = {
    'kcm_kscreen': ('gnome-control-center display', 'xfce4-display-settings'),
    'kcm_wallpaper': ('gnome-control-center background', 'xfdesktop-settings'),
    'kcm_networkmanagement': ('gnome-control-center wifi', 'nm-connection-editor'),
    'kcm_bluetooth': ('gnome-control-center bluetooth', 'blueman-manager'),
    'kcm_pulseaudio': ('gnome-control-center sound', 'pavucontrol'),
    'kcm_users': ('gnome-control-center users', 'xfce4-settings-manager'),
    'kcm_regionandlang': ('gnome-control-center region', 'xfce4-settings-manager'),
    'kcm_keyboard': ('gnome-control-center keyboard', 'xfce4-keyboard-settings'),
    'kcm_mouse': ('gnome-control-center mouse', 'xfce4-mouse-settings'),
    'kcm_touchpad': ('gnome-control-center mouse', 'xfce4-mouse-settings'),
    'kcm_powerdevilprofilesconfig': ('gnome-control-center power', 'xfce4-power-manager-settings'),
    'kcm_clock': ('gnome-control-center system', 'xfce4-settings-manager'),
    'kcm_printer_manager': ('gnome-control-center printers', 'system-config-printer'),
    'kcm_notifications': ('gnome-control-center notifications', 'xfce4-notifyd-config'),
    'kcm_componentchooser': ('gnome-control-center default-apps', 'xfce4-mime-settings'),
    'kcm_colors': ('gnome-control-center appearance', 'xfce4-appearance-settings'),
    'kcm_lookandfeel': ('gnome-control-center appearance', 'xfce4-appearance-settings'),
    'kcm_keys': ('gnome-control-center keyboard', 'xfce4-keyboard-settings'),
    'kcm_about-distro': ('gnome-control-center system', 'xfce4-about'),
}


def adaptar(cmd):
    """Devolve o comando equivalente no ambiente atual, ou None se ali nao existir."""
    if AMB == 'plasma' or not cmd:
        return cmd
    g = AMB == 'gnome'
    m = re.match(r'^\s*kcmshell6\s+(\S+)', cmd)
    if m:
        par = PAINEIS.get(m.group(1))
        if par:
            return par[0] if g else par[1]
        return 'gnome-control-center' if g else 'xfce4-settings-manager'
    if re.match(r'^\s*systemsettings\b', cmd):
        return 'gnome-control-center' if g else 'xfce4-settings-manager'
    m = re.match(r'^\s*plasma-apply-colorscheme\s+(\S+)', cmd)
    if m:
        claro = 'light' in m.group(1).lower() or 'claro' in m.group(1).lower()
        if g:
            return 'gsettings set org.gnome.desktop.interface color-scheme %s' % ('default' if claro else 'prefer-dark')
        return "xfconf-query -c xsettings -p /Net/ThemeName -s %s" % ('Adwaita' if claro else 'Adwaita-dark')
    m = re.match(r'^\s*plasma-apply-wallpaperimage\s+(.+)$', cmd)
    if m:
        return 'carinaeos-fundo %s' % m.group(1)
    if 'NightColor' in cmd and 'kwriteconfig6' in cmd:
        if not g:
            return None
        ligar = re.search(r'Active\s+true', cmd) is not None
        return 'gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled %s' % ('true' if ligar else 'false')
    if re.search(r'\b(qdbus6 org\.kde\.KWin|kwriteconfig6 --file kwinrc|plasmashell)\b', cmd):
        return None
    if re.match(r'^\s*dolphin\b', cmd) and g and os.path.exists('/usr/bin/nautilus'):
        return re.sub(r'^\s*dolphin(\s+--select)?', 'nautilus', cmd, 1)
    if re.match(r'^\s*dolphin\b', cmd) and not g and os.path.exists('/usr/bin/thunar'):
        return re.sub(r'^\s*dolphin(\s+--select)?', 'thunar', cmd, 1)
    return cmd
