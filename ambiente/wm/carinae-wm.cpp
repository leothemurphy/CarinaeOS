/*
    Gravidade (gravidade) — o gestor de janelas do CarinaeOS (X11)

    Faz o trabalho que o KWin fazia: põe moldura com título e botões (à macOS) nas janelas,
    deixa mover/redimensionar, dá o foco, maximiza, minimiza, põe em ecrã inteiro, encaixa nas
    metades/zonas, gere as 4 áreas de trabalho, respeita a Dock e a barra de cima (struts) nos
    três monitores, e trata dos atalhos de teclado (~/.config/carinaeos/atalhos.conf).

    Fala EWMH/ICCCM, por isso a Dock (Aurora), o Chrome, o Electron, o GTK e o Qt
    entendem-no sem nada de especial.

      gravidade               (numa sessão sem gestor de janelas)
      gravidade --substituir  (toma o lugar do KWin ou de outro gestor que esteja a correr)

    SPDX-License-Identifier: GPL-2.0-or-later
*/
#include <xcb/xcb.h>
#include <xcb/randr.h>
#include <xcb/xcb_icccm.h>
#include <xcb/xcb_keysyms.h>
#include <xcb/xcb_cursor.h>
#include <cairo/cairo-xcb.h>
#include <X11/keysym.h>
#include <X11/XF86keysym.h>

#include <poll.h>
#include <signal.h>
#include <sys/time.h>
#include <unistd.h>

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <map>
#include <memory>
#include <sstream>
#include <string>
#include <vector>

// ---------------------------------------------------------------------------------------------
// aparência
// ---------------------------------------------------------------------------------------------
static const int TITULO = 32;      // altura da barra de título
static const int BORDA = 5;        // borda (onde se agarra para redimensionar)
static const int CANTO = 18;       // tamanho dos cantos para redimensionar na diagonal
static const int NAREAS = 4;       // áreas de trabalho

struct Cor { double r, g, b; };
static const Cor COR_TITULO_ATIVO   = {0.125, 0.118, 0.157};
static const Cor COR_TITULO_INATIVO = {0.090, 0.086, 0.110};
static const Cor COR_TEXTO_ATIVO    = {0.945, 0.933, 0.965};
static const Cor COR_TEXTO_INATIVO  = {0.55, 0.54, 0.60};
static const Cor COR_FECHAR  = {1.00, 0.373, 0.341};   // #ff5f57
static const Cor COR_MINIMIZAR = {0.996, 0.737, 0.180}; // #febc2e
static const Cor COR_MAXIMIZAR = {0.157, 0.784, 0.251}; // #28c840
static const Cor COR_BOTAO_INATIVO = {0.33, 0.32, 0.37};

static uint32_t pixel(Cor c) {
    return 0xff000000u | (uint32_t(c.r * 255) << 16) | (uint32_t(c.g * 255) << 8) | uint32_t(c.b * 255);
}

// ---------------------------------------------------------------------------------------------
// X
// ---------------------------------------------------------------------------------------------
static xcb_connection_t *X;
static xcb_screen_t *S;
static xcb_window_t R;
static xcb_window_t verificacao;           // janela de _NET_SUPPORTING_WM_CHECK e dona do WM_S0
static xcb_key_symbols_t *teclas;
static xcb_cursor_context_t *ctxCursor;
static uint8_t randrEvento = 0;
static xcb_timestamp_t ultimoTempo = XCB_CURRENT_TIME;

enum {
    WM_PROTOCOLS, WM_DELETE_WINDOW, WM_TAKE_FOCUS, WM_STATE, WM_CHANGE_STATE, WM_S0, MANAGER, UTF8_STRING,
    NET_SUPPORTED, NET_SUPPORTING_WM_CHECK, NET_WM_NAME, NET_CLIENT_LIST, NET_CLIENT_LIST_STACKING,
    NET_ACTIVE_WINDOW, NET_CLOSE_WINDOW, NET_WM_STATE, NET_WM_STATE_FULLSCREEN, NET_WM_STATE_MAXIMIZED_VERT,
    NET_WM_STATE_MAXIMIZED_HORZ, NET_WM_STATE_HIDDEN, NET_WM_STATE_ABOVE, NET_WM_STATE_BELOW,
    NET_WM_STATE_STICKY, NET_WM_STATE_SKIP_TASKBAR, NET_WM_STATE_SKIP_PAGER, NET_WM_STATE_DEMANDS_ATTENTION,
    NET_WM_STATE_FOCUSED, NET_WM_WINDOW_TYPE, NET_WM_WINDOW_TYPE_NORMAL, NET_WM_WINDOW_TYPE_DOCK,
    NET_WM_WINDOW_TYPE_DESKTOP, NET_WM_WINDOW_TYPE_DIALOG, NET_WM_WINDOW_TYPE_UTILITY,
    NET_WM_WINDOW_TYPE_SPLASH, NET_WM_WINDOW_TYPE_NOTIFICATION, NET_WM_WINDOW_TYPE_TOOLTIP,
    NET_WM_WINDOW_TYPE_MENU, NET_WM_WINDOW_TYPE_DROPDOWN_MENU, NET_WM_WINDOW_TYPE_POPUP_MENU,
    NET_WM_WINDOW_TYPE_TOOLBAR, NET_WM_WINDOW_TYPE_COMBO, NET_WM_WINDOW_TYPE_DND,
    NET_WM_STRUT, NET_WM_STRUT_PARTIAL, NET_WORKAREA, NET_NUMBER_OF_DESKTOPS, NET_CURRENT_DESKTOP,
    NET_DESKTOP_NAMES, NET_DESKTOP_VIEWPORT, NET_DESKTOP_GEOMETRY, NET_WM_DESKTOP, NET_FRAME_EXTENTS,
    NET_REQUEST_FRAME_EXTENTS, NET_WM_MOVERESIZE, NET_MOVERESIZE_WINDOW, NET_WM_PID, NET_SHOWING_DESKTOP,
    MOTIF_WM_HINTS, NUM_ATOMOS
};
static const char *nomesAtomos[NUM_ATOMOS] = {
    "WM_PROTOCOLS", "WM_DELETE_WINDOW", "WM_TAKE_FOCUS", "WM_STATE", "WM_CHANGE_STATE", "WM_S0", "MANAGER", "UTF8_STRING",
    "_NET_SUPPORTED", "_NET_SUPPORTING_WM_CHECK", "_NET_WM_NAME", "_NET_CLIENT_LIST", "_NET_CLIENT_LIST_STACKING",
    "_NET_ACTIVE_WINDOW", "_NET_CLOSE_WINDOW", "_NET_WM_STATE", "_NET_WM_STATE_FULLSCREEN", "_NET_WM_STATE_MAXIMIZED_VERT",
    "_NET_WM_STATE_MAXIMIZED_HORZ", "_NET_WM_STATE_HIDDEN", "_NET_WM_STATE_ABOVE", "_NET_WM_STATE_BELOW",
    "_NET_WM_STATE_STICKY", "_NET_WM_STATE_SKIP_TASKBAR", "_NET_WM_STATE_SKIP_PAGER", "_NET_WM_STATE_DEMANDS_ATTENTION",
    "_NET_WM_STATE_FOCUSED", "_NET_WM_WINDOW_TYPE", "_NET_WM_WINDOW_TYPE_NORMAL", "_NET_WM_WINDOW_TYPE_DOCK",
    "_NET_WM_WINDOW_TYPE_DESKTOP", "_NET_WM_WINDOW_TYPE_DIALOG", "_NET_WM_WINDOW_TYPE_UTILITY",
    "_NET_WM_WINDOW_TYPE_SPLASH", "_NET_WM_WINDOW_TYPE_NOTIFICATION", "_NET_WM_WINDOW_TYPE_TOOLTIP",
    "_NET_WM_WINDOW_TYPE_MENU", "_NET_WM_WINDOW_TYPE_DROPDOWN_MENU", "_NET_WM_WINDOW_TYPE_POPUP_MENU",
    "_NET_WM_WINDOW_TYPE_TOOLBAR", "_NET_WM_WINDOW_TYPE_COMBO", "_NET_WM_WINDOW_TYPE_DND",
    "_NET_WM_STRUT", "_NET_WM_STRUT_PARTIAL", "_NET_WORKAREA", "_NET_NUMBER_OF_DESKTOPS", "_NET_CURRENT_DESKTOP",
    "_NET_DESKTOP_NAMES", "_NET_DESKTOP_VIEWPORT", "_NET_DESKTOP_GEOMETRY", "_NET_WM_DESKTOP", "_NET_FRAME_EXTENTS",
    "_NET_REQUEST_FRAME_EXTENTS", "_NET_WM_MOVERESIZE", "_NET_MOVERESIZE_WINDOW", "_NET_WM_PID", "_NET_SHOWING_DESKTOP",
    "_MOTIF_WM_HINTS",
};
static xcb_atom_t A[NUM_ATOMOS];

static void carregarAtomos() {
    xcb_intern_atom_cookie_t ck[NUM_ATOMOS];
    for (int i = 0; i < NUM_ATOMOS; ++i)
        ck[i] = xcb_intern_atom(X, 0, strlen(nomesAtomos[i]), nomesAtomos[i]);
    for (int i = 0; i < NUM_ATOMOS; ++i) {
        xcb_intern_atom_reply_t *r = xcb_intern_atom_reply(X, ck[i], nullptr);
        A[i] = r ? r->atom : xcb_atom_t(XCB_ATOM_NONE);
        free(r);
    }
}

static std::vector<uint32_t> propU32(xcb_window_t w, xcb_atom_t a, xcb_atom_t tipo = XCB_ATOM_ANY, uint32_t max = 4096) {
    std::vector<uint32_t> v;
    xcb_get_property_reply_t *r = xcb_get_property_reply(X, xcb_get_property(X, 0, w, a, tipo, 0, max), nullptr);
    if (r) {
        if (r->format == 32) {
            int n = xcb_get_property_value_length(r) / 4;
            uint32_t *p = (uint32_t *)xcb_get_property_value(r);
            v.assign(p, p + n);
        }
        free(r);
    }
    return v;
}

static std::string propTexto(xcb_window_t w, xcb_atom_t a, xcb_atom_t tipo) {
    std::string s;
    xcb_get_property_reply_t *r = xcb_get_property_reply(X, xcb_get_property(X, 0, w, a, tipo, 0, 1024), nullptr);
    if (r) {
        if (r->format == 8)
            s.assign((const char *)xcb_get_property_value(r), xcb_get_property_value_length(r));
        free(r);
    }
    return s;
}

static void definirU32(xcb_window_t w, xcb_atom_t a, xcb_atom_t tipo, const std::vector<uint32_t> &v) {
    xcb_change_property(X, XCB_PROP_MODE_REPLACE, w, a, tipo, 32, v.size(), v.data());
}

static xcb_visualtype_t *visualDe(xcb_visualid_t id) {
    for (xcb_depth_iterator_t d = xcb_screen_allowed_depths_iterator(S); d.rem; xcb_depth_next(&d))
        for (xcb_visualtype_iterator_t v = xcb_depth_visuals_iterator(d.data); v.rem; xcb_visualtype_next(&v))
            if (v.data->visual_id == id) return v.data;
    return nullptr;
}

static long agoraMs() {
    timeval t;
    gettimeofday(&t, nullptr);
    return t.tv_sec * 1000L + t.tv_usec / 1000;
}

static void executar(const std::string &cmd) {
    if (cmd.empty()) return;
    if (fork() == 0) {
        setsid();
        if (X) close(xcb_get_file_descriptor(X));
        execl("/bin/sh", "sh", "-c", cmd.c_str(), (char *)nullptr);
        _exit(127);
    }
}

// ---------------------------------------------------------------------------------------------
// monitores
// ---------------------------------------------------------------------------------------------
struct Ret {
    int x = 0, y = 0, w = 0, h = 0;
    bool contem(int px, int py) const { return px >= x && px < x + w && py >= y && py < y + h; }
    bool cruza(const Ret &o) const { return x < o.x + o.w && o.x < x + w && y < o.y + o.h && o.y < y + h; }
};
struct Monitor { Ret geo, util; };
static std::vector<Monitor> monitores;

// ---------------------------------------------------------------------------------------------
// clientes
// ---------------------------------------------------------------------------------------------
enum Tipo { T_NORMAL, T_DIALOGO, T_UTILITARIO, T_DOCK, T_FUNDO, T_FLUTUANTE };

struct Cliente {
    xcb_window_t win = 0;
    xcb_window_t moldura = 0;          // == win quando não tem moldura
    Tipo tipo = T_NORMAL;
    bool decorada = true;              // tem barra de título
    bool comMoldura() const { return moldura != win; }
    // geometria: (x, y) = canto da moldura no ecrã; (w, h) = tamanho da janela da app
    int x = 0, y = 0, w = 1, h = 1;
    int rx = 0, ry = 0, rw = 0, rh = 0;     // para repor depois de maximizar/encaixar
    bool temReposicao = false;
    int minW = 1, minH = 1;
    std::string titulo;
    xcb_window_t transitoria = 0;
    bool aceitaFoco = true, pedeFoco = false, apagar = false;
    bool minimizada = false, maximizada = false, cheia = false, acima = false, abaixo = false, fixa = false;
    bool saltarTarefas = false, saltarPager = false, atencao = false;
    int encaixe = 0;                   // 0 nada, 1 esquerda, 2 direita, 11..13 zonas 25/50/25
    uint32_t area = 0;
    bool mapeada = false;
    int ignorarUnmap = 0;
    uint8_t profundidade = 24;
    xcb_visualid_t visual = 0;
    cairo_surface_t *sup = nullptr;
    int hover = -1;                    // botão por baixo do rato (0 fechar, 1 minimizar, 2 maximizar)
    int premido = -1;
    uint32_t cursorAtual = 0;

    int topo() const { return (comMoldura() && decorada && !cheia) ? TITULO : 0; }
    int borda() const { return (comMoldura() && decorada && !cheia) ? BORDA : 0; }
    int mw() const { return w + 2 * borda(); }
    int mh() const { return h + topo() + borda(); }
};

static std::vector<std::unique_ptr<Cliente>> clientes;    // por ordem de chegada
static std::vector<Cliente *> pilha;                      // de baixo para cima
static std::vector<Cliente *> recentes;                   // o mais recente primeiro (Alt+Tab)
static std::vector<xcb_window_t> docas, fundos, flutuantes;
static Cliente *focada = nullptr;
static uint32_t areaAtual = 0;
static bool mesaMostrada = false;
static std::vector<Cliente *> escondidasPelaMesa;

static Cliente *clienteDe(xcb_window_t w) {
    for (auto &c : clientes)
        if (c->win == w || c->moldura == w) return c.get();
    return nullptr;
}

static void atualizarListas() {
    std::vector<uint32_t> lista, emPilha;
    for (auto &c : clientes) lista.push_back(c->win);
    for (Cliente *c : pilha) emPilha.push_back(c->win);
    definirU32(R, A[NET_CLIENT_LIST], XCB_ATOM_WINDOW, lista);
    definirU32(R, A[NET_CLIENT_LIST_STACKING], XCB_ATOM_WINDOW, emPilha);
}

static void escreverEstado(Cliente *c) {
    std::vector<uint32_t> e;
    if (c->cheia) e.push_back(A[NET_WM_STATE_FULLSCREEN]);
    if (c->maximizada) { e.push_back(A[NET_WM_STATE_MAXIMIZED_VERT]); e.push_back(A[NET_WM_STATE_MAXIMIZED_HORZ]); }
    if (c->minimizada) e.push_back(A[NET_WM_STATE_HIDDEN]);
    if (c->acima) e.push_back(A[NET_WM_STATE_ABOVE]);
    if (c->abaixo) e.push_back(A[NET_WM_STATE_BELOW]);
    if (c->fixa) e.push_back(A[NET_WM_STATE_STICKY]);
    if (c->saltarTarefas) e.push_back(A[NET_WM_STATE_SKIP_TASKBAR]);
    if (c->saltarPager) e.push_back(A[NET_WM_STATE_SKIP_PAGER]);
    if (c->atencao) e.push_back(A[NET_WM_STATE_DEMANDS_ATTENTION]);
    if (c == focada) e.push_back(A[NET_WM_STATE_FOCUSED]);
    definirU32(c->win, A[NET_WM_STATE], XCB_ATOM_ATOM, e);
    uint32_t wmEstado[2] = {uint32_t(c->minimizada ? XCB_ICCCM_WM_STATE_ICONIC : XCB_ICCCM_WM_STATE_NORMAL), XCB_NONE};
    xcb_change_property(X, XCB_PROP_MODE_REPLACE, c->win, A[WM_STATE], A[WM_STATE], 32, 2, wmEstado);
}

static void escreverExtensoes(Cliente *c) {
    definirU32(c->win, A[NET_FRAME_EXTENTS], XCB_ATOM_CARDINAL,
               {uint32_t(c->borda()), uint32_t(c->borda()), uint32_t(c->topo()), uint32_t(c->borda())});
}

// ---------------------------------------------------------------------------------------------
// monitores e áreas úteis (o que sobra tirando a Dock e a barra)
// ---------------------------------------------------------------------------------------------
static Ret geometriaRaiz(xcb_window_t w) {
    Ret r;
    xcb_get_geometry_reply_t *g = xcb_get_geometry_reply(X, xcb_get_geometry(X, w), nullptr);
    if (!g) return r;
    xcb_translate_coordinates_reply_t *t =
        xcb_translate_coordinates_reply(X, xcb_translate_coordinates(X, w, R, 0, 0), nullptr);
    r = {t ? t->dst_x : g->x, t ? t->dst_y : g->y, g->width, g->height};
    free(t);
    free(g);
    return r;
}

static void escreverAreas();

static void calcularUteis() {
    for (Monitor &m : monitores) m.util = m.geo;
    for (xcb_window_t d : docas) {
        bool reserva = !propU32(d, A[NET_WM_STRUT_PARTIAL]).empty() || !propU32(d, A[NET_WM_STRUT]).empty();
        if (!reserva) continue;
        Ret g = geometriaRaiz(d);
        for (Monitor &m : monitores) {
            if (!g.cruza(m.geo)) continue;
            Ret &u = m.util;
            if (g.w >= g.h) {     // horizontal: em cima ou em baixo
                if (g.y + g.h / 2 > m.geo.y + m.geo.h / 2) {
                    int fim = std::min(u.y + u.h, g.y);
                    u.h = std::max(50, fim - u.y);
                } else {
                    int ini = std::max(u.y, g.y + g.h);
                    u.h = std::max(50, u.y + u.h - ini);
                    u.y = ini;
                }
            } else {              // vertical: à esquerda ou à direita
                if (g.x + g.w / 2 > m.geo.x + m.geo.w / 2) {
                    int fim = std::min(u.x + u.w, g.x);
                    u.w = std::max(50, fim - u.x);
                } else {
                    int ini = std::max(u.x, g.x + g.w);
                    u.w = std::max(50, u.x + u.w - ini);
                    u.x = ini;
                }
            }
        }
    }
    escreverAreas();
}

static void lerMonitores() {
    monitores.clear();
    xcb_randr_get_monitors_reply_t *r = xcb_randr_get_monitors_reply(X, xcb_randr_get_monitors(X, R, 1), nullptr);
    if (r) {
        // o primário primeiro
        for (xcb_randr_monitor_info_iterator_t it = xcb_randr_get_monitors_monitors_iterator(r); it.rem;
             xcb_randr_monitor_info_next(&it)) {
            Monitor m;
            m.geo = {it.data->x, it.data->y, it.data->width, it.data->height};
            if (it.data->primary) monitores.insert(monitores.begin(), m);
            else monitores.push_back(m);
        }
        free(r);
    }
    // um "monitor" que só engloba outros (xrandr --setmonitor) não conta: ficam os de dentro
    if (monitores.size() > 2) {
        std::vector<Monitor> ficam;
        for (const Monitor &m : monitores) {
            int dentro = 0;
            for (const Monitor &o : monitores)
                if (&o != &m && o.geo.x >= m.geo.x && o.geo.y >= m.geo.y && o.geo.x + o.geo.w <= m.geo.x + m.geo.w &&
                    o.geo.y + o.geo.h <= m.geo.y + m.geo.h && (o.geo.w != m.geo.w || o.geo.h != m.geo.h))
                    dentro++;
            if (dentro < 2) ficam.push_back(m);
        }
        if (!ficam.empty()) monitores = ficam;
    }
    if (monitores.empty()) {
        Monitor m;
        m.geo = {0, 0, S->width_in_pixels, S->height_in_pixels};
        monitores.push_back(m);
    }
    calcularUteis();
}

static Monitor &monitorEm(int px, int py) {
    for (Monitor &m : monitores)
        if (m.geo.contem(px, py)) return m;
    // o mais próximo
    Monitor *melhor = &monitores[0];
    long dist = -1;
    for (Monitor &m : monitores) {
        long dx = std::max(0, std::max(m.geo.x - px, px - (m.geo.x + m.geo.w)));
        long dy = std::max(0, std::max(m.geo.y - py, py - (m.geo.y + m.geo.h)));
        long d = dx * dx + dy * dy;
        if (dist < 0 || d < dist) { dist = d; melhor = &m; }
    }
    return *melhor;
}

static Monitor &monitorDe(Cliente *c) { return monitorEm(c->x + c->mw() / 2, c->y + c->mh() / 2); }

static void escreverAreas() {
    const Ret &u = monitores.empty() ? Ret{0, 0, S->width_in_pixels, S->height_in_pixels} : monitores[0].util;
    std::vector<uint32_t> wa, vp;
    for (int i = 0; i < NAREAS; ++i) {
        wa.insert(wa.end(), {uint32_t(u.x), uint32_t(u.y), uint32_t(u.w), uint32_t(u.h)});
        vp.insert(vp.end(), {0, 0});
    }
    definirU32(R, A[NET_WORKAREA], XCB_ATOM_CARDINAL, wa);
    definirU32(R, A[NET_DESKTOP_VIEWPORT], XCB_ATOM_CARDINAL, vp);
    definirU32(R, A[NET_DESKTOP_GEOMETRY], XCB_ATOM_CARDINAL, {S->width_in_pixels, S->height_in_pixels});
}

static Monitor &monitorDoRato() {
    xcb_query_pointer_reply_t *p = xcb_query_pointer_reply(X, xcb_query_pointer(X, R), nullptr);
    int px = p ? p->root_x : 0, py = p ? p->root_y : 0;
    free(p);
    return monitorEm(px, py);
}

// ---------------------------------------------------------------------------------------------
// desenho da moldura (cairo)
// ---------------------------------------------------------------------------------------------
static void corCairo(cairo_t *cr, Cor c) { cairo_set_source_rgba(cr, c.r, c.g, c.b, 1.0); }

// onde ficam os botões (~/.config/carinaeos/gravidade.conf, "botoes = mac | windows | fechar"; a Supernova escolhe)
//   mac: fechar, minimizar, maximizar à esquerda;  windows: minimizar, maximizar, fechar à direita;  fechar: só o fechar, à direita
static std::string disposicaoBotoes = "mac";
static bool botaoExiste(int i) { return disposicaoBotoes != "fechar" || i == 0; }
static int centroBotaoX(Cliente *c, int i) {
    if (disposicaoBotoes == "mac") return BORDA + 16 + i * 22;
    const int dir = c->mw() - BORDA - 16;               // o botão mais à direita
    if (disposicaoBotoes == "fechar") return dir;
    return dir - (i == 0 ? 0 : i == 2 ? 22 : 44);       // minimizar, maximizar, fechar
}
// a zona dos botões na barra do título (para mostrar os símbolos ao passar o rato)
static bool naZonaBotoes(Cliente *c, int x) {
    if (disposicaoBotoes == "mac") return x > BORDA && x < centroBotaoX(c, 2) + 12;
    const int esq = disposicaoBotoes == "fechar" ? centroBotaoX(c, 0) : centroBotaoX(c, 1);
    return x > esq - 12 && x < c->mw() - BORDA;
}
static void lerGravidadeConf() {
    disposicaoBotoes = "mac";
    const char *home = getenv("HOME");
    std::ifstream f(std::string(home ? home : "") + "/.config/carinaeos/gravidade.conf");
    std::string l;
    while (std::getline(f, l)) {
        size_t eq = l.find('=');
        if (l.empty() || l[0] == '#' || eq == std::string::npos) continue;
        std::string k = l.substr(0, eq), v = l.substr(eq + 1);
        auto apara = [](std::string x) { size_t a = x.find_first_not_of(" \t\r"), b = x.find_last_not_of(" \t\r");
                                         return a == std::string::npos ? std::string() : x.substr(a, b - a + 1); };
        k = apara(k); v = apara(v);
        if (k == "botoes" && (v == "mac" || v == "windows" || v == "fechar")) disposicaoBotoes = v;
    }
}

static void desenhar(Cliente *c) {
    if (!c->comMoldura() || !c->mapeada) return;
    int W = c->mw(), H = c->mh();
    if (!c->sup) {
        xcb_visualtype_t *vt = visualDe(c->visual);
        if (!vt) return;
        c->sup = cairo_xcb_surface_create(X, c->moldura, vt, W, H);
    } else {
        cairo_xcb_surface_set_size(c->sup, W, H);
    }
    bool ativa = (c == focada);
    cairo_t *cr = cairo_create(c->sup);
    cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE);
    corCairo(cr, ativa ? COR_TITULO_ATIVO : COR_TITULO_INATIVO);
    cairo_paint(cr);
    cairo_set_operator(cr, CAIRO_OPERATOR_OVER);
    if (c->topo() > 0) {
        // linha fina por baixo do título
        cairo_set_source_rgba(cr, 1, 1, 1, ativa ? 0.06 : 0.03);
        cairo_rectangle(cr, 0, TITULO - 1, W, 1);
        cairo_fill(cr);
        // os três botões (como no macOS)
        const Cor cores[3] = {COR_FECHAR, COR_MINIMIZAR, COR_MAXIMIZAR};
        bool mostrarSimbolos = c->hover >= 0;
        for (int i = 0; i < 3; ++i) {
            if (!botaoExiste(i)) continue;
            double cx = centroBotaoX(c, i), cy = TITULO / 2.0;
            corCairo(cr, (ativa || mostrarSimbolos) ? cores[i] : COR_BOTAO_INATIVO);
            cairo_arc(cr, cx, cy, 6.5, 0, 2 * M_PI);
            cairo_fill(cr);
            if (mostrarSimbolos) {
                cairo_set_source_rgba(cr, 0, 0, 0, c->premido == i ? 0.75 : 0.55);
                cairo_set_line_width(cr, 1.4);
                cairo_set_line_cap(cr, CAIRO_LINE_CAP_ROUND);
                if (i == 0) {
                    cairo_move_to(cr, cx - 2.8, cy - 2.8); cairo_line_to(cr, cx + 2.8, cy + 2.8);
                    cairo_move_to(cr, cx + 2.8, cy - 2.8); cairo_line_to(cr, cx - 2.8, cy + 2.8);
                } else if (i == 1) {
                    cairo_move_to(cr, cx - 3.4, cy); cairo_line_to(cr, cx + 3.4, cy);
                } else {
                    cairo_move_to(cr, cx - 3.2, cy); cairo_line_to(cr, cx + 3.2, cy);
                    cairo_move_to(cr, cx, cy - 3.2); cairo_line_to(cr, cx, cy + 3.2);
                }
                cairo_stroke(cr);
            }
        }
        // título ao centro, cortado com reticências se não couber
        cairo_select_font_face(cr, "Sans", CAIRO_FONT_SLANT_NORMAL, ativa ? CAIRO_FONT_WEIGHT_BOLD : CAIRO_FONT_WEIGHT_NORMAL);
        cairo_set_font_size(cr, 12.5);
        std::string t = c->titulo;
        double maxLarg = W - 2 * (BORDA + 16 + 44 + 20);
        cairo_text_extents_t ext;
        cairo_text_extents(cr, t.c_str(), &ext);
        bool cortado = false;
        while (!t.empty() && ext.x_advance > maxLarg) {
            do { t.pop_back(); } while (!t.empty() && (uint8_t(t.back()) & 0xC0) == 0x80);
            if (!t.empty()) t.pop_back();
            cortado = true;
            std::string com = t + "…";
            cairo_text_extents(cr, com.c_str(), &ext);
        }
        if (cortado) t += "…";
        if (maxLarg > 20) {
            cairo_text_extents(cr, t.c_str(), &ext);
            corCairo(cr, ativa ? COR_TEXTO_ATIVO : COR_TEXTO_INATIVO);
            cairo_move_to(cr, (W - ext.x_advance) / 2.0, TITULO / 2.0 + 4.5);
            cairo_show_text(cr, t.c_str());
        }
    }
    cairo_destroy(cr);
    cairo_surface_flush(c->sup);
}

// ---------------------------------------------------------------------------------------------
// geometria e ordem
// ---------------------------------------------------------------------------------------------
static void enviarConfigure(Cliente *c, int cx, int cy, int cw, int ch) {
    xcb_configure_notify_event_t ev = {};
    ev.response_type = XCB_CONFIGURE_NOTIFY;
    ev.event = c->win;
    ev.window = c->win;
    ev.x = cx;
    ev.y = cy;
    ev.width = cw;
    ev.height = ch;
    ev.border_width = 0;
    ev.above_sibling = XCB_NONE;
    ev.override_redirect = 0;
    xcb_send_event(X, 0, c->win, XCB_EVENT_MASK_STRUCTURE_NOTIFY, (const char *)&ev);
}

static void aplicar(Cliente *c) {
    if (c->cheia) {
        Monitor &m = monitorDe(c);
        if (c->comMoldura()) {
            uint32_t fv[] = {uint32_t(m.geo.x), uint32_t(m.geo.y), uint32_t(m.geo.w), uint32_t(m.geo.h)};
            xcb_configure_window(X, c->moldura, XCB_CONFIG_WINDOW_X | XCB_CONFIG_WINDOW_Y |
                                 XCB_CONFIG_WINDOW_WIDTH | XCB_CONFIG_WINDOW_HEIGHT, fv);
            uint32_t cv[] = {0, 0, uint32_t(m.geo.w), uint32_t(m.geo.h)};
            xcb_configure_window(X, c->win, XCB_CONFIG_WINDOW_X | XCB_CONFIG_WINDOW_Y |
                                 XCB_CONFIG_WINDOW_WIDTH | XCB_CONFIG_WINDOW_HEIGHT, cv);
        } else {
            uint32_t fv[] = {uint32_t(m.geo.x), uint32_t(m.geo.y), uint32_t(m.geo.w), uint32_t(m.geo.h), 0};
            xcb_configure_window(X, c->win, XCB_CONFIG_WINDOW_X | XCB_CONFIG_WINDOW_Y |
                                 XCB_CONFIG_WINDOW_WIDTH | XCB_CONFIG_WINDOW_HEIGHT | XCB_CONFIG_WINDOW_BORDER_WIDTH, fv);
        }
        enviarConfigure(c, m.geo.x, m.geo.y, m.geo.w, m.geo.h);
    } else {
        c->w = std::max(c->w, std::max(1, c->minW));
        c->h = std::max(c->h, std::max(1, c->minH));
        if (c->comMoldura()) {
            uint32_t fv[] = {uint32_t(c->x), uint32_t(c->y), uint32_t(c->mw()), uint32_t(c->mh())};
            xcb_configure_window(X, c->moldura, XCB_CONFIG_WINDOW_X | XCB_CONFIG_WINDOW_Y |
                                 XCB_CONFIG_WINDOW_WIDTH | XCB_CONFIG_WINDOW_HEIGHT, fv);
            uint32_t cv[] = {uint32_t(c->borda()), uint32_t(c->topo()), uint32_t(c->w), uint32_t(c->h)};
            xcb_configure_window(X, c->win, XCB_CONFIG_WINDOW_X | XCB_CONFIG_WINDOW_Y |
                                 XCB_CONFIG_WINDOW_WIDTH | XCB_CONFIG_WINDOW_HEIGHT, cv);
        } else {
            uint32_t fv[] = {uint32_t(c->x), uint32_t(c->y), uint32_t(c->w), uint32_t(c->h), 0};
            xcb_configure_window(X, c->win, XCB_CONFIG_WINDOW_X | XCB_CONFIG_WINDOW_Y |
                                 XCB_CONFIG_WINDOW_WIDTH | XCB_CONFIG_WINDOW_HEIGHT | XCB_CONFIG_WINDOW_BORDER_WIDTH, fv);
        }
        enviarConfigure(c, c->x + c->borda(), c->y + c->topo(), c->w, c->h);
    }
    escreverExtensoes(c);
    desenhar(c);
}

static int camada(Cliente *c) {
    if (c->abaixo) return 0;
    if (c->cheia && c == focada) return 4;
    if (c->acima) return 2;
    return 1;
}

static void reempilhar() {
    std::vector<xcb_window_t> ordem;
    for (xcb_window_t f : fundos) ordem.push_back(f);
    std::vector<Cliente *> ord = pilha;
    std::stable_sort(ord.begin(), ord.end(), [](Cliente *a, Cliente *b) { return camada(a) < camada(b); });
    pilha = ord;
    bool docasPostas = false;
    for (Cliente *c : ord) {
        if (!docasPostas && camada(c) >= 4) {
            for (xcb_window_t d : docas) ordem.push_back(d);
            docasPostas = true;
        }
        ordem.push_back(c->moldura);
    }
    if (!docasPostas)
        for (xcb_window_t d : docas) ordem.push_back(d);
    for (xcb_window_t f : flutuantes) ordem.push_back(f);
    for (size_t i = 0; i < ordem.size(); ++i) {
        if (i == 0) {
            uint32_t v[] = {XCB_STACK_MODE_BELOW};
            xcb_configure_window(X, ordem[i], XCB_CONFIG_WINDOW_STACK_MODE, v);
        } else {
            uint32_t v[] = {ordem[i - 1], XCB_STACK_MODE_ABOVE};
            xcb_configure_window(X, ordem[i], XCB_CONFIG_WINDOW_SIBLING | XCB_CONFIG_WINDOW_STACK_MODE, v);
        }
    }
    atualizarListas();
}

static void levantar(Cliente *c) {
    pilha.erase(std::remove(pilha.begin(), pilha.end(), c), pilha.end());
    pilha.push_back(c);
    // os diálogos desta janela vão com ela
    for (auto &d : clientes)
        if (d->transitoria == c->win && d.get() != c) {
            pilha.erase(std::remove(pilha.begin(), pilha.end(), d.get()), pilha.end());
            pilha.push_back(d.get());
        }
    reempilhar();
}

// ---------------------------------------------------------------------------------------------
// foco
// ---------------------------------------------------------------------------------------------
static bool visivel(Cliente *c) { return !c->minimizada && (c->fixa || c->area == areaAtual); }

static void focar(Cliente *c) {
    Cliente *antes = focada;
    if (c && !visivel(c)) c = nullptr;
    focada = c;
    if (c) {
        if (c->aceitaFoco)
            xcb_set_input_focus(X, XCB_INPUT_FOCUS_POINTER_ROOT, c->win, ultimoTempo);
        if (c->pedeFoco) {
            xcb_client_message_event_t ev = {};
            ev.response_type = XCB_CLIENT_MESSAGE;
            ev.format = 32;
            ev.window = c->win;
            ev.type = A[WM_PROTOCOLS];
            ev.data.data32[0] = A[WM_TAKE_FOCUS];
            ev.data.data32[1] = ultimoTempo;
            xcb_send_event(X, 0, c->win, XCB_EVENT_MASK_NO_EVENT, (const char *)&ev);
        }
        c->atencao = false;
        recentes.erase(std::remove(recentes.begin(), recentes.end(), c), recentes.end());
        recentes.insert(recentes.begin(), c);
        definirU32(R, A[NET_ACTIVE_WINDOW], XCB_ATOM_WINDOW, {c->win});
        escreverEstado(c);
    } else {
        xcb_set_input_focus(X, XCB_INPUT_FOCUS_POINTER_ROOT, verificacao, ultimoTempo);
        definirU32(R, A[NET_ACTIVE_WINDOW], XCB_ATOM_WINDOW, {XCB_NONE});
    }
    if (antes && antes != c) {
        escreverEstado(antes);
        desenhar(antes);
    }
    if (c) desenhar(c);
    if ((antes && antes->cheia) || (c && c->cheia)) reempilhar();
}

static void focarOutra() {
    for (Cliente *c : recentes)
        if (visivel(c) && c->tipo != T_UTILITARIO) { focar(c); return; }
    focar(nullptr);
}

static void ativar(Cliente *c);

// ---------------------------------------------------------------------------------------------
// mostrar/esconder (minimizar, áreas de trabalho)
// ---------------------------------------------------------------------------------------------
static void atualizarVisibilidade(Cliente *c) {
    bool deve = visivel(c);
    if (deve && !c->mapeada) {
        if (!c->comMoldura()) xcb_map_window(X, c->win);
        xcb_map_window(X, c->moldura);
        c->mapeada = true;
        desenhar(c);
    } else if (!deve && c->mapeada) {
        if (!c->comMoldura()) c->ignorarUnmap++;
        xcb_unmap_window(X, c->moldura);
        c->mapeada = false;
    }
    escreverEstado(c);
}

static void minimizar(Cliente *c) {
    if (c->minimizada) return;
    c->minimizada = true;
    atualizarVisibilidade(c);
    if (focada == c) focarOutra();
}

static void mudarArea(uint32_t n) {
    if (n >= NAREAS || n == areaAtual) return;
    areaAtual = n;
    for (auto &c : clientes) atualizarVisibilidade(c.get());
    definirU32(R, A[NET_CURRENT_DESKTOP], XCB_ATOM_CARDINAL, {areaAtual});
    if (!focada || !visivel(focada)) focarOutra();
}

static void moverParaArea(Cliente *c, uint32_t n) {
    if (!c || n >= NAREAS) return;
    c->area = n;
    definirU32(c->win, A[NET_WM_DESKTOP], XCB_ATOM_CARDINAL, {c->fixa ? 0xFFFFFFFFu : n});
    atualizarVisibilidade(c);
    if (focada == c && !visivel(c)) focarOutra();
}

static void ativar(Cliente *c) {
    if (!c) return;
    if (!c->fixa && c->area != areaAtual) mudarArea(c->area);
    if (c->minimizada) {
        c->minimizada = false;
        atualizarVisibilidade(c);
    }
    if (mesaMostrada) {
        mesaMostrada = false;
        escondidasPelaMesa.clear();
        definirU32(R, A[NET_SHOWING_DESKTOP], XCB_ATOM_CARDINAL, {0});
    }
    levantar(c);
    focar(c);
}

// ---------------------------------------------------------------------------------------------
// maximizar, encaixar, ecrã inteiro
// ---------------------------------------------------------------------------------------------
static void guardarReposicao(Cliente *c) {
    if (c->maximizada || c->encaixe || c->cheia) return;
    c->rx = c->x; c->ry = c->y; c->rw = c->w; c->rh = c->h;
    c->temReposicao = true;
}

static void porNoRetangulo(Cliente *c, const Ret &r) {
    c->x = r.x;
    c->y = r.y;
    c->w = std::max(c->minW, r.w - 2 * c->borda());
    c->h = std::max(c->minH, r.h - c->topo() - c->borda());
}

static void repor(Cliente *c) {
    c->maximizada = false;
    c->encaixe = 0;
    if (c->temReposicao) {
        c->x = c->rx; c->y = c->ry; c->w = c->rw; c->h = c->rh;
    }
    aplicar(c);
    escreverEstado(c);
}

static void maximizar(Cliente *c, bool sim) {
    if (!c || c->tipo == T_UTILITARIO) return;
    if (sim) {
        guardarReposicao(c);
        Monitor &m = monitorDe(c);
        c->maximizada = true;
        c->encaixe = 0;
        porNoRetangulo(c, m.util);
        aplicar(c);
        escreverEstado(c);
    } else {
        repor(c);
    }
}

static void encaixar(Cliente *c, int lado, Monitor *mon = nullptr) {
    if (!c) return;
    Monitor &m = mon ? *mon : monitorDe(c);
    if (c->encaixe == lado && !mon) { repor(c); return; }
    guardarReposicao(c);
    c->maximizada = false;
    c->encaixe = lado;
    Ret u = m.util, r = u;
    switch (lado) {
    case 1: r.w = u.w / 2; break;
    case 2: r.x = u.x + u.w / 2; r.w = u.w - u.w / 2; break;
    case 11: r.w = u.w / 4; break;                                    // zonas 25 / 50 / 25
    case 12: r.x = u.x + u.w / 4; r.w = u.w / 2; break;
    case 13: r.x = u.x + u.w / 4 + u.w / 2; r.w = u.w - u.w / 4 - u.w / 2; break;
    }
    porNoRetangulo(c, r);
    aplicar(c);
    escreverEstado(c);
}

static void telaCheia(Cliente *c, bool sim) {
    if (!c || c->cheia == sim) return;
    if (sim) guardarReposicao(c);
    c->cheia = sim;
    if (!sim) {
        if (c->maximizada) maximizar(c, true);
        else if (c->encaixe) { int e = c->encaixe; c->encaixe = 0; encaixar(c, e); }
        else repor(c);
    } else {
        aplicar(c);
    }
    escreverEstado(c);
    reempilhar();
}

static void fechar(Cliente *c) {
    if (!c) return;
    if (c->apagar) {
        xcb_client_message_event_t ev = {};
        ev.response_type = XCB_CLIENT_MESSAGE;
        ev.format = 32;
        ev.window = c->win;
        ev.type = A[WM_PROTOCOLS];
        ev.data.data32[0] = A[WM_DELETE_WINDOW];
        ev.data.data32[1] = ultimoTempo;
        xcb_send_event(X, 0, c->win, XCB_EVENT_MASK_NO_EVENT, (const char *)&ev);
    } else {
        xcb_kill_client(X, c->win);
    }
}

static void mostrarMesa() {
    if (!mesaMostrada) {
        escondidasPelaMesa.clear();
        for (auto &c : clientes)
            if (visivel(c.get())) {
                escondidasPelaMesa.push_back(c.get());
                c->minimizada = true;
                atualizarVisibilidade(c.get());
            }
        mesaMostrada = true;
        focar(nullptr);
    } else {
        for (Cliente *c : escondidasPelaMesa) {
            c->minimizada = false;
            atualizarVisibilidade(c);
        }
        mesaMostrada = false;
        if (!escondidasPelaMesa.empty()) focar(escondidasPelaMesa.back());
        escondidasPelaMesa.clear();
    }
    definirU32(R, A[NET_SHOWING_DESKTOP], XCB_ATOM_CARDINAL, {mesaMostrada ? 1u : 0u});
}

// ---------------------------------------------------------------------------------------------
// ler as propriedades de uma janela
// ---------------------------------------------------------------------------------------------
static void lerTitulo(Cliente *c) {
    std::string t = propTexto(c->win, A[NET_WM_NAME], A[UTF8_STRING]);
    if (t.empty()) t = propTexto(c->win, XCB_ATOM_WM_NAME, XCB_ATOM_ANY);
    c->titulo = t;
}

static void lerProtocolos(Cliente *c) {
    c->pedeFoco = c->apagar = false;
    for (uint32_t a : propU32(c->win, A[WM_PROTOCOLS], XCB_ATOM_ATOM)) {
        if (a == A[WM_TAKE_FOCUS]) c->pedeFoco = true;
        if (a == A[WM_DELETE_WINDOW]) c->apagar = true;
    }
    xcb_icccm_wm_hints_t dicas;
    if (xcb_icccm_get_wm_hints_reply(X, xcb_icccm_get_wm_hints(X, c->win), &dicas, nullptr)) {
        if (dicas.flags & XCB_ICCCM_WM_HINT_INPUT) c->aceitaFoco = dicas.input;
        if (dicas.flags & XCB_ICCCM_WM_HINT_X_URGENCY) c->atencao = true;
    }
}

static void lerTamanhos(Cliente *c, bool *posUsuario) {
    xcb_size_hints_t h;
    if (xcb_icccm_get_wm_normal_hints_reply(X, xcb_icccm_get_wm_normal_hints(X, c->win), &h, nullptr)) {
        if (h.flags & XCB_ICCCM_SIZE_HINT_P_MIN_SIZE) {
            c->minW = std::max(1, h.min_width);
            c->minH = std::max(1, h.min_height);
        }
        if (posUsuario) *posUsuario = (h.flags & (XCB_ICCCM_SIZE_HINT_US_POSITION | XCB_ICCCM_SIZE_HINT_P_POSITION)) != 0;
    }
}

static Tipo lerTipo(xcb_window_t w, bool *temTransitoria, xcb_window_t *trans) {
    xcb_window_t t = 0;
    xcb_icccm_get_wm_transient_for_reply(X, xcb_icccm_get_wm_transient_for(X, w), &t, nullptr);
    if (trans) *trans = t;
    if (temTransitoria) *temTransitoria = t != 0;
    for (uint32_t a : propU32(w, A[NET_WM_WINDOW_TYPE], XCB_ATOM_ATOM)) {
        if (a == A[NET_WM_WINDOW_TYPE_DOCK]) return T_DOCK;
        if (a == A[NET_WM_WINDOW_TYPE_DESKTOP]) return T_FUNDO;
        if (a == A[NET_WM_WINDOW_TYPE_DIALOG]) return T_DIALOGO;
        if (a == A[NET_WM_WINDOW_TYPE_UTILITY] || a == A[NET_WM_WINDOW_TYPE_TOOLBAR]) return T_UTILITARIO;
        if (a == A[NET_WM_WINDOW_TYPE_SPLASH] || a == A[NET_WM_WINDOW_TYPE_NOTIFICATION] ||
            a == A[NET_WM_WINDOW_TYPE_TOOLTIP] || a == A[NET_WM_WINDOW_TYPE_MENU] ||
            a == A[NET_WM_WINDOW_TYPE_DROPDOWN_MENU] || a == A[NET_WM_WINDOW_TYPE_POPUP_MENU] ||
            a == A[NET_WM_WINDOW_TYPE_COMBO] || a == A[NET_WM_WINDOW_TYPE_DND])
            return T_FLUTUANTE;
        if (a == A[NET_WM_WINDOW_TYPE_NORMAL]) return t ? T_DIALOGO : T_NORMAL;
    }
    return t ? T_DIALOGO : T_NORMAL;
}

static bool semDecoracaoMotif(xcb_window_t w) {
    std::vector<uint32_t> m = propU32(w, A[MOTIF_WM_HINTS], XCB_ATOM_ANY, 5);
    // flags & MWM_HINTS_DECORATIONS (2) e decorations == 0
    return m.size() >= 3 && (m[0] & 2) && m[2] == 0;
}

static void lerEstadoInicial(Cliente *c) {
    for (uint32_t a : propU32(c->win, A[NET_WM_STATE], XCB_ATOM_ATOM)) {
        if (a == A[NET_WM_STATE_FULLSCREEN]) c->cheia = true;
        else if (a == A[NET_WM_STATE_MAXIMIZED_VERT] || a == A[NET_WM_STATE_MAXIMIZED_HORZ]) c->maximizada = true;
        else if (a == A[NET_WM_STATE_ABOVE]) c->acima = true;
        else if (a == A[NET_WM_STATE_BELOW]) c->abaixo = true;
        else if (a == A[NET_WM_STATE_STICKY]) c->fixa = true;
        else if (a == A[NET_WM_STATE_SKIP_TASKBAR]) c->saltarTarefas = true;
        else if (a == A[NET_WM_STATE_SKIP_PAGER]) c->saltarPager = true;
    }
    std::vector<uint32_t> d = propU32(c->win, A[NET_WM_DESKTOP], XCB_ATOM_CARDINAL);
    if (!d.empty()) {
        if (d[0] == 0xFFFFFFFFu) c->fixa = true;
        else if (d[0] < NAREAS) c->area = d[0];
        else c->area = areaAtual;
    } else {
        c->area = areaAtual;
    }
}

// ---------------------------------------------------------------------------------------------
// gerir / largar uma janela
// ---------------------------------------------------------------------------------------------
static void agarrarBotoes(xcb_window_t w) {
    // clicar numa janela dá-lhe o foco (o clique segue depois para a app)
    xcb_grab_button(X, 0, w, XCB_EVENT_MASK_BUTTON_PRESS, XCB_GRAB_MODE_SYNC, XCB_GRAB_MODE_ASYNC,
                    XCB_NONE, XCB_NONE, XCB_BUTTON_INDEX_ANY, XCB_MOD_MASK_ANY);
}

static void gerir(xcb_window_t w, bool jaMapeada) {
    if (clienteDe(w)) return;
    xcb_get_window_attributes_reply_t *at = xcb_get_window_attributes_reply(X, xcb_get_window_attributes(X, w), nullptr);
    if (!at) return;
    if (at->override_redirect) { free(at); return; }
    xcb_visualid_t visual = at->visual;
    free(at);

    bool temTrans = false;
    xcb_window_t trans = 0;
    Tipo tipo = lerTipo(w, &temTrans, &trans);
    uint32_t mascaraCliente[] = {XCB_EVENT_MASK_PROPERTY_CHANGE | XCB_EVENT_MASK_STRUCTURE_NOTIFY};

    if (tipo == T_DOCK || tipo == T_FUNDO || tipo == T_FLUTUANTE) {
        xcb_change_window_attributes(X, w, XCB_CW_EVENT_MASK, mascaraCliente);
        auto &lista = tipo == T_DOCK ? docas : tipo == T_FUNDO ? fundos : flutuantes;
        if (std::find(lista.begin(), lista.end(), w) == lista.end()) lista.push_back(w);
        definirU32(w, A[NET_WM_DESKTOP], XCB_ATOM_CARDINAL, {0xFFFFFFFFu});
        xcb_map_window(X, w);
        if (tipo == T_DOCK) {
            calcularUteis();
            for (auto &c : clientes) {
                if (c->maximizada) { Monitor &m = monitorDe(c.get()); porNoRetangulo(c.get(), m.util); aplicar(c.get()); }
                else if (c->encaixe) { int e = c->encaixe; c->encaixe = 0; encaixar(c.get(), e); }
            }
        }
        reempilhar();
        return;
    }

    xcb_get_geometry_reply_t *g = xcb_get_geometry_reply(X, xcb_get_geometry(X, w), nullptr);
    if (!g) return;

    auto novo = std::make_unique<Cliente>();
    Cliente *c = novo.get();
    c->win = w;
    c->tipo = tipo;
    c->transitoria = trans;
    c->profundidade = g->depth;
    c->visual = visual;
    c->w = g->width;
    c->h = g->height;
    int gx = g->x, gy = g->y;
    free(g);

    lerTitulo(c);
    lerProtocolos(c);
    bool posUsuario = false;
    lerTamanhos(c, &posUsuario);
    lerEstadoInicial(c);
    c->decorada = !semDecoracaoMotif(w);

    xcb_change_window_attributes(X, w, XCB_CW_EVENT_MASK, mascaraCliente);
    uint32_t sem = 0;
    xcb_configure_window(X, w, XCB_CONFIG_WINDOW_BORDER_WIDTH, &sem);

    if (c->decorada) {
        // moldura com o mesmo visual da janela (assim as apps transparentes continuam transparentes)
        c->moldura = xcb_generate_id(X);
        xcb_colormap_t mapa = xcb_generate_id(X);
        xcb_create_colormap(X, XCB_COLORMAP_ALLOC_NONE, mapa, R, visual);
        uint32_t mascara = XCB_CW_BACK_PIXEL | XCB_CW_BORDER_PIXEL | XCB_CW_EVENT_MASK | XCB_CW_COLORMAP;
        uint32_t valores[] = {pixel(COR_TITULO_INATIVO), 0,
                              XCB_EVENT_MASK_SUBSTRUCTURE_REDIRECT | XCB_EVENT_MASK_SUBSTRUCTURE_NOTIFY |
                              XCB_EVENT_MASK_BUTTON_PRESS | XCB_EVENT_MASK_BUTTON_RELEASE |
                              XCB_EVENT_MASK_POINTER_MOTION | XCB_EVENT_MASK_EXPOSURE |
                              XCB_EVENT_MASK_LEAVE_WINDOW,
                              mapa};
        xcb_create_window(X, c->profundidade, c->moldura, R, 0, 0, c->mw(), c->mh(), 0,
                          XCB_WINDOW_CLASS_INPUT_OUTPUT, visual, mascara, valores);
        xcb_free_colormap(X, mapa);
        if (jaMapeada) c->ignorarUnmap++;
        xcb_reparent_window(X, w, c->moldura, c->borda(), c->topo());
        xcb_change_save_set(X, XCB_SET_MODE_INSERT, w);
    } else {
        c->moldura = w;
    }
    agarrarBotoes(w);

    // onde pôr a janela
    Monitor &m = monitorDoRato();
    if (c->cheia) {
        c->x = m.geo.x; c->y = m.geo.y;
    } else if (posUsuario && (gx != 0 || gy != 0)) {
        c->x = gx; c->y = gy;
    } else {
        Cliente *pai = trans ? clienteDe(trans) : nullptr;
        if (pai) {
            c->x = pai->x + (pai->mw() - c->mw()) / 2;
            c->y = pai->y + (pai->mh() - c->mh()) / 3;
        } else {
            c->x = m.util.x + (m.util.w - c->mw()) / 2;
            c->y = m.util.y + (m.util.h - c->mh()) / 2;
        }
    }
    if (!c->cheia) {
        Monitor &mm = monitorEm(c->x + c->mw() / 2, c->y + c->mh() / 2);
        if (c->mw() > mm.util.w) c->w = std::max(c->minW, mm.util.w - 2 * c->borda());
        if (c->mh() > mm.util.h) c->h = std::max(c->minH, mm.util.h - c->topo() - c->borda());
        if (!(posUsuario && (gx != 0 || gy != 0))) {
            c->x = std::max(mm.util.x, std::min(c->x, mm.util.x + mm.util.w - c->mw()));
            c->y = std::max(mm.util.y, std::min(c->y, mm.util.y + mm.util.h - c->mh()));
        }
    }

    clientes.push_back(std::move(novo));
    pilha.push_back(c);
    recentes.push_back(c);

    bool queriaMax = c->maximizada;
    c->maximizada = false;
    aplicar(c);
    if (queriaMax) maximizar(c, true);
    definirU32(c->win, A[NET_WM_DESKTOP], XCB_ATOM_CARDINAL, {c->fixa ? 0xFFFFFFFFu : c->area});
    c->mapeada = false;
    if (visivel(c)) {
        xcb_map_window(X, c->win);
        if (c->comMoldura()) xcb_map_window(X, c->moldura);
        c->mapeada = true;
    }
    escreverEstado(c);
    levantar(c);
    if (visivel(c)) focar(c);
    desenhar(c);
}

static void largar(Cliente *c, bool destruida) {
    if (!c) return;
    if (c->sup) { cairo_surface_destroy(c->sup); c->sup = nullptr; }
    if (c->comMoldura()) {
        if (!destruida) {
            xcb_unmap_window(X, c->win);
            xcb_reparent_window(X, c->win, R, c->x + c->borda(), c->y + c->topo());
            xcb_change_save_set(X, XCB_SET_MODE_DELETE, c->win);
        }
        xcb_destroy_window(X, c->moldura);
    }
    if (!destruida) {
        uint32_t wmEstado[2] = {XCB_ICCCM_WM_STATE_WITHDRAWN, XCB_NONE};
        xcb_change_property(X, XCB_PROP_MODE_REPLACE, c->win, A[WM_STATE], A[WM_STATE], 32, 2, wmEstado);
        xcb_delete_property(X, c->win, A[NET_WM_DESKTOP]);
        xcb_delete_property(X, c->win, A[NET_WM_STATE]);
    }
    bool eraFocada = focada == c;
    if (eraFocada) focada = nullptr;
    pilha.erase(std::remove(pilha.begin(), pilha.end(), c), pilha.end());
    recentes.erase(std::remove(recentes.begin(), recentes.end(), c), recentes.end());
    escondidasPelaMesa.erase(std::remove(escondidasPelaMesa.begin(), escondidasPelaMesa.end(), c), escondidasPelaMesa.end());
    // os diálogos que dependiam desta janela voltam para o primeiro plano
    Cliente *pai = c->transitoria ? clienteDe(c->transitoria) : nullptr;
    clientes.erase(std::remove_if(clientes.begin(), clientes.end(),
                                  [c](const std::unique_ptr<Cliente> &p) { return p.get() == c; }),
                   clientes.end());
    atualizarListas();
    if (eraFocada) {
        if (pai && visivel(pai)) focar(pai);
        else focarOutra();
    }
}

static void largarOutra(xcb_window_t w) {
    auto tirar = [w](std::vector<xcb_window_t> &v) {
        auto it = std::find(v.begin(), v.end(), w);
        if (it == v.end()) return false;
        v.erase(it);
        return true;
    };
    if (tirar(docas)) {
        calcularUteis();
        for (auto &c : clientes)
            if (c->maximizada) { Monitor &m = monitorDe(c.get()); porNoRetangulo(c.get(), m.util); aplicar(c.get()); }
    }
    tirar(fundos);
    tirar(flutuantes);
}

// ---------------------------------------------------------------------------------------------
// arrastar (mover / redimensionar)
// ---------------------------------------------------------------------------------------------
enum { B_ESQ = 1, B_DIR = 2, B_CIMA = 4, B_BAIXO = 8 };
struct Arrasto {
    Cliente *c = nullptr;
    bool mover = false;
    int bordas = 0;
    int px = 0, py = 0, ox = 0, oy = 0, ow = 0, oh = 0;
    bool restaurouAoMover = false;
} arrasto;

static xcb_cursor_t cursor(const char *nome) {
    static std::map<std::string, xcb_cursor_t> cache;
    auto it = cache.find(nome);
    if (it != cache.end()) return it->second;
    xcb_cursor_t c = ctxCursor ? xcb_cursor_load_cursor(ctxCursor, nome) : XCB_NONE;
    cache[nome] = c;
    return c;
}

static const char *nomeCursor(int bordas) {
    switch (bordas) {
    case B_ESQ: return "left_side";
    case B_DIR: return "right_side";
    case B_CIMA: return "top_side";
    case B_BAIXO: return "bottom_side";
    case B_ESQ | B_CIMA: return "top_left_corner";
    case B_DIR | B_CIMA: return "top_right_corner";
    case B_ESQ | B_BAIXO: return "bottom_left_corner";
    case B_DIR | B_BAIXO: return "bottom_right_corner";
    }
    return "left_ptr";
}

static int bordasEm(Cliente *c, int lx, int ly) {
    if (!c->comMoldura() || c->maximizada || c->cheia || !c->decorada) return 0;
    int W = c->mw(), H = c->mh(), b = 0;
    bool naBorda = lx < BORDA || lx >= W - BORDA || ly < BORDA || ly >= H - BORDA;
    if (!naBorda) {
        // na barra de título, os cantos de cima também redimensionam
        if (ly < BORDA + 2 && (lx < CANTO || lx >= W - CANTO)) naBorda = true;
        else return 0;
    }
    if (lx < CANTO) b |= B_ESQ;
    else if (lx >= W - CANTO) b |= B_DIR;
    if (ly < CANTO) b |= B_CIMA;
    else if (ly >= H - CANTO) b |= B_BAIXO;
    // num lado comprido sem canto, só esse lado
    if (lx >= BORDA && lx < W - BORDA) b &= ~(B_ESQ | B_DIR);
    if (ly >= BORDA && ly < H - BORDA) b &= ~(B_CIMA | B_BAIXO);
    return b;
}

static int botaoEm(Cliente *c, int lx, int ly) {
    if (c->topo() == 0) return -1;
    for (int i = 0; i < 3; ++i) {
        if (!botaoExiste(i)) continue;
        int dx = lx - centroBotaoX(c, i), dy = ly - TITULO / 2;
        if (dx * dx + dy * dy <= 9 * 9) return i;
    }
    return -1;
}

static void comecarArrasto(Cliente *c, bool mover, int bordas, int px, int py) {
    arrasto = Arrasto{};
    arrasto.c = c;
    arrasto.mover = mover;
    arrasto.bordas = bordas;
    arrasto.px = px; arrasto.py = py;
    arrasto.ox = c->x; arrasto.oy = c->y; arrasto.ow = c->w; arrasto.oh = c->h;
    xcb_grab_pointer(X, 0, R, XCB_EVENT_MASK_BUTTON_RELEASE | XCB_EVENT_MASK_POINTER_MOTION,
                     XCB_GRAB_MODE_ASYNC, XCB_GRAB_MODE_ASYNC, XCB_NONE,
                     cursor(mover ? "fleur" : nomeCursor(bordas)), XCB_CURRENT_TIME);
}

static void moverArrasto(int px, int py) {
    Cliente *c = arrasto.c;
    if (!c) return;
    int dx = px - arrasto.px, dy = py - arrasto.py;
    if (arrasto.mover) {
        if ((c->maximizada || c->encaixe) && (std::abs(dx) > 8 || std::abs(dy) > 8)) {
            // ao arrastar uma janela maximizada, ela volta ao tamanho antigo debaixo do rato
            double prop = double(arrasto.px - c->x) / std::max(1, c->mw());
            c->maximizada = false;
            c->encaixe = 0;
            if (c->temReposicao) { c->w = c->rw; c->h = c->rh; }
            arrasto.ox = arrasto.px - int(prop * c->mw());
            arrasto.oy = c->y;
            arrasto.ow = c->w; arrasto.oh = c->h;
            escreverEstado(c);
        }
        if (c->maximizada || c->encaixe) return;
        c->x = arrasto.ox + dx;
        c->y = arrasto.oy + dy;
        // não deixa o título ir para debaixo da barra de cima
        Monitor &m = monitorEm(px, py);
        if (c->y < m.util.y && py >= m.util.y) c->y = m.util.y;
    } else {
        int x = arrasto.ox, y = arrasto.oy, w = arrasto.ow, h = arrasto.oh;
        if (arrasto.bordas & B_ESQ) { int nw = std::max(c->minW, w - dx); x += w - nw; w = nw; }
        if (arrasto.bordas & B_DIR) w = std::max(c->minW, w + dx);
        if (arrasto.bordas & B_CIMA) { int nh = std::max(c->minH, h - dy); y += h - nh; h = nh; }
        if (arrasto.bordas & B_BAIXO) h = std::max(c->minH, h + dy);
        c->x = x; c->y = y; c->w = std::max(60, w); c->h = std::max(30, h);
    }
    aplicar(c);
}

// há outro monitor do outro lado desta borda? (então não é borda para encaixar)
static bool haVizinho(int px, int py) {
    for (Monitor &m : monitores)
        if (m.geo.contem(px, py)) return true;
    return false;
}

static void acabarArrasto(int px, int py) {
    Cliente *c = arrasto.c;
    xcb_ungrab_pointer(X, XCB_CURRENT_TIME);
    arrasto = Arrasto{};
    if (!c || clienteDe(c->win) != c) return;
    if (c->tipo == T_UTILITARIO) return;
    // encaixar ao largar nas bordas do ecrã (como no KWin)
    Monitor &m = monitorEm(px, py);
    const Ret &g = m.geo;
    if (py <= g.y + 1 && !haVizinho(px, g.y - 2)) {
        c->rx = c->x; c->ry = std::max(m.util.y, c->y); c->rw = c->w; c->rh = c->h; c->temReposicao = true;
        maximizar(c, true);
    } else if (px <= g.x + 1 && !haVizinho(g.x - 2, py)) {
        c->rx = c->x; c->ry = c->y; c->rw = c->w; c->rh = c->h; c->temReposicao = true;
        encaixar(c, 1, &m);
    } else if (px >= g.x + g.w - 2 && !haVizinho(g.x + g.w + 1, py)) {
        c->rx = c->x; c->ry = c->y; c->rw = c->w; c->rh = c->h; c->temReposicao = true;
        encaixar(c, 2, &m);
    }
}

// ---------------------------------------------------------------------------------------------
// atalhos de teclado (~/.config/carinaeos/atalhos.conf)
// ---------------------------------------------------------------------------------------------
struct Atalho { uint16_t mods; xcb_keysym_t tecla; std::string acao; };
static std::vector<Atalho> atalhos;
static std::string acaoSuper;        // tocar só na tecla Super (sem outra tecla)
static const uint16_t MODS = XCB_MOD_MASK_SHIFT | XCB_MOD_MASK_CONTROL | XCB_MOD_MASK_1 | XCB_MOD_MASK_4;

static std::string aparar(const std::string &s) {
    size_t a = s.find_first_not_of(" \t\r\n"), b = s.find_last_not_of(" \t\r\n");
    return a == std::string::npos ? "" : s.substr(a, b - a + 1);
}
static std::string minusculas(std::string s) {
    for (char &ch : s) ch = tolower((unsigned char)ch);
    return s;
}

static xcb_keysym_t teclaDeNome(const std::string &n) {
    static const std::map<std::string, xcb_keysym_t> tabela = {
        {"return", XK_Return}, {"enter", XK_Return}, {"tab", XK_Tab}, {"escape", XK_Escape}, {"esc", XK_Escape},
        {"space", XK_space}, {"espaco", XK_space}, {"espaço", XK_space}, {"backspace", XK_BackSpace},
        {"delete", XK_Delete}, {"del", XK_Delete}, {"insert", XK_Insert}, {"home", XK_Home}, {"end", XK_End},
        {"pgup", XK_Page_Up}, {"pageup", XK_Page_Up}, {"pgdown", XK_Page_Down}, {"pagedown", XK_Page_Down},
        {"left", XK_Left}, {"right", XK_Right}, {"up", XK_Up}, {"down", XK_Down},
        {"print", XK_Print}, {"grave", XK_grave}, {"`", XK_grave}, {"minus", XK_minus}, {"equal", XK_equal},
        {"plus", XK_plus}, {"comma", XK_comma}, {"period", XK_period}, {"slash", XK_slash},
        {"volumeup", XF86XK_AudioRaiseVolume}, {"volumedown", XF86XK_AudioLowerVolume},
        {"mute", XF86XK_AudioMute}, {"micmute", XF86XK_AudioMicMute}, {"play", XF86XK_AudioPlay},
        {"next", XF86XK_AudioNext}, {"prev", XF86XK_AudioPrev}, {"stop", XF86XK_AudioStop},
        {"brightnessup", XF86XK_MonBrightnessUp}, {"brightnessdown", XF86XK_MonBrightnessDown},
        {"calculator", XF86XK_Calculator}, {"mail", XF86XK_Mail}, {"www", XF86XK_WWW},
        {"explorer", XF86XK_Explorer}, {"search", XF86XK_Search},
        {"poweroff", XF86XK_PowerOff}, {"power", XF86XK_PowerOff}, {"sleep", XF86XK_Sleep},
        {"suspend", XF86XK_Suspend},
    };
    std::string m = minusculas(n);
    auto it = tabela.find(m);
    if (it != tabela.end()) return it->second;
    if (m.size() == 1 && ((m[0] >= 'a' && m[0] <= 'z') || (m[0] >= '0' && m[0] <= '9'))) return xcb_keysym_t(m[0]);
    if (m.size() >= 2 && m[0] == 'f') {
        int n2 = atoi(m.c_str() + 1);
        if (n2 >= 1 && n2 <= 24) return XK_F1 + n2 - 1;
    }
    return 0;
}

static const char *ATALHOS_PADRAO =
    "Super = @lancador\n"
    "Alt+F1 = @lancador\n"
    "Alt+Tab = @alternar\n"
    "Alt+Shift+Tab = @alternar-inverso\n"
    "Alt+F4 = @fechar\n"
    "Super+Up = @maximizar\n"
    "Super+PgUp = @maximizar\n"
    "Super+Down = @repor-ou-minimizar\n"
    "Super+PgDown = @minimizar\n"
    "Super+Left = @esquerda\n"
    "Super+Right = @direita\n"
    "Super+Alt+1 = @zona 1\n"
    "Super+Alt+2 = @zona 2\n"
    "Super+Alt+3 = @zona 3\n"
    "Super+F = @tela-cheia\n"
    "Super+D = @mostrar-mesa\n"
    "Super+Ctrl+Left = @area-anterior\n"
    "Super+Ctrl+Right = @area-seguinte\n"
    "Super+Ctrl+Shift+Left = @levar-area-anterior\n"
    "Super+Ctrl+Shift+Right = @levar-area-seguinte\n"
    "Super+Ctrl+Escape = xkill\n"
    "Super+L = carinae-sessao bloquear\n"
    "Super+E = xdg-open \"$HOME\"\n"
    "Super+Return = x-terminal-emulator\n"
    "Ctrl+Alt+T = x-terminal-emulator\n"
    "Ctrl+Space = carinaeos-comando\n"
    "Print = carinae-captura regiao\n"
    "Shift+Print = carinae-captura\n"
    "Alt+Print = carinae-captura janela\n"
    "Calculator = carinaeos-calculadora\n"
    "Super+period = carinaeos-emojis\n"
    "VolumeUp = wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+\n"
    "VolumeDown = wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-\n"
    "Mute = wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle\n"
    "MicMute = wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle\n"
    "Play = playerctl play-pause\n"
    "Next = playerctl next\n"
    "Prev = playerctl previous\n"
    "PowerOff = carinae-energia --botao\n"
    "Sleep = carinae-sessao suspender\n"
    "Super+1 = @tarefa 1\nSuper+2 = @tarefa 2\nSuper+3 = @tarefa 3\nSuper+4 = @tarefa 4\nSuper+5 = @tarefa 5\n"
    "Super+6 = @tarefa 6\nSuper+7 = @tarefa 7\nSuper+8 = @tarefa 8\nSuper+9 = @tarefa 9\n";

static void lerAtalhos() {
    atalhos.clear();
    acaoSuper.clear();
    std::string texto;
    const char *home = getenv("HOME");
    std::vector<std::string> caminhos = {
        std::string(home ? home : "") + "/.config/carinaeos/atalhos.conf",
        "/usr/local/share/carinaeos/atalhos.conf",
        "/usr/share/carinaeos/atalhos.conf",
    };
    for (const std::string &c : caminhos) {
        std::ifstream f(c);
        if (f) { std::stringstream ss; ss << f.rdbuf(); texto = ss.str(); break; }
    }
    if (texto.empty()) texto = ATALHOS_PADRAO;
    std::istringstream in(texto);
    std::string linha;
    while (std::getline(in, linha)) {
        linha = aparar(linha);
        if (linha.empty() || linha[0] == '#') continue;
        size_t eq = linha.find('=');
        if (eq == std::string::npos) continue;
        std::string comb = aparar(linha.substr(0, eq)), acao = aparar(linha.substr(eq + 1));
        uint16_t mods = 0;
        xcb_keysym_t tecla = 0;
        bool soSuper = false;
        std::stringstream partes(comb);
        std::string p;
        std::vector<std::string> ps;
        while (std::getline(partes, p, '+')) ps.push_back(aparar(p));
        if (ps.empty()) continue;
        for (size_t i = 0; i < ps.size(); ++i) {
            std::string m = minusculas(ps[i]);
            bool ultimo = i + 1 == ps.size();
            if (m == "super" || m == "meta" || m == "win" || m == "mod4") {
                if (ultimo) soSuper = true; else mods |= XCB_MOD_MASK_4;
            } else if (m == "alt" || m == "mod1") mods |= XCB_MOD_MASK_1;
            else if (m == "ctrl" || m == "control") mods |= XCB_MOD_MASK_CONTROL;
            else if (m == "shift") mods |= XCB_MOD_MASK_SHIFT;
            else if (ultimo) tecla = teclaDeNome(ps[i]);
        }
        if (soSuper && mods == 0) { acaoSuper = acao; continue; }
        if (!tecla) { fprintf(stderr, "gravidade: atalho que não percebo: %s\n", comb.c_str()); continue; }
        atalhos.push_back({mods, tecla, acao});
    }
}

static void agarrarTeclas() {
    xcb_ungrab_key(X, XCB_GRAB_ANY, R, XCB_MOD_MASK_ANY);
    if (teclas) xcb_key_symbols_free(teclas);
    teclas = xcb_key_symbols_alloc(X);
    const uint16_t trancas[] = {0, XCB_MOD_MASK_LOCK, XCB_MOD_MASK_2, XCB_MOD_MASK_LOCK | XCB_MOD_MASK_2};
    auto agarrar = [&](xcb_keysym_t ks, uint16_t mods) {
        xcb_keycode_t *kc = xcb_key_symbols_get_keycode(teclas, ks);
        if (!kc) return;
        for (xcb_keycode_t *k = kc; *k; ++k)
            for (uint16_t t : trancas)
                xcb_grab_key(X, 1, R, mods | t, *k, XCB_GRAB_MODE_ASYNC, XCB_GRAB_MODE_ASYNC);
        free(kc);
    };
    for (const Atalho &a : atalhos) agarrar(a.tecla, a.mods);
    if (!acaoSuper.empty()) {
        agarrar(XK_Super_L, 0);
        agarrar(XK_Super_R, 0);
    }
}

// Alt+Tab
static bool alternando = false;
static size_t alternarIndice = 0;
static Cliente *alternarInicio = nullptr;

static std::vector<Cliente *> paraAlternar() {
    std::vector<Cliente *> v;
    for (Cliente *c : recentes)
        if ((c->fixa || c->area == areaAtual) && !c->saltarTarefas && c->tipo != T_UTILITARIO) v.push_back(c);
    return v;
}

static void alternar(int passo) {
    std::vector<Cliente *> v = paraAlternar();
    if (v.empty()) return;
    if (!alternando) {
        alternando = true;
        alternarInicio = focada;
        alternarIndice = 0;
        xcb_grab_keyboard(X, 0, R, XCB_CURRENT_TIME, XCB_GRAB_MODE_ASYNC, XCB_GRAB_MODE_ASYNC);
    }
    alternarIndice = (alternarIndice + v.size() + passo) % v.size();
    Cliente *c = v[alternarIndice];
    // durante o Alt+Tab só se mostra; a lista dos recentes só muda no fim
    if (c->minimizada) { c->minimizada = false; atualizarVisibilidade(c); }
    pilha.erase(std::remove(pilha.begin(), pilha.end(), c), pilha.end());
    pilha.push_back(c);
    reempilhar();
    Cliente *antes = focada;
    focada = c;
    if (c->aceitaFoco) xcb_set_input_focus(X, XCB_INPUT_FOCUS_POINTER_ROOT, c->win, ultimoTempo);
    if (antes) desenhar(antes);
    desenhar(c);
}

static void acabarAlternar(bool cancelar) {
    if (!alternando) return;
    alternando = false;
    xcb_ungrab_keyboard(X, XCB_CURRENT_TIME);
    Cliente *c = focada;
    if (cancelar && alternarInicio && clienteDe(alternarInicio->win)) c = alternarInicio;
    if (c) ativar(c);
}

static void acao(const std::string &a);

static Cliente *alvo() { return focada; }

static void acao(const std::string &a) {
    if (a.empty()) return;
    if (a[0] != '@') { executar(a); return; }
    std::string nome = a, arg;
    size_t sp = a.find(' ');
    if (sp != std::string::npos) { nome = a.substr(0, sp); arg = aparar(a.substr(sp + 1)); }
    Cliente *c = alvo();
    if (nome == "@lancador") executar("aurora --enviar lancador || carinae-shell --enviar lancador");
    else if (nome == "@tarefa") executar("aurora --enviar 'tarefa " + arg + "'");
    else if (nome == "@alternar") alternar(1);
    else if (nome == "@alternar-inverso") alternar(-1);
    else if (nome == "@fechar") fechar(c);
    else if (nome == "@maximizar") { if (c) maximizar(c, !c->maximizada); }
    else if (nome == "@minimizar") { if (c) minimizar(c); }
    else if (nome == "@repor-ou-minimizar") {
        if (c) { if (c->maximizada || c->encaixe) repor(c); else minimizar(c); }
    }
    else if (nome == "@esquerda") encaixar(c, 1);
    else if (nome == "@direita") encaixar(c, 2);
    else if (nome == "@zona") { int z = atoi(arg.c_str()); if (z >= 1 && z <= 3) encaixar(c, 10 + z); }
    else if (nome == "@tela-cheia") { if (c) telaCheia(c, !c->cheia); }
    else if (nome == "@mostrar-mesa") mostrarMesa();
    else if (nome == "@area") mudarArea(uint32_t(std::max(1, atoi(arg.c_str())) - 1));
    else if (nome == "@area-anterior") mudarArea((areaAtual + NAREAS - 1) % NAREAS);
    else if (nome == "@area-seguinte") mudarArea((areaAtual + 1) % NAREAS);
    else if (nome == "@levar-area-anterior") { if (c) { uint32_t n = (areaAtual + NAREAS - 1) % NAREAS; moverParaArea(c, n); mudarArea(n); ativar(c); } }
    else if (nome == "@levar-area-seguinte") { if (c) { uint32_t n = (areaAtual + 1) % NAREAS; moverParaArea(c, n); mudarArea(n); ativar(c); } }
    else if (nome == "@recarregar") { lerAtalhos(); lerGravidadeConf(); agarrarTeclas(); for (Cliente *x : pilha) desenhar(x); }
    else if (nome == "@sair") exit(0);
    else fprintf(stderr, "gravidade: ação desconhecida %s\n", a.c_str());
}

// ---------------------------------------------------------------------------------------------
// eventos
// ---------------------------------------------------------------------------------------------
static bool superSozinho = false;
static long superQuando = 0;
static long ultimoCliqueTitulo = 0;
static xcb_window_t ultimoCliqueJanela = 0;
static volatile sig_atomic_t pedidoRecarregar = 0, pedidoSair = 0;

static void naTecla(xcb_key_press_event_t *e, bool premida) {
    ultimoTempo = e->time;
    xcb_keysym_t ks = xcb_key_symbols_get_keysym(teclas, e->detail, 0);
    if (ks == XK_Super_L || ks == XK_Super_R) {
        if (premida) { superSozinho = true; superQuando = agoraMs(); }
        else if (superSozinho && agoraMs() - superQuando < 700) { superSozinho = false; acao(acaoSuper); }
        return;
    }
    if (premida) superSozinho = false;
    if (alternando) {
        if (!premida && (ks == XK_Alt_L || ks == XK_Alt_R)) { acabarAlternar(false); return; }
        if (premida && ks == XK_Escape) { acabarAlternar(true); return; }
        if (premida && (ks == XK_Tab || ks == XK_ISO_Left_Tab)) { alternar((e->state & XCB_MOD_MASK_SHIFT) ? -1 : 1); return; }
        return;
    }
    if (!premida) return;
    uint16_t mods = e->state & MODS;
    for (const Atalho &a : atalhos)
        if (a.tecla == ks && a.mods == mods) { acao(a.acao); return; }
}

static void naMensagem(xcb_client_message_event_t *e) {
    Cliente *c = clienteDe(e->window);
    uint32_t *d = e->data.data32;
    if (e->type == A[NET_ACTIVE_WINDOW]) {
        if (c) ativar(c);
    } else if (e->type == A[NET_CLOSE_WINDOW]) {
        if (c) fechar(c);
    } else if (e->type == A[WM_CHANGE_STATE]) {
        if (c && d[0] == XCB_ICCCM_WM_STATE_ICONIC) minimizar(c);
    } else if (e->type == A[NET_CURRENT_DESKTOP]) {
        mudarArea(d[0]);
    } else if (e->type == A[NET_WM_DESKTOP]) {
        if (c) {
            if (d[0] == 0xFFFFFFFFu) { c->fixa = true; atualizarVisibilidade(c); }
            else { c->fixa = false; moverParaArea(c, d[0]); }
        }
    } else if (e->type == A[NET_SHOWING_DESKTOP]) {
        if (bool(d[0]) != mesaMostrada) mostrarMesa();
    } else if (e->type == A[NET_REQUEST_FRAME_EXTENTS]) {
        definirU32(e->window, A[NET_FRAME_EXTENTS], XCB_ATOM_CARDINAL,
                   {uint32_t(BORDA), uint32_t(BORDA), uint32_t(TITULO), uint32_t(BORDA)});
    } else if (e->type == A[NET_WM_STATE] && c) {
        for (int i = 1; i <= 2; ++i) {
            xcb_atom_t at = d[i];
            if (!at) continue;
            auto quer = [&](bool atual) { return d[0] == 1 ? true : d[0] == 0 ? false : !atual; };
            if (at == A[NET_WM_STATE_FULLSCREEN]) telaCheia(c, quer(c->cheia));
            else if (at == A[NET_WM_STATE_MAXIMIZED_VERT] || at == A[NET_WM_STATE_MAXIMIZED_HORZ]) {
                bool q = quer(c->maximizada);
                if (q != c->maximizada) maximizar(c, q);
                if (i == 1 && (d[2] == A[NET_WM_STATE_MAXIMIZED_VERT] || d[2] == A[NET_WM_STATE_MAXIMIZED_HORZ])) break;
            } else if (at == A[NET_WM_STATE_HIDDEN]) { if (quer(c->minimizada)) minimizar(c); else ativar(c); }
            else if (at == A[NET_WM_STATE_ABOVE]) { c->acima = quer(c->acima); reempilhar(); }
            else if (at == A[NET_WM_STATE_BELOW]) { c->abaixo = quer(c->abaixo); reempilhar(); }
            else if (at == A[NET_WM_STATE_STICKY]) { c->fixa = quer(c->fixa); atualizarVisibilidade(c); }
            else if (at == A[NET_WM_STATE_SKIP_TASKBAR]) c->saltarTarefas = quer(c->saltarTarefas);
            else if (at == A[NET_WM_STATE_SKIP_PAGER]) c->saltarPager = quer(c->saltarPager);
            else if (at == A[NET_WM_STATE_DEMANDS_ATTENTION]) c->atencao = quer(c->atencao);
        }
        escreverEstado(c);
    } else if (e->type == A[NET_WM_MOVERESIZE] && c) {
        int dir = d[2];
        if (dir == 11) { if (arrasto.c) acabarArrasto(d[0], d[1]); return; }
        if (dir > 8) return;
        if (dir == 8) { comecarArrasto(c, true, 0, d[0], d[1]); return; }
        static const int mapa[8] = {B_ESQ | B_CIMA, B_CIMA, B_DIR | B_CIMA, B_DIR, B_DIR | B_BAIXO, B_BAIXO, B_ESQ | B_BAIXO, B_ESQ};
        if (c->maximizada || c->encaixe) { c->maximizada = false; c->encaixe = 0; escreverEstado(c); }
        comecarArrasto(c, false, mapa[dir], d[0], d[1]);
    } else if (e->type == A[NET_MOVERESIZE_WINDOW] && c) {
        uint32_t fl = d[0];
        if (fl & (1 << 8)) c->x = int32_t(d[1]);
        if (fl & (1 << 9)) c->y = int32_t(d[2]);
        if (fl & (1 << 10)) c->w = d[3];
        if (fl & (1 << 11)) c->h = d[4];
        aplicar(c);
    }
}

static void noPedidoConfigurar(xcb_configure_request_event_t *e) {
    Cliente *c = clienteDe(e->window);
    if (!c || c->win != e->window) {
        // janelas que não gerimos (docas, fundos...): faz o que pedem
        uint32_t v[7];
        int i = 0;
        uint16_t m = 0;
        if (e->value_mask & XCB_CONFIG_WINDOW_X) { m |= XCB_CONFIG_WINDOW_X; v[i++] = e->x; }
        if (e->value_mask & XCB_CONFIG_WINDOW_Y) { m |= XCB_CONFIG_WINDOW_Y; v[i++] = e->y; }
        if (e->value_mask & XCB_CONFIG_WINDOW_WIDTH) { m |= XCB_CONFIG_WINDOW_WIDTH; v[i++] = e->width; }
        if (e->value_mask & XCB_CONFIG_WINDOW_HEIGHT) { m |= XCB_CONFIG_WINDOW_HEIGHT; v[i++] = e->height; }
        if (e->value_mask & XCB_CONFIG_WINDOW_BORDER_WIDTH) { m |= XCB_CONFIG_WINDOW_BORDER_WIDTH; v[i++] = e->border_width; }
        xcb_configure_window(X, e->window, m, v);
        if (std::find(docas.begin(), docas.end(), e->window) != docas.end()) {
            xcb_flush(X);
            calcularUteis();
            for (auto &cc : clientes)
                if (cc->maximizada) { Monitor &mm = monitorDe(cc.get()); porNoRetangulo(cc.get(), mm.util); aplicar(cc.get()); }
        }
        return;
    }
    if (c->cheia || c->maximizada || c->encaixe) {
        enviarConfigure(c, c->x + c->borda(), c->y + c->topo(), c->w, c->h);
        return;
    }
    if (e->value_mask & XCB_CONFIG_WINDOW_X) c->x = e->x;
    if (e->value_mask & XCB_CONFIG_WINDOW_Y) c->y = e->y;
    if (e->value_mask & XCB_CONFIG_WINDOW_WIDTH) c->w = e->width;
    if (e->value_mask & XCB_CONFIG_WINDOW_HEIGHT) c->h = e->height;
    aplicar(c);
}

static void noBotao(xcb_button_press_event_t *e) {
    ultimoTempo = e->time;
    superSozinho = false;
    Cliente *c = clienteDe(e->event);
    if (!c) return;
    if (e->event == c->win) {
        // clique dentro da app: foco, e o clique segue para a app
        xcb_allow_events(X, XCB_ALLOW_REPLAY_POINTER, e->time);
        if (focada != c) { levantar(c); focar(c); }
        else if (pilha.empty() || pilha.back() != c) levantar(c);
        // Alt+arrastar move, Alt+botão direito redimensiona
        if (e->state & XCB_MOD_MASK_1) {
            if (e->detail == 1) comecarArrasto(c, true, 0, e->root_x, e->root_y);
            else if (e->detail == 3) {
                int lx = e->root_x - c->x, ly = e->root_y - c->y;
                int b = (lx < c->mw() / 2 ? B_ESQ : B_DIR) | (ly < c->mh() / 2 ? B_CIMA : B_BAIXO);
                comecarArrasto(c, false, b, e->root_x, e->root_y);
            }
        }
        return;
    }
    // na moldura
    if (focada != c) { levantar(c); focar(c); }
    else levantar(c);
    int lx = e->event_x, ly = e->event_y;
    if (e->detail == 1) {
        int b = bordasEm(c, lx, ly);
        if (b) { comecarArrasto(c, false, b, e->root_x, e->root_y); return; }
        int bt = botaoEm(c, lx, ly);
        if (bt >= 0) { c->premido = bt; desenhar(c); return; }
        if (ly < c->topo()) {
            long agora = agoraMs();
            if (ultimoCliqueJanela == c->win && agora - ultimoCliqueTitulo < 400) {
                ultimoCliqueTitulo = 0;
                maximizar(c, !c->maximizada);
                return;
            }
            ultimoCliqueTitulo = agora;
            ultimoCliqueJanela = c->win;
            comecarArrasto(c, true, 0, e->root_x, e->root_y);
        }
    } else if (e->detail == 2 && ly < c->topo()) {
        // botão do meio no título: manda para trás
        pilha.erase(std::remove(pilha.begin(), pilha.end(), c), pilha.end());
        pilha.insert(pilha.begin(), c);
        reempilhar();
        focarOutra();
    }
}

static void noSoltar(xcb_button_release_event_t *e) {
    ultimoTempo = e->time;
    if (arrasto.c) { acabarArrasto(e->root_x, e->root_y); return; }
    Cliente *c = clienteDe(e->event);
    if (!c || c->premido < 0) return;
    int bt = botaoEm(c, e->event_x, e->event_y), p = c->premido;
    c->premido = -1;
    desenhar(c);
    if (bt != p) return;
    if (p == 0) fechar(c);
    else if (p == 1) minimizar(c);
    else if (p == 2) {
        // botão verde: ecrã inteiro com Shift, senão maximizar
        if (e->state & XCB_MOD_MASK_SHIFT) telaCheia(c, true);
        else maximizar(c, !c->maximizada);
    }
}

static void noMovimento(xcb_motion_notify_event_t *e) {
    if (arrasto.c) { moverArrasto(e->root_x, e->root_y); return; }
    Cliente *c = clienteDe(e->event);
    if (!c || e->event != c->moldura || !c->comMoldura()) return;
    int b = bordasEm(c, e->event_x, e->event_y);
    xcb_cursor_t cur = cursor(nomeCursor(b));
    if (cur != c->cursorAtual) {
        c->cursorAtual = cur;
        xcb_change_window_attributes(X, c->moldura, XCB_CW_CURSOR, &cur);
    }
    const bool zona = e->event_y < c->topo() && naZonaBotoes(c, e->event_x);
    int hv = zona ? botaoEm(c, e->event_x, e->event_y) : -1;
    if (zona) hv = std::max(hv, 3);
    if ((hv >= 0) != (c->hover >= 0)) { c->hover = hv; desenhar(c); }
    else c->hover = hv;
}

static void naPropriedade(xcb_property_notify_event_t *e) {
    if (std::find(docas.begin(), docas.end(), e->window) != docas.end()) {
        if (e->atom == A[NET_WM_STRUT] || e->atom == A[NET_WM_STRUT_PARTIAL]) {
            calcularUteis();
            for (auto &c : clientes)
                if (c->maximizada) { Monitor &m = monitorDe(c.get()); porNoRetangulo(c.get(), m.util); aplicar(c.get()); }
        }
        return;
    }
    Cliente *c = clienteDe(e->window);
    if (!c || c->win != e->window) return;
    if (e->atom == A[NET_WM_NAME] || e->atom == XCB_ATOM_WM_NAME) { lerTitulo(c); desenhar(c); }
    else if (e->atom == A[WM_PROTOCOLS] || e->atom == XCB_ATOM_WM_HINTS) lerProtocolos(c);
    else if (e->atom == XCB_ATOM_WM_NORMAL_HINTS) lerTamanhos(c, nullptr);
    else if (e->atom == A[MOTIF_WM_HINTS] && c->comMoldura()) {
        bool d = !semDecoracaoMotif(c->win);
        if (d != c->decorada) { c->decorada = d; aplicar(c); }
    }
}

static void tratar(xcb_generic_event_t *ev) {
    uint8_t tipo = ev->response_type & ~0x80;
    if (randrEvento && tipo == randrEvento + XCB_RANDR_SCREEN_CHANGE_NOTIFY) {
        lerMonitores();
        for (auto &c : clientes) {
            Monitor &m = monitorDe(c.get());
            if (c->cheia || c->maximizada) { if (c->maximizada) porNoRetangulo(c.get(), m.util); aplicar(c.get()); }
            else if (!m.geo.cruza({c->x, c->y, c->mw(), c->mh()})) { c->x = m.util.x + 40; c->y = m.util.y + 40; aplicar(c.get()); }
        }
        return;
    }
    switch (tipo) {
    case 0: {
        xcb_generic_error_t *er = (xcb_generic_error_t *)ev;
        // BadWindow de janelas que já fecharam: normal
        if (er->error_code != XCB_WINDOW && er->error_code != XCB_MATCH && er->error_code != XCB_DRAWABLE)
            fprintf(stderr, "gravidade: erro X %d (pedido %d)\n", er->error_code, er->major_code);
        break;
    }
    case XCB_MAP_REQUEST:
        gerir(((xcb_map_request_event_t *)ev)->window, false);
        break;
    case XCB_UNMAP_NOTIFY: {
        auto *e = (xcb_unmap_notify_event_t *)ev;
        if (e->event == e->window) break;          // a cópia que vem da própria janela
        Cliente *c = clienteDe(e->window);
        if (c && c->win == e->window) {
            if (c->ignorarUnmap > 0) { c->ignorarUnmap--; break; }
            largar(c, false);
        } else if (!c) {
            largarOutra(e->window);
            reempilhar();
        }
        break;
    }
    case XCB_DESTROY_NOTIFY: {
        auto *e = (xcb_destroy_notify_event_t *)ev;
        Cliente *c = clienteDe(e->window);
        if (c && c->win == e->window) largar(c, true);
        else if (!c) largarOutra(e->window);
        break;
    }
    case XCB_CONFIGURE_REQUEST:
        noPedidoConfigurar((xcb_configure_request_event_t *)ev);
        break;
    case XCB_CLIENT_MESSAGE:
        naMensagem((xcb_client_message_event_t *)ev);
        break;
    case XCB_PROPERTY_NOTIFY:
        naPropriedade((xcb_property_notify_event_t *)ev);
        break;
    case XCB_BUTTON_PRESS:
        noBotao((xcb_button_press_event_t *)ev);
        break;
    case XCB_BUTTON_RELEASE:
        noSoltar((xcb_button_release_event_t *)ev);
        break;
    case XCB_MOTION_NOTIFY:
        noMovimento((xcb_motion_notify_event_t *)ev);
        break;
    case XCB_LEAVE_NOTIFY: {
        auto *e = (xcb_leave_notify_event_t *)ev;
        Cliente *c = clienteDe(e->event);
        if (c && c->hover >= 0) { c->hover = -1; c->premido = -1; desenhar(c); }
        break;
    }
    case XCB_EXPOSE: {
        auto *e = (xcb_expose_event_t *)ev;
        if (e->count == 0) { Cliente *c = clienteDe(e->window); if (c) desenhar(c); }
        break;
    }
    case XCB_KEY_PRESS:
        naTecla((xcb_key_press_event_t *)ev, true);
        break;
    case XCB_KEY_RELEASE:
        naTecla((xcb_key_press_event_t *)ev, false);
        break;
    case XCB_MAPPING_NOTIFY: {
        auto *e = (xcb_mapping_notify_event_t *)ev;
        if (e->request == XCB_MAPPING_KEYBOARD || e->request == XCB_MAPPING_MODIFIER) agarrarTeclas();
        break;
    }
    case XCB_SELECTION_CLEAR: {
        auto *e = (xcb_selection_clear_event_t *)ev;
        if (e->selection == A[WM_S0]) {
            fprintf(stderr, "gravidade: outro gestor de janelas tomou o lugar; a sair.\n");
            pedidoSair = 1;
        }
        break;
    }
    }
}

// ---------------------------------------------------------------------------------------------
// arranque
// ---------------------------------------------------------------------------------------------
static void anunciar() {
    std::vector<uint32_t> sup;
    for (int i = NET_SUPPORTED; i <= NET_SHOWING_DESKTOP; ++i) sup.push_back(A[i]);
    definirU32(R, A[NET_SUPPORTED], XCB_ATOM_ATOM, sup);
    definirU32(R, A[NET_SUPPORTING_WM_CHECK], XCB_ATOM_WINDOW, {verificacao});
    definirU32(verificacao, A[NET_SUPPORTING_WM_CHECK], XCB_ATOM_WINDOW, {verificacao});
    const char *nome = "Gravidade";
    xcb_change_property(X, XCB_PROP_MODE_REPLACE, verificacao, A[NET_WM_NAME], A[UTF8_STRING], 8, strlen(nome), nome);
    definirU32(R, A[NET_NUMBER_OF_DESKTOPS], XCB_ATOM_CARDINAL, {uint32_t(NAREAS)});
    std::vector<uint32_t> atual = propU32(R, A[NET_CURRENT_DESKTOP], XCB_ATOM_CARDINAL);
    areaAtual = (!atual.empty() && atual[0] < NAREAS) ? atual[0] : 0;
    definirU32(R, A[NET_CURRENT_DESKTOP], XCB_ATOM_CARDINAL, {areaAtual});
    std::string nomes;
    for (int i = 0; i < NAREAS; ++i) { nomes += "Área " + std::to_string(i + 1); nomes.push_back('\0'); }
    xcb_change_property(X, XCB_PROP_MODE_REPLACE, R, A[NET_DESKTOP_NAMES], A[UTF8_STRING], 8, nomes.size(), nomes.data());
    definirU32(R, A[NET_SHOWING_DESKTOP], XCB_ATOM_CARDINAL, {0});
}

static bool tomarLugar(bool substituir) {
    verificacao = xcb_generate_id(X);
    uint32_t vals[] = {1, XCB_EVENT_MASK_PROPERTY_CHANGE};
    xcb_create_window(X, XCB_COPY_FROM_PARENT, verificacao, R, -10, -10, 1, 1, 0, XCB_WINDOW_CLASS_INPUT_ONLY,
                      XCB_COPY_FROM_PARENT, XCB_CW_OVERRIDE_REDIRECT | XCB_CW_EVENT_MASK, vals);
    xcb_get_selection_owner_reply_t *dono =
        xcb_get_selection_owner_reply(X, xcb_get_selection_owner(X, A[WM_S0]), nullptr);
    xcb_window_t antigo = dono ? dono->owner : XCB_NONE;
    free(dono);
    if (antigo != XCB_NONE && !substituir) {
        fprintf(stderr, "gravidade: já há um gestor de janelas. Usa --substituir para tomar o lugar dele.\n");
        return false;
    }
    if (antigo != XCB_NONE) {
        uint32_t m = XCB_EVENT_MASK_STRUCTURE_NOTIFY;
        xcb_change_window_attributes(X, antigo, XCB_CW_EVENT_MASK, &m);
    }
    xcb_set_selection_owner(X, verificacao, A[WM_S0], XCB_CURRENT_TIME);
    xcb_flush(X);
    if (antigo != XCB_NONE) {
        // espera até 5 s que o antigo saia
        long fim = agoraMs() + 5000;
        bool saiu = false;
        while (!saiu && agoraMs() < fim) {
            xcb_generic_event_t *ev;
            while ((ev = xcb_poll_for_event(X))) {
                if ((ev->response_type & ~0x80) == XCB_DESTROY_NOTIFY &&
                    ((xcb_destroy_notify_event_t *)ev)->window == antigo)
                    saiu = true;
                free(ev);
            }
            if (!saiu) usleep(20000);
        }
        if (!saiu) fprintf(stderr, "gravidade: o gestor antigo não saiu a tempo; vou tentar na mesma.\n");
    }
    // avisa que há um novo dono (ICCCM)
    xcb_client_message_event_t ev = {};
    ev.response_type = XCB_CLIENT_MESSAGE;
    ev.format = 32;
    ev.window = R;
    ev.type = A[MANAGER];
    ev.data.data32[0] = XCB_CURRENT_TIME;
    ev.data.data32[1] = A[WM_S0];
    ev.data.data32[2] = verificacao;
    xcb_send_event(X, 0, R, XCB_EVENT_MASK_STRUCTURE_NOTIFY, (const char *)&ev);

    for (int tentativa = 0; tentativa < 20; ++tentativa) {
        uint32_t mascara = XCB_EVENT_MASK_SUBSTRUCTURE_REDIRECT | XCB_EVENT_MASK_SUBSTRUCTURE_NOTIFY |
                           XCB_EVENT_MASK_PROPERTY_CHANGE | XCB_EVENT_MASK_STRUCTURE_NOTIFY;
        xcb_generic_error_t *er =
            xcb_request_check(X, xcb_change_window_attributes_checked(X, R, XCB_CW_EVENT_MASK, &mascara));
        if (!er) return true;
        free(er);
        usleep(100000);
    }
    fprintf(stderr, "gravidade: não consegui tornar-me o gestor de janelas.\n");
    return false;
}

static void gerirExistentes() {
    xcb_query_tree_reply_t *t = xcb_query_tree_reply(X, xcb_query_tree(X, R), nullptr);
    if (!t) return;
    xcb_window_t *filhos = xcb_query_tree_children(t);
    int n = xcb_query_tree_children_length(t);
    for (int i = 0; i < n; ++i) {
        xcb_window_t w = filhos[i];
        if (w == verificacao) continue;
        xcb_get_window_attributes_reply_t *a = xcb_get_window_attributes_reply(X, xcb_get_window_attributes(X, w), nullptr);
        if (!a) continue;
        bool ok = !a->override_redirect && a->map_state == XCB_MAP_STATE_VIEWABLE;
        free(a);
        if (ok) gerir(w, true);
    }
    free(t);
}

int main(int argc, char **argv) {
    bool substituir = false;
    for (int i = 1; i < argc; ++i) {
        std::string a = argv[i];
        if (a == "--substituir" || a == "--replace") substituir = true;
        else if (a == "--versao" || a == "--version") { puts("gravidade 0.1"); return 0; }
        else if (a == "--ajuda" || a == "--help" || a == "-h") {
            puts("gravidade — o gestor de janelas do CarinaeOS\n"
                 "  --substituir   toma o lugar do gestor de janelas atual (ex.: KWin)\n"
                 "  Atalhos em ~/.config/carinaeos/atalhos.conf (kill -HUP para reler)");
            return 0;
        }
    }
    signal(SIGCHLD, SIG_IGN);
    signal(SIGHUP, [](int) { pedidoRecarregar = 1; });
    signal(SIGTERM, [](int) { pedidoSair = 1; });
    signal(SIGINT, [](int) { pedidoSair = 1; });

    int ecra = 0;
    X = xcb_connect(nullptr, &ecra);
    if (xcb_connection_has_error(X)) { fprintf(stderr, "gravidade: sem ligação ao X\n"); return 1; }
    xcb_screen_iterator_t it = xcb_setup_roots_iterator(xcb_get_setup(X));
    for (int i = 0; i < ecra; ++i) xcb_screen_next(&it);
    S = it.data;
    R = S->root;
    carregarAtomos();
    if (!tomarLugar(substituir)) return 1;

    const xcb_query_extension_reply_t *rr = xcb_get_extension_data(X, &xcb_randr_id);
    if (rr && rr->present) {
        randrEvento = rr->first_event;
        xcb_randr_select_input(X, R, XCB_RANDR_NOTIFY_MASK_SCREEN_CHANGE);
    }
    if (xcb_cursor_context_new(X, S, &ctxCursor) < 0) ctxCursor = nullptr;
    xcb_cursor_t seta = cursor("left_ptr");
    xcb_change_window_attributes(X, R, XCB_CW_CURSOR, &seta);

    anunciar();
    lerMonitores();
    lerAtalhos();
    lerGravidadeConf();
    agarrarTeclas();
    gerirExistentes();
    focarOutra();
    xcb_flush(X);
    fprintf(stderr, "gravidade: pronto (%zu monitor(es), %zu janela(s))\n", monitores.size(), clientes.size());

    pollfd pfd = {xcb_get_file_descriptor(X), POLLIN, 0};
    while (!pedidoSair) {
        xcb_flush(X);
        poll(&pfd, 1, 1000);
        if (pedidoRecarregar) { pedidoRecarregar = 0; lerAtalhos(); lerGravidadeConf(); agarrarTeclas(); for (Cliente *x : pilha) desenhar(x); }
        xcb_generic_event_t *ev;
        while ((ev = xcb_poll_for_event(X))) {
            tratar(ev);
            free(ev);
        }
        if (xcb_connection_has_error(X)) break;
    }
    // devolve as janelas ao ecrã, sem molduras (para outro gestor poder pegar nelas)
    for (auto &c : clientes) {
        if (c->comMoldura()) {
            xcb_reparent_window(X, c->win, R, c->x + c->borda(), c->y + c->topo());
            xcb_map_window(X, c->win);
        } else if (!c->mapeada) {
            xcb_map_window(X, c->win);
        }
    }
    xcb_flush(X);
    xcb_disconnect(X);
    return 0;
}
