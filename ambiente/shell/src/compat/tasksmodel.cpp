// SPDX-License-Identifier: GPL-2.0-or-later
#include "tasksmodel.h"
#include "../catalogo.h"

#include <QDateTime>
#include <QIcon>
#include <QMetaEnum>
#include <QSet>
#include <QUrl>

#include <unistd.h>

using namespace X11;

TasksModel::TasksModel(QObject *parent) : QAbstractItemModel(parent) {
    m_agenda.setSingleShot(true);
    m_agenda.setInterval(25);
    connect(&m_agenda, &QTimer::timeout, this, &TasksModel::recalcular);
    m_limpaIniciando.setInterval(1000);
    connect(&m_limpaIniciando, &QTimer::timeout, this, [this] {
        const qint64 agora = QDateTime::currentMSecsSinceEpoch();
        bool mudou = false;
        for (auto it = m_iniciando.begin(); it != m_iniciando.end();) {
            if (agora - it.value() > 12000) { it = m_iniciando.erase(it); mudou = true; }
            else ++it;
        }
        if (m_iniciando.isEmpty()) m_limpaIniciando.stop();
        if (mudou) agendar();
    });
    connect(Catalogo::instancia(), &Catalogo::mudou, this, [this] {
        for (auto it = m_janelas.begin(); it != m_janelas.end(); ++it) it->appId.clear();
        for (xcb_window_t w : std::as_const(m_ordem)) lerJanela(w, false);
        agendar();
    });
    if (disponivel()) {
        ouvir(this);
        selecionar(raiz(), XCB_EVENT_MASK_PROPERTY_CHANGE);
        lerTudo();
        recalcular();
    }
}

TasksModel::~TasksModel() { deixar(this); }

// --- leitura do X -------------------------------------------------------------------------
void TasksModel::lerTudo() {
    const QVector<quint32> lista = cardinais(raiz(), atomo("_NET_CLIENT_LIST"), XCB_ATOM_WINDOW);
    QSet<xcb_window_t> agora(lista.begin(), lista.end());
    for (auto it = m_janelas.begin(); it != m_janelas.end();) {
        if (!agora.contains(it.key())) it = m_janelas.erase(it);
        else ++it;
    }
    for (quint32 w : lista)
        if (!m_janelas.contains(w)) lerJanela(w, true);
    m_ordem = QVector<xcb_window_t>(lista.begin(), lista.end());
    const QVector<quint32> pilha = cardinais(raiz(), atomo("_NET_CLIENT_LIST_STACKING"), XCB_ATOM_WINDOW);
    m_pilha = QVector<xcb_window_t>(pilha.begin(), pilha.end());
    lerAtiva();
    agendar();
}

void TasksModel::lerAtiva() {
    const QVector<quint32> a = cardinais(raiz(), atomo("_NET_ACTIVE_WINDOW"), XCB_ATOM_WINDOW);
    m_ativa = a.isEmpty() ? 0 : a.first();
}

void TasksModel::lerJanela(xcb_window_t w, bool nova) {
    if (nova) selecionar(w, XCB_EVENT_MASK_PROPERTY_CHANGE);
    Janela j = m_janelas.value(w);
    j.id = w;
    j.titulo = titulo(w);
    const auto cl = classe(w);
    j.instancia = cl.first;
    j.classe = cl.second;
    j.pid = pid(w);
    j.minimizada = j.maximizada = j.cheia = j.atencao = false;
    bool saltar = false;
    for (quint32 a : cardinais(w, atomo("_NET_WM_STATE"), XCB_ATOM_ATOM)) {
        if (a == atomo("_NET_WM_STATE_HIDDEN")) j.minimizada = true;
        else if (a == atomo("_NET_WM_STATE_SKIP_TASKBAR")) saltar = true;
        else if (a == atomo("_NET_WM_STATE_MAXIMIZED_VERT")) j.maximizada = true;
        else if (a == atomo("_NET_WM_STATE_FULLSCREEN")) j.cheia = true;
        else if (a == atomo("_NET_WM_STATE_DEMANDS_ATTENTION")) j.atencao = true;
    }
    bool tipoOk = true, dialogo = false;
    const QVector<quint32> tipos = cardinais(w, atomo("_NET_WM_WINDOW_TYPE"), XCB_ATOM_ATOM);
    // o Qt põe _KDE_NET_WM_WINDOW_TYPE_OVERRIDE antes do tipo verdadeiro nas janelas sem moldura
    // (Terminal, Fotos, Notas…): esse não conta
    quint32 t = 0;
    for (const quint32 x : tipos) if (x != atomo("_KDE_NET_WM_WINDOW_TYPE_OVERRIDE")) { t = x; break; }
    if (t) {
        dialogo = t == atomo("_NET_WM_WINDOW_TYPE_DIALOG");
        tipoOk = t == atomo("_NET_WM_WINDOW_TYPE_NORMAL") || dialogo;
    }
    const bool transitoria = !cardinais(w, XCB_ATOM_WM_TRANSIENT_FOR, XCB_ATOM_WINDOW).isEmpty();
    j.mostrar = !saltar && tipoOk && !(dialogo && transitoria) && !(transitoria && tipos.isEmpty())
                && j.pid != quint32(::getpid()) && j.classe != QLatin1String("carinae-shell");

    if (j.appId.isEmpty()) {
        QByteArray dica = bytes(w, atomo("_KDE_NET_WM_DESKTOP_FILE"));
        if (dica.isEmpty()) dica = bytes(w, atomo("_GTK_APPLICATION_ID"));
        j.appId = Catalogo::instancia()->idParaJanela(j.instancia, j.classe, QString::fromUtf8(dica));
        if (j.appId.isEmpty() && m_pidApp.contains(j.pid)) j.appId = m_pidApp.value(j.pid);
    }
    if (const App *a = Catalogo::instancia()->porId(j.appId)) {
        j.icone = a->icone;
        j.nomeApp = a->nome;
    } else {
        const QString c = j.classe.toLower();
        j.icone = QIcon::hasThemeIcon(c) ? c : (QIcon::hasThemeIcon(j.instancia.toLower()) ? j.instancia.toLower()
                                                                                             : QStringLiteral("application-x-executable"));
        j.nomeApp = j.classe.isEmpty() ? j.titulo : j.classe;
    }
    if (!j.appId.isEmpty() && j.mostrar) m_iniciando.remove(j.appId);
    m_janelas.insert(w, j);
}

void TasksModel::eventoX(xcb_generic_event_t *ev) {
    if ((ev->response_type & ~0x80) != XCB_PROPERTY_NOTIFY) return;
    auto *e = reinterpret_cast<xcb_property_notify_event_t *>(ev);
    if (e->window == raiz()) {
        if (e->atom == atomo("_NET_CLIENT_LIST")) lerTudo();
        else if (e->atom == atomo("_NET_CLIENT_LIST_STACKING")) {
            const QVector<quint32> p = cardinais(raiz(), atomo("_NET_CLIENT_LIST_STACKING"), XCB_ATOM_WINDOW);
            m_pilha = QVector<xcb_window_t>(p.begin(), p.end());
        } else if (e->atom == atomo("_NET_ACTIVE_WINDOW")) { lerAtiva(); agendar(); }
        return;
    }
    if (!m_janelas.contains(e->window)) return;
    if (e->atom == atomo("_NET_WM_NAME") || e->atom == XCB_ATOM_WM_NAME || e->atom == atomo("_NET_WM_STATE") ||
        e->atom == XCB_ATOM_WM_CLASS || e->atom == atomo("_NET_WM_WINDOW_TYPE") || e->atom == atomo("_KDE_NET_WM_DESKTOP_FILE")) {
        if (e->atom == XCB_ATOM_WM_CLASS || e->atom == atomo("_KDE_NET_WM_DESKTOP_FILE")) m_janelas[e->window].appId.clear();
        lerJanela(e->window, false);
        agendar();
    }
}

void TasksModel::agendar() {
    if (!m_agenda.isActive()) m_agenda.start();
}

// --- as linhas da Dock --------------------------------------------------------------------
QString TasksModel::idDe(const QVariant &url) const {
    const QString s = url.metaType() == QMetaType::fromType<QUrl>() ? url.toUrl().toString() : url.toString();
    return Catalogo::instancia()->idDeUrl(s);
}

void TasksModel::recalcular() {
    QVector<Linha> novas;
    QHash<QString, int> porChave;
    QSet<xcb_window_t> usadas;
    for (const QString &url : std::as_const(m_lancadores)) {
        Linha l;
        l.lancador = url;
        l.appId = idDe(url);
        l.chave = l.appId.toLower();
        if (l.chave.isEmpty() || porChave.contains(l.chave)) continue;
        for (xcb_window_t w : std::as_const(m_ordem)) {
            const Janela &j = m_janelas[w];
            if (j.mostrar && j.appId.toLower() == l.chave) { l.janelas.append(w); usadas.insert(w); }
        }
        l.iniciando = l.janelas.isEmpty() && m_iniciando.contains(l.appId);
        porChave.insert(l.chave, novas.size());
        novas.append(l);
    }
    for (xcb_window_t w : std::as_const(m_ordem)) {
        if (usadas.contains(w)) continue;
        const Janela &j = m_janelas[w];
        if (!j.mostrar) continue;
        const QString chave = !j.appId.isEmpty() ? j.appId.toLower()
                              : QStringLiteral("classe:") + (j.classe.isEmpty() ? QString::number(w) : j.classe.toLower());
        auto it = porChave.constFind(chave);
        if (it == porChave.constEnd()) {
            Linha l;
            l.chave = chave;
            l.appId = j.appId;
            porChave.insert(chave, novas.size());
            novas.append(l);
            it = porChave.constFind(chave);
        }
        novas[*it].janelas.append(w);
    }

    const int antes = m_linhas.size();
    QSet<QString> chavesNovas;
    for (const Linha &l : std::as_const(novas)) chavesNovas.insert(l.chave);
    for (int i = m_linhas.size() - 1; i >= 0; --i) {
        if (chavesNovas.contains(m_linhas[i].chave)) continue;
        beginRemoveRows(QModelIndex(), i, i);
        m_linhas.removeAt(i);
        endRemoveRows();
    }
    for (int i = 0; i < novas.size(); ++i) {
        if (i < m_linhas.size() && m_linhas[i].chave == novas[i].chave) {
            atualizarLinha(i, novas[i]);
            continue;
        }
        int j = -1;
        for (int k = i + 1; k < m_linhas.size(); ++k)
            if (m_linhas[k].chave == novas[i].chave) { j = k; break; }
        if (j != -1) {
            beginMoveRows(QModelIndex(), j, j, QModelIndex(), i);
            m_linhas.move(j, i);
            endMoveRows();
            atualizarLinha(i, novas[i]);
        } else {
            beginInsertRows(QModelIndex(), i, i);
            Linha l = novas[i];
            l.uid = m_proximoUid++;
            m_linhas.insert(i, l);
            endInsertRows();
        }
    }
    if (m_linhas.size() != antes) Q_EMIT countChanged();
}

void TasksModel::atualizarLinha(int i, const Linha &nova) {
    Linha &l = m_linhas[i];
    const QModelIndex topo = index(i, 0);
    if (l.janelas != nova.janelas) {
        const int filhosAntes = l.janelas.size() > 1 ? l.janelas.size() : 0;
        const int filhosDepois = nova.janelas.size() > 1 ? nova.janelas.size() : 0;
        if (filhosAntes > 0) {
            beginRemoveRows(topo, 0, filhosAntes - 1);
            l.janelas.clear();
            endRemoveRows();
        }
        if (filhosDepois > 0) {
            beginInsertRows(topo, 0, filhosDepois - 1);
            l.janelas = nova.janelas;
            endInsertRows();
        } else {
            l.janelas = nova.janelas;
        }
    }
    l.lancador = nova.lancador;
    l.appId = nova.appId;
    l.iniciando = nova.iniciando;
    Q_EMIT dataChanged(topo, topo);
    if (l.janelas.size() > 1) Q_EMIT dataChanged(index(0, 0, topo), index(l.janelas.size() - 1, 0, topo));
}

// --- modelo -------------------------------------------------------------------------------
int TasksModel::linhaPorUid(quint32 uid) const {
    for (int i = 0; i < m_linhas.size(); ++i)
        if (m_linhas[i].uid == uid) return i;
    return -1;
}

QModelIndex TasksModel::index(int row, int column, const QModelIndex &parent) const {
    if (column != 0 || row < 0) return QModelIndex();
    if (!parent.isValid()) return row < m_linhas.size() ? createIndex(row, 0, quintptr(0)) : QModelIndex();
    if (parent.internalId() != 0 || parent.row() >= m_linhas.size()) return QModelIndex();
    const Linha &l = m_linhas[parent.row()];
    if (l.janelas.size() > 1 && row < l.janelas.size()) return createIndex(row, 0, quintptr(l.uid));
    return QModelIndex();
}

QModelIndex TasksModel::parent(const QModelIndex &child) const {
    if (!child.isValid() || child.internalId() == 0) return QModelIndex();
    const int r = linhaPorUid(quint32(child.internalId()));
    return r < 0 ? QModelIndex() : createIndex(r, 0, quintptr(0));
}

int TasksModel::rowCount(const QModelIndex &parent) const {
    if (!parent.isValid()) return m_linhas.size();
    if (parent.internalId() != 0 || parent.row() >= m_linhas.size()) return 0;
    const int n = m_linhas[parent.row()].janelas.size();
    return n > 1 ? n : 0;
}

const TasksModel::Linha *TasksModel::linhaDe(const QModelIndex &idx) const {
    if (!idx.isValid()) return nullptr;
    const int r = idx.internalId() == 0 ? idx.row() : linhaPorUid(quint32(idx.internalId()));
    return (r >= 0 && r < m_linhas.size()) ? &m_linhas[r] : nullptr;
}

QVector<xcb_window_t> TasksModel::janelasDe(const QModelIndex &idx) const {
    const Linha *l = linhaDe(idx);
    if (!l) return {};
    if (idx.internalId() != 0) {
        if (idx.row() < l->janelas.size()) return {l->janelas[idx.row()]};
        return {};
    }
    return l->janelas;
}

QHash<int, QByteArray> TasksModel::roleNames() const {
    QHash<int, QByteArray> r = QAbstractItemModel::roleNames();
    const QMetaEnum e = QMetaEnum::fromType<Papeis>();
    for (int i = 0; i < e.keyCount(); ++i) r.insert(e.value(i), e.key(i));
    return r;
}

QVariant TasksModel::data(const QModelIndex &idx, int role) const {
    const Linha *l = linhaDe(idx);
    if (!l) return QVariant();
    const App *app = Catalogo::instancia()->porId(l->appId);
    const bool filho = idx.internalId() != 0;
    const QVector<xcb_window_t> wins = janelasDe(idx);
    const Janela *j = wins.size() == 1 ? &m_janelas.find(wins.first()).value() : nullptr;
    if (j && !m_janelas.contains(wins.first())) j = nullptr;
    const Janela *primeira = !l->janelas.isEmpty() && m_janelas.contains(l->janelas.first()) ? &m_janelas.find(l->janelas.first()).value() : nullptr;

    switch (role) {
    case Qt::DisplayRole:
        if (j) return j->titulo;
        if (app) return app->nome;
        if (primeira) return primeira->nomeApp;
        return l->appId;
    case Qt::DecorationRole:
        if (app && !app->icone.isEmpty()) return app->icone;
        if (j) return j->icone;
        if (primeira) return primeira->icone;
        return QStringLiteral("application-x-executable");
    case AppId: return l->appId;
    case AppName: return app ? app->nome : (primeira ? primeira->nomeApp : l->appId);
    case GenericName: return app ? app->nomeGenerico : QString();
    case LauncherUrl:
    case LauncherUrlWithoutIcon:
        if (!l->lancador.isEmpty()) return l->lancador;
        if (app) return QString(QStringLiteral("applications:") + app->id);
        return QString();
    case WinIdList: {
        QVariantList v;
        for (xcb_window_t w : wins) v.append(quint32(w));
        return v;
    }
    case IsLauncher: return !filho && l->janelas.isEmpty() && !l->iniciando;
    case IsStartup: return !filho && l->janelas.isEmpty() && l->iniciando;
    case IsWindow: return !wins.isEmpty();
    case IsActive:
        for (xcb_window_t w : wins) if (w == m_ativa) return true;
        return false;
    case IsMinimized: {
        if (wins.isEmpty()) return false;
        for (xcb_window_t w : wins) if (!m_janelas.value(w).minimizada) return false;
        return true;
    }
    case IsMaximized: return j && j->maximizada;
    case IsFullScreen: return j && j->cheia;
    case IsGroupParent: return !filho && l->janelas.size() > 1;
    case ChildCount: return (!filho && l->janelas.size() > 1) ? l->janelas.size() : 0;
    case IsGroupable: return true;
    case IsDemandingAttention:
        for (xcb_window_t w : wins) if (m_janelas.value(w).atencao) return true;
        return false;
    case AppPid: return wins.isEmpty() ? 0 : int(m_janelas.value(wins.first()).pid);
    case HasLauncher: return !l->lancador.isEmpty();
    case IsClosable: return !wins.isEmpty();
    case CanLaunchNewInstance: return app != nullptr;
    case SkipTaskbar: return false;
    case IsOnAllVirtualDesktops: return false;
    case StackingOrder: return wins.isEmpty() ? -1 : int(m_pilha.indexOf(wins.first()));
    }
    return QVariant();
}

QModelIndex TasksModel::makeModelIndex(int row, int childRow) const {
    if (row < 0 || row >= m_linhas.size()) return QModelIndex();
    const QModelIndex p = index(row, 0);
    return childRow < 0 ? p : index(childRow, 0, p);
}

// --- lançadores ---------------------------------------------------------------------------
void TasksModel::setLauncherList(const QStringList &lista) {
    QStringList limpa;
    QSet<QString> vistos;
    for (const QString &u : lista) {
        const QString id = idDe(u).toLower();
        if (u.isEmpty() || vistos.contains(id)) continue;
        vistos.insert(id);
        limpa << u;
    }
    if (limpa == m_lancadores) return;
    m_lancadores = limpa;
    Q_EMIT launcherListChanged();
    recalcular();
}

int TasksModel::launcherPosition(const QVariant &url) const {
    const QString id = idDe(url).toLower();
    if (id.isEmpty()) return -1;
    for (int i = 0; i < m_lancadores.size(); ++i)
        if (idDe(m_lancadores[i]).toLower() == id) return i;
    return -1;
}

bool TasksModel::requestAddLauncher(const QVariant &url) {
    QString u = url.metaType() == QMetaType::fromType<QUrl>() ? url.toUrl().toString() : url.toString();
    if (u.isEmpty()) return false;
    if (u.startsWith(QLatin1String("file://"))) {
        if (const App *a = Catalogo::instancia()->porCaminho(QUrl(u).toLocalFile())) u = QStringLiteral("applications:") + a->id;
    } else if (!u.contains(QLatin1Char(':')) && u.endsWith(QLatin1String(".desktop"))) {
        u = QStringLiteral("applications:") + u;
    }
    if (launcherPosition(u) != -1) return false;
    m_lancadores.append(u);
    Q_EMIT launcherListChanged();
    recalcular();
    return true;
}

bool TasksModel::requestRemoveLauncher(const QVariant &url) {
    const int p = launcherPosition(url);
    if (p < 0) return false;
    m_lancadores.removeAt(p);
    Q_EMIT launcherListChanged();
    recalcular();
    return true;
}

bool TasksModel::move(int de, int para, const QModelIndex &parent) {
    if (parent.isValid() || de == para || de < 0 || para < 0 || de >= m_linhas.size() || para >= m_linhas.size()) return false;
    const int pd = m_lancadores.indexOf(m_linhas[de].lancador);
    const int pp = m_lancadores.indexOf(m_linhas[para].lancador);
    if (pd < 0 || pp < 0) return false;
    beginMoveRows(QModelIndex(), de, de, QModelIndex(), para > de ? para + 1 : para);
    m_linhas.move(de, para);
    endMoveRows();
    m_lancadores.move(pd, pp);
    Q_EMIT launcherListChanged();
    return true;
}

void TasksModel::syncLaunchers() { Q_EMIT launcherListChanged(); }

// --- ações --------------------------------------------------------------------------------
void TasksModel::ativarJanela(xcb_window_t w) {
    pedirAoGestor(w, atomo("_NET_ACTIVE_WINDOW"), 2, XCB_CURRENT_TIME, m_ativa);
}

void TasksModel::lancarLinha(const Linha &l) {
    qint64 pid = 0;
    if (Catalogo::instancia()->porId(l.appId)) pid = Catalogo::instancia()->lancar(l.appId);
    else if (l.lancador.startsWith(QLatin1String("file://"))) pid = Catalogo::instancia()->lancarArquivo(QUrl(l.lancador).toLocalFile());
    if (!pid) return;
    m_pidApp.insert(quint32(pid), l.appId);
    m_iniciando.insert(l.appId, QDateTime::currentMSecsSinceEpoch());
    m_limpaIniciando.start();
    agendar();
}

void TasksModel::requestActivate(const QModelIndex &idx) {
    const Linha *l = linhaDe(idx);
    if (!l) return;
    const QVector<xcb_window_t> wins = janelasDe(idx);
    if (wins.isEmpty()) {
        if (idx.internalId() == 0) lancarLinha(*l);
        return;
    }
    if (wins.size() == 1) { ativarJanela(wins.first()); return; }
    // grupo: se uma já está ativa, passa à seguinte; senão a que está mais à frente
    const int ativa = wins.indexOf(m_ativa);
    if (ativa >= 0) { ativarJanela(wins[(ativa + 1) % wins.size()]); return; }
    xcb_window_t melhor = wins.first();
    int pos = -1;
    for (xcb_window_t w : wins) {
        const int p = m_pilha.indexOf(w);
        if (p > pos) { pos = p; melhor = w; }
    }
    ativarJanela(melhor);
}

void TasksModel::requestNewInstance(const QModelIndex &idx) {
    if (const Linha *l = linhaDe(idx)) lancarLinha(*l);
}

void TasksModel::requestOpenUrls(const QModelIndex &idx, const QVariantList &urls) {
    const Linha *l = linhaDe(idx);
    if (!l) return;
    QStringList u;
    for (const QVariant &v : urls) u << (v.metaType() == QMetaType::fromType<QUrl>() ? v.toUrl().toString() : v.toString());
    Catalogo::instancia()->lancar(l->appId, QString(), u);
}

void TasksModel::requestClose(const QModelIndex &idx) {
    for (xcb_window_t w : janelasDe(idx)) pedirAoGestor(w, atomo("_NET_CLOSE_WINDOW"), XCB_CURRENT_TIME, 2);
}

void TasksModel::requestToggleMinimized(const QModelIndex &idx) {
    const QVector<xcb_window_t> wins = janelasDe(idx);
    if (wins.isEmpty()) return;
    bool todas = true;
    for (xcb_window_t w : wins) todas &= m_janelas.value(w).minimizada;
    for (xcb_window_t w : wins) {
        if (todas) ativarJanela(w);
        else pedirAoGestor(w, atomo("WM_CHANGE_STATE"), 3 /* IconicState */);
    }
}

void TasksModel::requestToggleMaximized(const QModelIndex &idx) {
    for (xcb_window_t w : janelasDe(idx))
        pedirAoGestor(w, atomo("_NET_WM_STATE"), 2, atomo("_NET_WM_STATE_MAXIMIZED_VERT"), atomo("_NET_WM_STATE_MAXIMIZED_HORZ"), 2);
}

void TasksModel::requestPublishDelegateGeometry(const QModelIndex &idx, const QRect &geo, QObject *) {
    for (xcb_window_t w : janelasDe(idx))
        definirCardinais(w, atomo("_NET_WM_ICON_GEOMETRY"), XCB_ATOM_CARDINAL,
                         {quint32(geo.x()), quint32(geo.y()), quint32(geo.width()), quint32(geo.height())});
    flush();
}

void TasksModel::requestActivateByPosition(int posicao) {
    if (posicao >= 1 && posicao <= m_linhas.size()) requestActivate(makeModelIndex(posicao - 1));
}
