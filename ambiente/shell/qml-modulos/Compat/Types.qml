// CarinaeOS — os valores de PlasmaCore.Types que a Dock usa
import QtQuick

QtObject {
    enum Location { Floating = 0, Desktop = 1, FullScreen = 2, TopEdge = 3, BottomEdge = 4, LeftEdge = 5, RightEdge = 6 }
    enum FormFactor { Planar = 0, MediaCenter = 1, Horizontal = 2, Vertical = 3, Application = 4 }
    enum BackgroundHints { NoBackground = 0, StandardBackground = 1, TranslucentBackground = 2, ShadowBackground = 4, ConfigurableBackground = 8 }
}
