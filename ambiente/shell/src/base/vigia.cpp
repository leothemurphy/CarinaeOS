// SPDX-License-Identifier: GPL-2.0-or-later
#include "vigia.h"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusServiceWatcher>

// ---------------------------------------------------------------------------------------- vigia
Vigia::Vigia(QObject *parent) : QObject(parent) {
    m_saidas = new QDBusServiceWatcher(this);
    m_saidas->setConnection(QDBusConnection::sessionBus());
    m_saidas->setWatchMode(QDBusServiceWatcher::WatchForUnregistration);
    connect(m_saidas, &QDBusServiceWatcher::serviceUnregistered, this, [this](const QString &dono) {
        m_saidas->removeWatchedService(dono);
        for (const QString &k : QStringList(m_itens)) {
            if (k == dono || k.startsWith(dono + QLatin1Char('/'))) {
                m_itens.removeAll(k);
                Q_EMIT StatusNotifierItemUnregistered(k);
            }
        }
    });
}

void Vigia::RegisterStatusNotifierItem(const QString &servico) {
    // pode vir o nome no barramento ("org.kde.StatusNotifierItem-12-1") ou só o caminho ("/org/ayatana/…")
    const QString remetente = calledFromDBus() ? message().service() : QString();
    QString chave = servico;
    if (servico.startsWith(QLatin1Char('/'))) chave = remetente + servico;
    const QString dono = chave.section(QLatin1Char('/'), 0, 0);
    if (m_itens.contains(chave)) return;
    m_itens << chave;
    m_saidas->addWatchedService(dono);
    if (!remetente.isEmpty() && remetente != dono) m_saidas->addWatchedService(remetente);
    Q_EMIT StatusNotifierItemRegistered(chave);
}

void Vigia::RegisterStatusNotifierHost(const QString &) {
    Q_EMIT StatusNotifierHostRegistered();
}

