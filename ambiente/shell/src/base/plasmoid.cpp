// SPDX-License-Identifier: GPL-2.0-or-later
#include "plasmoid.h"
#include <QStandardPaths>
#include "sistema.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJSValue>
#include <QJsonDocument>
#include <QJsonObject>
#include <QScreen>
#include <QTextStream>

// os valores por omissão da Dock (os mesmos do main.xml do plasmoide)
static QVariantMap padroes() {
    return {
        {QStringLiteral("launchers"), QStringList{
            QStringLiteral("applications:carinaeos-arquivos.desktop"), QStringLiteral("applications:carinaeos-terminal.desktop"),
            QStringLiteral("applications:carinaeos-fotos.desktop"), QStringLiteral("applications:carinaeos-pdf.desktop"),
            QStringLiteral("applications:carinaeos-compactador.desktop"), QStringLiteral("applications:systemsettings.desktop")}},
        {QStringLiteral("iconSize"), 48},
        {QStringLiteral("zoom"), 1.9},
        {QStringLiteral("bounce"), true},
        {QStringLiteral("separators"), QStringList()},
        {QStringLiteral("separatorColor"), QStringLiteral("#59ffffff")},
        {QStringLiteral("separatorWidth"), 1},
        {QStringLiteral("glassHeight"), 0},
        {QStringLiteral("showTrash"), true},
    };
}

Configuracao::Configuracao(const QString &arquivo, QObject *parent) : QQmlPropertyMap(this, parent), m_arquivo(arquivo) {
    m_gravar.setSingleShot(true);
    m_gravar.setInterval(400);
    connect(&m_gravar, &QTimer::timeout, this, &Configuracao::gravarJa);
    const QVariantMap p = padroes();
    for (auto it = p.begin(); it != p.end(); ++it) insert(it.key(), it.value());
    if (QFileInfo::exists(m_arquivo)) carregar();
    else { importarDoPlasma(); gravarJa(); }
    connect(this, &QQmlPropertyMap::valueChanged, this, [this] { m_gravar.start(); });
}

QVariant Configuracao::updateValue(const QString &, const QVariant &valor) {
    // os arrays de JavaScript chegam como QJSValue: guardamos já convertidos
    if (valor.metaType() == QMetaType::fromType<QJSValue>()) {
        const QVariant v = valor.value<QJSValue>().toVariant();
        if (v.metaType() == QMetaType::fromType<QVariantList>()) return v.toStringList();
        return v;
    }
    if (valor.metaType() == QMetaType::fromType<QVariantList>()) return valor.toStringList();
    return valor;
}

void Configuracao::carregar() {
    QFile f(m_arquivo);
    if (!f.open(QIODevice::ReadOnly)) return;
    const QJsonObject o = QJsonDocument::fromJson(f.readAll()).object();
    const QVariantMap p = padroes();
    for (auto it = o.begin(); it != o.end(); ++it) {
        QVariant v = it.value().toVariant();
        const QVariant padrao = p.value(it.key());
        if (padrao.metaType() == QMetaType::fromType<QStringList>()) v = v.toStringList();
        insert(it.key(), v);
    }
    // os aplicativos do KDE que já têm um nosso: a Dock passa a apontar para o nosso (uma vez, ao ler)
    static const QList<QPair<QString, QString>> trocas = {
        {QStringLiteral("org.kde.konsole.desktop"), QStringLiteral("carinaeos-terminal.desktop")},
        {QStringLiteral("org.kde.dolphin.desktop"), QStringLiteral("carinaeos-arquivos.desktop")},
        {QStringLiteral("org.kde.plasma-systemmonitor.desktop"), QStringLiteral("carinaeos-monitor.desktop")},
        {QStringLiteral("org.kde.gwenview.desktop"), QStringLiteral("carinaeos-fotos.desktop")},
        {QStringLiteral("org.kde.okular.desktop"), QStringLiteral("carinaeos-pdf.desktop")},
        {QStringLiteral("org.kde.kcalc.desktop"), QStringLiteral("carinaeos-calculadora.desktop")},
        {QStringLiteral("org.kde.kate.desktop"), QStringLiteral("carinaeos-notas.desktop")},
        {QStringLiteral("org.kde.kwrite.desktop"), QStringLiteral("carinaeos-notas.desktop")},
        {QStringLiteral("org.kde.ark.desktop"), QStringLiteral("carinaeos-compactador.desktop")},
        {QStringLiteral("org.kde.plasma.emojier.desktop"), QStringLiteral("carinaeos-emojis.desktop")},
    };
    QStringList l = value(QStringLiteral("launchers")).toStringList();
    bool mudou = false;
    for (QString &x : l) {
        for (const auto &t : trocas) {
            if (x.endsWith(t.first) && !QStandardPaths::locate(QStandardPaths::ApplicationsLocation, t.second).isEmpty()) {
                x = QStringLiteral("applications:") + t.second;
                mudou = true;
            }
        }
    }
    if (mudou) {
        l.removeDuplicates();
        insert(QStringLiteral("launchers"), l);
        QTimer::singleShot(0, this, [this] { gravarJa(); });
    }
}

void Configuracao::gravarJa() {
    QJsonObject o;
    for (const QString &k : keys()) o.insert(k, QJsonValue::fromVariant(value(k)));
    QDir().mkpath(QFileInfo(m_arquivo).absolutePath());
    QFile f(m_arquivo);
    if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) f.write(QJsonDocument(o).toJson(QJsonDocument::Indented));
}

// lê a configuração da Dock antiga (plasmoide org.carinaeos.dock) do ficheiro do Plasma
void Configuracao::importarDoPlasma() {
    QFile f(QDir::homePath() + QStringLiteral("/.config/plasma-org.kde.plasma.desktop-appletsrc"));
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return;
    QTextStream in(&f);
    QString grupo, grupoDock;
    QHash<QString, QHash<QString, QString>> grupos;
    while (!in.atEnd()) {
        const QString l = in.readLine().trimmed();
        if (l.startsWith(QLatin1Char('['))) { grupo = l; continue; }
        const int eq = l.indexOf(QLatin1Char('='));
        if (eq <= 0) continue;
        const QString k = l.left(eq), v = l.mid(eq + 1);
        grupos[grupo].insert(k, v);
        if (k == QLatin1String("plugin") && v == QLatin1String("org.carinaeos.dock")) grupoDock = grupo;
    }
    if (grupoDock.isEmpty()) return;
    const QHash<QString, QString> cfg = grupos.value(grupoDock + QStringLiteral("[Configuration][General]"));
    const QVariantMap p = padroes();
    for (auto it = cfg.begin(); it != cfg.end(); ++it) {
        if (!p.contains(it.key())) continue;
        const QVariant padrao = p.value(it.key());
        const QString v = it.value();
        if (padrao.metaType() == QMetaType::fromType<QStringList>()) {
            QStringList l;
            QString atual;
            for (int i = 0; i < v.size(); ++i) {
                if (v[i] == QLatin1Char('\\') && i + 1 < v.size()) atual += v[++i];
                else if (v[i] == QLatin1Char(',')) { l << atual; atual.clear(); }
                else atual += v[i];
            }
            if (!atual.isEmpty()) l << atual;
            insert(it.key(), l);
        } else if (padrao.metaType() == QMetaType::fromType<bool>()) {
            insert(it.key(), v == QLatin1String("true"));
        } else if (padrao.metaType() == QMetaType::fromType<int>()) {
            insert(it.key(), v.toInt());
        } else if (padrao.metaType() == QMetaType::fromType<double>()) {
            insert(it.key(), v.toDouble());
        } else {
            insert(it.key(), v);
        }
    }
    qInfo("CarinaeOS: configuração da Dock importada do Plasma (%s)", qPrintable(grupoDock));
}

QRect Contentor::screenGeometry() const {
    QScreen *s = Sistema::instancia()->ecraPrincipal();
    return s ? s->geometry() : QRect();
}

Plasmoid::Plasmoid(QObject *parent) : QObject(parent) {
    m_config = new Configuracao(QDir::homePath() + QStringLiteral("/.config/carinaeos/dock.json"), this);
    m_contentor = new Contentor(this);
}

Plasmoid *Plasmoid::instancia() {
    static Plasmoid *p = new Plasmoid;
    return p;
}

Plasmoid *Plasmoid::create(QQmlEngine *, QJSEngine *) {
    Plasmoid *p = instancia();
    QJSEngine::setObjectOwnership(p, QJSEngine::CppOwnership);
    return p;
}
