// CarinaeOS — o "vigia" da bandeja (org.kde.StatusNotifierWatcher): onde os apps registam o ícone
// de segundo plano. Corre num processo próprio (carinae-vigia-bandeja), sempre ligado, para os
// ícones não se perderem quando a Aurora recarrega; se ele não estiver, a Aurora faz este papel.
// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QDBusContext>
#include <QObject>
#include <QStringList>

class QDBusServiceWatcher;

// o objeto D-Bus org.kde.StatusNotifierWatcher (quando ninguém o tem, somos nós)
class Vigia : public QObject, protected QDBusContext {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.kde.StatusNotifierWatcher")
    Q_PROPERTY(QStringList RegisteredStatusNotifierItems READ itens)
    Q_PROPERTY(bool IsStatusNotifierHostRegistered READ temHost)
    Q_PROPERTY(int ProtocolVersion READ versao)
public:
    explicit Vigia(QObject *parent = nullptr);
    QStringList itens() const { return m_itens; }
    bool temHost() const { return true; }
    int versao() const { return 0; }
public Q_SLOTS:
    void RegisterStatusNotifierItem(const QString &servico);
    void RegisterStatusNotifierHost(const QString &servico);
Q_SIGNALS:
    void StatusNotifierItemRegistered(const QString &servico);
    void StatusNotifierItemUnregistered(const QString &servico);
    void StatusNotifierHostRegistered();
private:
    QStringList m_itens;
    QDBusServiceWatcher *m_saidas;
};

