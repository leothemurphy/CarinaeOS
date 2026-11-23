// SPDX-License-Identifier: GPL-2.0-or-later
#include "rootmodel.h"
#include "../catalogo.h"

#include <QCollator>
#include <QLocale>
#include <QMap>

// --- AppsModel ------------------------------------------------------------------------------
AppsModel::AppsModel(const QString &nome, QObject *parent) : QAbstractListModel(parent), m_nome(nome) {}

void AppsModel::definir(const QStringList &ids) {
    if (ids == m_ids) return;
    const bool mudouN = ids.size() != m_ids.size();
    beginResetModel();
    m_ids = ids;
    endResetModel();
    if (mudouN) Q_EMIT countChanged();
}

QHash<int, QByteArray> AppsModel::roleNames() const {
    return {{Qt::DisplayRole, "display"}, {Qt::DecorationRole, "decoration"}, {FavoriteId, "favoriteId"},
            {Description, "description"}, {Url, "url"}, {HasActionList, "hasActionList"},
            {ActionList, "actionList"}, {Group, "group"}, {IsParent, "isParent"}, {HasChildren, "hasChildren"}};
}

static QVariantList listaDeAcoes(const App *a) {
    QVariantList l;
    for (const AcaoApp &x : a->acoes) {
        l.append(QVariantMap{{QStringLiteral("text"), x.nome}, {QStringLiteral("icon"), x.icone.isEmpty() ? a->icone : x.icone},
                             {QStringLiteral("actionId"), QStringLiteral("_kicker_jumpListAction")},
                             {QStringLiteral("actionArgument"), x.id}});
    }
    return l;
}

QVariant AppsModel::data(const QModelIndex &idx, int role) const {
    if (!idx.isValid() || idx.row() >= m_ids.size()) return QVariant();
    const App *a = Catalogo::instancia()->porId(m_ids[idx.row()]);
    if (!a) return QVariant();
    switch (role) {
    case Qt::DisplayRole: return a->nome;
    case Qt::DecorationRole: return a->icone;
    case FavoriteId: return a->id;
    case Description: return a->descricao();
    case Url: return QString(QStringLiteral("file://") + a->caminho);
    case HasActionList: return !a->acoes.isEmpty();
    case ActionList: return listaDeAcoes(a);
    case Group: return a->nome.left(1).toUpper();
    case IsParent:
    case HasChildren: return false;
    }
    return QVariant();
}

bool AppsModel::trigger(int row, const QString &actionId, const QVariant &argument) {
    if (row < 0 || row >= m_ids.size()) return false;
    QString acao;
    if (actionId == QLatin1String("_kicker_jumpListAction")) acao = argument.toString();
    return Catalogo::instancia()->lancar(m_ids[row], acao) != 0;
}

QString AppsModel::labelForRow(int row) const {
    const App *a = row >= 0 && row < m_ids.size() ? Catalogo::instancia()->porId(m_ids[row]) : nullptr;
    return a ? a->nome : QString();
}

// --- RootModel ------------------------------------------------------------------------------
RootModel::RootModel(QObject *parent) : QAbstractListModel(parent) {
    m_todos = new AppsModel(QStringLiteral("Todos os aplicativos"), this);
    connect(Catalogo::instancia(), &Catalogo::mudou, this, [this] {
        if (m_preenchido) refresh();
    });
}

QHash<int, QByteArray> RootModel::roleNames() const {
    return {{Qt::DisplayRole, "display"}, {Qt::DecorationRole, "decoration"}, {Qt::UserRole + 1, "favoriteId"},
            {Qt::UserRole + 2, "hasChildren"}, {Qt::UserRole + 3, "description"}};
}

QVariant RootModel::data(const QModelIndex &idx, int role) const {
    if (!idx.isValid()) return QVariant();
    const int r = idx.row();
    const QString nome = r == 0 ? QStringLiteral("Todos os aplicativos") : m_cats.value(r - 1).nome;
    const QString icone = r == 0 ? QStringLiteral("applications-all") : m_cats.value(r - 1).icone;
    switch (role) {
    case Qt::DisplayRole: return nome;
    case Qt::DecorationRole: return icone;
    case Qt::UserRole + 1: return QString();
    case Qt::UserRole + 2: return true;
    case Qt::UserRole + 3: return nome;
    }
    return QVariant();
}

QObject *RootModel::modelForRow(int row) {
    if (row == 0) return m_todos;
    if (row < 1 || row > m_cats.size()) return nullptr;
    return m_cats[row - 1].modelo.data();
}

void RootModel::refresh() {
    m_preenchido = true;
    const QVector<App> &apps = Catalogo::instancia()->apps();
    QStringList todos;
    QMap<QString, QPair<QString, QStringList>> porCat;   // nome -> (ícone, ids)
    for (const App &a : apps) {
        todos << a.id;
        QString icone;
        const QString cat = Catalogo::nomeCategoria(a, &icone);
        auto &c = porCat[cat];
        c.first = icone;
        c.second << a.id;
    }
    m_todos->definir(todos);

    QCollator col(QLocale::system());
    col.setCaseSensitivity(Qt::CaseInsensitive);
    QStringList nomes = porCat.keys();
    std::sort(nomes.begin(), nomes.end(), [&col](const QString &a, const QString &b) { return col.compare(a, b) < 0; });

    beginResetModel();
    QVector<Cat> velhas = m_cats;
    m_cats.clear();
    for (const QString &n : std::as_const(nomes)) {
        Cat c;
        c.nome = n;
        c.icone = porCat[n].first;
        // reaproveita o modelo antigo da mesma categoria (os Repeaters não perdem o fio)
        for (Cat &v : velhas)
            if (v.nome == n && v.modelo) { c.modelo = v.modelo; v.modelo = nullptr; break; }
        if (!c.modelo) c.modelo = new AppsModel(n, this);
        c.modelo->definir(porCat[n].second);
        m_cats.append(c);
    }
    for (Cat &v : velhas)
        if (v.modelo) v.modelo->deleteLater();
    endResetModel();
    Q_EMIT countChanged();
    Q_EMIT refreshed();
}

// --- RecentUsageModel -----------------------------------------------------------------------
RecentUsageModel::RecentUsageModel(QObject *parent) : QAbstractListModel(parent) {
    connect(Catalogo::instancia(), &Catalogo::usoMudou, this, &RecentUsageModel::atualizar);
    connect(Catalogo::instancia(), &Catalogo::mudou, this, &RecentUsageModel::atualizar);
    atualizar();
}

void RecentUsageModel::atualizar() {
    QStringList ids;
    for (const auto &p : Catalogo::instancia()->maisUsados()) {
        const App *a = Catalogo::instancia()->porId(p.first);
        if (a && a->visivel) ids << a->id;
        if (ids.size() >= 40) break;
    }
    if (ids == m_ids) return;
    beginResetModel();
    m_ids = ids;
    endResetModel();
    Q_EMIT countChanged();
}

QHash<int, QByteArray> RecentUsageModel::roleNames() const {
    return {{Qt::DisplayRole, "display"}, {Qt::DecorationRole, "decoration"}, {Qt::UserRole + 1, "favoriteId"},
            {Qt::UserRole + 2, "url"}, {Qt::UserRole + 3, "description"}};
}

QVariant RecentUsageModel::data(const QModelIndex &idx, int role) const {
    if (!idx.isValid() || idx.row() >= m_ids.size()) return QVariant();
    const App *a = Catalogo::instancia()->porId(m_ids[idx.row()]);
    if (!a) return QVariant();
    switch (role) {
    case Qt::DisplayRole: return a->nome;
    case Qt::DecorationRole: return a->icone;
    case Qt::UserRole + 1: return a->id;
    case Qt::UserRole + 2: return QString(QStringLiteral("applications:") + a->id);
    case Qt::UserRole + 3: return a->descricao();
    }
    return QVariant();
}

bool RecentUsageModel::trigger(int row, const QString &, const QVariant &) {
    if (row < 0 || row >= m_ids.size()) return false;
    return Catalogo::instancia()->lancar(m_ids[row]) != 0;
}
