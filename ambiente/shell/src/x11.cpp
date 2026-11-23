// SPDX-License-Identifier: GPL-2.0-or-later
#include "x11.h"

#include <QAbstractNativeEventFilter>
#include <QCoreApplication>
#include <QGuiApplication>
#include <QHash>
#include <QList>

namespace X11 {

static QList<Ouvinte *> s_ouvintes;
static QHash<QByteArray, xcb_atom_t> s_atomos;

Ouvinte::~Ouvinte() { deixar(this); }

bool disponivel() { return con() != nullptr; }

xcb_connection_t *con() {
    if (!qGuiApp) return nullptr;
    auto *x = qGuiApp->nativeInterface<QNativeInterface::QX11Application>();
    return x ? x->connection() : nullptr;
}

xcb_window_t raiz() {
    static xcb_window_t r = 0;
    if (!r && con()) r = xcb_setup_roots_iterator(xcb_get_setup(con())).data->root;
    return r;
}

xcb_atom_t atomo(const char *nome) {
    const QByteArray n(nome);
    auto it = s_atomos.constFind(n);
    if (it != s_atomos.constEnd()) return *it;
    if (!con()) return XCB_ATOM_NONE;
    xcb_intern_atom_reply_t *r = xcb_intern_atom_reply(con(), xcb_intern_atom(con(), 0, n.size(), n.constData()), nullptr);
    xcb_atom_t a = r ? r->atom : xcb_atom_t(XCB_ATOM_NONE);
    free(r);
    s_atomos.insert(n, a);
    return a;
}

QVector<quint32> cardinais(xcb_window_t w, xcb_atom_t prop, xcb_atom_t tipo) {
    QVector<quint32> v;
    if (!con() || !w) return v;
    xcb_get_property_reply_t *r = xcb_get_property_reply(con(), xcb_get_property(con(), 0, w, prop, tipo, 0, 4096), nullptr);
    if (r) {
        if (r->format == 32) {
            const int n = xcb_get_property_value_length(r) / 4;
            const quint32 *p = static_cast<const quint32 *>(xcb_get_property_value(r));
            v.reserve(n);
            for (int i = 0; i < n; ++i) v.append(p[i]);
        }
        free(r);
    }
    return v;
}

QByteArray bytes(xcb_window_t w, xcb_atom_t prop, xcb_atom_t tipo) {
    QByteArray b;
    if (!con() || !w) return b;
    xcb_get_property_reply_t *r = xcb_get_property_reply(con(), xcb_get_property(con(), 0, w, prop, tipo, 0, 2048), nullptr);
    if (r) {
        if (r->format == 8)
            b = QByteArray(static_cast<const char *>(xcb_get_property_value(r)), xcb_get_property_value_length(r));
        free(r);
    }
    return b;
}

QString titulo(xcb_window_t w) {
    QByteArray b = bytes(w, atomo("_NET_WM_NAME"), atomo("UTF8_STRING"));
    if (b.isEmpty()) b = bytes(w, XCB_ATOM_WM_NAME);
    return QString::fromUtf8(b);
}

QPair<QString, QString> classe(xcb_window_t w) {
    const QByteArray b = bytes(w, XCB_ATOM_WM_CLASS, XCB_ATOM_STRING);
    const QList<QByteArray> partes = b.split('\0');
    return {partes.value(0).isEmpty() ? QString() : QString::fromUtf8(partes.value(0)),
            partes.value(1).isEmpty() ? QString() : QString::fromUtf8(partes.value(1))};
}

quint32 pid(xcb_window_t w) {
    const QVector<quint32> v = cardinais(w, atomo("_NET_WM_PID"), XCB_ATOM_CARDINAL);
    return v.isEmpty() ? 0 : v.first();
}

void definirCardinais(xcb_window_t w, xcb_atom_t prop, xcb_atom_t tipo, const QVector<quint32> &v) {
    if (!con() || !w) return;
    xcb_change_property(con(), XCB_PROP_MODE_REPLACE, w, prop, tipo, 32, v.size(), v.constData());
}

void pedirAoGestor(xcb_window_t w, xcb_atom_t tipo, quint32 d0, quint32 d1, quint32 d2, quint32 d3, quint32 d4) {
    if (!con()) return;
    xcb_client_message_event_t ev = {};
    ev.response_type = XCB_CLIENT_MESSAGE;
    ev.format = 32;
    ev.window = w;
    ev.type = tipo;
    ev.data.data32[0] = d0;
    ev.data.data32[1] = d1;
    ev.data.data32[2] = d2;
    ev.data.data32[3] = d3;
    ev.data.data32[4] = d4;
    xcb_send_event(con(), 0, raiz(),
                   XCB_EVENT_MASK_SUBSTRUCTURE_REDIRECT | XCB_EVENT_MASK_SUBSTRUCTURE_NOTIFY,
                   reinterpret_cast<const char *>(&ev));
    xcb_flush(con());
}

void selecionar(xcb_window_t w, quint32 mascara) {
    if (!con() || !w) return;
    xcb_get_window_attributes_reply_t *a = xcb_get_window_attributes_reply(con(), xcb_get_window_attributes(con(), w), nullptr);
    quint32 atual = a ? a->your_event_mask : 0;
    free(a);
    if ((atual & mascara) == mascara) return;
    const quint32 nova = atual | mascara;
    xcb_change_window_attributes(con(), w, XCB_CW_EVENT_MASK, &nova);
}

void flush() {
    if (con()) xcb_flush(con());
}

class Filtro : public QAbstractNativeEventFilter {
public:
    bool nativeEventFilter(const QByteArray &tipo, void *msg, qintptr *) override {
        if (tipo != "xcb_generic_event_t") return false;
        auto *ev = static_cast<xcb_generic_event_t *>(msg);
        const auto copia = s_ouvintes;
        for (Ouvinte *o : copia) o->eventoX(ev);
        return false;
    }
};

void instalarFiltro() {
    static Filtro *f = nullptr;
    if (!f && QCoreApplication::instance()) {
        f = new Filtro;
        QCoreApplication::instance()->installNativeEventFilter(f);
    }
}

void ouvir(Ouvinte *o) {
    instalarFiltro();
    if (!s_ouvintes.contains(o)) s_ouvintes.append(o);
}

void deixar(Ouvinte *o) { s_ouvintes.removeAll(o); }

} // namespace X11
