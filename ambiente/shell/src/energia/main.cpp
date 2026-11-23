// CarinaeOS — carinae-energia: a gestão de energia da sessão (substitui o powerdevil do KDE).
//  • desliga o ecrã depois de X minutos sem mexer (e bloqueia, se assim estiver escolhido);
//  • suspende o computador depois de Y minutos sem mexer (se escolhido);
//  • o botão de ligar/desligar do computador faz o que estiver escolhido (por omissão: pergunta);
//  • é o serviço org.freedesktop.ScreenSaver e org.freedesktop.PowerManagement.Inhibit: quando o
//    Firefox, o Chrome, o VLC ou o Pulsar estão a mostrar um vídeo, o ecrã não se apaga.
// As escolhas ficam em ~/.config/carinaeos/energia.json (lidas outra vez sempre que mudam).
//   carinae-energia            o serviço (arrancado pela sessão)
//   carinae-energia --botao    o que fazer quando se carrega no botão de ligar (chamado pela Gravidade)
//   carinae-energia --estado   mostra o estado (inibidores, tempo parado)
// SPDX-License-Identifier: GPL-2.0-or-later
#include <QCoreApplication>
#include <QDBusAbstractAdaptor>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusContext>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusReply>
#include <QDBusServiceWatcher>
#include <QDBusUnixFileDescriptor>
#include <QDir>
#include <QFile>
#include <QFileSystemWatcher>
#include <QHash>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QTextStream>
#include <QTimer>
#include <xcb/screensaver.h>
#include <xcb/xcb.h>

static QTextStream err(stderr);
static QString pastaCfg() { return QDir::homePath() + QStringLiteral("/.config/carinaeos"); }
static QString ficheiroCfg() { return pastaCfg() + QStringLiteral("/energia.json"); }

struct Escolhas {
    int desligarEcra = 0;          // minutos (0 = nunca)
    bool bloquear = false;         // bloquear quando o ecrã se apaga
    bool bloquearAoSuspender = true;
    int suspender = 0;             // minutos (0 = nunca)
    QString botao = QStringLiteral("perguntar");   // perguntar | desligar | suspender | nada
};

// lê um ficheiro de configuração do KDE ("[AC][Display]" não é um grupo que o QSettings entenda)
static QHash<QString, QString> lerKde(const QString &ficheiro) {
    QHash<QString, QString> v;
    QFile f(ficheiro);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return v;
    QString grupo;
    while (!f.atEnd()) {
        const QString l = QString::fromUtf8(f.readLine()).trimmed();
        if (l.startsWith(QLatin1Char('['))) { grupo = l; continue; }
        const int i = l.indexOf(QLatin1Char('='));
        if (i > 0) v.insert(grupo + l.left(i).trimmed(), l.mid(i + 1).trimmed());
    }
    return v;
}

// a primeira vez: o que estava escolhido no Plasma (powerdevil/kscreenlocker), se houver
static Escolhas importarDoPlasma() {
    Escolhas e;
    e.desligarEcra = 10;
    e.bloquear = true;
    const auto pd = lerKde(QDir::homePath() + QStringLiteral("/.config/powerdevilrc"));
    if (!pd.isEmpty()) {
        const bool desliga = pd.value(QStringLiteral("[AC][Display]TurnOffDisplayWhenIdle"), QStringLiteral("true")) != QLatin1String("false");
        const int seg = pd.value(QStringLiteral("[AC][Display]TurnOffDisplayIdleTimeoutSec"), QStringLiteral("600")).toInt();
        e.desligarEcra = desliga && seg > 0 ? qMax(1, seg / 60) : 0;
        const int acao = pd.value(QStringLiteral("[AC][SuspendAndShutdown]AutoSuspendAction"), QStringLiteral("0")).toInt();
        const int segS = pd.value(QStringLiteral("[AC][SuspendAndShutdown]AutoSuspendIdleTimeoutSec"), QStringLiteral("0")).toInt();
        e.suspender = acao == 1 && segS > 0 ? qMax(1, segS / 60) : 0;
    }
    const auto ks = lerKde(QDir::homePath() + QStringLiteral("/.config/kscreenlockerrc"));
    if (!ks.isEmpty()) {
        e.bloquear = ks.value(QStringLiteral("[Daemon]Autolock"), QStringLiteral("true")) != QLatin1String("false");
        e.bloquearAoSuspender = ks.value(QStringLiteral("[Daemon]LockOnResume"), QStringLiteral("true")) != QLatin1String("false");
    }
    return e;
}

static void gravar(const Escolhas &e) {
    QDir().mkpath(pastaCfg());
    QJsonObject o{{QStringLiteral("desligarEcra"), e.desligarEcra}, {QStringLiteral("bloquear"), e.bloquear},
                  {QStringLiteral("bloquearAoSuspender"), e.bloquearAoSuspender},
                  {QStringLiteral("suspender"), e.suspender}, {QStringLiteral("botao"), e.botao}};
    QFile f(ficheiroCfg());
    if (f.open(QIODevice::WriteOnly)) f.write(QJsonDocument(o).toJson());
}

static Escolhas ler() {
    QFile f(ficheiroCfg());
    if (!f.open(QIODevice::ReadOnly)) {
        Escolhas e = importarDoPlasma();
        gravar(e);
        return e;
    }
    const QJsonObject o = QJsonDocument::fromJson(f.readAll()).object();
    Escolhas e;
    e.desligarEcra = o.value(QStringLiteral("desligarEcra")).toInt(10);
    e.bloquear = o.value(QStringLiteral("bloquear")).toBool(true);
    e.bloquearAoSuspender = o.value(QStringLiteral("bloquearAoSuspender")).toBool(true);
    e.suspender = o.value(QStringLiteral("suspender")).toInt(0);
    e.botao = o.value(QStringLiteral("botao")).toString(QStringLiteral("perguntar"));
    return e;
}

static void correr(const QString &cmd) {
    QProcess::startDetached(QStringLiteral("sh"), {QStringLiteral("-c"), QStringLiteral("(") + cmd + QStringLiteral(") >/dev/null 2>&1")});
}

// ---- quem está a pedir para o ecrã não se apagar ----------------------------------------------------
class Inibidores : public QObject {
    Q_OBJECT
public:
    struct Pedido { QString app, motivo, dono; };
    QHash<uint, Pedido> pedidos;
    uint proximo = 1;
    QDBusServiceWatcher *olho;
    explicit Inibidores(QObject *p) : QObject(p) {
        olho = new QDBusServiceWatcher(this);
        olho->setConnection(QDBusConnection::sessionBus());
        olho->setWatchMode(QDBusServiceWatcher::WatchForUnregistration);
        // o programa fechou sem dizer "já podes": larga os pedidos dele
        connect(olho, &QDBusServiceWatcher::serviceUnregistered, this, [this](const QString &dono) {
            for (auto it = pedidos.begin(); it != pedidos.end();)
                it = it.value().dono == dono ? pedidos.erase(it) : std::next(it);
            olho->removeWatchedService(dono);
        });
    }
    uint inibir(const QString &app, const QString &motivo, const QString &dono) {
        const uint c = proximo++;
        pedidos.insert(c, {app, motivo, dono});
        if (!dono.isEmpty()) olho->addWatchedService(dono);
        err << "carinae-energia: " << app << " pede o ecrã ligado (" << motivo << ")\n";
        err.flush();
        return c;
    }
    void largar(uint c) { pedidos.remove(c); }
    bool ativo() const { return !pedidos.isEmpty(); }
};

class Energia;

// org.freedesktop.ScreenSaver (Firefox, Chrome, VLC, mpv, Electron…)
class AdaptadorEcra : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.ScreenSaver")
public:
    AdaptadorEcra(QObject *o, Inibidores *i, Energia *e) : QDBusAbstractAdaptor(o), m_i(i), m_e(e) {}
public Q_SLOTS:
    uint Inhibit(const QString &app, const QString &motivo, const QDBusMessage &msg);
    void UnInhibit(uint cookie) { m_i->largar(cookie); }
    void SimulateUserActivity();
    bool GetActive();
    uint GetActiveTime() { return 0; }
    uint GetSessionIdleTime();
    bool SetActive(bool e);
    void Lock() { correr(QStringLiteral("carinae-sessao bloquear")); }
Q_SIGNALS:
    void ActiveChanged(bool);
private:
    Inibidores *m_i;
    Energia *m_e;
};

// org.freedesktop.PowerManagement.Inhibit (programas mais antigos)
class AdaptadorPM : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.PowerManagement.Inhibit")
public:
    AdaptadorPM(QObject *o, Inibidores *i) : QDBusAbstractAdaptor(o), m_i(i) {}
public Q_SLOTS:
    uint Inhibit(const QString &app, const QString &motivo, const QDBusMessage &msg) { return m_i->inibir(app, motivo, msg.service()); }
    void UnInhibit(uint cookie) { m_i->largar(cookie); }
    bool HasInhibit() { return m_i->ativo(); }
Q_SIGNALS:
    void HasInhibitChanged(bool);
private:
    Inibidores *m_i;
};

// ---- o serviço --------------------------------------------------------------------------------------
class Energia : public QObject {
    Q_OBJECT
public:
    Inibidores *inib;
    Escolhas e;
    xcb_connection_t *x = nullptr;
    xcb_window_t raiz = 0;
    bool ecraApagado = false, bloqueou = false, suspendeu = false;
    QDBusUnixFileDescriptor travaBotao;     // o logind não desliga logo quando se carrega no botão

    Energia() {
        inib = new Inibidores(this);
        x = xcb_connect(nullptr, nullptr);
        if (xcb_connection_has_error(x)) { err << "carinae-energia: sem ecrã X\n"; x = nullptr; }
        else raiz = xcb_setup_roots_iterator(xcb_get_setup(x)).data->root;
        e = ler();
        aplicarX();

        auto *olho = new QFileSystemWatcher(this);
        QDir().mkpath(pastaCfg());
        olho->addPath(pastaCfg());
        olho->addPath(ficheiroCfg());
        auto reler = [this, olho] {
            if (!olho->files().contains(ficheiroCfg()) && QFile::exists(ficheiroCfg())) olho->addPath(ficheiroCfg());
            e = ler();
            err << "carinae-energia: ecrã " << e.desligarEcra << " min, bloquear " << e.bloquear
                << ", suspender " << e.suspender << " min, botão " << e.botao << "\n";
            err.flush();
        };
        connect(olho, &QFileSystemWatcher::fileChanged, this, reler);
        connect(olho, &QFileSystemWatcher::directoryChanged, this, reler);

        auto *t = new QTimer(this);
        t->setInterval(5000);
        connect(t, &QTimer::timeout, this, &Energia::verificar);
        t->start();
        segurarBotao();
    }

    // o X não apaga nem bloqueia por conta própria: quem decide somos nós
    void aplicarX() {
        correr(QStringLiteral("xset s off; xset +dpms; xset dpms 0 0 0"));
    }

    uint parado() const {      // segundos sem teclado/rato
        if (!x) return 0;
        auto *r = xcb_screensaver_query_info_reply(x, xcb_screensaver_query_info(x, raiz), nullptr);
        if (!r) return 0;
        const uint ms = r->ms_since_user_input;
        free(r);
        return ms / 1000;
    }

    // o logind também tem pedidos (ex.: uma cópia grande, o "systemd-inhibit" de um programa)
    bool logindImpede(const QString &o) const {
        QDBusInterface m(QStringLiteral("org.freedesktop.login1"), QStringLiteral("/org/freedesktop/login1"),
                         QStringLiteral("org.freedesktop.login1.Manager"), QDBusConnection::systemBus());
        QDBusMessage r = m.call(QStringLiteral("ListInhibitors"));
        if (r.type() != QDBusMessage::ReplyMessage || r.arguments().isEmpty()) return false;
        const QDBusArgument a = r.arguments().first().value<QDBusArgument>();
        bool impede = false;
        a.beginArray();
        while (!a.atEnd()) {
            QString what, who, why, mode;
            uint uid = 0, pid = 0;
            a.beginStructure();
            a >> what >> who >> why >> mode >> uid >> pid;
            a.endStructure();
            if (mode == QLatin1String("block") && what.split(QLatin1Char(':')).contains(o) && pid != uint(QCoreApplication::applicationPid()))
                impede = true;
        }
        a.endArray();
        return impede;
    }

    void verificar() {
        const uint s = parado();
        if (s < 5) {                      // voltou a mexer
            ecraApagado = bloqueou = suspendeu = false;
            return;
        }
        if (inib->ativo()) return;        // um vídeo a tocar, por exemplo
        if (e.desligarEcra > 0 && s >= uint(e.desligarEcra) * 60 && !ecraApagado && !logindImpede(QStringLiteral("idle"))) {
            ecraApagado = true;
            if (e.bloquear && !bloqueou) {
                bloqueou = true;
                correr(QStringLiteral("loginctl lock-session"));
                QTimer::singleShot(1500, this, [] { correr(QStringLiteral("xset dpms force off")); });
            } else {
                correr(QStringLiteral("xset dpms force off"));
            }
        }
        if (e.suspender > 0 && s >= uint(e.suspender) * 60 && !suspendeu
            && !logindImpede(QStringLiteral("sleep")) && !logindImpede(QStringLiteral("idle"))) {
            suspendeu = true;
            err << "carinae-energia: a suspender (" << s / 60 << " min parado)\n";
            err.flush();
            correr(QStringLiteral("systemctl suspend"));
        }
    }

    void acordar() {
        if (x) { xcb_force_screen_saver(x, XCB_SCREEN_SAVER_RESET); xcb_flush(x); }
        correr(QStringLiteral("xset dpms force on"));
        ecraApagado = false;
    }

    // o botão de ligar: o logind deixa de desligar logo; a Gravidade apanha a tecla e chama --botao
    void segurarBotao() {
        QDBusInterface m(QStringLiteral("org.freedesktop.login1"), QStringLiteral("/org/freedesktop/login1"),
                         QStringLiteral("org.freedesktop.login1.Manager"), QDBusConnection::systemBus());
        QDBusReply<QDBusUnixFileDescriptor> r = m.call(QStringLiteral("Inhibit"), QStringLiteral("handle-power-key:handle-suspend-key"),
                                                       QStringLiteral("CarinaeOS"), QStringLiteral("O CarinaeOS trata do botão de ligar"),
                                                       QStringLiteral("block"));
        if (r.isValid()) travaBotao = r.value();
        else err << "carinae-energia: não consegui segurar o botão de ligar (" << r.error().message() << ")\n";
    }
};

uint AdaptadorEcra::Inhibit(const QString &app, const QString &motivo, const QDBusMessage &msg) {
    return m_i->inibir(app, motivo, msg.service());
}
void AdaptadorEcra::SimulateUserActivity() { m_e->acordar(); }
bool AdaptadorEcra::GetActive() { return m_e->ecraApagado; }
uint AdaptadorEcra::GetSessionIdleTime() { return m_e->parado(); }
bool AdaptadorEcra::SetActive(bool ativo) {
    if (ativo) correr(QStringLiteral("xset dpms force off"));
    else m_e->acordar();
    return true;
}

// --botao: o que fazer quando se carrega no botão de ligar
static int botao() {
    const Escolhas e = ler();
    if (e.botao == QLatin1String("desligar")) correr(QStringLiteral("carinae-sessao desligar --sem-perguntar"));
    else if (e.botao == QLatin1String("suspender")) correr(QStringLiteral("carinae-sessao suspender"));
    else if (e.botao == QLatin1String("perguntar")) correr(QStringLiteral("aurora --enviar desligar || carinae-sessao desligar"));
    return 0;
}

int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("carinae-energia"));
    const QStringList args = app.arguments();
    if (args.contains(QStringLiteral("--botao"))) return botao();
    if (args.contains(QStringLiteral("--estado"))) {
        QDBusInterface s(QStringLiteral("org.freedesktop.ScreenSaver"), QStringLiteral("/org/freedesktop/ScreenSaver"),
                         QStringLiteral("org.freedesktop.ScreenSaver"));
        QDBusReply<uint> p = s.call(QStringLiteral("GetSessionIdleTime"));
        QTextStream(stdout) << "parado há " << (p.isValid() ? p.value() : 0) << " s\n" << QFile(ficheiroCfg()).fileName() << "\n";
        return 0;
    }

    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) { err << "carinae-energia: sem D-Bus\n"; return 1; }
    if (bus.interface()->isServiceRegistered(QStringLiteral("org.freedesktop.ScreenSaver")).value()) {
        err << "carinae-energia: já há outro serviço de ecrã ("
            << bus.interface()->serviceOwner(QStringLiteral("org.freedesktop.ScreenSaver")).value() << ")\n";
    }
    Energia energia;
    auto *objEcra = new QObject(&app);
    new AdaptadorEcra(objEcra, energia.inib, &energia);
    auto *objPM = new QObject(&app);
    new AdaptadorPM(objPM, energia.inib);
    bus.registerObject(QStringLiteral("/org/freedesktop/ScreenSaver"), objEcra);
    bus.registerObject(QStringLiteral("/ScreenSaver"), objEcra);
    bus.registerObject(QStringLiteral("/org/freedesktop/PowerManagement/Inhibit"), objPM);
    bus.registerService(QStringLiteral("org.freedesktop.ScreenSaver"));
    bus.registerService(QStringLiteral("org.freedesktop.PowerManagement"));
    bus.registerService(QStringLiteral("org.freedesktop.PowerManagement.Inhibit"));
    err << "carinae-energia: pronto (ecrã " << energia.e.desligarEcra << " min, suspender " << energia.e.suspender << " min)\n";
    err.flush();
    return app.exec();
}

#include "main.moc"
