// CarinaeOS — cores e letras (substitui Kirigami.Theme; o CarinaeOS é escuro)
pragma Singleton
import QtQuick

QtObject {
    readonly property color textColor: "#f1eef6"
    readonly property color disabledTextColor: Qt.rgba(0.94, 0.93, 0.96, 0.45)
    readonly property color backgroundColor: "#1c1a22"
    readonly property color alternateBackgroundColor: "#24212c"
    readonly property color highlightColor: "#7b5cff"
    readonly property color highlightedTextColor: "#ffffff"
    readonly property color linkColor: "#8fb4ff"
    readonly property color negativeTextColor: "#ff6b6b"
    readonly property color positiveTextColor: "#5fd38d"
    readonly property color neutralTextColor: "#ffb46e"
    readonly property font defaultFont: Qt.application.font
    readonly property font smallFont: Qt.font({ family: Qt.application.font.family, pointSize: Math.max(7, Qt.application.font.pointSize - 1) })
}
