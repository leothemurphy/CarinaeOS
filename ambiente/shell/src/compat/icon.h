// CarinaeOS — Icon: desenha um ícone do tema (substitui o Kirigami.Icon)
// source: nome do tema ("user-trash"), caminho, url ou QIcon. isMask + color pintam-no de uma cor.
// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QColor>
#include <QIcon>
#include <QPixmap>
#include <QQuickPaintedItem>
#include <QtQml/qqmlregistration.h>

class Icon : public QQuickPaintedItem {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QVariant source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(QString fallback READ fallback WRITE setFallback NOTIFY sourceChanged)
    Q_PROPERTY(QString placeholder MEMBER m_placeholder NOTIFY sourceChanged)
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(bool selected MEMBER m_selected NOTIFY activeChanged)
    Q_PROPERTY(bool isMask READ isMask WRITE setIsMask NOTIFY corChanged)
    Q_PROPERTY(QColor color READ color WRITE setColor NOTIFY corChanged)
    Q_PROPERTY(bool animated MEMBER m_animated NOTIFY activeChanged)
    Q_PROPERTY(bool roundToIconSize MEMBER m_arredondar NOTIFY activeChanged)
    Q_PROPERTY(bool valid READ valid NOTIFY sourceChanged)
    Q_PROPERTY(qreal paintedWidth READ paintedWidth NOTIFY sourceChanged)
    Q_PROPERTY(qreal paintedHeight READ paintedHeight NOTIFY sourceChanged)
public:
    explicit Icon(QQuickItem *parent = nullptr);

    QVariant source() const { return m_fonte; }
    void setSource(const QVariant &s);
    QString fallback() const { return m_alternativa; }
    void setFallback(const QString &f);
    bool active() const { return m_ativo; }
    void setActive(bool a);
    bool isMask() const { return m_mascara; }
    void setIsMask(bool m);
    QColor color() const { return m_cor; }
    void setColor(const QColor &c);
    bool valid() const { return !m_icone.isNull(); }
    qreal paintedWidth() const { return qMin(width(), height()); }
    qreal paintedHeight() const { return qMin(width(), height()); }

    void paint(QPainter *p) override;

    static QIcon iconeDe(const QVariant &fonte, const QString &alternativa = QString());

Q_SIGNALS:
    void sourceChanged();
    void activeChanged();
    void corChanged();

private:
    void recarregar();
    QVariant m_fonte;
    QString m_alternativa, m_placeholder;
    QIcon m_icone;
    bool m_ativo = false, m_selected = false, m_mascara = false, m_animated = false, m_arredondar = false;
    QColor m_cor;
    QPixmap m_cache;
    QSize m_cacheTam;
    bool m_cacheAtivo = false;
};
