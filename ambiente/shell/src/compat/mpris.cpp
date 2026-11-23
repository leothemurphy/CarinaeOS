// SPDX-License-Identifier: GPL-2.0-or-later
#include "mpris.h"

#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusVariant>
#include <QTimer>

static const QString CAMINHO = QStringLiteral("/org/mpris/MediaPlayer2");
static const QString RAIZ = QStringLiteral("org.mpris.MediaPlayer2");
static const QString LEITOR = QStringLiteral("org.mpris.MediaPlayer2.Player");
static const QString PROPS = QStringLiteral("org.freedesktop.DBus.Properties");

// o D-Bus entrega os dicionários e as listas embrulhados: desembrulha tudo
static QVariant limpar(const QVariant &v) {
    if (v.metaType() == QMetaType::fromType<QDBusVariant>()) return limpar(v.value<QDBusVariant>().variant());
    if (v.metaType() == QMetaType::fromType<QDBusArgument>()) {
        const QDBusArgument a = v.value<QDBusArgument>();
        if (a.currentType() == QDBusArgument::MapType) {
            QVariantMap m;
            a >> m;
            for (auto it = m.begin(); it != m.end(); ++it) *it = limpar(*it);
            return m;
        }
        if (a.currentType() == QDBusArgument::ArrayType) {
            QStringList l;
            a >> l;
            return l;
        }
    }
    if (v.metaType() == QMetaType::fromType<QDBusObjectPath>()) return v.value<QDBusObjectPath>().path();
    return v;
}

PlayerContainer::PlayerContainer(const QString &servico, QObject *parent) : QObject(parent), m_servico(servico) {
    QDBusConnection::sessionBus().connect(servico, CAMINHO, PROPS, QStringLiteral("PropertiesChanged"), this,
                                          SLOT(propriedadesMudaram(QString, QVariantMap, QStringList)));
    QDBusConnection::sessionBus().connect(servico, CAMINHO, LEITOR, QStringLiteral("Seeked"), this, SLOT(saltou(qlonglong)));
    lerTudo();
}

void PlayerContainer::lerTudo() {
    for (const QString &interface : {RAIZ, LEITOR}) {
        QDBusMessage m = QDBusMessage::createMethodCall(m_servico, CAMINHO, PROPS, QStringLiteral("GetAll"));
        m << interface;
        auto *w = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(m), this);
        connect(w, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *w) {
            QDBusPendingReply<QVariantMap> r = *w;
            if (!r.isError()) aplicar(r.value());
            w->deleteLater();
        });
    }
}

void PlayerContainer::aplicar(const QVariantMap &bruto) {
    QVariantMap p;
    for (auto it = bruto.begin(); it != bruto.end(); ++it) p.insert(it.key(), limpar(it.value()));
    bool posMudou = false;
    if (p.contains(QStringLiteral("Identity"))) m_identidade = p.value(QStringLiteral("Identity")).toString();
    if (p.contains(QStringLiteral("DesktopEntry"))) m_desktop = p.value(QStringLiteral("DesktopEntry")).toString();
    if (p.contains(QStringLiteral("PlaybackStatus"))) {
        const QString e = p.value(QStringLiteral("PlaybackStatus")).toString();
        m_estado = e == QLatin1String("Playing") ? PlaybackStatus::Playing
                 : e == QLatin1String("Paused")  ? PlaybackStatus::Paused
                 : e == QLatin1String("Stopped") ? PlaybackStatus::Stopped : PlaybackStatus::Unknown;
    }
    if (p.contains(QStringLiteral("Metadata"))) {
        const QVariantMap md = p.value(QStringLiteral("Metadata")).toMap();
        m_titulo = md.value(QStringLiteral("xesam:title")).toString();
        const QVariant ar = md.value(QStringLiteral("xesam:artist"));
        m_artista = ar.metaType() == QMetaType::fromType<QStringList>() ? ar.toStringList().join(QStringLiteral(", ")) : ar.toString();
        m_album = md.value(QStringLiteral("xesam:album")).toString();
        m_capa = md.value(QStringLiteral("mpris:artUrl")).toString();
        m_duracao = md.value(QStringLiteral("mpris:length")).toLongLong();
        const QString id = md.value(QStringLiteral("mpris:trackid")).toString();
        if (id != m_trackId) { m_trackId = id; m_posicao = 0; posMudou = true; }
    }
    if (p.contains(QStringLiteral("Position"))) { m_posicao = p.value(QStringLiteral("Position")).toLongLong(); posMudou = true; }
    if (p.contains(QStringLiteral("Volume"))) m_volume = p.value(QStringLiteral("Volume")).toDouble();
    if (p.contains(QStringLiteral("Shuffle"))) m_aleatorio = p.value(QStringLiteral("Shuffle")).toBool() ? ShuffleStatus::On : ShuffleStatus::Off;
    if (p.contains(QStringLiteral("LoopStatus"))) {
        const QString l = p.value(QStringLiteral("LoopStatus")).toString();
        m_repetir = l == QLatin1String("Track") ? LoopStatus::Track : l == QLatin1String("Playlist") ? LoopStatus::Playlist : LoopStatus::None;
    }
    if (p.contains(QStringLiteral("CanGoNext"))) m_podeSeguinte = p.value(QStringLiteral("CanGoNext")).toBool();
    if (p.contains(QStringLiteral("CanGoPrevious"))) m_podeAnterior = p.value(QStringLiteral("CanGoPrevious")).toBool();
    if (p.contains(QStringLiteral("CanPlay"))) m_podeTocar = p.value(QStringLiteral("CanPlay")).toBool();
    if (p.contains(QStringLiteral("CanPause"))) m_podePausar = p.value(QStringLiteral("CanPause")).toBool();
    if (p.contains(QStringLiteral("CanSeek"))) m_podeSaltar = p.value(QStringLiteral("CanSeek")).toBool();
    Q_EMIT mudou();
    if (posMudou) Q_EMIT posicaoMudou();
}

void PlayerContainer::propriedadesMudaram(const QString &, const QVariantMap &mudadas, const QStringList &invalidadas) {
    aplicar(mudadas);
    if (!invalidadas.isEmpty()) lerTudo();
}

void PlayerContainer::saltou(qlonglong posicao) {
    m_posicao = posicao;
    Q_EMIT posicaoMudou();
}

void PlayerContainer::updatePosition() {
    QDBusMessage m = QDBusMessage::createMethodCall(m_servico, CAMINHO, PROPS, QStringLiteral("Get"));
    m << LEITOR << QStringLiteral("Position");
    auto *w = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(m), this);
    connect(w, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *w) {
        QDBusPendingReply<QDBusVariant> r = *w;
        if (!r.isError()) {
            m_posicao = r.value().variant().toLongLong();
            Q_EMIT posicaoMudou();
        }
        w->deleteLater();
    });
}

void PlayerContainer::chamar(const QString &metodo, const QVariantList &args) {
    QDBusMessage m = QDBusMessage::createMethodCall(m_servico, CAMINHO, LEITOR, metodo);
    m.setArguments(args);
    QDBusConnection::sessionBus().asyncCall(m);
}

void PlayerContainer::definir(const QString &propriedade, const QVariant &valor) {
    QDBusMessage m = QDBusMessage::createMethodCall(m_servico, CAMINHO, PROPS, QStringLiteral("Set"));
    m << LEITOR << propriedade << QVariant::fromValue(QDBusVariant(valor));
    QDBusConnection::sessionBus().asyncCall(m);
}

void PlayerContainer::Seek(qlonglong deslocacao) { chamar(QStringLiteral("Seek"), {deslocacao}); }

void PlayerContainer::SetPosition(qlonglong posicao) {
    chamar(QStringLiteral("SetPosition"), {QVariant::fromValue(QDBusObjectPath(m_trackId.isEmpty() ? QStringLiteral("/") : m_trackId)), posicao});
}

void PlayerContainer::Raise() {
    QDBusConnection::sessionBus().asyncCall(QDBusMessage::createMethodCall(m_servico, CAMINHO, RAIZ, QStringLiteral("Raise")));
}

void PlayerContainer::Quit() {
    QDBusConnection::sessionBus().asyncCall(QDBusMessage::createMethodCall(m_servico, CAMINHO, RAIZ, QStringLiteral("Quit")));
}

void PlayerContainer::setVolume(double v) { definir(QStringLiteral("Volume"), qBound(0.0, v, 1.0)); }
void PlayerContainer::setShuffle(int s) { definir(QStringLiteral("Shuffle"), s == ShuffleStatus::On); }
void PlayerContainer::setLoopStatus(int l) {
    definir(QStringLiteral("LoopStatus"), l == LoopStatus::Track ? QStringLiteral("Track")
                                        : l == LoopStatus::Playlist ? QStringLiteral("Playlist") : QStringLiteral("None"));
}

// --- Mpris2Model ------------------------------------------------------------------------------
Mpris2Model::Mpris2Model(QObject *parent) : QAbstractListModel(parent) {
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) return;
    bus.connect(QStringLiteral("org.freedesktop.DBus"), QStringLiteral("/org/freedesktop/DBus"), QStringLiteral("org.freedesktop.DBus"),
                QStringLiteral("NameOwnerChanged"), this, SLOT(donoMudou(QString, QString, QString)));
    const QStringList nomes = bus.interface()->registeredServiceNames().value();
    for (const QString &n : nomes)
        if (n.startsWith(RAIZ + QLatin1Char('.'))) acrescentar(n);
}

void Mpris2Model::donoMudou(const QString &nome, const QString &antigo, const QString &novo) {
    if (!nome.startsWith(RAIZ + QLatin1Char('.'))) return;
    if (!antigo.isEmpty()) tirar(nome);
    if (!novo.isEmpty()) acrescentar(nome);
}

void Mpris2Model::acrescentar(const QString &servico) {
    for (PlayerContainer *p : std::as_const(m_leitores))
        if (p->servico() == servico) return;
    for (PlayerContainer *p : std::as_const(m_pendentes))
        if (p->servico() == servico) return;
    auto *p = new PlayerContainer(servico, this);
    m_pendentes.append(p);
    // só entra na lista quando já se sabe o nome (Identity): quem usa o modelo decide logo por ele
    auto entrar = [this, p] {
        if (!m_pendentes.removeOne(p)) return;
        const int n = m_leitores.size();
        beginInsertRows(QModelIndex(), n, n);
        m_leitores.append(p);
        endInsertRows();
        Q_EMIT countChanged();
        if (m_atual < 0) setCurrentIndex(0);
    };
    connect(p, &PlayerContainer::mudou, this, [this, p, entrar] {
        if (m_pendentes.contains(p)) {
            if (!p->identity().isEmpty()) entrar();
            return;
        }
        const int i = m_leitores.indexOf(p);
        if (i >= 0) Q_EMIT dataChanged(index(i), index(i));
    });
    QTimer::singleShot(2000, p, entrar);      // leitor sem Identity: entra na mesma
}

void Mpris2Model::tirar(const QString &servico) {
    for (PlayerContainer *p : std::as_const(m_pendentes))
        if (p->servico() == servico) { m_pendentes.removeOne(p); p->deleteLater(); return; }
    for (int i = 0; i < m_leitores.size(); ++i) {
        if (m_leitores[i]->servico() != servico) continue;
        PlayerContainer *p = m_leitores[i];
        const bool eraAtual = i == m_atual;
        beginRemoveRows(QModelIndex(), i, i);
        m_leitores.removeAt(i);
        endRemoveRows();
        if (m_atual > i) m_atual--;
        else if (eraAtual) m_atual = m_leitores.isEmpty() ? -1 : qMin(i, int(m_leitores.size()) - 1);
        Q_EMIT countChanged();
        if (eraAtual || m_atual >= i) { Q_EMIT currentIndexChanged(); Q_EMIT currentPlayerChanged(); }
        p->deleteLater();
        return;
    }
}

void Mpris2Model::setCurrentIndex(int i) {
    if (i < -1 || i >= m_leitores.size() || i == m_atual) return;
    m_atual = i;
    Q_EMIT currentIndexChanged();
    Q_EMIT currentPlayerChanged();
}

PlayerContainer *Mpris2Model::currentPlayer() const {
    return (m_atual >= 0 && m_atual < m_leitores.size()) ? m_leitores[m_atual] : nullptr;
}

QHash<int, QByteArray> Mpris2Model::roleNames() const {
    return {{Qt::DisplayRole, "display"}, {Identity, "identity"}, {DesktopEntry, "desktopEntry"},
            {IconName, "iconName"}, {Container, "container"}, {PlaybackStatusRole, "playbackStatus"}};
}

QVariant Mpris2Model::data(const QModelIndex &idx, int role) const {
    if (!idx.isValid() || idx.row() >= m_leitores.size()) return QVariant();
    PlayerContainer *p = m_leitores[idx.row()];
    switch (role) {
    case Qt::DisplayRole:
    case Identity: return p->identity().isEmpty() ? p->servico().mid(RAIZ.size() + 1) : p->identity();
    case DesktopEntry: return p->desktopEntry();
    case IconName: return p->iconName();
    case Container: return QVariant::fromValue(p);
    case PlaybackStatusRole: return p->playbackStatus();
    }
    return QVariant();
}
