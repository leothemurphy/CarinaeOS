// SPDX-License-Identifier: GPL-2.0-or-later
#include "catalogo.h"

#include <QCollator>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocale>
#include <QProcess>
#include <QSet>
#include <QStandardPaths>
#include <QTextStream>
#include <QUrl>

#include <cmath>

#include <algorithm>

static const QStringList NOSSOS_AMBIENTES = {QStringLiteral("CarinaeOS"), QStringLiteral("KDE")};

Catalogo *Catalogo::instancia() {
    static Catalogo *c = new Catalogo;
    return c;
}

Catalogo::Catalogo(QObject *parent) : QObject(parent) {
    m_atraso.setSingleShot(true);
    m_atraso.setInterval(1500);
    connect(&m_atraso, &QTimer::timeout, this, &Catalogo::recarregar);
    lerUso();
    recarregar();
}

QStringList Catalogo::pastasAplicativos() {
    QStringList dados;
    const QString casa = QDir::homePath();
    QString xdgHome = qEnvironmentVariable("XDG_DATA_HOME");
    if (xdgHome.isEmpty()) xdgHome = casa + QStringLiteral("/.local/share");
    dados << xdgHome;
    dados << casa + QStringLiteral("/.local/share/flatpak/exports/share");
    QString xdgDirs = qEnvironmentVariable("XDG_DATA_DIRS");
    if (xdgDirs.isEmpty()) xdgDirs = QStringLiteral("/usr/local/share:/usr/share");
    dados << xdgDirs.split(QLatin1Char(':'), Qt::SkipEmptyParts);
    dados << QStringLiteral("/var/lib/flatpak/exports/share") << QStringLiteral("/usr/local/share") << QStringLiteral("/usr/share");
    QStringList r;
    for (const QString &d : std::as_const(dados)) {
        const QString p = QDir::cleanPath(d + QStringLiteral("/applications"));
        if (!r.contains(p) && QFileInfo(p).isDir()) r << p;
    }
    return r;
}

// --- leitura de .desktop (especificação freedesktop) -------------------------------------
static QString desescapar(const QString &s) {
    QString r;
    r.reserve(s.size());
    for (int i = 0; i < s.size(); ++i) {
        if (s[i] == QLatin1Char('\\') && i + 1 < s.size()) {
            const QChar n = s[++i];
            if (n == QLatin1Char('s')) r += QLatin1Char(' ');
            else if (n == QLatin1Char('n')) r += QLatin1Char('\n');
            else if (n == QLatin1Char('t')) r += QLatin1Char('\t');
            else if (n == QLatin1Char('r')) r += QLatin1Char('\r');
            else if (n == QLatin1Char(';')) r += QStringLiteral("\\;");
            else r += n;
        } else {
            r += s[i];
        }
    }
    return r;
}

static QStringList lista(const QString &s) {
    QStringList r;
    QString atual;
    for (int i = 0; i < s.size(); ++i) {
        if (s[i] == QLatin1Char('\\') && i + 1 < s.size() && s[i + 1] == QLatin1Char(';')) { atual += QLatin1Char(';'); ++i; }
        else if (s[i] == QLatin1Char(';')) { if (!atual.isEmpty()) r << atual; atual.clear(); }
        else atual += s[i];
    }
    if (!atual.isEmpty()) r << atual;
    return r;
}

struct Grupo {
    QHash<QString, QString> v;
    QString loc(const QString &chave) const {
        static const QString idioma = QLocale::system().name();                  // pt_BR
        static const QString curto = idioma.section(QLatin1Char('_'), 0, 0);     // pt
        for (const QString &l : {idioma, curto}) {
            auto it = v.constFind(chave + QLatin1Char('[') + l + QLatin1Char(']'));
            if (it != v.constEnd() && !it->isEmpty()) return desescapar(*it);
        }
        return desescapar(v.value(chave));
    }
    QString cru(const QString &chave) const { return v.value(chave); }
    bool sim(const QString &chave) const { return v.value(chave).trimmed().toLower() == QLatin1String("true"); }
};

static bool lerGrupos(const QString &caminho, QHash<QString, Grupo> &grupos) {
    QFile f(caminho);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return false;
    QTextStream in(&f);
    QString grupo;
    while (!in.atEnd()) {
        const QString linha = in.readLine().trimmed();
        if (linha.isEmpty() || linha.startsWith(QLatin1Char('#'))) continue;
        if (linha.startsWith(QLatin1Char('[')) && linha.endsWith(QLatin1Char(']'))) {
            grupo = linha.mid(1, linha.size() - 2);
            continue;
        }
        const int eq = linha.indexOf(QLatin1Char('='));
        if (eq <= 0 || grupo.isEmpty()) continue;
        if (grupo != QLatin1String("Desktop Entry") && !grupo.startsWith(QLatin1String("Desktop Action "))) continue;
        grupos[grupo].v.insert(linha.left(eq).trimmed(), linha.mid(eq + 1).trimmed());
    }
    return grupos.contains(QStringLiteral("Desktop Entry"));
}

static QStringList separarExec(const QString &exec) {
    // divide em argumentos respeitando aspas "..." e os escapes \" \` \$ \\ dentro delas
    QStringList args;
    QString atual;
    bool aspas = false, tem = false;
    for (int i = 0; i < exec.size(); ++i) {
        const QChar c = exec[i];
        if (aspas) {
            if (c == QLatin1Char('\\') && i + 1 < exec.size()) { atual += exec[++i]; }
            else if (c == QLatin1Char('"')) aspas = false;
            else atual += c;
        } else if (c == QLatin1Char('"')) { aspas = true; tem = true; }
        else if (c.isSpace()) { if (tem || !atual.isEmpty()) args << atual; atual.clear(); tem = false; }
        else if (c == QLatin1Char('\\') && i + 1 < exec.size()) { atual += exec[++i]; }
        else atual += c;
    }
    if (tem || !atual.isEmpty()) args << atual;
    return args;
}

static QString executavel(const QString &exec) {
    QStringList a = separarExec(exec);
    // "env VAR=x prog", "flatpak run x"
    while (!a.isEmpty() && (a.first() == QLatin1String("env") || a.first().contains(QLatin1Char('=')))) a.removeFirst();
    if (a.isEmpty()) return QString();
    return QFileInfo(a.first()).fileName().toLower();
}

bool Catalogo::lerDesktop(const QString &caminho, const QString &id, App &a) const {
    QHash<QString, Grupo> grupos;
    if (!lerGrupos(caminho, grupos)) return false;
    const Grupo &g = grupos[QStringLiteral("Desktop Entry")];
    if (g.cru(QStringLiteral("Type")) != QLatin1String("Application")) return false;
    a.id = id;
    a.caminho = caminho;
    a.nome = g.loc(QStringLiteral("Name"));
    a.nomeGenerico = g.loc(QStringLiteral("GenericName"));
    a.comentario = g.loc(QStringLiteral("Comment"));
    a.icone = g.cru(QStringLiteral("Icon"));
    a.exec = g.cru(QStringLiteral("Exec"));
    a.pasta = g.cru(QStringLiteral("Path"));
    a.wmClass = g.cru(QStringLiteral("StartupWMClass"));
    a.categorias = lista(g.cru(QStringLiteral("Categories")));
    a.palavras = lista(g.loc(QStringLiteral("Keywords")));
    a.terminal = g.sim(QStringLiteral("Terminal"));
    a.instalado = QFileInfo(caminho).lastModified().toMSecsSinceEpoch();
    bool vis = !g.sim(QStringLiteral("NoDisplay")) && !g.sim(QStringLiteral("Hidden")) && !a.exec.isEmpty();
    const QStringList so = lista(g.cru(QStringLiteral("OnlyShowIn")));
    const QStringList nao = lista(g.cru(QStringLiteral("NotShowIn")));
    if (!so.isEmpty()) {
        bool algum = false;
        for (const QString &n : NOSSOS_AMBIENTES) algum |= so.contains(n);
        vis &= algum;
    }
    for (const QString &n : nao) if (n == QLatin1String("CarinaeOS")) vis = false;
    const QString tryExec = g.cru(QStringLiteral("TryExec"));
    if (vis && !tryExec.isEmpty()) {
        vis = tryExec.startsWith(QLatin1Char('/')) ? QFileInfo(tryExec).isExecutable()
                                                    : !QStandardPaths::findExecutable(tryExec).isEmpty();
    }
    a.visivel = vis;
    for (const QString &acao : lista(g.cru(QStringLiteral("Actions")))) {
        const Grupo &ga = grupos.value(QStringLiteral("Desktop Action ") + acao);
        if (ga.cru(QStringLiteral("Exec")).isEmpty()) continue;
        a.acoes.append({acao, ga.loc(QStringLiteral("Name")), ga.cru(QStringLiteral("Icon")), ga.cru(QStringLiteral("Exec"))});
    }
    return true;
}

void Catalogo::recarregar() {
    m_todos.clear();
    m_porId.clear();
    m_porCaminho.clear();
    m_porClasse.clear();
    QSet<QString> vistos;
    for (const QString &pasta : pastasAplicativos()) {
        QDirIterator it(pasta, {QStringLiteral("*.desktop")}, QDir::Files | QDir::Readable, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            const QString caminho = it.next();
            QString id = QDir(pasta).relativeFilePath(caminho);
            id.replace(QLatin1Char('/'), QLatin1Char('-'));
            if (vistos.contains(id)) continue;        // a primeira pasta tem prioridade (~/.local primeiro)
            vistos.insert(id);
            App a;
            if (!lerDesktop(caminho, id, a)) continue;
            m_todos.append(a);
        }
    }
    QCollator col(QLocale::system());
    col.setCaseSensitivity(Qt::CaseInsensitive);
    col.setNumericMode(true);
    std::sort(m_todos.begin(), m_todos.end(), [&col](const App &x, const App &y) { return col.compare(x.nome, y.nome) < 0; });
    m_visiveis.clear();
    for (int i = 0; i < m_todos.size(); ++i) {
        const App &a = m_todos[i];
        m_porId.insert(a.id.toLower(), i);
        m_porCaminho.insert(a.caminho, i);
        if (a.visivel) m_visiveis.append(a);
    }
    // o executável só identifica um aplicativo se mais nenhum o usar
    // (vários .desktop com "flatpak run", "env", "python3"... não dizem nada)
    QHash<QString, int> usosExec;
    for (const App &a : std::as_const(m_todos)) usosExec[executavel(a.exec)]++;
    static const QSet<QString> genericos = {QStringLiteral("flatpak"), QStringLiteral("snap"), QStringLiteral("sh"),
        QStringLiteral("bash"), QStringLiteral("python3"), QStringLiteral("python"), QStringLiteral("java"),
        QStringLiteral("wine"), QStringLiteral("electron"), QStringLiteral("xdg-open"), QStringLiteral("gtk-launch"),
        QStringLiteral("kioclient"), QStringLiteral("kioclient5"), QStringLiteral("kde-open"), QStringLiteral("perl")};
    // para reconhecer as janelas: primeiro os visíveis (ganham), depois os escondidos
    for (int passo = 0; passo < 2; ++passo) {
        for (const App &a : std::as_const(m_todos)) {
            if (a.visivel != (passo == 0)) continue;
            auto por = [&](const QString &k) {
                const QString c = k.toLower();
                if (!c.isEmpty() && !m_porClasse.contains(c)) m_porClasse.insert(c, a.id);
            };
            por(a.wmClass);
            QString base = a.id;
            base.chop(8);   // ".desktop"
            por(base);
            por(base.section(QLatin1Char('.'), -1));
            const QString ex = executavel(a.exec);
            if (usosExec.value(ex) == 1 && !genericos.contains(ex)) por(ex);
        }
    }
    vigiar();
    Q_EMIT mudou();
}

void Catalogo::vigiar() {
    if (!m_vigia) {
        m_vigia = new QFileSystemWatcher(this);
        connect(m_vigia, &QFileSystemWatcher::directoryChanged, this, [this] { m_atraso.start(); });
    }
    QStringList dirs;
    for (const QString &p : pastasAplicativos()) {
        dirs << p;
        QDirIterator it(p, QDir::Dirs | QDir::NoDotAndDotDot, QDirIterator::Subdirectories);
        while (it.hasNext()) dirs << it.next();
    }
    // as pastas que ainda não existem (a primeira app Flatpak cria ~/.local/share/flatpak/exports/...,
    // /var/lib/flatpak/exports/...): vigia-se a pasta-mãe mais próxima, para dar pela criação
    const QString casa = QDir::homePath();
    for (const QString &falta : {casa + QStringLiteral("/.local/share/applications"),
                                 casa + QStringLiteral("/.local/share/flatpak/exports/share/applications"),
                                 QStringLiteral("/var/lib/flatpak/exports/share/applications")}) {
        QString p = falta;
        while (!p.isEmpty() && p != QStringLiteral("/") && !QFileInfo(p).isDir()) p = QFileInfo(p).path();
        if (!p.isEmpty() && p != QStringLiteral("/") && !dirs.contains(p)) dirs << p;
    }
    const QStringList atuais = m_vigia->directories();
    for (const QString &d : std::as_const(dirs))
        if (!atuais.contains(d)) m_vigia->addPath(d);
}

const App *Catalogo::porId(const QString &id) const {
    auto it = m_porId.constFind(id.toLower());
    if (it == m_porId.constEnd()) {
        if (!id.endsWith(QLatin1String(".desktop"))) return porId(id + QStringLiteral(".desktop"));
        return nullptr;
    }
    return &m_todos[*it];
}

const App *Catalogo::porCaminho(const QString &caminho) const {
    auto it = m_porCaminho.constFind(caminho);
    return it == m_porCaminho.constEnd() ? nullptr : &m_todos[*it];
}

QString Catalogo::idDeUrl(const QString &url) const {
    QString u = url.trimmed();
    if (u.startsWith(QLatin1String("applications:"))) return u.mid(13);
    if (u.startsWith(QLatin1String("file://"))) {
        const QString caminho = QUrl(u).toLocalFile();
        if (const App *a = porCaminho(caminho)) return a->id;
        return QFileInfo(caminho).fileName();
    }
    if (u.startsWith(QLatin1Char('/'))) {
        if (const App *a = porCaminho(u)) return a->id;
        return QFileInfo(u).fileName();
    }
    return u;
}

QString Catalogo::idParaJanela(const QString &instancia, const QString &classe, const QString &dica) const {
    if (!dica.isEmpty()) {
        QString d = dica;
        if (d.startsWith(QLatin1Char('/'))) { if (const App *a = porCaminho(d)) return a->id; d = QFileInfo(d).fileName(); }
        if (const App *a = porId(d)) return a->id;
    }
    for (const QString &k : {classe, instancia}) {
        const QString c = k.toLower();
        if (c.isEmpty()) continue;
        auto it = m_porClasse.constFind(c);
        if (it != m_porClasse.constEnd()) return *it;
        if (const App *a = porId(c)) return a->id;
    }
    // "Google-chrome" -> "google-chrome-stable", "org.kde.dolphin" ...
    const QString c = classe.toLower();
    if (!c.isEmpty()) {
        for (const App &a : m_visiveis)
            if (a.id.toLower().startsWith(c) || a.wmClass.toLower() == c) return a.id;
    }
    return QString();
}

// --- abrir ---------------------------------------------------------------------------------
qint64 Catalogo::executarExec(const QString &exec, const App *a, const QStringList &urls) {
    QStringList args;
    bool usouUrls = false;
    for (const QString &arg : separarExec(exec)) {
        if (arg == QLatin1String("%f") || arg == QLatin1String("%u")) {
            if (!urls.isEmpty()) {
                args << (arg == QLatin1String("%f") && urls.first().startsWith(QLatin1String("file://")) ? QUrl(urls.first()).toLocalFile() : urls.first());
                usouUrls = true;
            }
            continue;
        }
        if (arg == QLatin1String("%F") || arg == QLatin1String("%U")) {
            for (const QString &u : urls) args << (arg == QLatin1String("%F") && u.startsWith(QLatin1String("file://")) ? QUrl(u).toLocalFile() : u);
            usouUrls = true;
            continue;
        }
        if (arg == QLatin1String("%i")) {
            if (a && !a->icone.isEmpty()) args << QStringLiteral("--icon") << a->icone;
            continue;
        }
        QString x = arg;
        x.replace(QLatin1String("%c"), a ? a->nome : QString());
        x.replace(QLatin1String("%k"), a ? a->caminho : QString());
        for (const char *velho : {"%d", "%D", "%n", "%N", "%v", "%m"}) x.remove(QLatin1String(velho));
        x.replace(QLatin1String("%%"), QLatin1String("%"));
        if (!x.isEmpty() || arg.isEmpty()) args << x;
    }
    Q_UNUSED(usouUrls)
    if (args.isEmpty()) return 0;
    if (a && a->terminal) {
        QString term = QStandardPaths::findExecutable(QStringLiteral("carinae-terminal"));
        if (term.isEmpty()) term = QStandardPaths::findExecutable(QStringLiteral("x-terminal-emulator"));
        if (term.isEmpty()) term = QStandardPaths::findExecutable(QStringLiteral("konsole"));
        if (!term.isEmpty()) args = QStringList{term, QStringLiteral("-e")} + args;
    }
    const QString prog = args.takeFirst();
    QString pasta = a && !a->pasta.isEmpty() ? a->pasta : QDir::homePath();
    qint64 pid = 0;
    if (!QProcess::startDetached(prog, args, pasta, &pid)) {
        qWarning("CarinaeOS: não consegui abrir %s", qPrintable(prog));
        return 0;
    }
    return pid;
}

qint64 Catalogo::lancar(const QString &id, const QString &acao, const QStringList &urls) {
    const App *a = porId(id);
    if (!a) return 0;
    QString exec = a->exec;
    if (!acao.isEmpty()) {
        for (const AcaoApp &x : a->acoes)
            if (x.id == acao) { exec = x.exec; break; }
    }
    const QString ident = a->id;
    const qint64 pid = executarExec(exec, a, urls);
    if (pid) registarUso(ident);
    return pid;
}

qint64 Catalogo::lancarArquivo(const QString &caminhoDesktop) {
    if (const App *a = porCaminho(caminhoDesktop)) return lancar(a->id);
    App tmp;
    if (!lerDesktop(caminhoDesktop, QFileInfo(caminhoDesktop).fileName(), tmp)) return 0;
    return executarExec(tmp.exec, &tmp, {});
}

// --- uso (para "Mais usados") ------------------------------------------------------------
static QString arquivoUso() {
    return QDir::homePath() + QStringLiteral("/.local/share/carinaeos/usados.json");
}

void Catalogo::lerUso() {
    QFile f(arquivoUso());
    if (!f.open(QIODevice::ReadOnly)) return;
    const QJsonObject o = QJsonDocument::fromJson(f.readAll()).object();
    for (auto it = o.begin(); it != o.end(); ++it) {
        const QJsonObject v = it.value().toObject();
        m_uso.insert(it.key(), {v.value(QStringLiteral("n")).toInt(), qint64(v.value(QStringLiteral("t")).toDouble())});
    }
}

void Catalogo::gravarUso() {
    QJsonObject o;
    for (auto it = m_uso.constBegin(); it != m_uso.constEnd(); ++it)
        o.insert(it.key(), QJsonObject{{QStringLiteral("n"), it->first}, {QStringLiteral("t"), double(it->second)}});
    QDir().mkpath(QFileInfo(arquivoUso()).absolutePath());
    QFile f(arquivoUso());
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) f.write(QJsonDocument(o).toJson(QJsonDocument::Compact));
}

void Catalogo::registarUso(const QString &id) {
    auto &u = m_uso[id];
    u.first += 1;
    u.second = QDateTime::currentMSecsSinceEpoch();
    gravarUso();
    Q_EMIT usoMudou();
}

QVector<QPair<QString, int>> Catalogo::maisUsados() const {
    QVector<QPair<QString, int>> r;
    const qint64 agora = QDateTime::currentMSecsSinceEpoch();
    QVector<QPair<double, QString>> pontos;
    for (auto it = m_uso.constBegin(); it != m_uso.constEnd(); ++it) {
        if (!porId(it.key())) continue;
        // as vezes contam, mas o uso recente pesa mais (meia-vida de 30 dias)
        const double dias = double(agora - it->second) / 86400000.0;
        pontos.append({it->first * std::pow(0.5, dias / 30.0) + 0.001 * it->first, it.key()});
    }
    std::sort(pontos.begin(), pontos.end(), [](auto &a, auto &b) { return a.first > b.first; });
    for (auto &p : pontos) r.append({p.second, m_uso.value(p.second).first});
    return r;
}

// --- categorias (os mesmos nomes do menu do KDE em português, para os ambientes do lançador
// continuarem a bater certo com ~/.config/carinaeos-cartoes.json) ---------------------------
struct Cat { const char *xdg; const char *nome; const char *icone; };
static const Cat CATS[] = {
    {"Development", "Desenvolvimento", "applications-development"},
    {"Education", "Educação", "applications-education"},
    {"Science", "Educação", "applications-education"},
    {"Game", "Jogos", "applications-games"},
    {"Graphics", "Gráficos", "applications-graphics"},
    {"Network", "Internet", "applications-internet"},
    {"AudioVideo", "Multimídia", "applications-multimedia"},
    {"Audio", "Multimídia", "applications-multimedia"},
    {"Video", "Multimídia", "applications-multimedia"},
    {"Office", "Escritório", "applications-office"},
    {"Settings", "Configurações", "preferences-system"},
    {"System", "Sistema", "applications-system"},
    {"Utility", "Utilitários", "applications-utilities"},
    {"Help", "Ajuda", "help-browser"},
    {"Documentation", "Ajuda", "help-browser"},
};

QString Catalogo::nomeCategoria(const App &a, QString *icone) {
    for (const Cat &c : CATS) {
        if (a.categorias.contains(QLatin1String(c.xdg))) {
            if (icone) *icone = QLatin1String(c.icone);
            return QString::fromUtf8(c.nome);
        }
    }
    if (icone) *icone = QStringLiteral("applications-other");
    return QStringLiteral("Perdidos e achados");
}

QStringList Catalogo::categoriasPrincipais(const App &a) {
    return {nomeCategoria(a)};
}
