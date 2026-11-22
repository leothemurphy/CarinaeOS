// SPDX-License-Identifier: GPL-2.0-or-later
#include "windowthumbnail.h"
#include "../x11.h"

#include <QPainter>
#include <xcb/composite.h>

static bool compositeOk() {
    static int ok = -1;
    if (ok < 0) {
        ok = 0;
        if (xcb_connection_t *c = X11::con()) {
            const xcb_query_extension_reply_t *e = xcb_get_extension_data(c, &xcb_composite_id);
            if (e && e->present) {
                xcb_composite_query_version_reply_t *v =
                    xcb_composite_query_version_reply(c, xcb_composite_query_version(c, 0, 4), nullptr);
                ok = v ? 1 : 0;
                free(v);
            }
        }
    }
    return ok == 1;
}

WindowThumbnail::WindowThumbnail(QQuickItem *parent) : QQuickPaintedItem(parent) {
    m_relogio.setInterval(500);
    connect(&m_relogio, &QTimer::timeout, this, &WindowThumbnail::capturar);
}

void WindowThumbnail::setWinId(const QVariant &w) {
    if (w == m_win) return;
    m_win = w;
    m_janela = w.toUInt();
    m_redirecionada = false;
    m_imagem = QImage();
    Q_EMIT winIdChanged();
    capturar();
    if (isVisible() && m_janela) m_relogio.start();
}

void WindowThumbnail::itemChange(ItemChange change, const ItemChangeData &value) {
    if (change == ItemVisibleHasChanged) {
        if (value.boolValue && m_janela) { capturar(); m_relogio.start(); }
        else m_relogio.stop();
    }
    QQuickPaintedItem::itemChange(change, value);
}

void WindowThumbnail::capturar() {
    xcb_connection_t *c = X11::con();
    if (!c || !m_janela || !compositeOk()) return;
    if (!m_redirecionada) {
        // o conteúdo da janela fica guardado fora do ecrã mesmo quando está tapada
        xcb_composite_redirect_window(c, m_janela, XCB_COMPOSITE_REDIRECT_AUTOMATIC);
        m_redirecionada = true;
    }
    xcb_get_geometry_reply_t *g = xcb_get_geometry_reply(c, xcb_get_geometry(c, m_janela), nullptr);
    if (!g) return;
    const int w = g->width, h = g->height, prof = g->depth;
    free(g);
    if (w < 2 || h < 2) return;
    const xcb_pixmap_t pm = xcb_generate_id(c);
    xcb_generic_error_t *er = xcb_request_check(c, xcb_composite_name_window_pixmap_checked(c, m_janela, pm));
    if (er) { free(er); return; }
    xcb_get_image_reply_t *img = xcb_get_image_reply(c, xcb_get_image(c, XCB_IMAGE_FORMAT_Z_PIXMAP, pm, 0, 0, w, h, ~0u), nullptr);
    xcb_free_pixmap(c, pm);
    if (!img) return;
    const uint8_t *dados = xcb_get_image_data(img);
    const int len = xcb_get_image_data_length(img);
    if (len >= w * h * 4) {
        QImage q(dados, w, h, w * 4, prof == 32 ? QImage::Format_ARGB32_Premultiplied : QImage::Format_RGB32);
        // reduz logo (a miniatura é pequena) para não guardar imagens enormes
        const QSize alvo = QSizeF(w, h).scaled(QSizeF(qMax(1.0, width()), qMax(1.0, height())) * 2, Qt::KeepAspectRatio).toSize();
        m_imagem = q.scaled(alvo, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    }
    free(img);
    update();
}

void WindowThumbnail::paint(QPainter *p) {
    if (m_imagem.isNull()) return;
    const QSizeF t = QSizeF(m_imagem.size()).scaled(QSizeF(width(), height()), Qt::KeepAspectRatio);
    if (t != m_pintada) { m_pintada = t; Q_EMIT paintedSizeChanged(); }
    const QRectF r((width() - t.width()) / 2, (height() - t.height()) / 2, t.width(), t.height());
    p->setRenderHint(QPainter::SmoothPixmapTransform);
    p->drawImage(r, m_imagem);
}
