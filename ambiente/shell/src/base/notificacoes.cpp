// CarinaeOS — Notificações (servidor org.freedesktop.Notifications, versão 1.2 da especificação)
// SPDX-License-Identifier: GPL-2.0-or-later
#include "notificacoes.h"

#include <QBuffer>
#include <QDateTime>
#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QImage>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocale>
#include <QProcess>
#include <QRegularExpression>
#include <QSaveFile>
#include <QStandardPaths>
#include <QTextStream>
#include <QTimer>
#include <QUrl>

static const int MAX_HISTORICO = 60;

static QString pastaCfg() { return QDir::homePath() + QStringLiteral("/.config/carinaeos"); }
static QString ficheiroNaoIncomodar() { return pastaCfg() + QStringLiteral("/nao-incomodar"); }
static QString ficheiroHistorico() {
    return QDir::homePath() + QStringLiteral("/.local/share/carinaeos/notificacoes.json");
}

Notificacoes *Notificacoes::instancia() {
    static Notificacoes *n = new Notificacoes;
    return n;
}

Notificacoes *Notificacoes::create(QQmlEngine *, QJSEngine *) {
    Notificacoes *n = instancia();
    QQmlEngine::setObjectOwnership(n, QQmlEngine::CppOwnership);
    return n;
}

Notificacoes::Notificacoes(QObject *parent) : QObject(parent) {
    m_relogio = new QTimer(this);
    m_relogio->setInterval(250);
    connect(m_relogio, &QTimer::timeout, this, &Notificacoes::expirar);

    m_gravar = new QTimer(this);
    m_gravar->setSingleShot(true);
    m_gravar->setInterval(1500);
    connect(m_gravar, &QTimer::timeout, this, &Notificacoes::gravarHistorico);

    // "Não incomodar": um ficheiro, para o Comando, a Central e os scripts mudarem à vontade
    QDir().mkpath(pastaCfg());
    m_olho = new QFileSystemWatcher(this);
    m_olho->addPath(pastaCfg());
    connect(m_olho, &QFileSystemWatcher::directoryChanged, this, &Notificacoes::lerNaoIncomodar);
    lerNaoIncomodar();
    carregarHistorico();

    new NotificacoesAdaptador(this);
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.registerObject(QStringLiteral("/org/freedesktop/Notifications"), this)) {
        QTextStream(stderr) << "Aurora: notificações — não consegui registar o objeto D-Bus\n";
        return;
    }
    // se outro servidor já estiver ligado (ex.: o do Plasma), pedimos o lugar dele
    const auto r = bus.interface()->registerService(QStringLiteral("org.freedesktop.Notifications"),
                                                    QDBusConnectionInterface::ReplaceExistingService,
                                                    QDBusConnectionInterface::AllowReplacement);
    m_servidor = r.isValid() && r.value() == QDBusConnectionInterface::ServiceRegistered;
    QTextStream(stderr) << (m_servidor ? "Aurora: notificações prontas\n"
                                       : "Aurora: notificações — outro programa já é o servidor\n");
}

void Notificacoes::lerNaoIncomodar() {
    const bool v = QFileInfo::exists(ficheiroNaoIncomodar());
    if (v == m_naoIncomodar) return;
    m_naoIncomodar = v;
    Q_EMIT naoIncomodarChanged();
}

void Notificacoes::setNaoIncomodar(bool v) {
    if (v) {
        QFile f(ficheiroNaoIncomodar());
        if (f.open(QIODevice::WriteOnly)) f.close();
    } else {
        QFile::remove(ficheiroNaoIncomodar());
    }
    lerNaoIncomodar();
}

// ---- imagens -------------------------------------------------------------------------------------
// "image-data" / "icon_data": (iiibiiay) = largura, altura, bytes por linha, tem alfa, bits, canais, dados
QString Notificacoes::imagemDeDados(const QVariant &v) {
    if (!v.canConvert<QDBusArgument>()) return {};
    const QDBusArgument arg = v.value<QDBusArgument>();
    int w = 0, h = 0, passo = 0, bits = 0, canais = 0;
    bool alfa = false;
    QByteArray dados;
    arg.beginStructure();
    arg >> w >> h >> passo >> alfa >> bits >> canais >> dados;
    arg.endStructure();
    if (w <= 0 || h <= 0 || bits != 8 || (canais != 3 && canais != 4) || dados.size() < passo * (h - 1) + w * canais)
        return {};
    QImage img(reinterpret_cast<const uchar *>(dados.constData()), w, h, passo,
               alfa ? QImage::Format_RGBA8888 : QImage::Format_RGB888);
    QImage copia = img.copy();      // os dados do D-Bus vão-se embora
    if (copia.width() > 256 || copia.height() > 256)
        copia = copia.scaled(256, 256, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    QByteArray png;
    QBuffer b(&png);
    b.open(QIODevice::WriteOnly);
    copia.save(&b, "PNG");
    return QStringLiteral("data:image/png;base64,") + QString::fromLatin1(png.toBase64());
}

static QString caminhoOuNome(const QString &s) {
    if (s.startsWith(QLatin1String("file://"))) return s;
    if (s.startsWith(QLatin1Char('/'))) return QUrl::fromLocalFile(s).toString();
    return s;                       // nome de ícone do tema
}

// lê um campo do .desktop do app (Icon, Name…), com a tradução para a língua do sistema se houver
static QString campoDoDesktop(const QString &entrada, const QString &campo) {
    if (entrada.isEmpty()) return {};
    QString nome = entrada;
    if (!nome.endsWith(QLatin1String(".desktop"))) nome += QLatin1String(".desktop");
    const QString f = QStandardPaths::locate(QStandardPaths::ApplicationsLocation, nome);
    if (f.isEmpty()) return {};
    QFile fich(f);
    if (!fich.open(QIODevice::ReadOnly | QIODevice::Text)) return {};
    const QString lingua = QLocale().name();                       // pt_BR
    const QString curta = lingua.section(QLatin1Char('_'), 0, 0);  // pt
    QString simples, traduzido, traduzidoCurto;
    bool dentro = false;
    while (!fich.atEnd()) {
        const QString l = QString::fromUtf8(fich.readLine()).trimmed();
        if (l.startsWith(QLatin1Char('['))) { if (dentro) break; dentro = (l == QLatin1String("[Desktop Entry]")); continue; }
        if (!dentro) continue;
        const int ig = l.indexOf(QLatin1Char('='));
        if (ig < 0) continue;
        const QString k = l.left(ig).trimmed(), v = l.mid(ig + 1).trimmed();
        if (k == campo) simples = v;
        else if (k == campo + QLatin1Char('[') + lingua + QLatin1Char(']')) traduzido = v;
        else if (k == campo + QLatin1Char('[') + curta + QLatin1Char(']')) traduzidoCurto = v;
    }
    return !traduzido.isEmpty() ? traduzido : !traduzidoCurto.isEmpty() ? traduzidoCurto : simples;
}
static QString iconeDoDesktop(const QString &entrada) { return campoDoDesktop(entrada, QStringLiteral("Icon")); }

// O corpo pode ter um pouco de HTML (<b>, <i>, <u>, <a href>); o resto sai.
QString Notificacoes::limparCorpo(QString c) {
    c.replace(QRegularExpression(QStringLiteral("<img[^>]*>"), QRegularExpression::CaseInsensitiveOption), QString());
    c.replace(QRegularExpression(QStringLiteral("<(?!/?(b|i|u|a)(\\s|>|$))[^>]*>"),
                                 QRegularExpression::CaseInsensitiveOption), QString());
    c.replace(QLatin1Char('\n'), QStringLiteral("<br>"));
    return c.trimmed();
}

// ---- receber ---------------------------------------------------------------------------------------
uint Notificacoes::notify(const QString &app, uint substitui, const QString &icone, const QString &titulo,
                          const QString &corpo, const QStringList &acoes, const QVariantMap &dicas, int expira) {
    uint id = substitui;
    int pos = -1;
    if (id) {
        for (int i = 0; i < m_ativas.size(); ++i)
            if (m_ativas.at(i).toMap().value(QStringLiteral("id")).toUInt() == id) { pos = i; break; }
    }
    if (!id) id = m_proximo++;
    if (m_proximo == 0) m_proximo = 1;

    const int urgencia = dicas.contains(QStringLiteral("urgency")) ? dicas.value(QStringLiteral("urgency")).toInt() : 1;
    const QString entrada = dicas.value(QStringLiteral("desktop-entry")).toString();

    QString imagem;
    for (const char *k : {"image-data", "image_data", "icon_data"})
        if (imagem.isEmpty() && dicas.contains(QLatin1String(k))) imagem = imagemDeDados(dicas.value(QLatin1String(k)));
    for (const char *k : {"image-path", "image_path"})
        if (imagem.isEmpty() && dicas.contains(QLatin1String(k)))
            imagem = caminhoOuNome(dicas.value(QLatin1String(k)).toString());

    QString ic = caminhoOuNome(icone);
    if (ic.isEmpty()) ic = iconeDoDesktop(entrada);
    if (ic.isEmpty()) ic = QStringLiteral("dialog-information");
    // uma imagem "de ícone" (o app mandou o logótipo como imagem) passa a ícone
    if (imagem.isEmpty() && ic.startsWith(QLatin1String("file://"))) { imagem = ic; ic = iconeDoDesktop(entrada); }

    QVariantList botoes;
    for (int i = 0; i + 1 < acoes.size(); i += 2) {
        if (acoes.at(i) == QLatin1String("default")) continue;      // o clique no próprio aviso
        botoes << QVariantMap{{QStringLiteral("chave"), acoes.at(i)}, {QStringLiteral("texto"), acoes.at(i + 1)}};
    }
    QString nomeApp = app;
    if ((nomeApp.isEmpty() || nomeApp == entrada) && !entrada.isEmpty()) {
        nomeApp = campoDoDesktop(entrada, QStringLiteral("Name"));
        if (nomeApp.isEmpty()) nomeApp = entrada;
    }

    QVariantMap n{
        {QStringLiteral("id"), id},
        {QStringLiteral("app"), nomeApp},
        {QStringLiteral("icone"), ic},
        {QStringLiteral("imagem"), imagem},
        {QStringLiteral("titulo"), titulo},
        {QStringLiteral("corpo"), limparCorpo(corpo)},
        {QStringLiteral("acoes"), botoes},
        {QStringLiteral("temPadrao"), acoes.contains(QStringLiteral("default"))},
        {QStringLiteral("residente"), dicas.value(QStringLiteral("resident")).toBool()},
        {QStringLiteral("urgencia"), urgencia},
        {QStringLiteral("hora"), QDateTime::currentMSecsSinceEpoch()},
    };

    // aparece no ecrã? (em "não incomodar" só os urgentes)
    const bool mostrar = !m_naoIncomodar || urgencia >= 2;
    if (mostrar) {
        if (pos >= 0) m_ativas[pos] = n;
        else m_ativas.prepend(n);
        while (m_ativas.size() > 6) {                       // os mais antigos saem
            const uint velho = m_ativas.last().toMap().value(QStringLiteral("id")).toUInt();
            m_ativas.removeLast();
            m_expiraEm.remove(velho);
            Q_EMIT notificationClosed(velho, 1);
        }
        qint64 ms = expira;
        if (expira < 0) ms = urgencia >= 2 ? 0 : urgencia == 0 ? 4000 : 6500;
        else if (expira > 0 && expira < 3000) ms = 3000;
        m_expiraEm[id] = ms ? QDateTime::currentMSecsSinceEpoch() + ms : 0;
        if (!m_relogio->isActive()) m_relogio->start();
        Q_EMIT ativasChanged();
    }

    // histórico (os "transient" e os do próprio progresso não ficam)
    if (!dicas.value(QStringLiteral("transient")).toBool()) {
        QVariantMap h = n;
        if (imagem.startsWith(QLatin1String("data:"))) h.remove(QStringLiteral("imagem"));   // não guarda imagens grandes
        h.remove(QStringLiteral("acoes"));
        for (int i = 0; i < m_historico.size(); ++i)
            if (m_historico.at(i).toMap().value(QStringLiteral("id")).toUInt() == id) { m_historico.removeAt(i); break; }
        m_historico.prepend(h);
        while (m_historico.size() > MAX_HISTORICO) m_historico.removeLast();
        Q_EMIT historicoChanged();
        m_gravar->start();
    }

    // som: só quando o app pede um (e nunca em "não incomodar" nem com "suppress-sound")
    if (mostrar && !m_naoIncomodar && !dicas.value(QStringLiteral("suppress-sound")).toBool()) {
        const QString ficheiro = dicas.value(QStringLiteral("sound-file")).toString();
        const QString nome = dicas.value(QStringLiteral("sound-name")).toString();
        if (!ficheiro.isEmpty()) QProcess::startDetached(QStringLiteral("paplay"), {ficheiro});
        else if (!nome.isEmpty()) QProcess::startDetached(QStringLiteral("canberra-gtk-play"), {QStringLiteral("-i"), nome});
    }
    return id;
}

void Notificacoes::retirar(uint id, uint motivo) {
    for (int i = 0; i < m_ativas.size(); ++i) {
        if (m_ativas.at(i).toMap().value(QStringLiteral("id")).toUInt() == id) {
            m_ativas.removeAt(i);
            m_expiraEm.remove(id);
            m_seguro.remove(id);
            Q_EMIT ativasChanged();
            Q_EMIT notificationClosed(id, motivo);
            return;
        }
    }
}

void Notificacoes::expirar() {
    const qint64 agora = QDateTime::currentMSecsSinceEpoch();
    QList<uint> fora;
    for (auto it = m_expiraEm.cbegin(); it != m_expiraEm.cend(); ++it) {
        if (!it.value() || m_seguro.value(it.key())) continue;
        if (it.value() <= agora) fora << it.key();
    }
    for (uint id : fora) retirar(id, 1);
    if (m_ativas.isEmpty()) m_relogio->stop();
}

void Notificacoes::segurar(uint id, bool rato) {
    m_seguro[id] = rato;
    // ao tirar o rato, dá mais uns segundos para acabar de ler
    if (!rato && m_expiraEm.value(id))
        m_expiraEm[id] = qMax(m_expiraEm.value(id), QDateTime::currentMSecsSinceEpoch() + 2500);
}

void Notificacoes::fechar(uint id) { retirar(id, 2); }

void Notificacoes::closeNotification(uint id) { retirar(id, 3); }

void Notificacoes::acao(uint id, const QString &chave) {
    Q_EMIT actionInvoked(id, chave);
    bool residente = false;
    for (const QVariant &v : std::as_const(m_ativas))
        if (v.toMap().value(QStringLiteral("id")).toUInt() == id) residente = v.toMap().value(QStringLiteral("residente")).toBool();
    if (!residente) retirar(id, 2);
}

void Notificacoes::apagarDoHistorico(uint id) {
    for (int i = 0; i < m_historico.size(); ++i)
        if (m_historico.at(i).toMap().value(QStringLiteral("id")).toUInt() == id) {
            m_historico.removeAt(i);
            Q_EMIT historicoChanged();
            m_gravar->start();
            return;
        }
}

void Notificacoes::limparHistorico() {
    m_historico.clear();
    Q_EMIT historicoChanged();
    m_gravar->start();
}

// ---- histórico em disco ----------------------------------------------------------------------------
void Notificacoes::gravarHistorico() {
    QDir().mkpath(QFileInfo(ficheiroHistorico()).absolutePath());
    QSaveFile f(ficheiroHistorico());
    if (!f.open(QIODevice::WriteOnly)) return;
    f.write(QJsonDocument(QJsonArray::fromVariantList(m_historico)).toJson(QJsonDocument::Compact));
    if (f.commit()) QFile::setPermissions(ficheiroHistorico(), QFile::ReadOwner | QFile::WriteOwner);
}

void Notificacoes::carregarHistorico() {
    QFile f(ficheiroHistorico());
    if (!f.open(QIODevice::ReadOnly)) return;
    m_historico = QJsonDocument::fromJson(f.readAll()).array().toVariantList();
    // os números continuam depois dos que estão no histórico (para não confundir os apps)
    for (const QVariant &v : std::as_const(m_historico))
        m_proximo = qMax(m_proximo, v.toMap().value(QStringLiteral("id")).toUInt() + 1);
}

// ---- adaptador D-Bus ---------------------------------------------------------------------------------
NotificacoesAdaptador::NotificacoesAdaptador(Notificacoes *n) : QDBusAbstractAdaptor(n), m_n(n) {
    setAutoRelaySignals(false);
    connect(n, &Notificacoes::notificationClosed, this, &NotificacoesAdaptador::NotificationClosed);
    connect(n, &Notificacoes::actionInvoked, this, &NotificacoesAdaptador::ActionInvoked);
    connect(n, &Notificacoes::activationToken, this, &NotificacoesAdaptador::ActivationToken);
}

QStringList NotificacoesAdaptador::GetCapabilities() {
    return {QStringLiteral("body"), QStringLiteral("body-markup"), QStringLiteral("body-hyperlinks"),
            QStringLiteral("actions"), QStringLiteral("icon-static"), QStringLiteral("persistence"),
            QStringLiteral("sound")};
}

QString NotificacoesAdaptador::GetServerInformation(QString &vendedor, QString &versao, QString &especificacao) {
    vendedor = QStringLiteral("CarinaeOS");
    versao = QStringLiteral("1.0");
    especificacao = QStringLiteral("1.2");
    return QStringLiteral("Aurora");
}

uint NotificacoesAdaptador::Notify(const QString &app_name, uint replaces_id, const QString &app_icon,
                                   const QString &summary, const QString &body, const QStringList &actions,
                                   const QVariantMap &hints, int expire_timeout) {
    return m_n->notify(app_name, replaces_id, app_icon, summary, body, actions, hints, expire_timeout);
}

void NotificacoesAdaptador::CloseNotification(uint id) { m_n->closeNotification(id); }
