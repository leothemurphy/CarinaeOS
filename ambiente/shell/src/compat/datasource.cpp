// SPDX-License-Identifier: GPL-2.0-or-later
#include "datasource.h"

#include <QCoreApplication>
#include <QProcess>

#include <unistd.h>

DataSource::DataSource(QObject *parent) : QObject(parent) {}

DataSource::~DataSource() {
    // os processos que ainda correm (apps abertas daqui) não são mortos: ficam por conta própria
    for (QProcess *p : std::as_const(m_aCorrer)) {
        p->disconnect(this);
        p->setParent(nullptr);
    }
}

void DataSource::setEngine(const QString &e) {
    if (e == m_motor) return;
    m_motor = e;
    if (e != QLatin1String("executable"))
        qWarning("CarinaeOS DataSource: só o motor \"executable\" existe (pedido: %s)", qPrintable(e));
    Q_EMIT engineChanged();
}

void DataSource::setConnectedSources(const QStringList &l) {
    if (l == m_ligadas) return;
    for (const QString &f : l)
        if (!m_ligadas.contains(f)) connectSource(f);
    for (const QString &f : std::as_const(m_ligadas))
        if (!l.contains(f)) disconnectSource(f);
}

void DataSource::connectSource(const QString &fonte) {
    if (fonte.isEmpty() || m_ligadas.contains(fonte)) return;   // como no Plasma: a mesma fonte não corre duas vezes
    m_ligadas.append(fonte);
    Q_EMIT connectedSourcesChanged();
    Q_EMIT sourceConnected(fonte);
    correr(fonte);
}

void DataSource::disconnectSource(const QString &fonte) {
    if (!m_ligadas.removeOne(fonte)) return;
    Q_EMIT connectedSourcesChanged();
    Q_EMIT sourceDisconnected(fonte);
}

void DataSource::correr(const QString &fonte) {
    auto *p = new QProcess(this);
    p->setProgram(QStringLiteral("/bin/sh"));
    p->setArguments({QStringLiteral("-c"), fonte});
    p->setChildProcessModifier([] { ::setsid(); });
    m_aCorrer.insert(fonte, p);
    connect(p, &QProcess::finished, this, [this, p, fonte](int codigo, QProcess::ExitStatus estado) {
        QVariantMap d;
        d.insert(QStringLiteral("exit code"), codigo);
        d.insert(QStringLiteral("exit status"), estado == QProcess::NormalExit ? 0 : 1);
        d.insert(QStringLiteral("stdout"), QString::fromUtf8(p->readAllStandardOutput()));
        d.insert(QStringLiteral("stderr"), QString::fromUtf8(p->readAllStandardError()));
        m_aCorrer.remove(fonte);
        p->deleteLater();
        if (m_ligadas.contains(fonte)) {
            m_dados.insert(fonte, d);
            Q_EMIT dataChanged();
            Q_EMIT newData(fonte, d);
        }
    });
    connect(p, &QProcess::errorOccurred, this, [this, p, fonte](QProcess::ProcessError e) {
        if (e != QProcess::FailedToStart) return;
        m_aCorrer.remove(fonte);
        p->deleteLater();
        if (m_ligadas.contains(fonte)) {
            QVariantMap d{{QStringLiteral("exit code"), 127}, {QStringLiteral("stdout"), QString()},
                          {QStringLiteral("stderr"), p->errorString()}};
            Q_EMIT newData(fonte, d);
        }
    });
    p->start();
}
