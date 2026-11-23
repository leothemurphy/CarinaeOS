cmake_minimum_required(VERSION 3.16)
project(carinae-shell VERSION 0.1 LANGUAGES CXX)
include(GNUInstallDirs)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.4 REQUIRED COMPONENTS Core Gui Widgets Qml Quick QuickControls2 DBus)
find_package(PkgConfig REQUIRED)
pkg_check_modules(XCB REQUIRED IMPORTED_TARGET xcb xcb-composite)

qt_standard_project_setup()

# --- CarinaeOS.Compat: o que substitui o Plasma (Kirigami, PlasmaCore, TaskManager, Kicker...) ---
set_source_files_properties(qml-modulos/Compat/Units.qml qml-modulos/Compat/Theme.qml
    PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_library(carinae_compat STATIC)
qt_add_qml_module(carinae_compat
    URI CarinaeOS.Compat
    VERSION 1.0
    OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/CarinaeOS/Compat
    RESOURCE_PREFIX /qt/qml
    SOURCES
        src/x11.h src/x11.cpp
        src/catalogo.h src/catalogo.cpp
        src/compat/datasource.h src/compat/datasource.cpp
        src/compat/icon.h src/compat/icon.cpp
        src/compat/tasksmodel.h src/compat/tasksmodel.cpp
        src/compat/rootmodel.h src/compat/rootmodel.cpp
        src/compat/menu.h src/compat/menu.cpp
        src/compat/windowthumbnail.h src/compat/windowthumbnail.cpp
        src/compat/mpris.h src/compat/mpris.cpp
    QML_FILES
        qml-modulos/Compat/Units.qml
        qml-modulos/Compat/Theme.qml
        qml-modulos/Compat/Label.qml
        qml-modulos/Compat/Button.qml
        qml-modulos/Compat/ActivityInfo.qml
        qml-modulos/Compat/Types.qml
        qml-modulos/Compat/Dialog.qml
        qml-modulos/Compat/DashboardWindow.qml
)
target_include_directories(carinae_compat PUBLIC src src/compat)
target_link_libraries(carinae_compat PUBLIC Qt6::Core Qt6::Gui Qt6::Widgets Qt6::Qml Qt6::Quick Qt6::DBus PkgConfig::XCB)

# --- CarinaeOS.Base: Plasmoid (configuração da Dock), Sistema, KWindowSystem ---
qt_add_library(carinae_base STATIC)
qt_add_qml_module(carinae_base
    URI CarinaeOS.Base
    VERSION 1.0
    OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/CarinaeOS/Base
    RESOURCE_PREFIX /qt/qml
    SOURCES
        src/base/plasmoid.h src/base/plasmoid.cpp
        src/base/sistema.h src/base/sistema.cpp
        src/base/bandeja.h src/base/bandeja.cpp
        src/base/vigia.h src/base/vigia.cpp
        src/base/areatransferencia.h src/base/areatransferencia.cpp
        src/base/notificacoes.h src/base/notificacoes.cpp
    QML_FILES
        qml-modulos/Base/PlasmoidItem.qml
)
target_include_directories(carinae_base PUBLIC src src/base)
target_link_libraries(carinae_base PUBLIC carinae_compat)

qt_add_executable(carinae-shell src/main.cpp)
target_compile_definitions(carinae-shell PRIVATE CARINAE_QML_FONTE="${CMAKE_CURRENT_SOURCE_DIR}/qml")
target_link_libraries(carinae-shell PRIVATE
    carinae_compatplugin carinae_baseplugin carinae_compat carinae_base
    Qt6::Widgets Qt6::Quick Qt6::QuickControls2)


set_target_properties(carinae-shell PROPERTIES OUTPUT_NAME aurora)
install(TARGETS carinae-shell RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

# o vigia da bandeja: um processo pequeno, sempre ligado durante a sessão
qt_add_executable(carinae-vigia-bandeja src/vigia/main.cpp src/base/vigia.h src/base/vigia.cpp)
target_link_libraries(carinae-vigia-bandeja PRIVATE Qt6::Core Qt6::DBus)
install(TARGETS carinae-vigia-bandeja RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

# a energia da sessão (ecrã, suspender, botão de ligar, "não apagar durante os vídeos"): substitui o powerdevil
pkg_check_modules(XSS REQUIRED IMPORTED_TARGET xcb xcb-screensaver)
qt_add_executable(carinae-energia src/energia/main.cpp)
target_link_libraries(carinae-energia PRIVATE Qt6::Core Qt6::DBus PkgConfig::XSS)
install(TARGETS carinae-energia RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
# o nome antigo continua a funcionar (carinae-shell --enviar ...)
install(CODE "execute_process(COMMAND \${CMAKE_COMMAND} -E rm -f \$ENV{DESTDIR}${CMAKE_INSTALL_FULL_BINDIR}/carinae-shell)
              execute_process(COMMAND \${CMAKE_COMMAND} -E create_symlink aurora \$ENV{DESTDIR}${CMAKE_INSTALL_FULL_BINDIR}/carinae-shell)")
install(DIRECTORY qml/ DESTINATION ${CMAKE_INSTALL_DATADIR}/carinaeos/shell)
