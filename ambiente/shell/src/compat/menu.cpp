// SPDX-License-Identifier: GPL-2.0-or-later
#include "menu.h"
#include "icon.h"

#include <QCursor>
#include <QMenu>
#include <QQuickWindow>
#include <QScreen>

Menu::Menu(QObject *parent) : QObject(parent) {}

Menu::~Menu() { delete m_menu; }

QQmlListProperty<QObject> Menu::content() {
    return QQmlListProperty<QObject>(this, nullptr, &Menu::anexar, &Menu::contar, &Menu::em, &Menu::limpar);
}
void Menu::anexar(QQmlListProperty<QObject> *l, QObject *o) { static_cast<Menu *>(l->object)->m_itens.append(o); }
qsizetype Menu::contar(QQmlListProperty<QObject> *l) { return static_cast<Menu *>(l->object)->m_itens.size(); }
QObject *Menu::em(QQmlListProperty<QObject> *l, qsizetype i) { return static_cast<Menu *>(l->object)->m_itens.value(i); }
void Menu::limpar(QQmlListProperty<QObject> *l) { static_cast<Menu *>(l->object)->m_itens.clear(); }

void Menu::setVisualParent(QQuickItem *p) {
    if (p == m_pai) return;
    m_pai = p;
    Q_EMIT visualParentChanged();
}

void Menu::definirEstado(int e) {
    if (e == m_estado) return;
    m_estado = e;
    Q_EMIT statusChanged();
}

QMenu *Menu::construir() {
    if (!m_menu) {
        m_menu = new QMenu;
        m_menu->setAttribute(Qt::WA_TranslucentBackground, false);
        connect(m_menu, &QMenu::aboutToHide, this, [this] { definirEstado(Closed); });
        connect(m_menu, &QMenu::aboutToShow, this, [this] { definirEstado(Open); });
    }
    m_menu->clear();
    if (m_larguraMin > 0) m_menu->setMinimumWidth(m_larguraMin);
    for (QObject *o : std::as_const(m_itens)) {
        auto *it = qobject_cast<MenuItem *>(o);
        if (!it || !it->m_visivel) continue;
        if (it->m_separador) { m_menu->addSeparator(); continue; }
        if (it->m_secao) { m_menu->addSection(it->m_texto); continue; }
        QAction *a = m_menu->addAction(Icon::iconeDe(it->m_icone), it->m_texto);
        a->setEnabled(it->m_ativo);
        a->setCheckable(it->m_marcavel);
        a->setChecked(it->m_marcado);
        QPointer<MenuItem> p(it);
        connect(a, &QAction::triggered, this, [this, p](bool marcado) {
            if (!p) return;
            if (p->m_marcavel) { p->m_marcado = marcado; Q_EMIT p->toggled(marcado); Q_EMIT p->mudou(); }
            Q_EMIT p->clicked();
            Q_EMIT triggered(p.data());
        });
    }
    return m_menu;
}

void Menu::openRelative() {
    QMenu *m = construir();
    if (m->isEmpty()) return;
    if (!m_pai || !m_pai->window()) { m->popup(QCursor::pos()); return; }
    const QPointF g = m_pai->mapToGlobal(QPointF(0, 0));
    const QPoint canto(qRound(g.x()), qRound(g.y()));
    const int pw = qRound(m_pai->width()), ph = qRound(m_pai->height());
    const QSize t = m->sizeHint();
    QPoint p;
    switch (m_posicao) {
    case TopPosedLeftAlignedPopup: p = canto + QPoint(0, -t.height()); break;
    case TopPosedRightAlignedPopup: p = canto + QPoint(pw - t.width(), -t.height()); break;
    case BottomPosedLeftAlignedPopup: p = canto + QPoint(0, ph); break;
    case BottomPosedRightAlignedPopup: p = canto + QPoint(pw - t.width(), ph); break;
    case LeftPosedTopAlignedPopup: p = canto + QPoint(-t.width(), 0); break;
    case LeftPosedBottomAlignedPopup: p = canto + QPoint(-t.width(), ph - t.height()); break;
    case RightPosedTopAlignedPopup: p = canto + QPoint(pw, 0); break;
    case RightPosedBottomAlignedPopup: p = canto + QPoint(pw, ph - t.height()); break;
    default: p = QCursor::pos(); break;
    }
    // não sair do ecrã
    if (QScreen *s = m_pai->window()->screen()) {
        const QRect r = s->geometry();
        p.setX(qBound(r.left(), p.x(), r.right() - t.width()));
        p.setY(qBound(r.top(), p.y(), r.bottom() - t.height()));
    }
    m->popup(p);
}

void Menu::open(int x, int y) {
    QMenu *m = construir();
    if (m->isEmpty()) return;
    if (x < 0 || y < 0 || !m_pai) { m->popup(QCursor::pos()); return; }
    const QPointF g = m_pai->mapToGlobal(QPointF(x, y));
    m->popup(QPoint(qRound(g.x()), qRound(g.y())));
}

void Menu::close() {
    if (m_menu) m_menu->hide();
}
