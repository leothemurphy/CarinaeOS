// CarinaeOS — Notificações: a Aurora é o servidor org.freedesktop.Notifications da sessão.
// Os apps (Firefox, Claude, Telegram, notify-send, o KDE Connect…) mandam os avisos para aqui;
// mostramo-los no canto de cima à direita e guardamos os últimos no histórico da central.
// Com "Não incomodar" (~/.config/carinaeos/nao-incomodar) só os urgentes aparecem; os outros
// vão em silêncio para o histórico.
// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QDBusAbstractAdaptor>
#include <QDBusContext>
#include <QHash>
#include <QObject>
#include <QQmlEngine>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

class QTimer;
class QFileSystemWatcher;

class Notificacoes : public QObject, protected QDBusContext {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    // cada aviso: { id, app, icone, imagem, titulo, corpo, acoes: [{chave, texto}], urgencia (0..2), hora (ms) }
    Q_PROPERTY(QVariantList ativas READ ativas NOTIFY ativasChanged)
    Q_PROPERTY(QVariantList historico READ historico NOTIFY historicoChanged)
    Q_PROPERTY(bool naoIncomodar READ naoIncomodar WRITE setNaoIncomodar NOTIFY naoIncomodarChanged)
    Q_PROPERTY(bool servidor READ servidor CONSTANT)
public:
    static Notificacoes *instancia();
    static Notificacoes *create(QQmlEngine *, QJSEngine *);

    QVariantList ativas() const { return m_ativas; }
    QVariantList historico() const { return m_historico; }
    bool naoIncomodar() const { return m_naoIncomodar; }
    void setNaoIncomodar(bool v);
    bool servidor() const { return m_servidor; }

    Q_INVOKABLE void fechar(uint id);                       // o utilizador fechou (motivo 2)
    Q_INVOKABLE void acao(uint id, const QString &chave);   // clicou num botão (ou no aviso: "default")
    Q_INVOKABLE void segurar(uint id, bool rato);           // rato por cima: não expira
    Q_INVOKABLE void apagarDoHistorico(uint id);
    Q_INVOKABLE void limparHistorico();

    // chamados pelo adaptador D-Bus
    uint notify(const QString &app, uint substitui, const QString &icone, const QString &titulo,
                const QString &corpo, const QStringList &acoes, const QVariantMap &dicas, int expira);
    void closeNotification(uint id);

Q_SIGNALS:
    void ativasChanged();
    void historicoChanged();
    void naoIncomodarChanged();
    // para o adaptador
    void notificationClosed(uint id, uint motivo);
    void actionInvoked(uint id, const QString &chave);
    void activationToken(uint id, const QString &token);

private:
    explicit Notificacoes(QObject *parent = nullptr);
    void retirar(uint id, uint motivo);
    void expirar();
    void lerNaoIncomodar();
    void gravarHistorico();
    void carregarHistorico();
    static QString imagemDeDados(const QVariant &v);
    static QString limparCorpo(QString corpo);

    QVariantList m_ativas;
    QVariantList m_historico;
    QHash<uint, qint64> m_expiraEm;     // id -> ms (0 = não expira)
    QHash<uint, bool> m_seguro;
    QTimer *m_relogio = nullptr;
    QTimer *m_gravar = nullptr;
    QFileSystemWatcher *m_olho = nullptr;
    uint m_proximo = 1;
    bool m_naoIncomodar = false;
    bool m_servidor = false;
};

class NotificacoesAdaptador : public QDBusAbstractAdaptor {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.Notifications")
public:
    explicit NotificacoesAdaptador(Notificacoes *n);
public Q_SLOTS:
    QStringList GetCapabilities();
    QString GetServerInformation(QString &vendedor, QString &versao, QString &especificacao);
    uint Notify(const QString &app_name, uint replaces_id, const QString &app_icon, const QString &summary,
                const QString &body, const QStringList &actions, const QVariantMap &hints, int expire_timeout);
    void CloseNotification(uint id);
Q_SIGNALS:
    void NotificationClosed(uint id, uint reason);
    void ActionInvoked(uint id, const QString &action_key);
    void ActivationToken(uint id, const QString &activation_token);
private:
    Notificacoes *m_n;
};
