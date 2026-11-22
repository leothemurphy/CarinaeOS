// CarinaeOS — Sistema: o que o ambiente precisa de saber do sistema
// (ecrã principal, configuração do shell, janela ativa) e de fazer (painéis, fundo, correr comandos)
// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QJSValue>
#include <QObject>
#include <QPointer>
#include <QQmlEngine>
#include <QScreen>
#include <QVariantMap>
#include <QWindow>
#include <QtQml/qqmlregistration.h>

#include "../x11.h"

class QFileSystemWatcher;

class Sistema : public QObject, public X11::Ouvinte {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QScreen *ecraPrincipal READ ecraPrincipal NOTIFY ecraPrincipalChanged)
    // para o QML: o índice em Qt.application.screens e o nome do ecrã principal
    Q_PROPERTY(int indicePrincipal READ indicePrincipal NOTIFY ecraPrincipalChanged)
    Q_PROPERTY(QString nomePrincipal READ nomePrincipal NOTIFY ecraPrincipalChanged)
    Q_PROPERTY(QVariantMap shell READ shell NOTIFY shellChanged)
    Q_PROPERTY(QString tituloAtivo READ tituloAtivo NOTIFY ativaChanged)
    Q_PROPERTY(QString nomeAppAtiva READ nomeAppAtiva NOTIFY ativaChanged)
    Q_PROPERTY(QString iconeAppAtiva READ iconeAppAtiva NOTIFY ativaChanged)
    Q_PROPERTY(QString casa READ casa CONSTANT)
    Q_PROPERTY(QString pastaQml READ pastaQml CONSTANT)
public:
    static Sistema *instancia();
    static Sistema *create(QQmlEngine *, QJSEngine *);

    QScreen *ecraPrincipal() const;
    int indicePrincipal() const;
    QString nomePrincipal() const { QScreen *s = ecraPrincipal(); return s ? s->name() : QString(); }
    QVariantMap shell() const { return m_shell; }
    QString tituloAtivo() const { return m_titulo; }
    QString nomeAppAtiva() const { return m_nomeApp; }
    QString iconeAppAtiva() const { return m_iconeApp; }
    QString casa() const;
    QString pastaQml() const { return m_pastaQml; }
    void setPastaQml(const QString &p) { m_pastaQml = p; }

    // 1 = em cima, 2 = em baixo (como Types.TopEdge/BottomEdge: 3 e 4 também servem)
    Q_INVOKABLE void tornarPainel(QWindow *janela, int borda, int reserva);
    Q_INVOKABLE void reservar(QWindow *janela, int borda, int reserva);
    Q_INVOKABLE void tornarFundo(QWindow *janela);
    Q_INVOKABLE void executar(const QString &comando);
    Q_INVOKABLE QString lerTexto(const QString &caminho) const;
    // grava (de forma atómica: nunca fica meio escrito) um ficheiro de texto; cria a pasta se faltar
    Q_INVOKABLE bool gravarTexto(const QString &caminho, const QString &texto);
    Q_INVOKABLE void abrirAplicativo(const QString &id);
    // mostrar a área de trabalho / voltar a mostrar as janelas (_NET_SHOWING_DESKTOP)
    Q_INVOKABLE void alternarMesa();
    // dá o teclado a uma janela nossa (o Launchpad), mesmo que o gestor de janelas não o faça
    Q_INVOKABLE void focarTeclado(QWindow *janela);
    // passa ao papel de parede seguinte da lista da central de ajustes
    Q_INVOKABLE void papelSeguinte();
    // corre um comando sem bloquear e chama depois(saida, codigo) com o que ele escreveu
    Q_INVOKABLE void correr(const QString &comando, const QJSValue &depois);

    void eventoX(xcb_generic_event_t *ev) override;
    void pedirTarefa(int n) { Q_EMIT ativarTarefa(n); }
    void pedirDesligar(const QString &opcao) { Q_EMIT desligarPedido(opcao); }

Q_SIGNALS:
    void ecraPrincipalChanged();
    void shellChanged();
    void ativaChanged();
    void ativarTarefa(int n);
    void desligarPedido(const QString &opcao);          // o botão de ligar / "aurora --enviar desligar": o ecrã de desligar

private:
    explicit Sistema(QObject *parent = nullptr);
    void lerShell();
    void lerAtiva();
    QVariantMap m_shell;
    QString m_titulo, m_nomeApp, m_iconeApp;
    xcb_window_t m_ativa = 0;
    QFileSystemWatcher *m_vigia = nullptr;
    QString m_pastaQml;
};

class KWindowSystem : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool isPlatformX11 READ x11 CONSTANT)
    Q_PROPERTY(bool isPlatformWayland READ wayland CONSTANT)
public:
    using QObject::QObject;
    bool x11() const { return true; }
    bool wayland() const { return false; }
};
