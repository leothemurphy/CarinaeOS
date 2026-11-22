/*
    Aurora (aurora) — a parte visível do CarinaeOS: papel de parede, barra de cima, Dock e Launchpad.
    (o nome antigo, carinae-shell, continua a funcionar)

      aurora                    arranca (uma vez por sessão)
      aurora --enviar lancador  abre/fecha o Launchpad (é o que a Gravidade faz com a tecla Super)
      aurora --enviar 'tarefa 3'  ativa o 3.º ícone da Dock
      aurora --enviar recarregar  relê o QML (depois de mexer na Dock ou no lançador)

    O QML vive em /usr/local/share/carinaeos/shell (ou $CARINAE_QML): pode ser editado sem recompilar.
    SPDX-License-Identifier: GPL-2.0-or-later
*/
#include <QApplication>
#include <QDir>
#include <QElapsedTimer>
#include "notificacoes.h"
#include <QFileInfo>
#include <QIcon>
#include <QLocalServer>
#include <QLocalSocket>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QSettings>
#include <QTextStream>
#include <QtQml/qqmlextensionplugin.h>

#include "base/plasmoid.h"
#include "base/sistema.h"
#include "base/areatransferencia.h"
#include "catalogo.h"
#include "x11.h"

#include <unistd.h>

Q_IMPORT_QML_PLUGIN(CarinaeOS_CompatPlugin)
Q_IMPORT_QML_PLUGIN(CarinaeOS_BasePlugin)

static QString nomeCanal() { return QStringLiteral("carinae-shell-%1").arg(::getuid()); }

static int enviar(const QString &msg) {
    QLocalSocket s;
    s.connectToServer(nomeCanal());
    if (!s.waitForConnected(1500)) {
        QTextStream(stderr) << "aurora: não está a correr\n";
        return 1;
    }
    s.write(msg.toUtf8() + '\n');
    s.flush();
    s.waitForBytesWritten(1000);
    // a Aurora responde "ok" (ou "?" se não conhece o pedido; uma Aurora antiga não responde nada)
    QByteArray resposta;
    if (s.waitForReadyRead(2000)) resposta = s.readLine().trimmed();
    s.disconnectFromServer();
    if (resposta == "ok") return 0;
    // uma Aurora antiga não responde, mas "recarregar" e "sair" ela também conhece
    if (resposta.isEmpty() && (msg == QLatin1String("recarregar") || msg == QLatin1String("sair"))) return 0;
    QTextStream(stderr) << "aurora: o pedido \"" << msg << "\" não foi aceite"
                        << (resposta.isEmpty() ? " (a Aurora a correr é antiga: aurora --enviar recarregar)" : "") << "\n";
    return 3;
}

static QString pastaQml() {
    const QString env = qEnvironmentVariable("CARINAE_QML");
    if (!env.isEmpty()) return env;
    const QString junto = QDir::cleanPath(QCoreApplication::applicationDirPath() + QStringLiteral("/../share/carinaeos/shell"));
    if (QFileInfo::exists(junto + QStringLiteral("/shell/Main.qml"))) return junto;
#ifdef CARINAE_QML_FONTE
    return QStringLiteral(CARINAE_QML_FONTE);
#else
    return junto;
#endif
}

static void escolherTemaDeIcones() {
    QString tema = QIcon::themeName();
    if (tema.isEmpty() || tema == QLatin1String("hicolor")) {
        QSettings kde(QDir::homePath() + QStringLiteral("/.config/kdeglobals"), QSettings::IniFormat);
        tema = kde.value(QStringLiteral("Icons/Theme")).toString();
        if (tema.isEmpty()) tema = QStringLiteral("WhiteSur-dark");
        QIcon::setThemeName(tema);
    }
    QIcon::setFallbackThemeName(QStringLiteral("hicolor"));
}

int main(int argc, char **argv) {
    QElapsedTimer relogio;
    relogio.start();
    for (int i = 1; i < argc; ++i) {
        const QString a = QString::fromLocal8Bit(argv[i]);
        if ((a == QLatin1String("--enviar") || a == QLatin1String("--send")) && i + 1 < argc)
            return enviar(QString::fromLocal8Bit(argv[i + 1]));
        if (a == QLatin1String("--ajuda") || a == QLatin1String("--help")) {
            QTextStream(stdout) << "aurora [--enviar lancador|'tarefa N'|mesa|papel-seguinte|desligar|recarregar|sair]\n";
            return 0;
        }
    }

    // o CarinaeOS (por agora) é X11: o carinae-wm e a Dock falam EWMH
    if (qEnvironmentVariableIsEmpty("QT_QPA_PLATFORM")) qputenv("QT_QPA_PLATFORM", "xcb");
    QQuickWindow::setDefaultAlphaBuffer(true);
    QApplication app(argc, argv);
    QTextStream(stderr) << "aurora: [QApplication] " << relogio.elapsed() << " ms\n";
    app.setApplicationName(QStringLiteral("carinae-shell"));
    app.setOrganizationName(QStringLiteral("CarinaeOS"));
    app.setDesktopFileName(QStringLiteral("carinae-shell"));
    app.setQuitOnLastWindowClosed(false);
    escolherTemaDeIcones();
    QTextStream(stderr) << "aurora: [tema de ícones] " << relogio.elapsed() << " ms\n";
    // os controlos (menus, campos, botões) usam o Fusion do Qt, com as cores da sessão (qt6ct) — sem o
    // estilo org.kde.desktop, que puxava o Kirigami e as bibliotecas do KDE
    if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE")) QQuickStyle::setStyle(QStringLiteral("Fusion"));
    QTextStream(stderr) << "aurora: [estilo] " << relogio.elapsed() << " ms\n";

    // só uma Aurora por sessão
    {
        QLocalSocket teste;
        teste.connectToServer(nomeCanal());
        if (teste.waitForConnected(300)) {
            QTextStream(stderr) << "aurora: já está a correr\n";
            return 0;
        }
    }
    QLocalServer::removeServer(nomeCanal());
    QLocalServer servidor;
    servidor.setSocketOptions(QLocalServer::UserAccessOption);
    if (!servidor.listen(nomeCanal())) QTextStream(stderr) << "aurora: sem canal de comandos\n";

    X11::instalarFiltro();
    QTextStream(stderr) << "aurora: [X11] " << relogio.elapsed() << " ms\n";
    Catalogo::instancia();
    QTextStream(stderr) << "aurora: [catálogo de apps] " << relogio.elapsed() << " ms\n";
    const QString qml = pastaQml();
    Sistema::instancia()->setPastaQml(qml);

    QQmlApplicationEngine motor;
    motor.addImportPath(QStringLiteral("qrc:/qt/qml"));
    motor.addImportPath(qml + QStringLiteral("/modulos"));

    AreaTransferencia areaTransferencia;
    Notificacoes::instancia();
    QTextStream(stderr) << "aurora: [área de transferência] " << relogio.elapsed() << " ms\n";

    QObject::connect(&servidor, &QLocalServer::newConnection, &app, [&] {
        while (QLocalSocket *s = servidor.nextPendingConnection()) {
            QObject::connect(s, &QLocalSocket::readyRead, s, [s, &app, &servidor] {
                while (s->canReadLine()) {
                    const QString m = QString::fromUtf8(s->readLine()).trimmed();
                    bool conhecido = true;
                    if (m == QLatin1String("lancador")) Plasmoid::instancia()->ativar();
                    else if (m.startsWith(QLatin1String("tarefa "))) Sistema::instancia()->pedirTarefa(m.mid(7).toInt());
                    else if (m == QLatin1String("mesa")) Sistema::instancia()->alternarMesa();
                    else if (m == QLatin1String("papel-seguinte")) Sistema::instancia()->papelSeguinte();
                    else if (m.startsWith(QLatin1String("desligar"))) Sistema::instancia()->pedirDesligar(m.mid(8).trimmed());
                    else if (m == QLatin1String("recarregar")) {
                        // reinicia o shell (o QML é relido do disco)
                        static_cast<Configuracao *>(Plasmoid::instancia()->configuration())->gravarJa();
                        servidor.close();
                        // na sessão do CarinaeOS o startcarinae volta a arrancar-nos (código 42);
                        // fora dela (ex.: carinae-experimentar) arrancamos nós a nova cópia
                        if (qEnvironmentVariableIsSet("CARINAE_VIGIADO")) app.exit(42);
                        else { QProcess::startDetached(QCoreApplication::applicationFilePath(), {}); app.quit(); }
                    } else if (m == QLatin1String("sair")) app.quit();
                    else conhecido = false;
                    s->write(conhecido ? "ok\n" : "?\n");
                    s->flush();
                }
            });
            QObject::connect(s, &QLocalSocket::disconnected, s, &QObject::deleteLater);
        }
    });

    QObject::connect(&motor, &QQmlApplicationEngine::objectCreationFailed, &app, [] {
        QTextStream(stderr) << "aurora: o QML não carregou (vê os erros acima)\n";
        QCoreApplication::exit(2);
    }, Qt::QueuedConnection);
    QTextStream(stderr) << "aurora: pronta a carregar o QML em " << relogio.elapsed() << " ms\n";
    motor.load(QUrl::fromLocalFile(qml + QStringLiteral("/shell/Main.qml")));
    QTextStream(stderr) << "aurora: QML carregado em " << relogio.elapsed() << " ms\n";
    const int r = app.exec();
    static_cast<Configuracao *>(Plasmoid::instancia()->configuration())->gravarJa();
    return r;
}
