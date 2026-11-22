// CarinaeOS — carinae-vigia-bandeja: guarda a lista dos ícones de segundo plano (StatusNotifierItem)
// durante toda a sessão. A Aurora lê a lista daqui; assim, recarregar a Aurora não faz os ícones
// do Chrome, do Claude, do Discord… desaparecerem (esses apps só se registam uma vez).
// SPDX-License-Identifier: GPL-2.0-or-later
#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <cstdio>

#include "../base/vigia.h"

int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("carinae-vigia-bandeja"));
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) { fprintf(stderr, "carinae-vigia-bandeja: sem D-Bus\n"); return 1; }
    Vigia vigia;
    if (!bus.registerObject(QStringLiteral("/StatusNotifierWatcher"), &vigia,
                            QDBusConnection::ExportAllSlots | QDBusConnection::ExportAllSignals | QDBusConnection::ExportAllProperties)
        || !bus.registerService(QStringLiteral("org.kde.StatusNotifierWatcher"))) {
        fprintf(stderr, "carinae-vigia-bandeja: já há outro vigia (%s)\n",
                qPrintable(bus.interface()->serviceOwner(QStringLiteral("org.kde.StatusNotifierWatcher")).value()));
        return 0;
    }
    // se outro programa nos tirar o nome, saímos
    QObject::connect(bus.interface(), &QDBusConnectionInterface::serviceUnregistered, &app, [&](const QString &n) {
        if (n == QLatin1String("org.kde.StatusNotifierWatcher")) app.quit();
    });
    fprintf(stderr, "carinae-vigia-bandeja: pronto\n");
    return app.exec();
}
