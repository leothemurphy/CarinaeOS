// CarinaeOS — Terminal Carinae: o motor (pseudo-terminal + libvterm) e o desenho do ecrã de texto.
#pragma once

#include <QColor>
#include <QFont>
#include <QPointer>
#include <QQuickPaintedItem>
#include <QSocketNotifier>
#include <QTimer>
#include <QVariantList>
#include <deque>
#include <vector>

extern "C" {
#include <vterm.h>
}

class Terminal : public QQuickPaintedItem {
    Q_OBJECT
    // o que o QML define
    Q_PROPERTY(QStringList comando READ comando WRITE setComando NOTIFY configMudou)
    Q_PROPERTY(QString pastaInicial MEMBER m_pastaInicial NOTIFY configMudou)
    Q_PROPERTY(bool manter MEMBER m_manter NOTIFY configMudou)
    Q_PROPERTY(QString familia READ familia WRITE setFamilia NOTIFY configMudou)
    Q_PROPERTY(qreal tamanho READ tamanho WRITE setTamanho NOTIFY configMudou)
    Q_PROPERTY(QVariantList cores READ cores WRITE setCores NOTIFY configMudou)      // 16 cores (normais + fortes)
    Q_PROPERTY(QColor fundo READ fundo WRITE setFundo NOTIFY configMudou)
    Q_PROPERTY(QColor texto READ texto WRITE setTexto NOTIFY configMudou)
    Q_PROPERTY(QColor corCursor MEMBER m_corCursor NOTIFY configMudou)
    Q_PROPERTY(QString formaCursor MEMBER m_formaCursor NOTIFY configMudou)        // bloco | barra | sublinhado
    Q_PROPERTY(qreal opacidade MEMBER m_opacidade NOTIFY configMudou)              // 0..1 do fundo
    Q_PROPERTY(int margem MEMBER m_margem NOTIFY configMudou)
    // o que o QML lê
    Q_PROPERTY(QString titulo READ titulo NOTIFY tituloMudou)
    Q_PROPERTY(QString pasta READ pasta NOTIFY pastaMudou)
    Q_PROPERTY(QString programa READ programa NOTIFY pastaMudou)
    Q_PROPERTY(bool temSelecao READ temSelecao NOTIFY selecaoMudou)
    Q_PROPERTY(bool aCorrer READ aCorrer NOTIFY terminou)
    Q_PROPERTY(int colunas READ colunas NOTIFY tamanhoGrelhaMudou)
    Q_PROPERTY(int linhas READ linhas NOTIFY tamanhoGrelhaMudou)

public:
    explicit Terminal(QQuickItem *pai = nullptr);
    ~Terminal() override;

    void paint(QPainter *p) override;

    QStringList comando() const { return m_comando; }
    void setComando(const QStringList &c) { m_comando = c; emit configMudou(); }
    QString familia() const { return m_familia; }
    void setFamilia(const QString &f);
    qreal tamanho() const { return m_tamanho; }
    void setTamanho(qreal t);
    QVariantList cores() const;
    void setCores(const QVariantList &l);
    QColor fundo() const { return m_fundo; }
    void setFundo(const QColor &c);
    QColor texto() const { return m_texto; }
    void setTexto(const QColor &c);

    QString titulo() const { return m_titulo; }
    QString pasta() const { return m_pasta; }
    QString programa() const { return m_programa; }
    bool temSelecao() const { return m_selA != m_selB; }
    bool aCorrer() const { return m_pid > 0; }
    int colunas() const { return m_cols; }
    int linhas() const { return m_rows; }

    Q_INVOKABLE void copiar();
    Q_INVOKABLE void colar();
    Q_INVOKABLE void selecionarTudo();
    Q_INVOKABLE void limparHistorico();
    Q_INVOKABLE void escrever(const QString &texto);   // como se o utilizador escrevesse
    Q_INVOKABLE void focar();

signals:
    void configMudou();
    void tituloMudou();
    void pastaMudou();
    void selecaoMudou();
    void terminou(int codigo);
    void tamanhoGrelhaMudou();
    void menuPedido(qreal x, qreal y);
    void campainha();

protected:
    void componentComplete() override;
    void geometryChange(const QRectF &nova, const QRectF &antiga) override;
    void keyPressEvent(QKeyEvent *e) override;
    void inputMethodEvent(QInputMethodEvent *e) override;
    QVariant inputMethodQuery(Qt::InputMethodQuery q) const override;
    void mousePressEvent(QMouseEvent *e) override;
    void mouseMoveEvent(QMouseEvent *e) override;
    void mouseReleaseEvent(QMouseEvent *e) override;
    void mouseDoubleClickEvent(QMouseEvent *e) override;
    void wheelEvent(QWheelEvent *e) override;
    void focusInEvent(QFocusEvent *e) override;
    void focusOutEvent(QFocusEvent *e) override;
    void hoverMoveEvent(QHoverEvent *e) override;

private:
    // libvterm
    static int cbDamage(VTermRect r, void *u);
    static int cbMoveCursor(VTermPos pos, VTermPos old, int visible, void *u);
    static int cbProp(VTermProp prop, VTermValue *val, void *u);
    static int cbBell(void *u);
    static int cbPushLine(int cols, const VTermScreenCell *cells, void *u);
    static int cbPopLine(int cols, VTermScreenCell *cells, void *u);
    static int cbClearSb(void *u);
    static void cbSaida(const char *s, size_t len, void *u);

    void arrancar();
    void lerPty();
    void enviar(const char *s, size_t n);
    void redimensionar();
    void medirFonte();
    void aplicarPaleta();
    void pedirDesenho();
    void acabou();
    void atualizarPasta();

    struct Pos { long linha = 0; int col = 0; bool operator==(const Pos &o) const { return linha == o.linha && col == o.col; }
                 bool operator!=(const Pos &o) const { return !(*this == o); }
                 bool operator<(const Pos &o) const { return linha < o.linha || (linha == o.linha && col < o.col); } };
    // linha "absoluta": 0 = a mais antiga do histórico; as do ecrã vêm depois
    long linhasTotais() const { return long(m_historico.size()) + m_rows; }
    bool celula(long linhaAbs, int col, VTermScreenCell *c) const;
    Pos posDoRato(const QPointF &p) const;
    QString textoEntre(Pos a, Pos b) const;
    bool dentroSelecao(long linha, int col) const;
    QString palavraEm(Pos p, Pos *ini, Pos *fim) const;
    QColor cor(const VTermColor &c, bool frente, bool negrito) const;
    int modificadores(Qt::KeyboardModifiers m) const;

    VTerm *m_vt = nullptr;
    VTermScreen *m_ecra = nullptr;
    int m_master = -1;
    pid_t m_pid = 0;
    QSocketNotifier *m_leitor = nullptr;
    QByteArray m_pendente;
    QSocketNotifier *m_escritor = nullptr;

    int m_rows = 24, m_cols = 80;
    std::deque<std::vector<VTermScreenCell>> m_historico;
    static constexpr size_t MAX_HISTORICO = 10000;
    int m_rolar = 0;              // quantas linhas acima do fundo se está a ver

    VTermPos m_cursor{0, 0};
    bool m_cursorVisivel = true;
    bool m_cursorPisca = true;
    bool m_piscaFase = true;
    int m_formaPedida = 0;        // DECSCUSR do programa (0 = a nossa)
    bool m_ecraAlternativo = false;
    int m_modoRato = 0;
    QTimer m_pisca, m_desenho, m_vigiaPasta;

    Pos m_selA, m_selB;
    bool m_aSelecionar = false;
    int m_cliques = 0;
    QPointF m_ultimoClique;
    qint64 m_tempoClique = 0;
    int m_botaoRato = 0;

    QStringList m_comando;
    QString m_pastaInicial;
    bool m_manter = false;
    QString m_familia = QStringLiteral("Monospace");
    qreal m_tamanho = 11;
    QFont m_fonte, m_fonteNegrito, m_fonteItalico;
    qreal m_cw = 8, m_ch = 16, m_ascent = 12;
    QColor m_paleta[16];
    QColor m_fundo{20, 17, 31}, m_texto{232, 226, 244}, m_corCursor{255, 180, 110};
    QString m_formaCursor = QStringLiteral("barra");
    qreal m_opacidade = 0.92;
    int m_margem = 12;
    bool m_completo = false;

    QString m_titulo, m_tituloParcial, m_pasta, m_programa;
    QString m_preEdicao;
};
