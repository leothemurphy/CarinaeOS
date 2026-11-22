// CarinaeOS — Bandeja: os ícones dos apps em segundo plano (StatusNotifierItem, o que o Claude,
// o Discord, o Steam, o KDE Connect, o Telegram… usam). A Aurora é o "watcher" e o "host":
// os apps registam-se aqui, mostramos o ícone real e o menu deles (com.canonical.dbusmenu).
// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QDBusVariant>
#include <QHash>
#include <QObject>
#include <QPointer>
#include <QQmlEngine>
#include <QStringList>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

class Vigia;
class QMenu;
class QTimer;

class Bandeja : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    // cada item: { chave, titulo, iconeNome, iconeUrl, estado, dica }
    Q_PROPERTY(QVariantList itens READ itens NOTIFY itensChanged)
public:
    static Bandeja *instancia();
    static Bandeja *create(QQmlEngine *, QJSEngine *);
    QVariantList itens() const;

    Q_INVOKABLE void ativar(const QString &chave, int x, int y);       // clique esquerdo
    Q_INVOKABLE void secundario(const QString &chave, int x, int y);   // clique do meio
    Q_INVOKABLE void menu(const QString &chave, int x, int y);         // clique direito
    Q_INVOKABLE void rodar(const QString &chave, int delta);

Q_SIGNALS:
    void itensChanged();

private Q_SLOTS:
    void registado(const QString &servico);
    void desregistado(const QString &servico);
    void mudou();

private:
    explicit Bandeja(QObject *parent = nullptr);
    struct Item {
        QString servico, caminho, titulo, iconeNome, iconeUrl, estado, dica, menu, temaIcones;
        bool soMenu = false;
    };
    void iniciar();
    void ler(const QString &chave);
    void mostrarMenu(const Item &it, int x, int y);
    QHash<QString, Item> m_itens;
    QStringList m_ordem;
    Vigia *m_vigia = nullptr;
    class QDBusServiceWatcher *m_olhoVigia = nullptr;
    bool m_ligadoAoVigia = false;
    QPointer<QMenu> m_menuAberto;
    QTimer *m_releitura = nullptr;
};
