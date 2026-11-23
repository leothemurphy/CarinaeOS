// SPDX-License-Identifier: GPL-2.0-or-later
#include "icon.h"

#include <QFileInfo>
#include <QPainter>
#include <QQuickWindow>
#include <QUrl>

Icon::Icon(QQuickItem *parent) : QQuickPaintedItem(parent) {
    setImplicitSize(32, 32);
    setAntialiasing(true);
    setMipmap(true);
    connect(this, &QQuickItem::widthChanged, this, [this] { update(); });
    connect(this, &QQuickItem::heightChanged, this, [this] { update(); });
}

QIcon Icon::iconeDe(const QVariant &fonte, const QString &alternativa) {
    QIcon i;
    if (fonte.canConvert<QIcon>() && fonte.metaType() == QMetaType::fromType<QIcon>()) {
        i = fonte.value<QIcon>();
    } else {
        QString s = fonte.metaType() == QMetaType::fromType<QUrl>() ? fonte.toUrl().toString() : fonte.toString();
        if (s.startsWith(QLatin1String("file://"))) s = QUrl(s).toLocalFile();
        else if (s.startsWith(QLatin1String("qrc:"))) s = s.mid(3);
        if (!s.isEmpty()) {
            if (s.startsWith(QLatin1Char('/')) || s.startsWith(QLatin1Char(':'))) {
                if (QFileInfo::exists(s)) i = QIcon(s);
            } else {
                i = QIcon::fromTheme(s);
                // "folder-downloads-symbolic" -> "folder-downloads"; nomes com '-' vão perdendo o fim
                QString n = s;
                while (i.isNull() && n.contains(QLatin1Char('-'))) {
                    n = n.left(n.lastIndexOf(QLatin1Char('-')));
                    i = QIcon::fromTheme(n);
                }
            }
        }
    }
    if (i.isNull() && !alternativa.isEmpty()) i = QIcon::fromTheme(alternativa);
    return i;
}

void Icon::recarregar() {
    m_icone = iconeDe(m_fonte, m_alternativa);
    m_cache = QPixmap();
    Q_EMIT sourceChanged();
    update();
}

void Icon::setSource(const QVariant &s) {
    if (s == m_fonte) return;
    m_fonte = s;
    recarregar();
}

void Icon::setFallback(const QString &f) {
    if (f == m_alternativa) return;
    m_alternativa = f;
    recarregar();
}

void Icon::setActive(bool a) {
    if (a == m_ativo) return;
    m_ativo = a;
    Q_EMIT activeChanged();
    update();
}

void Icon::setIsMask(bool m) {
    if (m == m_mascara) return;
    m_mascara = m;
    m_cache = QPixmap();
    Q_EMIT corChanged();
    update();
}

void Icon::setColor(const QColor &c) {
    if (c == m_cor) return;
    m_cor = c;
    m_cache = QPixmap();
    Q_EMIT corChanged();
    update();
}

void Icon::paint(QPainter *p) {
    if (m_icone.isNull() || width() < 1 || height() < 1) return;
    const qreal dpr = window() ? window()->effectiveDevicePixelRatio() : 1.0;
    const int lado = int(qMin(width(), height()));
    const QSize tam(lado, lado);
    if (m_cache.isNull() || m_cacheTam != tam || m_cacheAtivo != m_ativo) {
        QPixmap px = m_icone.pixmap(tam, dpr, m_ativo ? QIcon::Active : QIcon::Normal);
        if (m_mascara && m_cor.isValid()) {
            QImage img = px.toImage().convertToFormat(QImage::Format_ARGB32_Premultiplied);
            QPainter q(&img);
            q.setCompositionMode(QPainter::CompositionMode_SourceIn);
            q.fillRect(img.rect(), m_cor);
            q.end();
            px = QPixmap::fromImage(img);
            px.setDevicePixelRatio(dpr);
        }
        m_cache = px;
        m_cacheTam = tam;
        m_cacheAtivo = m_ativo;
    }
    const QSizeF real = QSizeF(m_cache.size()) / m_cache.devicePixelRatio();
    const QSizeF alvo = real.scaled(QSizeF(width(), height()), Qt::KeepAspectRatio);
    const QRectF r((width() - alvo.width()) / 2, (height() - alvo.height()) / 2, alvo.width(), alvo.height());
    p->setRenderHint(QPainter::SmoothPixmapTransform, true);
    p->drawPixmap(r, m_cache, QRectF(QPointF(0, 0), QSizeF(m_cache.size())));
}
