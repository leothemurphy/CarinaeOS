// carinae-bloqueio — ecrã de bloqueio do CarinaeOS.
// Cobre todos os ecrãs, agarra teclado e rato (X11) e só sai (código 0) com a senha certa (PAM).
// Qualquer outra saída é tratada como falha pelo carinae-sessao, que volta a bloquear.
#include <QGuiApplication>
#include <QQmlEngine>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQuickWindow>
#include <QScreen>
#include <QTimer>
#include <QFile>
#include <QDir>
#include <QJsonDocument>
#include <QJsonObject>
#include <QStandardPaths>
#include <QUrl>
#include <QPointer>
#include <xcb/xcb.h>
#include <security/pam_appl.h>
#include <pwd.h>
#include <unistd.h>
#include <cstring>
#include <cstdlib>
#include <thread>

struct DadosPam { QByteArray senha; };

static int conversa(int n, const struct pam_message **msg, struct pam_response **resp, void *dados) {
    auto *d = static_cast<DadosPam *>(dados);
    auto *r = static_cast<pam_response *>(calloc(n, sizeof(pam_response)));
    if (!r) return PAM_BUF_ERR;
    for (int i = 0; i < n; ++i) {
        if (msg[i]->msg_style == PAM_PROMPT_ECHO_OFF || msg[i]->msg_style == PAM_PROMPT_ECHO_ON)
            r[i].resp = strdup(d->senha.constData());
    }
    *resp = r;
    return PAM_SUCCESS;
}

class Bloqueio : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString nome MEMBER m_nome CONSTANT)
    Q_PROPERTY(QString login MEMBER m_login CONSTANT)
    Q_PROPERTY(QUrl avatar MEMBER m_avatar CONSTANT)
    Q_PROPERTY(QUrl papel MEMBER m_papel CONSTANT)
    Q_PROPERTY(bool ocupado READ ocupado NOTIFY ocupadoMudou)
    Q_PROPERTY(bool teclado READ teclado NOTIFY tecladoMudou)
public:
    Bloqueio() {
        const passwd *pw = getpwuid(getuid());
        m_login = pw ? QString::fromLocal8Bit(pw->pw_name) : qEnvironmentVariable("USER");
        if (pw && pw->pw_gecos) m_nome = QString::fromLocal8Bit(pw->pw_gecos).section(QLatin1Char(','), 0, 0).trimmed();
        if (m_nome.isEmpty()) m_nome = m_login;
        const QString casa = QDir::homePath();
        for (const QString &f : {casa + "/.face.icon", casa + "/.face",
                                 "/var/lib/AccountsService/icons/" + m_login})
            if (QFile::exists(f)) { m_avatar = QUrl::fromLocalFile(f); break; }
        QFile cfg(QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + "/carinaeos-shell.json");
        if (cfg.open(QIODevice::ReadOnly)) {
            const QString p = QJsonDocument::fromJson(cfg.readAll()).object().value("papel").toString();
            if (!p.isEmpty() && QFile::exists(p)) m_papel = QUrl::fromLocalFile(p);
        }
    }
    bool ocupado() const { return m_ocupado; }
    bool teclado() const { return m_teclado; }
    void setTeclado(bool t) { if (t != m_teclado) { m_teclado = t; emit tecladoMudou(); } }

    Q_INVOKABLE void desbloquear(const QString &senha) {
        if (m_ocupado) return;
        m_ocupado = true; emit ocupadoMudou();
        QPointer<Bloqueio> eu(this);
        const QByteArray login = m_login.toLocal8Bit();
        QByteArray s = senha.toUtf8();
        std::thread([eu, login, s]() mutable {
            DadosPam d{s};
            pam_conv conv{conversa, &d};
            pam_handle_t *h = nullptr;
            int r = pam_start("carinae-bloqueio", login.constData(), &conv, &h);
            if (r == PAM_SUCCESS) r = pam_authenticate(h, 0);
            if (r == PAM_SUCCESS) pam_setcred(h, PAM_REFRESH_CRED);
            if (h) pam_end(h, r);
            d.senha.fill('\0'); s.fill('\0');
            const bool ok = (r == PAM_SUCCESS);
            QMetaObject::invokeMethod(qApp, [eu, ok]() {
                if (!eu) return;
                if (ok) { QCoreApplication::exit(0); return; }
                eu->m_ocupado = false; emit eu->ocupadoMudou();
                emit eu->errou();
            }, Qt::QueuedConnection);
        }).detach();
    }
signals:
    void ocupadoMudou();
    void tecladoMudou();
    void errou();
private:
    QString m_nome, m_login;
    QUrl m_avatar, m_papel;
    bool m_ocupado = false, m_teclado = false;
};

static xcb_connection_t *ligacao() {
    auto *x = qGuiApp->nativeInterface<QNativeInterface::QX11Application>();
    return x ? x->connection() : nullptr;
}

static bool agarrar(xcb_window_t w) {
    xcb_connection_t *c = ligacao();
    if (!c) return false;
    auto *rk = xcb_grab_keyboard_reply(c, xcb_grab_keyboard(c, 1, w, XCB_CURRENT_TIME,
                                       XCB_GRAB_MODE_ASYNC, XCB_GRAB_MODE_ASYNC), nullptr);
    const bool k = rk && rk->status == XCB_GRAB_STATUS_SUCCESS; free(rk);
    if (!k) return false;
    auto *rp = xcb_grab_pointer_reply(c, xcb_grab_pointer(c, 1, w,
        XCB_EVENT_MASK_BUTTON_PRESS | XCB_EVENT_MASK_BUTTON_RELEASE | XCB_EVENT_MASK_POINTER_MOTION,
        XCB_GRAB_MODE_ASYNC, XCB_GRAB_MODE_ASYNC, XCB_NONE, XCB_NONE, XCB_CURRENT_TIME), nullptr);
    const bool p = rp && rp->status == XCB_GRAB_STATUS_SUCCESS; free(rp);
    if (!p) { xcb_ungrab_keyboard(c, XCB_CURRENT_TIME); xcb_flush(c); }
    return p;
}

int main(int argc, char **argv) {
    qputenv("QT_QPA_PLATFORM", "xcb");
    QGuiApplication app(argc, argv);
    app.setApplicationName("carinae-bloqueio");
    app.setQuitOnLastWindowClosed(false);

    Bloqueio b;
    QQmlEngine motor;
    motor.rootContext()->setContextProperty("bloqueio", &b);
    QQmlComponent comp(&motor, QUrl("qrc:/bloqueio/Ecra.qml"));
    if (comp.isError()) { qWarning() << comp.errors(); return 2; }

    QList<QQuickWindow *> janelas;
    QQuickWindow *principal = nullptr;
    auto criar = [&](QScreen *s) {
        const bool pri = (s == QGuiApplication::primaryScreen()) || !principal;
        QObject *o = comp.createWithInitialProperties({{"ecra", QVariant::fromValue(s)}, {"principal", pri}});
        auto *w = qobject_cast<QQuickWindow *>(o);
        if (!w) { qWarning() << comp.errors(); delete o; return; }
        w->setScreen(s);
        w->setGeometry(s->geometry());
        w->show();
        janelas << w;
        if (pri && !principal) principal = w;
    };
    for (QScreen *s : QGuiApplication::screens()) criar(s);
    if (!principal) return 2;
    QObject::connect(&app, &QGuiApplication::screenAdded, &app, [&](QScreen *s) { criar(s); });
    QObject::connect(&app, &QGuiApplication::screenRemoved, &app, [&](QScreen *s) {
        for (QQuickWindow *w : std::as_const(janelas)) if (w->screen() == s) w->hide();
    });

    // agarrar teclado e rato; tenta até conseguir (um menu aberto pode estar a segurá-los)
    QTimer agarra;
    agarra.setInterval(100);
    QObject::connect(&agarra, &QTimer::timeout, &app, [&]() {
        if (!principal->isExposed()) return;
        if (agarrar(xcb_window_t(principal->winId()))) {
            agarra.stop();
            principal->requestActivate();
            b.setTeclado(true);
            // o xss-lock espera por isto para deixar o sistema suspender
            bool ok = false;
            const int fd = qEnvironmentVariableIntValue("XSS_SLEEP_LOCK_FD", &ok);
            if (ok && fd > 2) close(fd);
        }
    });
    agarra.start();

    // ficar sempre por cima (notificações e menus também são janelas sem gestor)
    QTimer cima;
    cima.setInterval(1000);
    QObject::connect(&cima, &QTimer::timeout, &app, [&]() {
        for (QQuickWindow *w : std::as_const(janelas)) if (w->isVisible()) w->raise();
        if (b.teclado()) principal->requestActivate();
    });
    cima.start();

    return app.exec();
}
#include "main.moc"
