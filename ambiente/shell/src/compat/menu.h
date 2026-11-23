// CarinaeOS — Menu/MenuItem: menu de contexto nativo (substitui PlasmaExtras.Menu).
// É um QMenu de verdade: abre fora da janela da Dock, com o estilo do sistema.
// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QObject>
#include <QPointer>
#include <QQmlListProperty>
#include <QQuickItem>
#include <QtQml/qqmlregistration.h>

class QMenu;

class MenuItem : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString text MEMBER m_texto NOTIFY mudou)
    Q_PROPERTY(QVariant icon MEMBER m_icone NOTIFY mudou)
    Q_PROPERTY(bool visible MEMBER m_visivel NOTIFY mudou)
    Q_PROPERTY(bool enabled MEMBER m_ativo NOTIFY mudou)
    Q_PROPERTY(bool separator MEMBER m_separador NOTIFY mudou)
    Q_PROPERTY(bool section MEMBER m_secao NOTIFY mudou)
    Q_PROPERTY(bool checkable MEMBER m_marcavel NOTIFY mudou)
    Q_PROPERTY(bool checked MEMBER m_marcado NOTIFY mudou)
public:
    using QObject::QObject;
    QString m_texto;
    QVariant m_icone;
    bool m_visivel = true, m_ativo = true, m_separador = false, m_secao = false, m_marcavel = false, m_marcado = false;
Q_SIGNALS:
    void clicked();
    void toggled(bool checked);
    void mudou();
};

class Menu : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_CLASSINFO("DefaultProperty", "content")
    Q_PROPERTY(QQmlListProperty<QObject> content READ content)
    Q_PROPERTY(QQuickItem *visualParent READ visualParent WRITE setVisualParent NOTIFY visualParentChanged)
    Q_PROPERTY(int placement MEMBER m_posicao NOTIFY placementChanged)
    Q_PROPERTY(int status READ status NOTIFY statusChanged)
    Q_PROPERTY(int minimumWidth MEMBER m_larguraMin NOTIFY placementChanged)
public:
    enum PopupPlacement {
        FloatingPopup = 0, TopPosedLeftAlignedPopup, TopPosedRightAlignedPopup, LeftPosedTopAlignedPopup,
        LeftPosedBottomAlignedPopup, BottomPosedLeftAlignedPopup, BottomPosedRightAlignedPopup,
        RightPosedTopAlignedPopup, RightPosedBottomAlignedPopup
    };
    Q_ENUM(PopupPlacement)
    enum Status { Closed = 0, Opening, Open, Closing };
    Q_ENUM(Status)

    explicit Menu(QObject *parent = nullptr);
    ~Menu() override;

    QQmlListProperty<QObject> content();
    QQuickItem *visualParent() const { return m_pai; }
    void setVisualParent(QQuickItem *p);
    int status() const { return m_estado; }

    Q_INVOKABLE void openRelative();
    Q_INVOKABLE void open(int x = -1, int y = -1);
    Q_INVOKABLE void close();
    Q_INVOKABLE void clearMenuItems() { m_itens.clear(); }
    Q_INVOKABLE void addMenuItem(MenuItem *item) { m_itens.append(item); }

Q_SIGNALS:
    void visualParentChanged();
    void placementChanged();
    void statusChanged();
    void triggered(QObject *item);

private:
    QMenu *construir();
    void definirEstado(int e);
    static void anexar(QQmlListProperty<QObject> *l, QObject *o);
    static qsizetype contar(QQmlListProperty<QObject> *l);
    static QObject *em(QQmlListProperty<QObject> *l, qsizetype i);
    static void limpar(QQmlListProperty<QObject> *l);

    QList<QObject *> m_itens;
    QPointer<QQuickItem> m_pai;
    QMenu *m_menu = nullptr;
    int m_posicao = TopPosedLeftAlignedPopup;
    int m_estado = Closed;
    int m_larguraMin = 0;
};
