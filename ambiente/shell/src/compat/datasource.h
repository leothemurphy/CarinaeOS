// CarinaeOS — DataSource: corre comandos (substitui o motor "executable" do Plasma5Support)
// A dock e o lançador usam-no com: connectSource(cmd) -> onNewData(fonte, {stdout, stderr, "exit code"})
// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QHash>
#include <QObject>
#include <QStringList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

class QProcess;

class DataSource : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString engine READ engine WRITE setEngine NOTIFY engineChanged)
    Q_PROPERTY(QStringList connectedSources READ connectedSources WRITE setConnectedSources NOTIFY connectedSourcesChanged)
    Q_PROPERTY(int interval MEMBER m_intervalo NOTIFY engineChanged)
    Q_PROPERTY(QVariantMap data READ data NOTIFY dataChanged)
public:
    explicit DataSource(QObject *parent = nullptr);
    ~DataSource() override;

    QString engine() const { return m_motor; }
    void setEngine(const QString &e);
    QStringList connectedSources() const { return m_ligadas; }
    void setConnectedSources(const QStringList &l);
    QVariantMap data() const { return m_dados; }

    Q_INVOKABLE void connectSource(const QString &fonte);
    Q_INVOKABLE void disconnectSource(const QString &fonte);

Q_SIGNALS:
    void newData(const QString &sourceName, const QVariantMap &data);
    void sourceConnected(const QString &source);
    void sourceDisconnected(const QString &source);
    void engineChanged();
    void connectedSourcesChanged();
    void dataChanged();

private:
    void correr(const QString &fonte);
    QString m_motor;
    QStringList m_ligadas;
    QHash<QString, QProcess *> m_aCorrer;
    QVariantMap m_dados;
    int m_intervalo = 0;
};
