// CarinaeOS — Terminal Carinae: o motor e o desenho.
//   O texto e as cores vêm da libvterm (a mesma biblioteca do terminal do Neovim); o processo corre
//   num pseudo-terminal (forkpty). O desenho é nosso, com as cores do tema do CarinaeOS.
#include "terminal.h"

#include <QClipboard>
#include <QCursor>
#include <QDateTime>
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFontMetricsF>
#include <QGuiApplication>
#include <QInputMethodEvent>
#include <QPainter>
#include <QRegularExpression>
#include <QStyleHints>
#include <QUrl>

#include <cerrno>
#include <csignal>
#include <cstdlib>
#include <fcntl.h>
#include <pty.h>
#include <pwd.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <termios.h>
#include <unistd.h>

static const char *PALETA_PADRAO[16] = {
    "#2a2438", "#ff6f91", "#7ee0a6", "#ffb46e", "#7aa7ff", "#c792ea", "#5fd7d0", "#d8d0e8",
    "#5a5270", "#ff8fab", "#a3f0c2", "#ffd09e", "#a3c2ff", "#ddb3f5", "#8fe8e2", "#ffffff"};

Terminal::Terminal(QQuickItem *pai) : QQuickPaintedItem(pai) {
    setFlag(ItemAcceptsInputMethod, true);
    setFlag(ItemIsFocusScope, false);
    setAcceptedMouseButtons(Qt::AllButtons);
    setAcceptHoverEvents(true);
    setActiveFocusOnTab(false);
    setFillColor(Qt::transparent);
    setOpaquePainting(false);
    setCursor(QCursor(Qt::IBeamCursor));
    for (int i = 0; i < 16; ++i) m_paleta[i] = QColor(PALETA_PADRAO[i]);

    m_vt = vterm_new(m_rows, m_cols);
    vterm_set_utf8(m_vt, 1);
    vterm_output_set_callback(m_vt, &Terminal::cbSaida, this);
    m_ecra = vterm_obtain_screen(m_vt);
    static VTermScreenCallbacks cbs = {};
    cbs.damage = &Terminal::cbDamage;
    cbs.movecursor = &Terminal::cbMoveCursor;
    cbs.settermprop = &Terminal::cbProp;
    cbs.bell = &Terminal::cbBell;
    cbs.sb_pushline = &Terminal::cbPushLine;
    cbs.sb_popline = &Terminal::cbPopLine;
    cbs.sb_clear = &Terminal::cbClearSb;
    vterm_screen_set_callbacks(m_ecra, &cbs, this);
    vterm_screen_enable_altscreen(m_ecra, 1);
    vterm_screen_enable_reflow(m_ecra, true);
    vterm_screen_set_damage_merge(m_ecra, VTERM_DAMAGE_SCROLL);
    vterm_screen_reset(m_ecra, 1);
    aplicarPaleta();

    m_pisca.setInterval(QGuiApplication::styleHints()->cursorFlashTime() / 2 > 0 ? QGuiApplication::styleHints()->cursorFlashTime() / 2 : 530);
    connect(&m_pisca, &QTimer::timeout, this, [this] { m_piscaFase = !m_piscaFase; update(); });
    m_desenho.setSingleShot(true);
    m_desenho.setInterval(8);
    connect(&m_desenho, &QTimer::timeout, this, [this] { update(); });
    m_vigiaPasta.setInterval(1000);
    connect(&m_vigiaPasta, &QTimer::timeout, this, &Terminal::atualizarPasta);
    medirFonte();
}

Terminal::~Terminal() {
    if (m_pid > 0) {
        ::kill(-m_pid, SIGHUP);
        ::kill(m_pid, SIGHUP);
        ::waitpid(m_pid, nullptr, WNOHANG);
    }
    if (m_master >= 0) ::close(m_master);
    if (m_vt) vterm_free(m_vt);
}

// ---- configuração ---------------------------------------------------------------------------
void Terminal::setFamilia(const QString &f) {
    if (f.isEmpty() || f == m_familia) return;
    m_familia = f;
    medirFonte();
    redimensionar();
    emit configMudou();
    update();
}

void Terminal::setTamanho(qreal t) {
    t = qBound<qreal>(6, t, 48);
    if (qFuzzyCompare(t, m_tamanho)) return;
    m_tamanho = t;
    medirFonte();
    redimensionar();
    emit configMudou();
    update();
}

QVariantList Terminal::cores() const {
    QVariantList l;
    for (const QColor &c : m_paleta) l << c;
    return l;
}

void Terminal::setCores(const QVariantList &l) {
    for (int i = 0; i < 16 && i < l.size(); ++i) m_paleta[i] = l[i].value<QColor>();
    aplicarPaleta();
    emit configMudou();
    update();
}

void Terminal::setFundo(const QColor &c) { m_fundo = c; aplicarPaleta(); emit configMudou(); update(); }
void Terminal::setTexto(const QColor &c) { m_texto = c; aplicarPaleta(); emit configMudou(); update(); }

void Terminal::aplicarPaleta() {
    VTermState *st = vterm_obtain_state(m_vt);
    for (int i = 0; i < 16; ++i) {
        VTermColor c;
        vterm_color_rgb(&c, m_paleta[i].red(), m_paleta[i].green(), m_paleta[i].blue());
        vterm_state_set_palette_color(st, i, &c);
    }
    VTermColor fg, bg;
    vterm_color_rgb(&fg, m_texto.red(), m_texto.green(), m_texto.blue());
    vterm_color_rgb(&bg, m_fundo.red(), m_fundo.green(), m_fundo.blue());
    vterm_state_set_default_colors(st, &fg, &bg);
    // o "negrito" não muda a cor (a letra fica só mais grossa), como nos terminais modernos
    vterm_state_set_bold_highbright(st, 0);
}

void Terminal::medirFonte() {
    m_fonte = QFont(m_familia);
    m_fonte.setStyleHint(QFont::Monospace, QFont::PreferDefault);
    m_fonte.setFixedPitch(true);
    m_fonte.setPointSizeF(m_tamanho);
    m_fonte.setKerning(false);
    m_fonte.setHintingPreference(QFont::PreferFullHinting);
    m_fonteNegrito = m_fonte;
    m_fonteNegrito.setBold(true);
    m_fonteItalico = m_fonte;
    m_fonteItalico.setItalic(true);
    QFontMetricsF fm(m_fonte);
    m_cw = fm.horizontalAdvance(QLatin1Char('M'));
    m_ch = std::ceil(fm.height());
    m_ascent = fm.ascent();
    if (m_cw < 1) m_cw = 8;
}

// ---- processo -------------------------------------------------------------------------------
void Terminal::componentComplete() {
    QQuickPaintedItem::componentComplete();
    m_completo = true;
    redimensionar();
    arrancar();
}

void Terminal::arrancar() {
    struct winsize ws = {};
    ws.ws_row = ushort(m_rows);
    ws.ws_col = ushort(m_cols);
    ws.ws_xpixel = ushort(m_cols * m_cw);
    ws.ws_ypixel = ushort(m_rows * m_ch);

    QByteArray pasta = QFile::encodeName(m_pastaInicial.isEmpty() ? QDir::homePath() : m_pastaInicial);
    QList<QByteArray> args;
    QByteArray shell = qgetenv("SHELL");
    if (shell.isEmpty()) {
        struct passwd *pw = getpwuid(getuid());
        shell = pw && pw->pw_shell && *pw->pw_shell ? QByteArray(pw->pw_shell) : QByteArray("/bin/bash");
    }
    if (m_comando.isEmpty()) {
        args << shell;
    } else if (m_comando.size() == 1 && m_comando.first().contains(QLatin1Char(' '))) {
        args << "/bin/sh" << "-c" << m_comando.first().toLocal8Bit();     // "-e 'htop -d 5'"
    } else {
        for (const QString &a : m_comando) args << a.toLocal8Bit();
    }

    pid_t pid = forkpty(&m_master, nullptr, nullptr, &ws);
    if (pid < 0) {
        const QByteArray erro = "\r\n\x1b[31mNão foi possível abrir o pseudo-terminal.\x1b[0m\r\n";
        vterm_input_write(m_vt, erro.constData(), erro.size());
        return;
    }
    if (pid == 0) {
        // filho
        if (chdir(pasta.constData()) != 0) (void)chdir(QFile::encodeName(QDir::homePath()).constData());
        setenv("TERM", "xterm-256color", 1);
        setenv("COLORTERM", "truecolor", 1);
        setenv("TERM_PROGRAM", "carinae-terminal", 1);
        unsetenv("COLUMNS");
        unsetenv("LINES");
        signal(SIGINT, SIG_DFL); signal(SIGQUIT, SIG_DFL); signal(SIGCHLD, SIG_DFL); signal(SIGPIPE, SIG_DFL);
        std::vector<char *> argv;
        // a shell sem comando é interativa; o nome começa por "-" para ler o perfil (como o login)
        QByteArray nome0 = args.first();
        if (m_comando.isEmpty()) nome0 = QByteArray("-") + QFileInfo(QString::fromLocal8Bit(args.first())).fileName().toLocal8Bit();
        argv.push_back(nome0.data());
        for (int i = 1; i < args.size(); ++i) argv.push_back(args[i].data());
        argv.push_back(nullptr);
        execvp(args.first().constData(), argv.data());
        fprintf(stderr, "carinae-terminal: não consegui executar %s: %s\n", args.first().constData(), strerror(errno));
        _exit(127);
    }
    m_pid = pid;
    fcntl(m_master, F_SETFL, fcntl(m_master, F_GETFL) | O_NONBLOCK);
    fcntl(m_master, F_SETFD, FD_CLOEXEC);
    m_leitor = new QSocketNotifier(m_master, QSocketNotifier::Read, this);
    connect(m_leitor, &QSocketNotifier::activated, this, &Terminal::lerPty);
    m_escritor = new QSocketNotifier(m_master, QSocketNotifier::Write, this);
    m_escritor->setEnabled(false);
    connect(m_escritor, &QSocketNotifier::activated, this, [this] { enviar(nullptr, 0); });
    m_vigiaPasta.start();
    QTimer::singleShot(300, this, &Terminal::atualizarPasta);
}

void Terminal::lerPty() {
    char buf[65536];
    for (int voltas = 0; voltas < 16; ++voltas) {
        ssize_t n = ::read(m_master, buf, sizeof buf);
        if (n > 0) {
            vterm_input_write(m_vt, buf, size_t(n));
            continue;
        }
        if (n < 0 && (errno == EAGAIN || errno == EINTR)) break;
        acabou();          // EIO: o processo fechou o terminal
        return;
    }
    vterm_screen_flush_damage(m_ecra);
    if (m_rolar != 0 && !m_ecraAlternativo) {
        // a ver o histórico: fica onde está (as linhas novas não puxam a vista)
    }
    pedirDesenho();
}

void Terminal::acabou() {
    if (m_leitor) m_leitor->setEnabled(false);
    if (m_escritor) m_escritor->setEnabled(false);
    int estado = 0, codigo = 0;
    if (m_pid > 0 && ::waitpid(m_pid, &estado, 0) > 0) codigo = WIFEXITED(estado) ? WEXITSTATUS(estado) : 128 + WTERMSIG(estado);
    m_pid = 0;
    m_vigiaPasta.stop();
    if (m_manter) {
        const QByteArray fim = QStringLiteral("\r\n\x1b[2m[o processo terminou com o código %1 — pode fechar esta aba]\x1b[0m").arg(codigo).toUtf8();
        vterm_input_write(m_vt, fim.constData(), size_t(fim.size()));
        vterm_screen_flush_damage(m_ecra);
        update();
    }
    emit terminou(codigo);
}

void Terminal::enviar(const char *s, size_t n) {
    if (s && n) m_pendente.append(s, qsizetype(n));
    if (m_master < 0 || m_pid <= 0) { m_pendente.clear(); return; }
    while (!m_pendente.isEmpty()) {
        ssize_t w = ::write(m_master, m_pendente.constData(), size_t(m_pendente.size()));
        if (w > 0) { m_pendente.remove(0, qsizetype(w)); continue; }
        if (w < 0 && errno == EINTR) continue;
        break;
    }
    if (m_escritor) m_escritor->setEnabled(!m_pendente.isEmpty());
}

void Terminal::escrever(const QString &texto) {
    const QByteArray b = texto.toUtf8();
    vterm_keyboard_start_paste(m_vt);
    for (const char32_t cp : texto.toUcs4()) vterm_keyboard_unichar(m_vt, uint32_t(cp), VTERM_MOD_NONE);
    vterm_keyboard_end_paste(m_vt);
    Q_UNUSED(b);
    m_rolar = 0;
    update();
}

void Terminal::atualizarPasta() {
    if (m_pid <= 0 || m_master < 0) return;
    pid_t fg = tcgetpgrp(m_master);
    const pid_t alvo = fg > 0 ? fg : m_pid;
    const QString cwd = QFile::symLinkTarget(QStringLiteral("/proc/%1/cwd").arg(m_pid));
    QFile comm(QStringLiteral("/proc/%1/comm").arg(alvo));
    QString prog;
    if (comm.open(QIODevice::ReadOnly)) prog = QString::fromUtf8(comm.readAll()).trimmed();
    if ((!cwd.isEmpty() && cwd != m_pasta) || prog != m_programa) {
        if (!cwd.isEmpty()) m_pasta = cwd;
        m_programa = prog;
        emit pastaMudou();
    }
}

// ---- tamanho --------------------------------------------------------------------------------
void Terminal::geometryChange(const QRectF &nova, const QRectF &antiga) {
    QQuickPaintedItem::geometryChange(nova, antiga);
    if (nova.size() != antiga.size()) redimensionar();
}

void Terminal::redimensionar() {
    if (width() <= 0 || height() <= 0) return;
    const int cols = qMax(2, int((width() - 2 * m_margem) / m_cw));
    const int rows = qMax(2, int((height() - 2 * m_margem) / m_ch));
    if (cols == m_cols && rows == m_rows) return;
    m_cols = cols;
    m_rows = rows;
    vterm_set_size(m_vt, rows, cols);
    vterm_screen_flush_damage(m_ecra);
    if (m_master >= 0) {
        struct winsize ws = {};
        ws.ws_row = ushort(rows); ws.ws_col = ushort(cols);
        ws.ws_xpixel = ushort(cols * m_cw); ws.ws_ypixel = ushort(rows * m_ch);
        ioctl(m_master, TIOCSWINSZ, &ws);
    }
    m_rolar = qMin(m_rolar, int(m_historico.size()));
    emit tamanhoGrelhaMudou();
    update();
}

// ---- chamadas da libvterm -------------------------------------------------------------------
int Terminal::cbDamage(VTermRect, void *u) { static_cast<Terminal *>(u)->pedirDesenho(); return 1; }

int Terminal::cbMoveCursor(VTermPos pos, VTermPos, int visible, void *u) {
    auto *t = static_cast<Terminal *>(u);
    t->m_cursor = pos;
    t->m_cursorVisivel = visible;
    t->m_piscaFase = true;
    if (t->m_pisca.isActive()) t->m_pisca.start();
    t->pedirDesenho();
    return 1;
}

int Terminal::cbProp(VTermProp prop, VTermValue *val, void *u) {
    auto *t = static_cast<Terminal *>(u);
    switch (prop) {
    case VTERM_PROP_CURSORVISIBLE: t->m_cursorVisivel = val->boolean; break;
    case VTERM_PROP_CURSORBLINK: t->m_cursorPisca = val->boolean; break;
    case VTERM_PROP_CURSORSHAPE: t->m_formaPedida = val->number; break;
    case VTERM_PROP_ALTSCREEN: t->m_ecraAlternativo = val->boolean; t->m_rolar = 0; break;
    case VTERM_PROP_MOUSE: t->m_modoRato = val->number; break;
    case VTERM_PROP_TITLE: {
        if (val->string.initial) t->m_tituloParcial.clear();
        t->m_tituloParcial += QString::fromUtf8(val->string.str, qsizetype(val->string.len));
        if (val->string.final && t->m_tituloParcial != t->m_titulo) {
            t->m_titulo = t->m_tituloParcial;
            emit t->tituloMudou();
        }
        break;
    }
    default: break;
    }
    t->pedirDesenho();
    return 1;
}

int Terminal::cbBell(void *u) { emit static_cast<Terminal *>(u)->campainha(); return 1; }

int Terminal::cbPushLine(int cols, const VTermScreenCell *cells, void *u) {
    auto *t = static_cast<Terminal *>(u);
    t->m_historico.emplace_back(cells, cells + cols);
    if (t->m_historico.size() > MAX_HISTORICO) {
        t->m_historico.pop_front();
        // a seleção está em linhas absolutas: anda uma para cima
        t->m_selA.linha--; t->m_selB.linha--;
    } else if (t->m_rolar > 0) {
        t->m_rolar++;          // quem está a ler o histórico não perde o sítio
    }
    return 1;
}

int Terminal::cbPopLine(int cols, VTermScreenCell *cells, void *u) {
    auto *t = static_cast<Terminal *>(u);
    if (t->m_historico.empty()) return 0;
    const auto &l = t->m_historico.back();
    for (int i = 0; i < cols; ++i) {
        if (i < int(l.size())) cells[i] = l[size_t(i)];
        else {
            cells[i] = VTermScreenCell{};
            cells[i].width = 1;
            vterm_color_indexed(&cells[i].fg, 7);
            cells[i].fg.type = VTERM_COLOR_DEFAULT_FG | VTERM_COLOR_RGB;
            cells[i].bg.type = VTERM_COLOR_DEFAULT_BG | VTERM_COLOR_RGB;
        }
    }
    t->m_historico.pop_back();
    if (t->m_rolar > 0) t->m_rolar--;
    return 1;
}

int Terminal::cbClearSb(void *u) {
    auto *t = static_cast<Terminal *>(u);
    t->m_historico.clear();
    t->m_rolar = 0;
    return 1;
}

void Terminal::cbSaida(const char *s, size_t len, void *u) { static_cast<Terminal *>(u)->enviar(s, len); }

void Terminal::pedirDesenho() { if (!m_desenho.isActive()) m_desenho.start(); }

// ---- células e cores ------------------------------------------------------------------------
bool Terminal::celula(long linhaAbs, int col, VTermScreenCell *c) const {
    const long h = long(m_historico.size());
    if (linhaAbs < 0) return false;
    if (linhaAbs < h) {
        const auto &l = m_historico[size_t(linhaAbs)];
        if (col >= int(l.size())) return false;
        *c = l[size_t(col)];
        return true;
    }
    VTermPos p{int(linhaAbs - h), col};
    if (p.row >= m_rows || col >= m_cols) return false;
    return vterm_screen_get_cell(m_ecra, p, c) != 0;
}

QColor Terminal::cor(const VTermColor &c0, bool frente, bool) const {
    VTermColor c = c0;
    if (frente ? VTERM_COLOR_IS_DEFAULT_FG(&c) : VTERM_COLOR_IS_DEFAULT_BG(&c)) return frente ? m_texto : QColor(Qt::transparent);
    vterm_screen_convert_color_to_rgb(m_ecra, &c);
    return QColor(c.rgb.red, c.rgb.green, c.rgb.blue);
}

// ---- desenho --------------------------------------------------------------------------------
void Terminal::paint(QPainter *p) {
    const QRectF tudo(0, 0, width(), height());
    QColor fundo = m_fundo;
    fundo.setAlphaF(float(m_opacidade));
    p->setCompositionMode(QPainter::CompositionMode_Source);
    p->fillRect(tudo, fundo);
    p->setCompositionMode(QPainter::CompositionMode_SourceOver);

    const long h = long(m_historico.size());
    const long primeira = h - m_rolar;          // linha absoluta no topo da vista
    const qreal x0 = m_margem, y0 = m_margem;
    QColor fundoOpaco = m_fundo;

    for (int r = 0; r < m_rows; ++r) {
        const long la = primeira + r;
        const qreal y = y0 + r * m_ch;
        QString run;
        int runCol = 0;
        QColor runCor;
        int runEstilo = 0;   // 1 negrito, 2 itálico, 4 sublinhado, 8 riscado
        auto despejar = [&] {
            if (run.isEmpty()) return;
            p->setFont((runEstilo & 1) ? m_fonteNegrito : (runEstilo & 2) ? m_fonteItalico : m_fonte);
            p->setPen(runCor);
            p->drawText(QPointF(x0 + runCol * m_cw, y + m_ascent), run);
            if (runEstilo & 4) p->fillRect(QRectF(x0 + runCol * m_cw, y + m_ascent + 2, run.size() * m_cw, 1), runCor);
            if (runEstilo & 8) p->fillRect(QRectF(x0 + runCol * m_cw, y + m_ch / 2, run.size() * m_cw, 1), runCor);
            run.clear();
        };
        for (int c = 0; c < m_cols; ++c) {
            VTermScreenCell cel;
            if (!celula(la, c, &cel)) { despejar(); continue; }
            QColor fg = cor(cel.fg, true, cel.attrs.bold);
            QColor bg = cor(cel.bg, false, false);
            if (cel.attrs.reverse) {
                const QColor f2 = bg.alpha() == 0 ? fundoOpaco : bg;
                bg = fg; fg = f2;
            }
            if (dentroSelecao(la, c)) { bg = m_texto; fg = fundoOpaco; bg.setAlpha(220); }
            const int largura = qMax(1, int(cel.width));
            if (bg.alpha() > 0) p->fillRect(QRectF(x0 + c * m_cw, y, m_cw * largura, m_ch), bg);
            if (cel.attrs.conceal) fg = bg.alpha() ? bg : fundoOpaco;
            const uint32_t ch0 = cel.chars[0];
            const int estilo = (cel.attrs.bold ? 1 : 0) | (cel.attrs.italic ? 2 : 0) | (cel.attrs.underline ? 4 : 0) | (cel.attrs.strike ? 8 : 0);
            if (ch0 == 0 || ch0 == ' ') {
                if (!run.isEmpty() && fg == runCor && estilo == runEstilo && !(estilo & 12)) { run += QLatin1Char(' '); }
                else { despejar(); if (estilo & 12) { runCol = c; runCor = fg; runEstilo = estilo; run = QStringLiteral(" "); despejar(); } }
                continue;
            }
            QString s;
            for (int k = 0; k < VTERM_MAX_CHARS_PER_CELL && cel.chars[k]; ++k) {
                const char32_t cp = char32_t(cel.chars[k]);
                s += QString::fromUcs4(&cp, 1);
            }
            if (ch0 < 0x80 && largura == 1) {
                if (run.isEmpty() || fg != runCor || estilo != runEstilo) { despejar(); runCol = c; runCor = fg; runEstilo = estilo; }
                run += s;
            } else {
                // fora do ASCII (acentos, caixas, emoji): cada um no seu sítio, para não desalinhar
                despejar();
                runCol = c; runCor = fg; runEstilo = estilo; run = s;
                despejar();
            }
            if (largura == 2) ++c;
        }
        despejar();
    }

    // cursor
    if (m_rolar == 0 && m_cursorVisivel && m_pid > 0) {
        const QRectF rc(x0 + m_cursor.col * m_cw, y0 + m_cursor.row * m_ch, m_cw, m_ch);
        if (!hasActiveFocus()) {
            p->setPen(QPen(m_corCursor, 1));
            p->setBrush(Qt::NoBrush);
            p->drawRect(rc.adjusted(0.5, 0.5, -0.5, -0.5));
        } else if (m_piscaFase || !m_cursorPisca) {
            // o programa pode pedir a forma (vim no modo de inserção pede a barra)
            QString forma = m_formaCursor;
            if (m_ecraAlternativo && m_formaPedida == VTERM_PROP_CURSORSHAPE_BLOCK) forma = QStringLiteral("bloco");
            else if (m_ecraAlternativo && m_formaPedida == VTERM_PROP_CURSORSHAPE_UNDERLINE) forma = QStringLiteral("sublinhado");
            else if (m_ecraAlternativo && m_formaPedida == VTERM_PROP_CURSORSHAPE_BAR_LEFT) forma = QStringLiteral("barra");
            if (forma == QLatin1String("bloco")) {
                p->fillRect(rc, m_corCursor);
                VTermScreenCell cel;
                if (celula(long(m_historico.size()) + m_cursor.row, m_cursor.col, &cel) && cel.chars[0] && cel.chars[0] != ' ') {
                    const char32_t cp = char32_t(cel.chars[0]);
                    p->setFont(cel.attrs.bold ? m_fonteNegrito : m_fonte);
                    p->setPen(fundoOpaco);
                    p->drawText(QPointF(rc.x(), rc.y() + m_ascent), QString::fromUcs4(&cp, 1));
                }
            } else if (forma == QLatin1String("sublinhado")) {
                p->fillRect(QRectF(rc.x(), rc.bottom() - 2, rc.width(), 2), m_corCursor);
            } else {
                p->fillRect(QRectF(rc.x(), rc.y(), 2, rc.height()), m_corCursor);
            }
        }
    }
    // texto a ser composto (acentos com teclas mortas, métodos de entrada)
    if (!m_preEdicao.isEmpty()) {
        const QRectF rc(x0 + m_cursor.col * m_cw, y0 + m_cursor.row * m_ch, m_cw * m_preEdicao.size(), m_ch);
        p->fillRect(rc, fundoOpaco);
        p->setFont(m_fonte);
        p->setPen(m_texto);
        p->drawText(QPointF(rc.x(), rc.y() + m_ascent), m_preEdicao);
        p->fillRect(QRectF(rc.x(), rc.bottom() - 1, rc.width(), 1), m_texto);
    }
    // barra de deslocamento discreta quando se está a ver o histórico
    if (m_rolar > 0 && !m_historico.empty()) {
        const qreal total = qreal(m_historico.size() + m_rows);
        const qreal alt = qMax<qreal>(24, height() * m_rows / total);
        const qreal topo = (height() - alt) * (qreal(m_historico.size() - m_rolar) / qreal(m_historico.size()));
        QColor b = m_texto; b.setAlpha(90);
        p->setPen(Qt::NoPen);
        p->setBrush(b);
        p->drawRoundedRect(QRectF(width() - 6, topo, 4, alt), 2, 2);
    }
}

// ---- teclado --------------------------------------------------------------------------------
int Terminal::modificadores(Qt::KeyboardModifiers m) const {
    int r = VTERM_MOD_NONE;
    if (m & Qt::ShiftModifier) r |= VTERM_MOD_SHIFT;
    if (m & Qt::AltModifier) r |= VTERM_MOD_ALT;
    if (m & Qt::ControlModifier) r |= VTERM_MOD_CTRL;
    return r;
}

void Terminal::keyPressEvent(QKeyEvent *e) {
    const Qt::KeyboardModifiers mods = e->modifiers();
    const int k = e->key();
    // Shift+PgUp/PgDn/Home/End: andar pelo histórico (no ecrã normal)
    if ((mods & Qt::ShiftModifier) && !m_ecraAlternativo &&
        (k == Qt::Key_PageUp || k == Qt::Key_PageDown || k == Qt::Key_Home || k == Qt::Key_End)) {
        const int passo = m_rows - 1;
        if (k == Qt::Key_PageUp) m_rolar = qMin(int(m_historico.size()), m_rolar + passo);
        else if (k == Qt::Key_PageDown) m_rolar = qMax(0, m_rolar - passo);
        else if (k == Qt::Key_Home) m_rolar = int(m_historico.size());
        else m_rolar = 0;
        update();
        return;
    }

    VTermModifier vm = VTermModifier(modificadores(mods));
    VTermKey vk = VTERM_KEY_NONE;
    switch (k) {
    case Qt::Key_Return: case Qt::Key_Enter: vk = VTERM_KEY_ENTER; break;
    case Qt::Key_Tab: vk = VTERM_KEY_TAB; break;
    case Qt::Key_Backtab: vk = VTERM_KEY_TAB; vm = VTermModifier(vm | VTERM_MOD_SHIFT); break;
    case Qt::Key_Backspace: vk = VTERM_KEY_BACKSPACE; break;
    case Qt::Key_Escape: vk = VTERM_KEY_ESCAPE; break;
    case Qt::Key_Up: vk = VTERM_KEY_UP; break;
    case Qt::Key_Down: vk = VTERM_KEY_DOWN; break;
    case Qt::Key_Left: vk = VTERM_KEY_LEFT; break;
    case Qt::Key_Right: vk = VTERM_KEY_RIGHT; break;
    case Qt::Key_Insert: vk = VTERM_KEY_INS; break;
    case Qt::Key_Delete: vk = VTERM_KEY_DEL; break;
    case Qt::Key_Home: vk = VTERM_KEY_HOME; break;
    case Qt::Key_End: vk = VTERM_KEY_END; break;
    case Qt::Key_PageUp: vk = VTERM_KEY_PAGEUP; break;
    case Qt::Key_PageDown: vk = VTERM_KEY_PAGEDOWN; break;
    default:
        if (k >= Qt::Key_F1 && k <= Qt::Key_F12) vk = VTermKey(VTERM_KEY_FUNCTION(k - Qt::Key_F1 + 1));
    }
    if (vk != VTERM_KEY_NONE) {
        vterm_keyboard_key(m_vt, vk, vm);
    } else if ((mods & Qt::ControlModifier) && k >= Qt::Key_A && k <= Qt::Key_Z) {
        vterm_keyboard_unichar(m_vt, uint32_t('a' + (k - Qt::Key_A)), VTermModifier(vm & ~VTERM_MOD_SHIFT));
    } else if ((mods & Qt::ControlModifier) && (k == Qt::Key_Space || k == Qt::Key_BracketLeft || k == Qt::Key_Backslash ||
                                                k == Qt::Key_BracketRight || k == Qt::Key_AsciiCircum || k == Qt::Key_Underscore)) {
        vterm_keyboard_unichar(m_vt, uint32_t(k == Qt::Key_Space ? ' ' : k), VTermModifier(vm & ~VTERM_MOD_SHIFT));
    } else if (!e->text().isEmpty()) {
        const VTermModifier m2 = VTermModifier(vm & VTERM_MOD_ALT);
        for (const char32_t cp : e->text().toUcs4()) {
            if (cp < 0x20 && !(mods & Qt::ControlModifier)) continue;
            if (cp < 0x20) { const char c = char(cp); enviar(&c, 1); continue; }
            vterm_keyboard_unichar(m_vt, uint32_t(cp), m2);
        }
    } else {
        QQuickPaintedItem::keyPressEvent(e);
        return;
    }
    e->accept();
    if (m_rolar) { m_rolar = 0; }
    m_piscaFase = true;
    if (m_pisca.isActive()) m_pisca.start();
    update();
}

void Terminal::inputMethodEvent(QInputMethodEvent *e) {
    if (!e->commitString().isEmpty()) {
        for (const char32_t cp : e->commitString().toUcs4()) vterm_keyboard_unichar(m_vt, uint32_t(cp), VTERM_MOD_NONE);
        m_rolar = 0;
    }
    m_preEdicao = e->preeditString();
    e->accept();
    update();
}

QVariant Terminal::inputMethodQuery(Qt::InputMethodQuery q) const {
    switch (q) {
    case Qt::ImEnabled: return true;
    case Qt::ImCursorRectangle: return QRectF(m_margem + m_cursor.col * m_cw, m_margem + m_cursor.row * m_ch, m_cw, m_ch);
    case Qt::ImFont: return m_fonte;
    case Qt::ImHints: return int(Qt::ImhNoPredictiveText | Qt::ImhNoAutoUppercase);
    default: return QQuickPaintedItem::inputMethodQuery(q);
    }
}

void Terminal::focusInEvent(QFocusEvent *e) {
    QQuickPaintedItem::focusInEvent(e);
    m_piscaFase = true;
    m_pisca.start();
    vterm_state_focus_in(vterm_obtain_state(m_vt));
    update();
}

void Terminal::focusOutEvent(QFocusEvent *e) {
    QQuickPaintedItem::focusOutEvent(e);
    m_pisca.stop();
    vterm_state_focus_out(vterm_obtain_state(m_vt));
    update();
}

void Terminal::focar() { forceActiveFocus(Qt::OtherFocusReason); }

// ---- rato e seleção -------------------------------------------------------------------------
Terminal::Pos Terminal::posDoRato(const QPointF &pt) const {
    Pos p;
    const int r = qBound(0, int((pt.y() - m_margem) / m_ch), m_rows - 1);
    p.col = qBound(0, int((pt.x() - m_margem) / m_cw + 0.5), m_cols);
    p.linha = long(m_historico.size()) - m_rolar + r;
    return p;
}

bool Terminal::dentroSelecao(long linha, int col) const {
    if (m_selA == m_selB) return false;
    Pos a = m_selA, b = m_selB;
    if (b < a) std::swap(a, b);
    Pos x{linha, col};
    return !(x < a) && x < b;
}

QString Terminal::textoEntre(Pos a, Pos b) const {
    if (b < a) std::swap(a, b);
    QString r;
    for (long l = a.linha; l <= b.linha; ++l) {
        QString linha;
        const int c0 = l == a.linha ? a.col : 0;
        const int c1 = l == b.linha ? b.col : m_cols;
        for (int c = c0; c < c1; ++c) {
            VTermScreenCell cel;
            if (!celula(l, c, &cel)) break;
            if (!cel.chars[0]) { linha += QLatin1Char(' '); continue; }
            for (int k = 0; k < VTERM_MAX_CHARS_PER_CELL && cel.chars[k]; ++k) {
                const char32_t cp = char32_t(cel.chars[k]);
                linha += QString::fromUcs4(&cp, 1);
            }
            if (cel.width == 2) ++c;
        }
        while (linha.endsWith(QLatin1Char(' '))) linha.chop(1);
        r += linha;
        if (l != b.linha) r += QLatin1Char('\n');
    }
    return r;
}

QString Terminal::palavraEm(Pos p, Pos *ini, Pos *fim) const {
    auto letra = [&](int c) -> QChar {
        VTermScreenCell cel;
        if (!celula(p.linha, c, &cel) || !cel.chars[0]) return QLatin1Char(' ');
        return cel.chars[0] < 0x10000 ? QChar(char16_t(cel.chars[0])) : QChar(QLatin1Char('x'));
    };
    static const QString separadores = QStringLiteral(" \t\"'`()[]{}<>|;,");
    int c = qMin(p.col, m_cols - 1);
    if (separadores.contains(letra(c))) { *ini = *fim = p; return {}; }
    int a = c, b = c;
    while (a > 0 && !separadores.contains(letra(a - 1))) --a;
    while (b < m_cols - 1 && !separadores.contains(letra(b + 1))) ++b;
    *ini = Pos{p.linha, a};
    *fim = Pos{p.linha, b + 1};
    return textoEntre(*ini, *fim);
}

static int botaoVterm(Qt::MouseButton b) {
    return b == Qt::LeftButton ? 1 : b == Qt::MiddleButton ? 2 : b == Qt::RightButton ? 3 : 0;
}

void Terminal::mousePressEvent(QMouseEvent *e) {
    forceActiveFocus(Qt::MouseFocusReason);
    // o programa quer o rato (htop, mc, vim com mouse=a); Shift força a seleção
    if (m_modoRato && !(e->modifiers() & Qt::ShiftModifier) && m_rolar == 0) {
        const int r = qBound(0, int((e->position().y() - m_margem) / m_ch), m_rows - 1);
        const int c = qBound(0, int((e->position().x() - m_margem) / m_cw), m_cols - 1);
        vterm_mouse_move(m_vt, r, c, VTermModifier(modificadores(e->modifiers())));
        vterm_mouse_button(m_vt, botaoVterm(e->button()), true, VTermModifier(modificadores(e->modifiers())));
        m_botaoRato = botaoVterm(e->button());
        e->accept();
        return;
    }
    if (e->button() == Qt::RightButton) {
        emit menuPedido(e->position().x(), e->position().y());
        e->accept();
        return;
    }
    if (e->button() == Qt::MiddleButton) {
        const QString t = QGuiApplication::clipboard()->text(QClipboard::Selection);
        if (!t.isEmpty()) escrever(t);
        e->accept();
        return;
    }
    if (e->button() != Qt::LeftButton) return;
    // Ctrl+clique abre o endereço
    if (e->modifiers() & Qt::ControlModifier) {
        Pos a, b;
        const QString w = palavraEm(posDoRato(e->position()), &a, &b);
        static const QRegularExpression url(QStringLiteral("^(https?://|www\\.)\\S+"));
        if (url.match(w).hasMatch()) {
            QDesktopServices::openUrl(QUrl::fromUserInput(w));
            e->accept();
            return;
        }
    }
    const qint64 agora = QDateTime::currentMSecsSinceEpoch();
    if (agora - m_tempoClique < 400 && (e->position() - m_ultimoClique).manhattanLength() < 6) m_cliques++;
    else m_cliques = 1;
    m_tempoClique = agora;
    m_ultimoClique = e->position();
    const Pos p = posDoRato(e->position());
    if (m_cliques >= 3) {
        m_selA = Pos{p.linha, 0};
        m_selB = Pos{p.linha, m_cols};
    } else if (m_cliques == 2) {
        palavraEm(p, &m_selA, &m_selB);
    } else if (e->modifiers() & Qt::ShiftModifier && temSelecao()) {
        m_selB = p;
    } else {
        m_selA = m_selB = p;
    }
    m_aSelecionar = true;
    emit selecaoMudou();
    update();
    e->accept();
}

void Terminal::mouseMoveEvent(QMouseEvent *e) {
    if (m_botaoRato) {
        if (m_modoRato >= VTERM_PROP_MOUSE_DRAG) {
            const int r = qBound(0, int((e->position().y() - m_margem) / m_ch), m_rows - 1);
            const int c = qBound(0, int((e->position().x() - m_margem) / m_cw), m_cols - 1);
            vterm_mouse_move(m_vt, r, c, VTermModifier(modificadores(e->modifiers())));
        }
        return;
    }
    if (!m_aSelecionar) return;
    // arrastar para fora rola o histórico
    if (e->position().y() < 0 && !m_ecraAlternativo) m_rolar = qMin(int(m_historico.size()), m_rolar + 1);
    else if (e->position().y() > height() && m_rolar > 0) m_rolar--;
    m_selB = posDoRato(e->position());
    emit selecaoMudou();
    update();
}

void Terminal::mouseReleaseEvent(QMouseEvent *e) {
    if (m_botaoRato) {
        vterm_mouse_button(m_vt, m_botaoRato, false, VTermModifier(modificadores(e->modifiers())));
        m_botaoRato = 0;
        return;
    }
    m_aSelecionar = false;
    if (temSelecao()) {
        // como em todos os terminais do Linux: o que se seleciona fica pronto para colar com o botão do meio
        QGuiApplication::clipboard()->setText(textoEntre(m_selA, m_selB), QClipboard::Selection);
    }
}

void Terminal::mouseDoubleClickEvent(QMouseEvent *e) { mousePressEvent(e); }

void Terminal::hoverMoveEvent(QHoverEvent *e) {
    if (m_modoRato == VTERM_PROP_MOUSE_MOVE && m_rolar == 0) {
        const int r = qBound(0, int((e->position().y() - m_margem) / m_ch), m_rows - 1);
        const int c = qBound(0, int((e->position().x() - m_margem) / m_cw), m_cols - 1);
        vterm_mouse_move(m_vt, r, c, VTERM_MOD_NONE);
    }
}

void Terminal::wheelEvent(QWheelEvent *e) {
    const int passos = e->angleDelta().y() / 40;      // 3 linhas por "clique" da roda
    if (passos == 0) return;
    if (m_modoRato && m_rolar == 0) {
        const int r = qBound(0, int((e->position().y() - m_margem) / m_ch), m_rows - 1);
        const int c = qBound(0, int((e->position().x() - m_margem) / m_cw), m_cols - 1);
        vterm_mouse_move(m_vt, r, c, VTERM_MOD_NONE);
        for (int i = 0; i < qAbs(passos) / 3 + 1; ++i) vterm_mouse_button(m_vt, passos > 0 ? 4 : 5, true, VTERM_MOD_NONE);
    } else if (m_ecraAlternativo) {
        // less, man, vim sem rato: a roda vira setas
        for (int i = 0; i < qAbs(passos); ++i) vterm_keyboard_key(m_vt, passos > 0 ? VTERM_KEY_UP : VTERM_KEY_DOWN, VTERM_MOD_NONE);
    } else {
        m_rolar = qBound(0, m_rolar + passos, int(m_historico.size()));
        update();
    }
    e->accept();
}

// ---- área de transferência ------------------------------------------------------------------
void Terminal::copiar() {
    if (!temSelecao()) return;
    QGuiApplication::clipboard()->setText(textoEntre(m_selA, m_selB));
}

void Terminal::colar() {
    QString t = QGuiApplication::clipboard()->text();
    if (t.isEmpty()) return;
    t.replace(QLatin1String("\r\n"), QLatin1String("\r")).replace(QLatin1Char('\n'), QLatin1Char('\r'));
    escrever(t);
}

void Terminal::selecionarTudo() {
    m_selA = Pos{0, 0};
    m_selB = Pos{linhasTotais() - 1, m_cols};
    emit selecaoMudou();
    update();
}

void Terminal::limparHistorico() {
    m_historico.clear();
    m_rolar = 0;
    m_selA = m_selB = Pos{};
    // como o "clear": limpa o ecrã e leva o cursor para cima (o programa redesenha o prompt)
    enviar("\x0c", 1);
    update();
}
