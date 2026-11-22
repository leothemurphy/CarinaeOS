// SPDX-License-Identifier: GPL-2.0-or-later
#include "bandeja.h"
#include "vigia.h"

#include <QAction>
#include <QBuffer>
#include <QCoreApplication>
#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusMetaType>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusServiceWatcher>
#include <QDateTime>
#include <QDir>
#include <QDirIterator>
#include <QTimer>
#include <QUrl>
#include <functional>
#include <QFileInfo>
#include <QIcon>
#include <QImage>
#include <QMenu>
#include <QPointer>
#include <QRegularExpression>
#include <QtEndian>

#include <unistd.h>

static const char *IFACE_ITEM = "org.kde.StatusNotifierItem";
static const char *IFACE_VIGIA = "org.kde.StatusNotifierWatcher";
static const char *IFACE_MENU = "com.canonical.dbusmenu";

// -------------------------------------------------------------------------------------- bandeja
Bandeja *Bandeja::instancia() {
    static Bandeja *b = new Bandeja;
    return b;
}

Bandeja *Bandeja::create(QQmlEngine *, QJSEngine *) {
    Bandeja *b = instancia();
    QJSEngine::setObjectOwnership(b, QJSEngine::CppOwnership);
    return b;
}

Bandeja::Bandeja(QObject *parent) : QObject(parent) {
    iniciar();
}

void Bandeja::iniciar() {
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) return;
    bus.registerService(QStringLiteral("org.kde.StatusNotifierHost-%1").arg(::getpid()));
    if (m_vigia) return;

    if (!m_vigia && bus.registerService(QString::fromLatin1(IFACE_VIGIA))) {
        // ninguém fazia de "vigia": passamos a ser nós
        m_vigia = new Vigia(this);
        bus.registerObject(QStringLiteral("/StatusNotifierWatcher"), m_vigia,
                           QDBusConnection::ExportAllSlots | QDBusConnection::ExportAllSignals | QDBusConnection::ExportAllProperties);
        connect(m_vigia, &Vigia::StatusNotifierItemRegistered, this, &Bandeja::registado);
        connect(m_vigia, &Vigia::StatusNotifierItemUnregistered, this, &Bandeja::desregistado);
        qInfo("Aurora: bandeja pronta (somos o StatusNotifierWatcher)");
        return;
    }
    // outro programa já é o vigia (normalmente o carinae-vigia-bandeja): somos só o "host".
    // Se ele desaparecer, a Aurora passa a fazer de vigia; se voltar a aparecer, relê-se a lista.
    if (!m_olhoVigia) {
        m_olhoVigia = new QDBusServiceWatcher(QString::fromLatin1(IFACE_VIGIA), bus, QDBusServiceWatcher::WatchForOwnerChange, this);
        connect(m_olhoVigia, &QDBusServiceWatcher::serviceOwnerChanged, this, [this](const QString &, const QString &, const QString &novo) {
            if (m_vigia) return;
            QTimer::singleShot(novo.isEmpty() ? 300 : 500, this, [this] { iniciar(); });
        });
    }
    if (!m_ligadoAoVigia) {
        m_ligadoAoVigia = true;
        bus.connect(QString::fromLatin1(IFACE_VIGIA), QStringLiteral("/StatusNotifierWatcher"), QString::fromLatin1(IFACE_VIGIA),
                    QStringLiteral("StatusNotifierItemRegistered"), this, SLOT(registado(QString)));
        bus.connect(QString::fromLatin1(IFACE_VIGIA), QStringLiteral("/StatusNotifierWatcher"), QString::fromLatin1(IFACE_VIGIA),
                    QStringLiteral("StatusNotifierItemUnregistered"), this, SLOT(desregistado(QString)));
    }
    QDBusMessage m = QDBusMessage::createMethodCall(QString::fromLatin1(IFACE_VIGIA), QStringLiteral("/StatusNotifierWatcher"),
                                                    QString::fromLatin1(IFACE_VIGIA), QStringLiteral("RegisterStatusNotifierHost"));
    m << QStringLiteral("org.kde.StatusNotifierHost-%1").arg(::getpid());
    bus.asyncCall(m);
    QDBusMessage p = QDBusMessage::createMethodCall(QString::fromLatin1(IFACE_VIGIA), QStringLiteral("/StatusNotifierWatcher"),
                                                    QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("Get"));
    p << QString::fromLatin1(IFACE_VIGIA) << QStringLiteral("RegisteredStatusNotifierItems");
    auto *w = new QDBusPendingCallWatcher(bus.asyncCall(p), this);
    connect(w, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *w) {
        w->deleteLater();
        QDBusPendingReply<QDBusVariant> r = *w;
        if (r.isError()) return;
        for (const QString &s : r.value().variant().toStringList()) registado(s);
    });
    qInfo("Aurora: bandeja pronta (host de outro StatusNotifierWatcher)");
}

void Bandeja::registado(const QString &chave) {
    if (m_itens.contains(chave)) return;
    Item it;
    const int barra = chave.indexOf(QLatin1Char('/'));
    it.servico = barra > 0 ? chave.left(barra) : chave;
    it.caminho = barra > 0 ? chave.mid(barra) : QStringLiteral("/StatusNotifierItem");
    m_itens.insert(chave, it);
    m_ordem << chave;

    QDBusConnection bus = QDBusConnection::sessionBus();
    for (const char *sinal : {"NewIcon", "NewAttentionIcon", "NewOverlayIcon", "NewTitle", "NewToolTip"})
        bus.connect(it.servico, it.caminho, QString::fromLatin1(IFACE_ITEM), QString::fromLatin1(sinal), this, SLOT(mudou()));
    bus.connect(it.servico, it.caminho, QString::fromLatin1(IFACE_ITEM), QStringLiteral("NewStatus"), this, SLOT(mudou()));
    ler(chave);
}

void Bandeja::desregistado(const QString &chave) {
    if (!m_itens.remove(chave)) return;
    m_ordem.removeAll(chave);
    Q_EMIT itensChanged();
}

void Bandeja::mudou() {
    // o sinal chega do nome único (":1.x") e não do nome com que o app se registou:
    // relê-se tudo (são poucos ícones), juntando várias mudanças seguidas numa só leitura
    if (!m_releitura) {
        m_releitura = new QTimer(this);
        m_releitura->setSingleShot(true);
        m_releitura->setInterval(150);
        connect(m_releitura, &QTimer::timeout, this, [this] { for (const QString &k : m_ordem) ler(k); });
    }
    m_releitura->start();
}

// ---- ler as propriedades de um item ------------------------------------------------------------
static QImage melhorPixmap(const QDBusArgument &arg) {
    QImage melhor;
    arg.beginArray();
    while (!arg.atEnd()) {
        int w = 0, h = 0;
        QByteArray dados;
        arg.beginStructure();
        arg >> w >> h >> dados;
        arg.endStructure();
        if (w <= 0 || h <= 0 || dados.size() < w * h * 4) continue;
        // escolhe o maior até 64 px (ou o maior de todos se forem todos pequenos)
        if (!melhor.isNull() && !(w > melhor.width() && (w <= 64 || melhor.width() < 22))) continue;
        QImage img(w, h, QImage::Format_ARGB32);
        const uchar *p = reinterpret_cast<const uchar *>(dados.constData());
        for (int y = 0; y < h; ++y) {
            QRgb *linha = reinterpret_cast<QRgb *>(img.scanLine(y));
            for (int x = 0; x < w; ++x) linha[x] = qFromBigEndian<quint32>(p + (y * w + x) * 4);   // ARGB em ordem de rede
        }
        melhor = img;
    }
    arg.endArray();
    return melhor;
}

static QString urlDeImagem(const QImage &img) {
    QByteArray png;
    QBuffer b(&png);
    b.open(QIODevice::WriteOnly);
    img.save(&b, "PNG");
    return QStringLiteral("data:image/png;base64,") + QString::fromLatin1(png.toBase64());
}

static QString procurarNoTema(const QString &pasta, const QString &nome) {
    if (pasta.isEmpty() || nome.isEmpty()) return QString();
    for (const char *ext : {".png", ".svg", ".xpm"}) {
        const QString f = pasta + QLatin1Char('/') + nome + QString::fromLatin1(ext);
        if (QFileInfo::exists(f)) return f;
    }
    // às vezes vem com a estrutura de um tema (hicolor/22x22/apps/…)
    QDirIterator it(pasta, {nome + QStringLiteral(".png"), nome + QStringLiteral(".svg")}, QDir::Files, QDirIterator::Subdirectories);
    QString maior;
    while (it.hasNext()) maior = it.next();
    return maior;
}

void Bandeja::ler(const QString &chave) {
    if (!m_itens.contains(chave)) return;
    const Item base = m_itens.value(chave);
    QDBusMessage m = QDBusMessage::createMethodCall(base.servico, base.caminho, QStringLiteral("org.freedesktop.DBus.Properties"),
                                                    QStringLiteral("GetAll"));
    m << QString::fromLatin1(IFACE_ITEM);
    auto *w = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(m, 4000), this);
    connect(w, &QDBusPendingCallWatcher::finished, this, [this, chave](QDBusPendingCallWatcher *w) {
        w->deleteLater();
        QDBusPendingReply<QVariantMap> r = *w;
        if (r.isError() || !m_itens.contains(chave)) return;
        const QVariantMap p = r.value();
        Item &it = m_itens[chave];
        it.titulo = p.value(QStringLiteral("Title")).toString();
        if (it.titulo.isEmpty()) it.titulo = p.value(QStringLiteral("Id")).toString();
        it.estado = p.value(QStringLiteral("Status")).toString();
        it.temaIcones = p.value(QStringLiteral("IconThemePath")).toString();
        it.soMenu = p.value(QStringLiteral("ItemIsMenu")).toBool();
        const QVariant menu = p.value(QStringLiteral("Menu"));
        it.menu = menu.canConvert<QDBusObjectPath>() ? menu.value<QDBusObjectPath>().path() : menu.toString();

        const bool atencao = it.estado == QLatin1String("NeedsAttention");
        QString nome = p.value(QString::fromLatin1(atencao ? "AttentionIconName" : "IconName")).toString();
        if (nome.isEmpty()) nome = p.value(QStringLiteral("IconName")).toString();
        QImage img;
        const QVariant pix = p.value(QString::fromLatin1(atencao ? "AttentionIconPixmap" : "IconPixmap"));
        if (pix.canConvert<QDBusArgument>()) img = melhorPixmap(pix.value<QDBusArgument>());
        if (img.isNull() && atencao) {
            const QVariant pix2 = p.value(QStringLiteral("IconPixmap"));
            if (pix2.canConvert<QDBusArgument>()) img = melhorPixmap(pix2.value<QDBusArgument>());
        }
        it.iconeNome.clear();
        it.iconeUrl.clear();
        if (nome.startsWith(QLatin1Char('/')) && QFileInfo::exists(nome)) {
            it.iconeUrl = QUrl::fromLocalFile(nome).toString();
        } else if (!nome.isEmpty()) {
            const QString f = procurarNoTema(it.temaIcones, nome);
            if (!f.isEmpty()) it.iconeUrl = QUrl::fromLocalFile(f).toString();
            else if (!QIcon::fromTheme(nome).isNull() || img.isNull()) it.iconeNome = nome;
        }
        if (it.iconeUrl.isEmpty() && it.iconeNome.isEmpty() && !img.isNull()) it.iconeUrl = urlDeImagem(img);

        // a dica: título (e texto) do ToolTip, sem HTML
        it.dica = it.titulo;
        const QVariant dica = p.value(QStringLiteral("ToolTip"));
        if (dica.canConvert<QDBusArgument>()) {
            const QDBusArgument a = dica.value<QDBusArgument>();
            QString icone, titulo, texto;
            a.beginStructure();
            a >> icone;
            a.beginArray();
            while (!a.atEnd()) { int w2, h2; QByteArray d; a.beginStructure(); a >> w2 >> h2 >> d; a.endStructure(); }
            a.endArray();
            a >> titulo >> texto;
            a.endStructure();
            QString t = titulo;
            if (!texto.isEmpty()) t += (t.isEmpty() ? QString() : QStringLiteral(" — ")) + texto;
            t.remove(QRegularExpression(QStringLiteral("<[^>]*>")));
            if (!t.trimmed().isEmpty()) it.dica = t.trimmed();
        }
        Q_EMIT itensChanged();
    });
}

QVariantList Bandeja::itens() const {
    QVariantList l;
    for (const QString &k : m_ordem) {
        const Item &it = m_itens[k];
        if (it.estado.isEmpty()) continue;                     // ainda não lido
        l << QVariantMap{{QStringLiteral("chave"), k}, {QStringLiteral("titulo"), it.titulo},
                         {QStringLiteral("iconeNome"), it.iconeNome}, {QStringLiteral("iconeUrl"), it.iconeUrl},
                         {QStringLiteral("estado"), it.estado}, {QStringLiteral("dica"), it.dica}};
    }
    return l;
}

// ---- cliques -----------------------------------------------------------------------------------
static QDBusMessage chamada(const QString &servico, const QString &caminho, const char *metodo) {
    return QDBusMessage::createMethodCall(servico, caminho, QString::fromLatin1(IFACE_ITEM), QString::fromLatin1(metodo));
}

void Bandeja::ativar(const QString &chave, int x, int y) {
    if (!m_itens.contains(chave)) return;
    const Item it = m_itens.value(chave);
    if (it.soMenu && !it.menu.isEmpty()) { mostrarMenu(it, x, y); return; }
    QDBusMessage m = chamada(it.servico, it.caminho, "Activate");
    m << x << y;
    auto *w = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(m), this);
    connect(w, &QDBusPendingCallWatcher::finished, this, [this, it, x, y](QDBusPendingCallWatcher *w) {
        w->deleteLater();
        if (w->isError() && !it.menu.isEmpty()) mostrarMenu(it, x, y);    // não sabe "ativar": mostra o menu
    });
}

void Bandeja::secundario(const QString &chave, int x, int y) {
    if (!m_itens.contains(chave)) return;
    const Item it = m_itens.value(chave);
    QDBusMessage m = chamada(it.servico, it.caminho, "SecondaryActivate");
    m << x << y;
    QDBusConnection::sessionBus().asyncCall(m);
}

void Bandeja::menu(const QString &chave, int x, int y) {
    if (!m_itens.contains(chave)) return;
    const Item it = m_itens.value(chave);
    if (!it.menu.isEmpty() && it.menu != QLatin1String("/NO_DBUSMENU")) { mostrarMenu(it, x, y); return; }
    QDBusMessage m = chamada(it.servico, it.caminho, "ContextMenu");
    m << x << y;
    QDBusConnection::sessionBus().asyncCall(m);
}

void Bandeja::rodar(const QString &chave, int delta) {
    if (!m_itens.contains(chave)) return;
    const Item it = m_itens.value(chave);
    QDBusMessage m = chamada(it.servico, it.caminho, "Scroll");
    m << delta << QStringLiteral("vertical");
    QDBusConnection::sessionBus().asyncCall(m);
}

// ---- o menu do app (com.canonical.dbusmenu) ------------------------------------------------------
struct NoMenu {
    int id = 0;
    QVariantMap props;
    QList<NoMenu> filhos;
};

static void lerNo(const QDBusArgument &a, NoMenu &n) {
    a.beginStructure();
    a >> n.id >> n.props;
    a.beginArray();
    while (!a.atEnd()) {
        QDBusVariant v;
        a >> v;
        NoMenu f;
        lerNo(v.variant().value<QDBusArgument>(), f);
        n.filhos << f;
    }
    a.endArray();
    a.endStructure();
}

static QString rotulo(QString t) {
    // "_Abrir" (mnemónica do dbusmenu) -> "&Abrir"; "&" literal -> "&&"
    t.replace(QLatin1Char('&'), QStringLiteral("&&"));
    QString r;
    for (int i = 0; i < t.size(); ++i) {
        if (t[i] == QLatin1Char('_')) {
            if (i + 1 < t.size() && t[i + 1] == QLatin1Char('_')) { r += QLatin1Char('_'); ++i; }
            else r += QLatin1Char('&');
        } else {
            r += t[i];
        }
    }
    return r;
}

static void encher(QMenu *menu, const QList<NoMenu> &nos, const std::function<void(int)> &clicar) {
    for (const NoMenu &n : nos) {
        if (n.props.contains(QStringLiteral("visible")) && !n.props.value(QStringLiteral("visible")).toBool()) continue;
        if (n.props.value(QStringLiteral("type")).toString() == QLatin1String("separator")) { menu->addSeparator(); continue; }
        QIcon icone;
        const QString nomeIcone = n.props.value(QStringLiteral("icon-name")).toString();
        if (!nomeIcone.isEmpty()) icone = QIcon::fromTheme(nomeIcone);
        const QByteArray dados = n.props.value(QStringLiteral("icon-data")).toByteArray();
        if (icone.isNull() && !dados.isEmpty()) icone = QIcon(QPixmap::fromImage(QImage::fromData(dados)));
        const QString texto = rotulo(n.props.value(QStringLiteral("label")).toString());
        if (!n.filhos.isEmpty() || n.props.value(QStringLiteral("children-display")).toString() == QLatin1String("submenu")) {
            QMenu *sub = menu->addMenu(icone, texto);
            encher(sub, n.filhos, clicar);
            continue;
        }
        QAction *a = menu->addAction(icone, texto);
        a->setEnabled(!n.props.contains(QStringLiteral("enabled")) || n.props.value(QStringLiteral("enabled")).toBool());
        const QString tipo = n.props.value(QStringLiteral("toggle-type")).toString();
        if (!tipo.isEmpty()) {
            a->setCheckable(true);
            a->setChecked(n.props.value(QStringLiteral("toggle-state")).toInt() == 1);
        }
        const int id = n.id;
        QObject::connect(a, &QAction::triggered, menu, [clicar, id] { clicar(id); });
    }
}

void Bandeja::mostrarMenu(const Item &it, int x, int y) {
    QDBusConnection bus = QDBusConnection::sessionBus();
    QDBusMessage antes = QDBusMessage::createMethodCall(it.servico, it.menu, QString::fromLatin1(IFACE_MENU), QStringLiteral("AboutToShow"));
    antes << 0;
    bus.asyncCall(antes);
    QDBusMessage m = QDBusMessage::createMethodCall(it.servico, it.menu, QString::fromLatin1(IFACE_MENU), QStringLiteral("GetLayout"));
    m << 0 << -1 << QStringList();
    auto *w = new QDBusPendingCallWatcher(bus.asyncCall(m, 4000), this);
    const QString servico = it.servico, caminho = it.menu;
    connect(w, &QDBusPendingCallWatcher::finished, this, [this, servico, caminho, x, y](QDBusPendingCallWatcher *w) {
        w->deleteLater();
        const QDBusMessage r = w->reply();
        if (r.type() != QDBusMessage::ReplyMessage || r.arguments().size() < 2) return;
        NoMenu raiz;
        lerNo(r.arguments().at(1).value<QDBusArgument>(), raiz);
        if (m_menuAberto) m_menuAberto->deleteLater();
        auto *menu = new QMenu;
        m_menuAberto = menu;
        menu->setAttribute(Qt::WA_DeleteOnClose);
        encher(menu, raiz.filhos, [servico, caminho](int id) {
            QDBusMessage e = QDBusMessage::createMethodCall(servico, caminho, QString::fromLatin1(IFACE_MENU), QStringLiteral("Event"));
            e << id << QStringLiteral("clicked") << QVariant::fromValue(QDBusVariant(QVariant(QString())))
              << uint(QDateTime::currentSecsSinceEpoch());
            QDBusConnection::sessionBus().asyncCall(e);
        });
        if (menu->isEmpty()) { menu->deleteLater(); m_menuAberto = nullptr; return; }
        menu->popup(QPoint(x, y));
    });
}
