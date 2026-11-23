// CarinaeOS — TasksModel: as apps fixadas e as janelas abertas, agrupadas por aplicativo
// (substitui o TaskManager.TasksModel do Plasma; fala EWMH com o carinae-wm ou outro gestor)
// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QAbstractItemModel>
#include <QHash>
#include <QRect>
#include <QStringList>
#include <QTimer>
#include <QVector>
#include <QtQml/qqmlregistration.h>

#include "../x11.h"

class TasksModel : public QAbstractItemModel, public X11::Ouvinte {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QStringList launcherList READ launcherList WRITE setLauncherList NOTIFY launcherListChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    // aceites por compatibilidade (o CarinaeOS agrupa sempre por aplicativo e mostra todos os ecrãs)
    Q_PROPERTY(QRect screenGeometry MEMBER m_ecra NOTIFY compatChanged)
    Q_PROPERTY(QVariant activity MEMBER m_atividade NOTIFY compatChanged)
    Q_PROPERTY(bool filterByActivity MEMBER m_c1 NOTIFY compatChanged)
    Q_PROPERTY(bool filterByScreen MEMBER m_c2 NOTIFY compatChanged)
    Q_PROPERTY(bool filterByVirtualDesktop MEMBER m_c3 NOTIFY compatChanged)
    Q_PROPERTY(int groupMode MEMBER m_grupo NOTIFY compatChanged)
    Q_PROPERTY(int sortMode MEMBER m_modoOrdem NOTIFY compatChanged)
    Q_PROPERTY(bool launchInPlace MEMBER m_c4 NOTIFY compatChanged)
    Q_PROPERTY(bool separateLaunchers MEMBER m_c5 NOTIFY compatChanged)
    Q_PROPERTY(bool hideActivatedLaunchers MEMBER m_c6 NOTIFY compatChanged)

public:
    enum GroupMode { GroupDisabled = 0, GroupApplications };
    Q_ENUM(GroupMode)
    enum SortMode { SortDisabled = 0, SortManual, SortAlpha, SortVirtualDesktop, SortActivity, SortLastActivated, SortWindowPositionPager };
    Q_ENUM(SortMode)
    enum Papeis {
        AppId = Qt::UserRole + 1, AppName, GenericName, LauncherUrl, LauncherUrlWithoutIcon, WinIdList, MimeType,
        IsLauncher, IsStartup, IsWindow, IsActive, IsMinimized, IsGroupParent, ChildCount, IsGroupable,
        IsDemandingAttention, AppPid, SkipTaskbar, IsOnAllVirtualDesktops, VirtualDesktops, StackingOrder,
        HasLauncher, IsClosable, IsMaximized, IsFullScreen, CanLaunchNewInstance, LastActivated
    };
    Q_ENUM(Papeis)

    explicit TasksModel(QObject *parent = nullptr);
    ~TasksModel() override;

    QModelIndex index(int row, int column, const QModelIndex &parent = QModelIndex()) const override;
    QModelIndex parent(const QModelIndex &child) const override;
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    int columnCount(const QModelIndex &) const override { return 1; }
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    QStringList launcherList() const { return m_lancadores; }
    void setLauncherList(const QStringList &l);
    int count() const { return m_linhas.size(); }

    Q_INVOKABLE QModelIndex makeModelIndex(int row, int childRow = -1) const;
    Q_INVOKABLE int launcherPosition(const QVariant &url) const;
    Q_INVOKABLE bool requestAddLauncher(const QVariant &url);
    Q_INVOKABLE bool requestRemoveLauncher(const QVariant &url);
    Q_INVOKABLE void requestActivate(const QModelIndex &idx);
    Q_INVOKABLE void requestNewInstance(const QModelIndex &idx);
    Q_INVOKABLE void requestOpenUrls(const QModelIndex &idx, const QVariantList &urls);
    Q_INVOKABLE void requestClose(const QModelIndex &idx);
    Q_INVOKABLE void requestToggleMinimized(const QModelIndex &idx);
    Q_INVOKABLE void requestToggleMaximized(const QModelIndex &idx);
    Q_INVOKABLE void requestPublishDelegateGeometry(const QModelIndex &idx, const QRect &geo, QObject *delegate = nullptr);
    Q_INVOKABLE bool move(int de, int para, const QModelIndex &parent = QModelIndex());
    Q_INVOKABLE void syncLaunchers();
    Q_INVOKABLE void requestActivateByPosition(int posicao);    // Super+1..9

    void eventoX(xcb_generic_event_t *ev) override;

Q_SIGNALS:
    void launcherListChanged();
    void countChanged();
    void compatChanged();

private:
    struct Janela {
        xcb_window_t id = 0;
        QString titulo, instancia, classe, appId, icone, nomeApp;
        quint32 pid = 0;
        bool minimizada = false, maximizada = false, cheia = false, atencao = false;
        bool mostrar = true;
    };
    struct Linha {
        quint32 uid = 0;
        QString chave;          // id do aplicativo (minúsculas) ou "classe:..." para janelas sem .desktop
        QString lancador;       // url fixado (vazio se não está na Dock)
        QString appId;
        QVector<xcb_window_t> janelas;
        bool iniciando = false;
    };

    void lerTudo();
    void lerJanela(xcb_window_t w, bool nova);
    void lerAtiva();
    void agendar();
    void recalcular();
    void atualizarLinha(int i, const Linha &nova);
    QVector<xcb_window_t> janelasDe(const QModelIndex &idx) const;
    const Linha *linhaDe(const QModelIndex &idx) const;
    int linhaPorUid(quint32 uid) const;
    QString idDe(const QVariant &url) const;
    void ativarJanela(xcb_window_t w);
    void lancarLinha(const Linha &l);

    QVector<Linha> m_linhas;
    QHash<xcb_window_t, Janela> m_janelas;
    QVector<xcb_window_t> m_ordem;        // _NET_CLIENT_LIST
    QVector<xcb_window_t> m_pilha;        // _NET_CLIENT_LIST_STACKING
    xcb_window_t m_ativa = 0;
    QStringList m_lancadores;
    QHash<QString, qint64> m_iniciando;   // appId -> quando foi pedido
    QHash<quint32, QString> m_pidApp;     // pid lançado por nós -> appId
    quint32 m_proximoUid = 1;
    QTimer m_agenda, m_limpaIniciando;

    QRect m_ecra;
    QVariant m_atividade;
    bool m_c1 = false, m_c2 = false, m_c3 = false, m_c4 = true, m_c5 = true, m_c6 = true;
    int m_grupo = 1, m_modoOrdem = 1;
};
