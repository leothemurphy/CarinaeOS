// SPDX-License-Identifier: GPL-2.0-or-later
#include "sistema.h"
#include "../catalogo.h"
#include "../x11.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSaveFile>
#include <QFileSystemWatcher>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QTimer>
#include <QUrl>

#include <unistd.h>
#include <pwd.h>

using namespace X11;

static QString arquivoShell() { return QDir::homePath() + QStringLiteral("/.config/carinaeos-shell.json"); }

Sistema *Sistema::instancia() {
    static Sistema *s = new Sistema;
    return s;
}

Sistema *Sistema::create(QQmlEngine *, QJSEngine *) {
    Sistema *s = instancia();
    QJSEngine::setObjectOwnership(s, QJSEngine::CppOwnership);
    return s;
}

Sistema::Sistema(QObject *parent) : QObject(parent) {
    m_vigia = new QFileSystemWatcher(this);
    lerShell();
    connect(m_vigia, &QFileSystemWatcher::fileChanged, this, [this] { QTimer::singleShot(150, this, &Sistema::lerShell); });
    connect(m_vigia, &QFileSystemWatcher::directoryChanged, this, [this] { QTimer::singleShot(150, this, &Sistema::lerShell); });
    connect(qGuiApp, &QGuiApplication::screenAdded, this, &Sistema::ecraPrincipalChanged);
    connect(qGuiApp, &QGuiApplication::screenRemoved, this, &Sistema::ecraPrincipalChanged);
    connect(qGuiApp, &QGuiApplication::primaryScreenChanged, this, &Sistema::ecraPrincipalChanged);
    if (disponivel()) {
        ouvir(this);
        selecionar(raiz(), XCB_EVENT_MASK_PROPERTY_CHANGE);
        lerAtiva();
    }
}

QString Sistema::casa() const { return QDir::homePath(); }

QString Sistema::nomeUtilizador() const {
    if (const passwd *p = getpwuid(getuid())) {
        const QString gecos = QString::fromLocal8Bit(p->pw_gecos).section(QLatin1Char(','), 0, 0).trimmed();
        if (!gecos.isEmpty()) return gecos;
        const QString login = QString::fromLocal8Bit(p->pw_name);
        if (!login.isEmpty()) return login.left(1).toUpper() + login.mid(1);
    }
    return qEnvironmentVariable("USER");
}

QString Sistema::fotoUtilizador() const {
    const QString login = qEnvironmentVariable("USER");
    const QStringList c = {QDir::homePath() + QStringLiteral("/.face.icon"), QDir::homePath() + QStringLiteral("/.face"),
                           QStringLiteral("/var/lib/AccountsService/icons/") + login,
                           QStringLiteral("/usr/share/carinaeos/marca/avatar-redondo.png")};
    for (const QString &f : c)
        if (QFileInfo(f).isFile() && QFileInfo(f).isReadable()) return QUrl::fromLocalFile(f).toString();
    return QString();
}

QScreen *Sistema::ecraPrincipal() const {
    // o mesmo ficheiro que o CarinaeOS já usava (~/.config/carinaeos/ecra-principal)
    QFile f(QDir::homePath() + QStringLiteral("/.config/carinaeos/ecra-principal"));
    if (f.open(QIODevice::ReadOnly)) {
        const QString nome = QString::fromUtf8(f.readAll()).trimmed();
        for (QScreen *s : QGuiApplication::screens())
            if (s->name() == nome) return s;
    }
    return QGuiApplication::primaryScreen();
}

int Sistema::indicePrincipal() const {
    const int i = QGuiApplication::screens().indexOf(ecraPrincipal());
    return i < 0 ? 0 : i;
}

void Sistema::lerShell() {
    QFile f(arquivoShell());
    QVariantMap m;
    if (f.open(QIODevice::ReadOnly)) m = QJsonDocument::fromJson(f.readAll()).object().toVariantMap();
    if (!m_vigia->files().contains(arquivoShell()) && QFile::exists(arquivoShell())) m_vigia->addPath(arquivoShell());
    const QString pasta = QDir::homePath() + QStringLiteral("/.config");
    if (!m_vigia->directories().contains(pasta)) m_vigia->addPath(pasta);
    if (m != m_shell) {
        m_shell = m;
        Q_EMIT shellChanged();
    }
}

void Sistema::lerAtiva() {
    const QVector<quint32> a = cardinais(raiz(), atomo("_NET_ACTIVE_WINDOW"), XCB_ATOM_WINDOW);
    const xcb_window_t w = a.isEmpty() ? 0 : a.first();
    if (w != m_ativa) {
        m_ativa = w;
        if (w) selecionar(w, XCB_EVENT_MASK_PROPERTY_CHANGE);
    }
    QString titulo, nome, icone;
    if (w && pid(w) != quint32(::getpid())) {
        titulo = X11::titulo(w);
        const auto cl = classe(w);
        QByteArray dica = bytes(w, atomo("_KDE_NET_WM_DESKTOP_FILE"));
        if (dica.isEmpty()) dica = bytes(w, atomo("_GTK_APPLICATION_ID"));
        const QString id = Catalogo::instancia()->idParaJanela(cl.first, cl.second, QString::fromUtf8(dica));
        if (const App *app = Catalogo::instancia()->porId(id)) { nome = app->nome; icone = app->icone; }
        else nome = cl.second.isEmpty() ? titulo : cl.second;
    }
    if (titulo != m_titulo || nome != m_nomeApp || icone != m_iconeApp) {
        m_titulo = titulo;
        m_nomeApp = nome;
        m_iconeApp = icone;
        Q_EMIT ativaChanged();
    }
}

void Sistema::eventoX(xcb_generic_event_t *ev) {
    if ((ev->response_type & ~0x80) != XCB_PROPERTY_NOTIFY) return;
    auto *e = reinterpret_cast<xcb_property_notify_event_t *>(ev);
    if ((e->window == raiz() && e->atom == atomo("_NET_ACTIVE_WINDOW")) ||
        (e->window == m_ativa && (e->atom == atomo("_NET_WM_NAME") || e->atom == XCB_ATOM_WM_NAME)))
        lerAtiva();
}

// --- painéis -------------------------------------------------------------------------------
void Sistema::tornarPainel(QWindow *janela, int borda, int reserva) {
    if (!janela) return;
    // o Qt escreve _NET_WM_WINDOW_TYPE a partir desta propriedade (0x4 = Dock)
    janela->setProperty("_q_xcb_wm_window_type", 0x4);
    janela->winId();
    const xcb_window_t w = xcb_window_t(janela->winId());
    definirCardinais(w, atomo("_NET_WM_WINDOW_TYPE"), XCB_ATOM_ATOM, {atomo("_NET_WM_WINDOW_TYPE_DOCK")});
    definirCardinais(w, atomo("_NET_WM_DESKTOP"), XCB_ATOM_CARDINAL, {0xFFFFFFFFu});
    reservar(janela, borda, reserva);
    QPointer<QWindow> p(janela);
    connect(janela, &QWindow::visibleChanged, this, [this, p, borda, reserva](bool v) {
        if (v && p) {
            definirCardinais(xcb_window_t(p->winId()), atomo("_NET_WM_WINDOW_TYPE"), XCB_ATOM_ATOM, {atomo("_NET_WM_WINDOW_TYPE_DOCK")});
            reservar(p, borda, reserva);
        }
    });
}

void Sistema::reservar(QWindow *janela, int borda, int reserva) {
    if (!janela || !disponivel()) return;
    const xcb_window_t w = xcb_window_t(janela->winId());
    xcb_get_geometry_reply_t *g = xcb_get_geometry_reply(con(), xcb_get_geometry(con(), raiz()), nullptr);
    const int alturaRaiz = g ? g->height : 0;
    free(g);
    const QRect r = janela->geometry();
    QVector<quint32> parcial(12, 0), simples(4, 0);
    const bool emCima = borda == 1 || borda == 3;
    if (reserva > 0) {
        if (emCima) {
            parcial[2] = quint32(r.y() + reserva);
            parcial[8] = quint32(r.x());
            parcial[9] = quint32(r.x() + r.width() - 1);
            simples[2] = parcial[2];
        } else {
            parcial[3] = quint32(qMax(0, alturaRaiz - (r.y() + r.height() - reserva)));
            parcial[10] = quint32(r.x());
            parcial[11] = quint32(r.x() + r.width() - 1);
            simples[3] = parcial[3];
        }
    }
    definirCardinais(w, atomo("_NET_WM_STRUT_PARTIAL"), XCB_ATOM_CARDINAL, parcial);
    definirCardinais(w, atomo("_NET_WM_STRUT"), XCB_ATOM_CARDINAL, simples);
    flush();
}

void Sistema::tornarFundo(QWindow *janela) {
    if (!janela) return;
    janela->setProperty("_q_xcb_wm_window_type", 0x2);
    const xcb_window_t w = xcb_window_t(janela->winId());
    definirCardinais(w, atomo("_NET_WM_WINDOW_TYPE"), XCB_ATOM_ATOM, {atomo("_NET_WM_WINDOW_TYPE_DESKTOP")});
    definirCardinais(w, atomo("_NET_WM_DESKTOP"), XCB_ATOM_CARDINAL, {0xFFFFFFFFu});
    flush();
}

void Sistema::executar(const QString &comando) {
    if (!comando.trimmed().isEmpty())
        QProcess::startDetached(QStringLiteral("/bin/sh"), {QStringLiteral("-c"), comando}, QDir::homePath());
}

void Sistema::correr(const QString &comando, const QJSValue &depois) {
    auto *p = new QProcess(this);
    p->setProcessChannelMode(QProcess::MergedChannels);
    QJSValue cb = depois;
    connect(p, &QProcess::finished, this, [p, cb](int codigo, QProcess::ExitStatus) mutable {
        const QString saida = QString::fromUtf8(p->readAll());
        p->deleteLater();
        if (cb.isCallable()) cb.call({QJSValue(saida), QJSValue(codigo)});
    });
    connect(p, &QProcess::errorOccurred, this, [p, cb](QProcess::ProcessError e) mutable {
        if (e != QProcess::FailedToStart) return;
        p->deleteLater();
        if (cb.isCallable()) cb.call({QJSValue(QString()), QJSValue(127)});
    });
    QTimer::singleShot(8000, p, [p] { if (p->state() != QProcess::NotRunning) p->kill(); });
    p->start(QStringLiteral("/bin/sh"), {QStringLiteral("-c"), comando});
}

void Sistema::papelSeguinte() {
    const QString casa = QDir::homePath();
    QStringList lista;
    QFile pj(casa + QStringLiteral("/.config/carinaeos/papeis.json"));
    if (pj.open(QIODevice::ReadOnly))
        for (const QJsonValue &v : QJsonDocument::fromJson(pj.readAll()).array()) lista << v.toString();
    if (lista.isEmpty())
        lista = {casa + QStringLiteral("/.local/share/carinaeos/papeis/tigre.jpg"),
                 casa + QStringLiteral("/.local/share/carinaeos/papeis/abstrato.jpg"),
                 QStringLiteral("/usr/share/wallpapers/CarinaeOS-Fusao/contents/images/3840x2160.jpg"),
                 QStringLiteral("/usr/share/backgrounds/carinaeos/eta-carinae.jpg"),
                 QStringLiteral("/usr/local/share/carinaeos/papeis/nebulosa.jpg"),
                 QStringLiteral("/usr/local/share/carinaeos/papeis/aurora.jpg"),
                 QStringLiteral("/usr/local/share/carinaeos/papeis/orbita.jpg")};
    QStringList existem;
    for (const QString &f : std::as_const(lista)) if (QFileInfo::exists(f)) existem << f;
    if (existem.isEmpty()) return;
    const QString atual = m_shell.value(QStringLiteral("papel")).toString();
    const QString proximo = existem.value((existem.indexOf(atual) + 1) % existem.size());
    QVariantMap c = m_shell;
    c.insert(QStringLiteral("papel"), proximo);
    c.insert(QStringLiteral("papel2"), proximo);
    gravarTexto(casa + QStringLiteral("/.config/carinaeos-shell.json"),
                QString::fromUtf8(QJsonDocument(QJsonObject::fromVariantMap(c)).toJson(QJsonDocument::Compact)));
}

void Sistema::alternarMesa() {
    if (!X11::disponivel()) return;
    const xcb_atom_t a = X11::atomo("_NET_SHOWING_DESKTOP");
    const QVector<quint32> v = X11::cardinais(X11::raiz(), a, XCB_ATOM_CARDINAL);
    const bool mostrada = !v.isEmpty() && v.first() != 0;
    X11::pedirAoGestor(X11::raiz(), a, mostrada ? 0 : 1);
    X11::flush();
}

void Sistema::focarTeclado(QWindow *janela) {
    if (!janela || !janela->isVisible() || !X11::disponivel()) return;
    const xcb_window_t w = xcb_window_t(janela->winId());
    // 1) pede ao gestor (fonte 2 = "pager": não é tratado como roubo de foco)
    X11::pedirAoGestor(w, X11::atomo("_NET_ACTIVE_WINDOW"), 2, XCB_CURRENT_TIME, 0);
    // 2) e dá-o diretamente: uma app pode pôr o teclado numa janela sua que esteja visível
    xcb_set_input_focus(X11::con(), XCB_INPUT_FOCUS_PARENT, w, XCB_CURRENT_TIME);
    X11::flush();
}

bool Sistema::gravarTexto(const QString &caminho, const QString &texto) {
    QString c = caminho;
    if (c.startsWith(QLatin1String("~/"))) c = QDir::homePath() + c.mid(1);
    QDir().mkpath(QFileInfo(c).absolutePath());
    QSaveFile f(c);
    if (!f.open(QIODevice::WriteOnly)) return false;
    f.write(texto.toUtf8());
    return f.commit();
}

QString Sistema::lerTexto(const QString &caminho) const {
    QString c = caminho;
    if (c.startsWith(QLatin1String("~/"))) c = QDir::homePath() + c.mid(1);
    QFile f(c);
    return f.open(QIODevice::ReadOnly) ? QString::fromUtf8(f.readAll()) : QString();
}

void Sistema::abrirAplicativo(const QString &id) { Catalogo::instancia()->lancar(id); }
