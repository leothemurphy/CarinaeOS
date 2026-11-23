// CarinaeOS — carinae-senha: o agente de autenticação (polkit) da sessão.
// Quando um programa precisa de permissões de administrador (instalar apps, mudar a data, montar um
// disco, o "pkexec"…), o polkit pergunta-nos; mostramos a janela "Autorizar" com o visual do CarinaeOS
// e passamos a senha ao polkit-agent-helper-1. A senha nunca fica guardada.
// Substitui o polkit-kde-authentication-agent-1. É um processo à parte (como o vigia da bandeja):
// se a Aurora for recarregada, o agente continua.
// SPDX-License-Identifier: GPL-2.0-or-later

#define POLKIT_AGENT_I_KNOW_API_IS_SUBJECT_TO_CHANGE 1
#include <polkitagent/polkitagent.h>
#include <polkit/polkit.h>

#include <QFile>
#include <QGuiApplication>
#include <QIcon>
#include <QObject>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQueue>
#include <QTextStream>
#include <QVariantList>
#include <pwd.h>
#include <unistd.h>

// ---- a ponte para a janela (QML) ---------------------------------------------------------------------
class Pedido : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool ativo READ ativo NOTIFY mudou)
    Q_PROPERTY(QString mensagem READ mensagem NOTIFY mudou)
    Q_PROPERTY(QString acao READ acao NOTIFY mudou)
    Q_PROPERTY(QString programa READ programa NOTIFY mudou)
    Q_PROPERTY(QString icone READ icone NOTIFY mudou)
    Q_PROPERTY(QVariantList utilizadores READ utilizadores NOTIFY mudou)
    Q_PROPERTY(int escolhido READ escolhido NOTIFY mudou)
    Q_PROPERTY(QString pergunta READ pergunta NOTIFY mudou)
    Q_PROPERTY(bool mostrarTexto READ mostrarTexto NOTIFY mudou)
    Q_PROPERTY(QString erro READ erro NOTIFY mudou)
    Q_PROPERTY(QString info READ info NOTIFY mudou)
    Q_PROPERTY(bool ocupado READ ocupado NOTIFY mudou)
    Q_PROPERTY(int tentativa READ tentativa NOTIFY mudou)
public:
    struct Dados {
        QString acao, mensagem, icone, cookie, programa;
        QList<PolkitIdentity *> identidades;
        GTask *tarefa = nullptr;
        GCancellable *cancelar = nullptr;
        gulong idCancelar = 0;
    };

    bool ativo() const { return m_atual != nullptr; }
    QString mensagem() const { return m_atual ? m_atual->mensagem : QString(); }
    QString acao() const { return m_atual ? m_atual->acao : QString(); }
    QString programa() const { return m_atual ? m_atual->programa : QString(); }
    QString icone() const { return m_atual ? m_atual->icone : QString(); }
    QVariantList utilizadores() const { return m_nomes; }
    int escolhido() const { return m_escolhido; }
    QString pergunta() const { return m_pergunta; }
    bool mostrarTexto() const { return m_eco; }
    QString erro() const { return m_erro; }
    QString info() const { return m_info; }
    bool ocupado() const { return m_ocupado; }
    int tentativa() const { return m_tentativa; }

    void novo(Dados *d) {
        m_fila.enqueue(d);
        if (!m_atual) seguinte();
    }

    void cancelado(Dados *d) {               // o polkit (ou o programa) desistiu
        if (d == m_atual) terminar(false, true);
        else if (m_fila.removeOne(d)) concluir(d, true);
    }

    // carinae-senha --ver: mostra a janela sem o polkit (para ver o visual)
    void demo() {
        static Dados d;
        d.acao = QStringLiteral("org.freedesktop.packagekit.package-install");
        d.mensagem = QStringLiteral("É necessária autenticação para instalar programas");
        d.programa = QStringLiteral("carinaeos-supernova");
        m_atual = &d;
        m_demo = true;
        m_nomes = {QStringLiteral("Leo (leo)"), QStringLiteral("Administrador (root)")};
        m_pergunta = QStringLiteral("Senha");
        Q_EMIT mudou();
    }

    Q_INVOKABLE void responder(const QString &senha) {
        if (m_demo) {
            if (m_tentativa++ == 0) { m_erro = QStringLiteral("Senha incorreta. Tente outra vez."); Q_EMIT falhou(); Q_EMIT mudou(); }
            else QGuiApplication::quit();
            return;
        }
        if (!m_sessao || m_ocupado) return;
        m_ocupado = true;
        m_erro.clear();
        Q_EMIT mudou();
        QByteArray b = senha.toUtf8();
        polkit_agent_session_response(m_sessao, b.constData());
        b.fill('\0');
    }
    Q_INVOKABLE void cancelar() { if (m_demo) { QGuiApplication::quit(); return; } if (m_atual) terminar(false, true); }
    Q_INVOKABLE void escolher(int i) {
        if (!m_atual || i < 0 || i >= m_atual->identidades.size() || i == m_escolhido) return;
        m_escolhido = i;
        m_erro.clear();
        comecarSessao();
    }

Q_SIGNALS:
    void mudou();
    void falhou();          // para a janela abanar

private:
    void seguinte() {
        if (m_fila.isEmpty()) { m_atual = nullptr; Q_EMIT mudou(); return; }
        m_atual = m_fila.dequeue();
        m_tentativa = 0;
        m_erro.clear();
        m_info.clear();
        // quem pode autorizar: primeiro o próprio utilizador, se puder; senão o primeiro da lista
        m_nomes.clear();
        m_escolhido = 0;
        const uid_t eu = getuid();
        for (int i = 0; i < m_atual->identidades.size(); ++i) {
            PolkitIdentity *id = m_atual->identidades.at(i);
            QString nome = QStringLiteral("?");
            if (POLKIT_IS_UNIX_USER(id)) {
                const uid_t uid = polkit_unix_user_get_uid(POLKIT_UNIX_USER(id));
                if (uid == eu) m_escolhido = i;
                if (passwd *pw = getpwuid(uid)) {
                    QString completo = QString::fromLocal8Bit(pw->pw_gecos).section(QLatin1Char(','), 0, 0);
                    nome = completo.isEmpty() ? QString::fromLocal8Bit(pw->pw_name)
                                              : completo + QStringLiteral(" (") + QString::fromLocal8Bit(pw->pw_name) + QLatin1Char(')');
                }
                if (uid == 0) nome = QStringLiteral("Administrador (root)");
            } else {
                gchar *s = polkit_identity_to_string(id);
                nome = QString::fromUtf8(s);
                g_free(s);
            }
            m_nomes << nome;
        }
        comecarSessao();
    }

    void comecarSessao() {
        pararSessao();
        if (!m_atual || m_atual->identidades.isEmpty()) { terminar(false, false); return; }
        m_pergunta.clear();
        m_ocupado = false;
        m_sessao = polkit_agent_session_new(m_atual->identidades.at(m_escolhido), m_atual->cookie.toUtf8().constData());
        g_signal_connect(m_sessao, "request", G_CALLBACK(+[](PolkitAgentSession *, const gchar *p, gboolean eco, gpointer u) {
            auto *self = static_cast<Pedido *>(u);
            QString t = QString::fromUtf8(p).trimmed();
            if (t.endsWith(QLatin1Char(':'))) t.chop(1);
            if (t.compare(QLatin1String("password"), Qt::CaseInsensitive) == 0 || t.isEmpty()) t = QStringLiteral("Senha");
            self->m_pergunta = t;
            self->m_eco = eco;
            self->m_ocupado = false;
            Q_EMIT self->mudou();
        }), this);
        g_signal_connect(m_sessao, "show-error", G_CALLBACK(+[](PolkitAgentSession *, const gchar *t, gpointer u) {
            auto *self = static_cast<Pedido *>(u);
            self->m_erro = QString::fromUtf8(t);
            Q_EMIT self->mudou();
        }), this);
        g_signal_connect(m_sessao, "show-info", G_CALLBACK(+[](PolkitAgentSession *, const gchar *t, gpointer u) {
            auto *self = static_cast<Pedido *>(u);
            self->m_info = QString::fromUtf8(t);
            Q_EMIT self->mudou();
        }), this);
        g_signal_connect(m_sessao, "completed", G_CALLBACK(+[](PolkitAgentSession *, gboolean ok, gpointer u) {
            static_cast<Pedido *>(u)->completo(ok);
        }), this);
        Q_EMIT mudou();
        polkit_agent_session_initiate(m_sessao);
    }

    void completo(bool ok) {
        if (ok) { terminar(true, false); return; }
        // senha errada: tenta outra vez (até 5 vezes)
        if (++m_tentativa >= 5) { terminar(false, false); return; }
        if (m_erro.isEmpty()) m_erro = QStringLiteral("Senha incorreta. Tente outra vez.");
        Q_EMIT falhou();
        const QString e = m_erro;
        comecarSessao();
        m_erro = e;
        Q_EMIT mudou();
    }

    void pararSessao() {
        if (!m_sessao) return;
        g_signal_handlers_disconnect_by_data(m_sessao, this);
        polkit_agent_session_cancel(m_sessao);
        g_object_unref(m_sessao);
        m_sessao = nullptr;
    }

    void terminar(bool ok, bool desistiu) {
        Q_UNUSED(ok);
        pararSessao();
        Dados *d = m_atual;
        m_atual = nullptr;
        if (d) concluir(d, desistiu);
        seguinte();
    }

    static void concluir(Dados *d, bool desistiu) {
        if (d->cancelar && d->idCancelar) g_cancellable_disconnect(d->cancelar, d->idCancelar);
        if (desistiu)
            g_task_return_new_error(d->tarefa, POLKIT_ERROR, POLKIT_ERROR_CANCELLED, "Cancelado pelo utilizador");
        else
            g_task_return_boolean(d->tarefa, TRUE);     // o polkit já sabe se foi autorizado
        g_object_unref(d->tarefa);
        for (PolkitIdentity *i : std::as_const(d->identidades)) g_object_unref(i);
        if (d->cancelar) g_object_unref(d->cancelar);
        delete d;
    }

    QQueue<Dados *> m_fila;
    Dados *m_atual = nullptr;
    PolkitAgentSession *m_sessao = nullptr;
    QVariantList m_nomes;
    int m_escolhido = 0;
    QString m_pergunta, m_erro, m_info;
    bool m_eco = false;
    bool m_ocupado = false;
    int m_tentativa = 0;
    bool m_demo = false;
};

static Pedido *g_pedido = nullptr;

// ---- o "listener" do polkit (GObject) -------------------------------------------------------------------
typedef struct { PolkitAgentListener parent; } CarinaeOuvinte;
typedef struct { PolkitAgentListenerClass parent_class; } CarinaeOuvinteClass;
G_DEFINE_TYPE(CarinaeOuvinte, carinae_ouvinte, POLKIT_AGENT_TYPE_LISTENER)

static QString nomeDoPrograma(PolkitDetails *det) {
    if (!det) return {};
    for (const char *k : {"polkit.caller-pid", "polkit.subject-pid"}) {
        const gchar *v = polkit_details_lookup(det, k);
        if (!v) continue;
        QFile f(QStringLiteral("/proc/%1/comm").arg(QString::fromLatin1(v)));
        if (f.open(QIODevice::ReadOnly)) return QString::fromUtf8(f.readAll()).trimmed();
    }
    return {};
}

static void carinae_iniciar(PolkitAgentListener *l, const gchar *acao, const gchar *mensagem, const gchar *icone,
                            PolkitDetails *det, const gchar *cookie, GList *ids, GCancellable *canc,
                            GAsyncReadyCallback cb, gpointer dados) {
    auto *d = new Pedido::Dados;
    d->acao = QString::fromUtf8(acao);
    d->mensagem = QString::fromUtf8(mensagem);
    d->icone = QString::fromUtf8(icone ? icone : "");
    d->cookie = QString::fromUtf8(cookie);
    d->programa = nomeDoPrograma(det);
    for (GList *i = ids; i; i = i->next) d->identidades << POLKIT_IDENTITY(g_object_ref(i->data));
    d->tarefa = g_task_new(l, canc, cb, dados);
    if (canc) {
        d->cancelar = G_CANCELLABLE(g_object_ref(canc));
        d->idCancelar = g_cancellable_connect(canc, G_CALLBACK(+[](GCancellable *, gpointer u) {
            g_pedido->cancelado(static_cast<Pedido::Dados *>(u));
        }), d, nullptr);
    }
    g_pedido->novo(d);
}

static gboolean carinae_terminar(PolkitAgentListener *, GAsyncResult *res, GError **erro) {
    return g_task_propagate_boolean(G_TASK(res), erro);
}

static void carinae_ouvinte_init(CarinaeOuvinte *) {}
static void carinae_ouvinte_class_init(CarinaeOuvinteClass *k) {
    PolkitAgentListenerClass *c = POLKIT_AGENT_LISTENER_CLASS(k);
    c->initiate_authentication = carinae_iniciar;
    c->initiate_authentication_finish = carinae_terminar;
}

int main(int argc, char **argv) {
    if (qEnvironmentVariableIsEmpty("QT_QPA_PLATFORM")) qputenv("QT_QPA_PLATFORM", "xcb");
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("carinae-senha"));
    app.setDesktopFileName(QStringLiteral("carinae-senha"));
    app.setQuitOnLastWindowClosed(false);

    Pedido pedido;
    g_pedido = &pedido;

    QQmlApplicationEngine motor;
    motor.rootContext()->setContextProperty(QStringLiteral("pedido"), &pedido);
    motor.load(QUrl(QStringLiteral("qrc:/senha/Janela.qml")));
    if (motor.rootObjects().isEmpty()) return 2;
    if (app.arguments().contains(QStringLiteral("--ver"))) { pedido.demo(); return app.exec(); }

    // regista-se para a sessão onde estamos
    GError *erro = nullptr;
    PolkitSubject *sessao = polkit_unix_session_new_for_process_sync(getpid(), nullptr, &erro);
    if (!sessao) {
        QTextStream(stderr) << "carinae-senha: não encontro a sessão: " << (erro ? erro->message : "?") << '\n';
        if (erro) g_error_free(erro);
        return 1;
    }
    auto *ouvinte = static_cast<PolkitAgentListener *>(g_object_new(carinae_ouvinte_get_type(), nullptr));
    gpointer registo = polkit_agent_listener_register(ouvinte, POLKIT_AGENT_REGISTER_FLAGS_NONE, sessao,
                                                      "/org/carinaeos/PolicyKit1/AuthenticationAgent", nullptr, &erro);
    g_object_unref(sessao);
    if (!registo) {
        QTextStream(stderr) << "carinae-senha: o polkit não aceitou o agente: " << (erro ? erro->message : "?") << '\n';
        if (erro) g_error_free(erro);
        return 1;
    }
    QTextStream(stderr) << "carinae-senha: pronto\n";
    const int r = app.exec();
    polkit_agent_listener_unregister(registo);
    g_object_unref(ouvinte);
    return r;
}

#include "main.moc"
