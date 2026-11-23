// CarinaeOS — WindowThumbnail: miniatura ao vivo de uma janela (X Composite)
// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QImage>
#include <QQuickPaintedItem>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

class WindowThumbnail : public QQuickPaintedItem {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QVariant winId READ winId WRITE setWinId NOTIFY winIdChanged)
    Q_PROPERTY(qreal paintedWidth READ paintedWidth NOTIFY paintedSizeChanged)
    Q_PROPERTY(qreal paintedHeight READ paintedHeight NOTIFY paintedSizeChanged)
    Q_PROPERTY(bool thumbnailAvailable READ disponivel NOTIFY paintedSizeChanged)
public:
    explicit WindowThumbnail(QQuickItem *parent = nullptr);
    QVariant winId() const { return m_win; }
    void setWinId(const QVariant &w);
    qreal paintedWidth() const { return m_pintada.width(); }
    qreal paintedHeight() const { return m_pintada.height(); }
    bool disponivel() const { return !m_imagem.isNull(); }
    void paint(QPainter *p) override;

Q_SIGNALS:
    void winIdChanged();
    void paintedSizeChanged();

protected:
    void itemChange(ItemChange change, const ItemChangeData &value) override;

private:
    void capturar();
    QVariant m_win;
    quint32 m_janela = 0;
    bool m_redirecionada = false;
    QImage m_imagem;
    QSizeF m_pintada;
    QTimer m_relogio;
};
