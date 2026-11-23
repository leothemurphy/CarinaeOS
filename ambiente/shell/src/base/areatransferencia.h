// CarinaeOS — histórico da área de transferência (o que o Klipper fazia no Plasma).
// Guarda os últimos textos copiados e responde no mesmo endereço D-Bus do Klipper (org.kde.klipper),
// por isso o Comando (Ctrl+Espaço › histórico) e outros programas funcionam sem mudanças.
// Também mantém o texto copiado depois de o programa de onde veio fechar.
// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QObject>
#include <QStringList>
#include <QTimer>

class AreaTransferencia : public QObject {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.kde.klipper.klipper")
public:
    explicit AreaTransferencia(QObject *parent = nullptr);
public Q_SLOTS:
    QStringList getClipboardHistoryMenu() const { return m_historico; }
    QString getClipboardContents() const { return m_historico.value(0); }
    QString getClipboardHistoryItem(int i) const { return m_historico.value(i); }
    void setClipboardContents(const QString &texto);
    void clearClipboardHistory();
private:
    void mudou();
    void gravar();
    QStringList m_historico;
    QTimer m_gravar;
    bool m_aMudar = false;
};
