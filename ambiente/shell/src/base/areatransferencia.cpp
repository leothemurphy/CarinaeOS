// SPDX-License-Identifier: GPL-2.0-or-later
#include "areatransferencia.h"

#include <QClipboard>
#include <QDBusConnection>
#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QJsonArray>
#include <QJsonDocument>
#include <QMimeData>
#include <QFileInfo>
#include <QSaveFile>
#include <QStandardPaths>

static QString arquivo() {
    return QDir::homePath() + QStringLiteral("/.local/share/carinaeos/area-transferencia.json");
}
static const int MAXIMO = 40;

AreaTransferencia::AreaTransferencia(QObject *parent) : QObject(parent) {
    QFile f(arquivo());
    if (f.open(QIODevice::ReadOnly))
        for (const QJsonValue &v : QJsonDocument::fromJson(f.readAll()).array()) m_historico << v.toString();
    m_gravar.setSingleShot(true);
    m_gravar.setInterval(2000);
    connect(&m_gravar, &QTimer::timeout, this, &AreaTransferencia::gravar);
    connect(QGuiApplication::clipboard(), &QClipboard::dataChanged, this, &AreaTransferencia::mudou);

    QDBusConnection bus = QDBusConnection::sessionBus();
    // só se ninguém (o Klipper do Plasma) já estiver a fazer isto
    if (bus.registerService(QStringLiteral("org.kde.klipper"))) {
        bus.registerObject(QStringLiteral("/klipper"), this, QDBusConnection::ExportAllSlots);
        qInfo("Aurora: histórico da área de transferência pronto");
    }
}

void AreaTransferencia::mudou() {
    if (m_aMudar) return;
    QClipboard *c = QGuiApplication::clipboard();
    const QMimeData *d = c->mimeData();
    // gestores de senhas pedem para não guardar
    if (d && d->hasFormat(QStringLiteral("x-kde-passwordManagerHint"))) return;
    const QString t = c->text();
    if (t.isEmpty()) {
        // o programa de onde veio fechou: volta a pôr o último texto (como o Klipper)
        if (!m_historico.isEmpty() && !(d && (d->hasImage() || d->hasUrls()))) {
            m_aMudar = true;
            c->setText(m_historico.first());
            m_aMudar = false;
        }
        return;
    }
    if (t.trimmed().isEmpty() || t.size() > 100000) return;
    m_historico.removeAll(t);
    m_historico.prepend(t);
    while (m_historico.size() > MAXIMO) m_historico.removeLast();
    m_gravar.start();
}

void AreaTransferencia::setClipboardContents(const QString &texto) {
    QGuiApplication::clipboard()->setText(texto);
}

void AreaTransferencia::clearClipboardHistory() {
    m_historico.clear();
    gravar();
}

void AreaTransferencia::gravar() {
    QDir().mkpath(QFileInfo(arquivo()).absolutePath());
    QSaveFile f(arquivo());
    if (!f.open(QIODevice::WriteOnly)) return;
    f.write(QJsonDocument(QJsonArray::fromStringList(m_historico)).toJson(QJsonDocument::Compact));
    f.commit();
    QFile::setPermissions(arquivo(), QFile::ReadOwner | QFile::WriteOwner);   // só o dono lê
}
