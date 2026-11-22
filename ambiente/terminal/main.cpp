// CarinaeOS — Terminal Carinae (carinae-terminal): abas, temas do CarinaeOS, sem o Konsole.
//   carinae-terminal                       abre uma janela com a shell
//   carinae-terminal -e comando args…      corre um comando (compatível com x-terminal-emulator)
//   carinae-terminal --workdir PASTA       começa nesta pasta
//   carinae-terminal --hold                não fecha a aba quando o comando acaba
#include "terminal.h"

#include <QDir>
#include <QFile>
#include <QFileSystemWatcher>
#include <QGuiApplication>
#include <QIcon>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QStandardPaths>
#include <QTimer>

// a aparência guardada em ~/.config/carinaeos/terminal.json (escrita pela "Aparência do terminal")
class Configuracao : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap dados READ dados NOTIFY mudou)
public:
    explicit Configuracao(QObject *pai = nullptr) : QObject(pai) {
        m_pasta = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation) + QStringLiteral("/carinaeos");
        m_ficheiro = m_pasta + QStringLiteral("/terminal.json");
        QDir().mkpath(m_pasta);
        m_vigia.addPath(m_pasta);
        if (QFile::exists(m_ficheiro)) m_vigia.addPath(m_ficheiro);
        m_atraso.setSingleShot(true);
        m_atraso.setInterval(150);
        connect(&m_vigia, &QFileSystemWatcher::directoryChanged, &m_atraso, qOverload<>(&QTimer::start));
        connect(&m_vigia, &QFileSystemWatcher::fileChanged, &m_atraso, qOverload<>(&QTimer::start));
        connect(&m_atraso, &QTimer::timeout, this, &Configuracao::ler);
        ler();
    }
    QVariantMap dados() const { return m_dados; }

    Q_INVOKABLE void novaJanela(const QString &pasta) {
        QProcess::startDetached(QCoreApplication::applicationFilePath(), {QStringLiteral("--workdir"), pasta});
    }
    Q_INVOKABLE void abrir(const QString &programa, const QStringList &args) { QProcess::startDetached(programa, args); }

signals:
    void mudou();

private:
    void ler() {
        if (QFile::exists(m_ficheiro) && !m_vigia.files().contains(m_ficheiro)) m_vigia.addPath(m_ficheiro);
        QFile f(m_ficheiro);
        QVariantMap novo;
        if (f.open(QIODevice::ReadOnly)) novo = QJsonDocument::fromJson(f.readAll()).object().toVariantMap();
        if (novo != m_dados) {
            m_dados = novo;
            emit mudou();
        }
    }
    QString m_pasta, m_ficheiro;
    QVariantMap m_dados;
    QFileSystemWatcher m_vigia;
    QTimer m_atraso;
};

int main(int argc, char **argv) {
    QQuickStyle::setStyle(QStringLiteral("Fusion"));
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("carinae-terminal"));
    app.setApplicationDisplayName(QStringLiteral("Carinae Terminal"));
    app.setDesktopFileName(QStringLiteral("carinaeos-terminal"));
    app.setWindowIcon(QIcon::fromTheme(QStringLiteral("carinaeos-terminal"), QIcon::fromTheme(QStringLiteral("utilities-terminal"))));

    QStringList comando;
    QString pasta = QDir::currentPath();
    QString titulo;
    bool manter = false;
    const QStringList a = app.arguments();
    for (int i = 1; i < a.size(); ++i) {
        const QString &x = a[i];
        if (x == QLatin1String("-e") || x == QLatin1String("-x") || x == QLatin1String("--")) { comando = a.mid(i + 1); break; }
        if ((x == QLatin1String("--workdir") || x == QLatin1String("-w") || x == QLatin1String("--working-directory")) && i + 1 < a.size()) pasta = a[++i];
        else if (x.startsWith(QLatin1String("--working-directory="))) pasta = x.mid(20);
        else if ((x == QLatin1String("-T") || x == QLatin1String("--title")) && i + 1 < a.size()) titulo = a[++i];
        else if (x == QLatin1String("--hold") || x == QLatin1String("--noclose") || x == QLatin1String("-hold")) manter = true;
        else if (x == QLatin1String("--help") || x == QLatin1String("-h")) {
            fputs("carinae-terminal [--workdir PASTA] [--hold] [-T TÍTULO] [-e COMANDO ARGS…]\n", stdout);
            return 0;
        }
    }
    if (pasta.isEmpty() || !QDir(pasta).exists()) pasta = QDir::homePath();

    qmlRegisterType<Terminal>("CarinaeOS.Terminal", 1, 0, "Terminal");
    Configuracao cfg;
    QQmlApplicationEngine motor;
    motor.rootContext()->setContextProperty(QStringLiteral("configuracao"), &cfg);
    motor.rootContext()->setContextProperty(QStringLiteral("comandoInicial"), comando);
    motor.rootContext()->setContextProperty(QStringLiteral("pastaInicial"), pasta);
    motor.rootContext()->setContextProperty(QStringLiteral("tituloInicial"), titulo);
    motor.rootContext()->setContextProperty(QStringLiteral("manterInicial"), manter);
    motor.load(QUrl(QStringLiteral("qrc:/terminal/Main.qml")));
    if (motor.rootObjects().isEmpty()) return 1;
    return app.exec();
}

#include "main.moc"
