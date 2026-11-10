// CarinaeOS - o nome do aplicativo ativo em negrito na barra de cima (como no macOS), com um menu
// da janela. Aparece sempre, mesmo com aplicativos que nao mostram menus na barra (Chrome, Electron).
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PC
import org.kde.taskmanager as TaskManager

PlasmoidItem {
    id: raiz
    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: "NoBackground"

    TaskManager.TasksModel {
        id: tarefas
        groupMode: TaskManager.TasksModel.GroupDisabled
        filterByVirtualDesktop: false
        filterByScreen: false
    }
    property var ativo: tarefas.activeTask
    property bool temJanela: false
    property string nome: "Área de trabalho"
    function atualizar() {
        const i = tarefas.activeTask
        let n = i ? (tarefas.data(i, TaskManager.AbstractTasksModel.AppName) || tarefas.data(i, Qt.DisplayRole) || "") : ""
        n = String(n).replace(/ ESR$/, "")
        temJanela = n !== ""
        ativo = i
        nome = n === "" ? "Área de trabalho" : (n.length > 28 ? n.slice(0, 27) + "…" : n)
    }
    Connections {
        target: tarefas
        function onActiveTaskChanged() { raiz.atualizar() }
        function onDataChanged() { raiz.atualizar() }
        function onCountChanged() { raiz.atualizar() }
    }
    Timer { interval: 700; running: true; repeat: true; onTriggered: raiz.atualizar() }
    Component.onCompleted: atualizar()

    fullRepresentation: Item {
        Layout.preferredWidth: botao.implicitWidth
        Layout.minimumWidth: botao.implicitWidth
        implicitWidth: botao.implicitWidth
        PC.ToolButton {
            id: botao
            anchors.verticalCenter: parent.verticalCenter
            text: raiz.nome
            font.bold: true
            flat: true
            onClicked: if (raiz.temJanela) menu.popup(botao, 0, botao.height)
        }
        QQC2.Menu {
            id: menu
            QQC2.MenuItem { text: "Nova janela"; onTriggered: tarefas.requestNewInstance(raiz.ativo) }
            QQC2.MenuSeparator {}
            QQC2.MenuItem { text: "Minimizar"; onTriggered: tarefas.requestToggleMinimized(raiz.ativo) }
            QQC2.MenuItem { text: "Ecrã inteiro / restaurar"; onTriggered: tarefas.requestToggleMaximized(raiz.ativo) }
            QQC2.MenuItem { text: "Manter por cima"; onTriggered: tarefas.requestToggleKeepAbove(raiz.ativo) }
            QQC2.MenuSeparator {}
            QQC2.MenuItem { text: "Fechar a janela"; onTriggered: tarefas.requestClose(raiz.ativo) }
        }
    }
}
