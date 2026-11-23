// Portado do Plasma pelo portar-do-plasma.py (CarinaeOS). Original: /home/claude/orig/plasmoids/org.carinaeos.dock/contents/ui/FundoIcone.qml
/*
    CarinaeOS — Dock: o quadrado suave por trás de cada ícone, que acende ao passar o mouse
    (nos três modelos). No modelo "Só ícones" (sem fundo) o quadrado é de vidro escuro,
    para se ver também sobre papéis de parede claros.
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick

Item {
    id: fundo
    required property var dock
    required property Item alvo          // o Item do ícone (x, y, width)
    property bool ativo: false           // o mouse está neste ícone
    property bool aberto: false          // a app tem janelas abertas
    property bool focada: false          // a janela da app é a ativa
    property bool pressionado: false
    readonly property bool semFundo: dock.e.fundo === "nenhum"
    readonly property bool efeitos: dock.e.efeito === true
    readonly property bool win: dock.win === true

    visible: dock.e.item === "tile"
    z: -1
    width: win ? dock.base : dock.base * 1.12; height: width
    x: alvo.x + alvo.width / 2 - width / 2
    y: alvo.y + alvo.height / 2 - height / 2

    Rectangle {
        anchors.fill: parent
        radius: fundo.win ? 5 : width * 0.24
        visible: fundo.efeitos
        // Windows 11: cinzento muito leve ao passar, um pouco mais na app ativa, mais escuro ao carregar
        color: fundo.win ? Qt.rgba(1, 1, 1, fundo.pressionado ? 0.045 : fundo.ativo ? 0.085 : fundo.focada ? 0.06 : 0)
             : fundo.semFundo ? Qt.rgba(0.08, 0.08, 0.11, fundo.ativo ? 0.55 : 0)
                              : Qt.rgba(1, 1, 1, fundo.ativo ? 0.15 : fundo.aberto ? 0.05 : 0)
        border.width: 1
        border.color: fundo.win ? Qt.rgba(1, 1, 1, (fundo.ativo || fundo.focada) ? 0.07 : 0)
                    : Qt.rgba(1, 1, 1, fundo.ativo ? (fundo.semFundo ? 0.30 : 0.18) : 0)
        Behavior on color { ColorAnimation { duration: fundo.win ? 90 : 160 } }
    }
}
