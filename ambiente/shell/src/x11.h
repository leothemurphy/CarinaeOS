// CarinaeOS — utilidades X11 partilhadas pelo carinae-shell (usa a ligação do próprio Qt)
// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QPair>
#include <QRect>
#include <QString>
#include <QVector>
#include <xcb/xcb.h>

namespace X11 {

bool disponivel();
xcb_connection_t *con();
xcb_window_t raiz();
xcb_atom_t atomo(const char *nome);

QVector<quint32> cardinais(xcb_window_t w, xcb_atom_t prop, xcb_atom_t tipo = XCB_ATOM_ANY);
QByteArray bytes(xcb_window_t w, xcb_atom_t prop, xcb_atom_t tipo = XCB_ATOM_ANY);
QString titulo(xcb_window_t w);
QPair<QString, QString> classe(xcb_window_t w);   // (instância, classe)
quint32 pid(xcb_window_t w);
void definirCardinais(xcb_window_t w, xcb_atom_t prop, xcb_atom_t tipo, const QVector<quint32> &v);
// pede algo ao gestor de janelas (mensagem para a raiz, como manda a EWMH)
void pedirAoGestor(xcb_window_t w, xcb_atom_t tipo, quint32 d0 = 0, quint32 d1 = 0, quint32 d2 = 0, quint32 d3 = 0, quint32 d4 = 0);
// acrescenta eventos à máscara desta ligação para a janela (sem tirar os que o Qt já pediu)
void selecionar(xcb_window_t w, quint32 mascara);
void flush();

class Ouvinte {
public:
    virtual ~Ouvinte();
    virtual void eventoX(xcb_generic_event_t *ev) = 0;
};
void ouvir(Ouvinte *o);
void deixar(Ouvinte *o);
void instalarFiltro();

} // namespace X11
