// CarinaeOS — modelos do lançador (substituem o Kicker do Plasma)
//   RootModel: linha 0 = todos os aplicativos; linhas 1.. = categorias (modelForRow(i) dá as apps)
//   AppsModel: lista de apps com trigger(linha, ação, argumento)
//   RecentUsageModel: os mais usados
// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QAbstractListModel>
#include <QPointer>
#include <QVector>
#include <QtQml/qqmlregistration.h>

class AppsModel : public QAbstractListModel {
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("vem do RootModel")
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(QString description MEMBER m_nome CONSTANT)
public:
    enum Papeis { FavoriteId = Qt::UserRole + 1, Description, Url, HasActionList, ActionList, Group, IsParent, HasChildren };
    explicit AppsModel(const QString &nome, QObject *parent = nullptr);

    void definir(const QStringList &ids);
    int rowCount(const QModelIndex &p = QModelIndex()) const override { return p.isValid() ? 0 : m_ids.size(); }
    QVariant data(const QModelIndex &idx, int role) const override;
    QHash<int, QByteArray> roleNames() const override;
    int count() const { return m_ids.size(); }

    Q_INVOKABLE bool trigger(int row, const QString &actionId, const QVariant &argument);
    Q_INVOKABLE QString labelForRow(int row) const;
    Q_INVOKABLE QObject *modelForRow(int) { return nullptr; }

Q_SIGNALS:
    void countChanged();

private:
    QString m_nome;
    QStringList m_ids;
};

class RootModel : public QAbstractListModel {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    // aceites por compatibilidade com o Kicker
    Q_PROPERTY(bool autoPopulate MEMBER m_autoPopular NOTIFY compatChanged)
    Q_PROPERTY(QObject *appletInterface MEMBER m_applet NOTIFY compatChanged)
    Q_PROPERTY(bool flat MEMBER m_c1 NOTIFY compatChanged)
    Q_PROPERTY(bool sorted MEMBER m_c2 NOTIFY compatChanged)
    Q_PROPERTY(bool showSeparators MEMBER m_c3 NOTIFY compatChanged)
    Q_PROPERTY(bool showAllApps MEMBER m_c4 NOTIFY compatChanged)
    Q_PROPERTY(bool showAllAppsCategorized MEMBER m_c5 NOTIFY compatChanged)
    Q_PROPERTY(bool showTopLevelItems MEMBER m_c6 NOTIFY compatChanged)
    Q_PROPERTY(bool showRecentApps MEMBER m_c7 NOTIFY compatChanged)
    Q_PROPERTY(bool showRecentDocs MEMBER m_c8 NOTIFY compatChanged)
    Q_PROPERTY(bool showPowerSession MEMBER m_c9 NOTIFY compatChanged)
    Q_PROPERTY(bool showFavoritesPlaceholder MEMBER m_c10 NOTIFY compatChanged)
public:
    explicit RootModel(QObject *parent = nullptr);

    int rowCount(const QModelIndex &p = QModelIndex()) const override { return p.isValid() ? 0 : m_cats.size() + 1; }
    QVariant data(const QModelIndex &idx, int role) const override;
    QHash<int, QByteArray> roleNames() const override;
    int count() const { return m_cats.size() + 1; }

    Q_INVOKABLE QObject *modelForRow(int row);
    Q_INVOKABLE bool trigger(int, const QString &, const QVariant &) { return false; }
    Q_INVOKABLE void refresh();

Q_SIGNALS:
    void refreshed();
    void countChanged();
    void compatChanged();

private:
    struct Cat { QString nome, icone; QPointer<AppsModel> modelo; };
    AppsModel *m_todos;
    QVector<Cat> m_cats;
    bool m_autoPopular = true;
    QObject *m_applet = nullptr;
    bool m_c1 = true, m_c2 = true, m_c3 = false, m_c4 = true, m_c5 = false, m_c6 = false, m_c7 = false, m_c8 = false, m_c9 = false, m_c10 = false;
    bool m_preenchido = false;
};

class RecentUsageModel : public QAbstractListModel {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(int shownItems MEMBER m_mostrar NOTIFY compatChanged)
    Q_PROPERTY(int ordering MEMBER m_ordem NOTIFY compatChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)
public:
    enum IncludeUsage { AppsAndDocs = 0, OnlyApps, OnlyDocs };
    Q_ENUM(IncludeUsage)
    enum Ordering { Recent = 0, Popular };
    Q_ENUM(Ordering)
    explicit RecentUsageModel(QObject *parent = nullptr);
    int rowCount(const QModelIndex &p = QModelIndex()) const override { return p.isValid() ? 0 : m_ids.size(); }
    QVariant data(const QModelIndex &idx, int role) const override;
    QHash<int, QByteArray> roleNames() const override;
    int count() const { return m_ids.size(); }
    Q_INVOKABLE bool trigger(int row, const QString &actionId, const QVariant &argument);

Q_SIGNALS:
    void compatChanged();
    void countChanged();

private:
    void atualizar();
    QStringList m_ids;
    int m_mostrar = 1, m_ordem = 1;
};
