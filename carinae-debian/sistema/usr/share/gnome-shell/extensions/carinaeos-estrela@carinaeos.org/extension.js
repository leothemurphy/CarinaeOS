// CarinaeOS - menu estrela na barra de cima do GNOME (o mesmo do Plasma)
import St from 'gi://St';
import Gio from 'gi://Gio';
import GLib from 'gi://GLib';
import * as Main from 'resource:///org/gnome/shell/ui/main.js';
import * as PanelMenu from 'resource:///org/gnome/shell/ui/panelMenu.js';
import * as PopupMenu from 'resource:///org/gnome/shell/ui/popupMenu.js';
import {Extension} from 'resource:///org/gnome/shell/extensions/extension.js';

export default class Estrela extends Extension {
    enable() {
        this._botao = new PanelMenu.Button(0.0, 'CarinaeOS', false);
        this._botao.add_child(new St.Icon({
            gicon: Gio.icon_new_for_string('carinaeos-estrela'),
            style_class: 'system-status-icon',
        }));
        const item = (texto, cmd) => {
            const i = new PopupMenu.PopupMenuItem(texto);
            i.connect('activate', () => GLib.spawn_command_line_async(cmd));
            this._botao.menu.addMenuItem(i);
        };
        const linha = () => this._botao.menu.addMenuItem(new PopupMenu.PopupSeparatorMenuItem());
        item('Sobre este computador', 'gnome-control-center system');
        linha();
        item('Central CarinaeOS…', 'carinaeos-central');
        item('Configurações do sistema…', 'gnome-control-center');
        item('Órbita (aplicativos)…', 'carinaeos-orbita');
        item('Perguntar à Eta…', 'carinaeos-eta');
        linha();
        item('Bloquear o ecrã', 'loginctl lock-session');
        item('Terminar sessão…', 'gnome-session-quit --logout');
        linha();
        item('Reiniciar…', 'gnome-session-quit --reboot');
        item('Desligar…', 'gnome-session-quit --power-off');
        Main.panel.addToStatusArea('carinaeos-estrela', this._botao, 0, 'left');
        Main.panel.statusArea.activities?.hide();
    }

    disable() {
        this._botao?.destroy();
        this._botao = null;
        Main.panel.statusArea.activities?.show();
    }
}
