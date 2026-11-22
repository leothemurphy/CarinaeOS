// CarinaeOS — Mpris2Model: os leitores de música do sistema (MPRIS, via D-Bus)
// Substitui o org.kde.plasma.private.mpris (Mpris2Model, PlaybackStatus, ShuffleStatus, LoopStatus).
// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QAbstractListModel>
#include <QPointer>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

namespace PlaybackStatus {
Q_NAMESPACE
QML_ELEMENT
enum Status { Unknown = 0, Stopped, Playing, Paused };
Q_ENUM_NS(Status)
}
namespace ShuffleStatus {
Q_NAMESPACE
QML_ELEMENT
enum Status { Unknown = 0, Off, On };
Q_ENUM_NS(Status)
}
namespace LoopStatus {
Q_NAMESPACE
QML_ELEMENT
enum Status { Unknown = 0, None, Track, Playlist };
Q_ENUM_NS(Status)
}

class PlayerContainer : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("vem do Mpris2Model")
    Q_PROPERTY(QString identity READ identity NOTIFY mudou)
    Q_PROPERTY(QString desktopEntry READ desktopEntry NOTIFY mudou)
    Q_PROPERTY(QString iconName READ iconName NOTIFY mudou)
    Q_PROPERTY(int playbackStatus READ playbackStatus NOTIFY mudou)
    Q_PROPERTY(QString track READ track NOTIFY mudou)
    Q_PROPERTY(QString artist READ artist NOTIFY mudou)
    Q_PROPERTY(QString album READ album NOTIFY mudou)
    Q_PROPERTY(QString artUrl READ artUrl NOTIFY mudou)
    Q_PROPERTY(qlonglong length READ length NOTIFY mudou)
    Q_PROPERTY(qlonglong position READ position NOTIFY posicaoMudou)
    Q_PROPERTY(double volume READ volume WRITE setVolume NOTIFY mudou)
    Q_PROPERTY(int shuffle READ shuffle WRITE setShuffle NOTIFY mudou)
    Q_PROPERTY(int loopStatus READ loopStatus WRITE setLoopStatus NOTIFY mudou)
    Q_PROPERTY(bool canGoNext READ canGoNext NOTIFY mudou)
    Q_PROPERTY(bool canGoPrevious READ canGoPrevious NOTIFY mudou)
    Q_PROPERTY(bool canPlay READ canPlay NOTIFY mudou)
    Q_PROPERTY(bool canPause READ canPause NOTIFY mudou)
    Q_PROPERTY(bool canSeek READ canSeek NOTIFY mudou)
    Q_PROPERTY(QString objectName READ servico CONSTANT)
public:
    explicit PlayerContainer(const QString &servico, QObject *parent = nullptr);

    QString servico() const { return m_servico; }
    QString identity() const { return m_identidade; }
    QString desktopEntry() const { return m_desktop; }
    QString iconName() const { return m_desktop; }
    int playbackStatus() const { return m_estado; }
    QString track() const { return m_titulo; }
    QString artist() const { return m_artista; }
    QString album() const { return m_album; }
    QString artUrl() const { return m_capa; }
    qlonglong length() const { return m_duracao; }
    qlonglong position() const { return m_posicao; }
    double volume() const { return m_volume; }
    int shuffle() const { return m_aleatorio; }
    int loopStatus() const { return m_repetir; }
    bool canGoNext() const { return m_podeSeguinte; }
    bool canGoPrevious() const { return m_podeAnterior; }
    bool canPlay() const { return m_podeTocar; }
    bool canPause() const { return m_podePausar; }
    bool canSeek() const { return m_podeSaltar; }

    void setVolume(double v);
    void setShuffle(int s);
    void setLoopStatus(int l);

    Q_INVOKABLE void Play() { chamar(QStringLiteral("Play")); }
    Q_INVOKABLE void Pause() { chamar(QStringLiteral("Pause")); }
    Q_INVOKABLE void PlayPause() { chamar(QStringLiteral("PlayPause")); }
    Q_INVOKABLE void Stop() { chamar(QStringLiteral("Stop")); }
    Q_INVOKABLE void Next() { chamar(QStringLiteral("Next")); }
    Q_INVOKABLE void Previous() { chamar(QStringLiteral("Previous")); }
    Q_INVOKABLE void Seek(qlonglong deslocacao);
    Q_INVOKABLE void SetPosition(qlonglong posicao);
    Q_INVOKABLE void Raise();
    Q_INVOKABLE void Quit();
    Q_INVOKABLE void updatePosition();

Q_SIGNALS:
    void mudou();
    void posicaoMudou();

private Q_SLOTS:
    void propriedadesMudaram(const QString &interface, const QVariantMap &mudadas, const QStringList &invalidadas);
    void saltou(qlonglong posicao);

private:
    void lerTudo();
    void aplicar(const QVariantMap &p);
    void chamar(const QString &metodo, const QVariantList &args = {});
    void definir(const QString &propriedade, const QVariant &valor);

    QString m_servico, m_identidade, m_desktop, m_titulo, m_artista, m_album, m_capa, m_trackId;
    int m_estado = 0, m_aleatorio = 0, m_repetir = 0;
    qlonglong m_duracao = 0, m_posicao = 0;
    double m_volume = 1.0;
    bool m_podeSeguinte = false, m_podeAnterior = false, m_podeTocar = false, m_podePausar = false, m_podeSaltar = false;
};

class Mpris2Model : public QAbstractListModel {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(int currentIndex READ currentIndex WRITE setCurrentIndex NOTIFY currentIndexChanged)
    Q_PROPERTY(PlayerContainer *currentPlayer READ currentPlayer NOTIFY currentPlayerChanged)
    Q_PROPERTY(int count READ count NOTIFY countChanged)
public:
    enum Papeis { Identity = Qt::UserRole + 1, DesktopEntry, IconName, Container, PlaybackStatusRole };
    explicit Mpris2Model(QObject *parent = nullptr);

    int rowCount(const QModelIndex &p = QModelIndex()) const override { return p.isValid() ? 0 : m_leitores.size(); }
    QVariant data(const QModelIndex &idx, int role) const override;
    QHash<int, QByteArray> roleNames() const override;
    int count() const { return m_leitores.size(); }
    int currentIndex() const { return m_atual; }
    void setCurrentIndex(int i);
    PlayerContainer *currentPlayer() const;

Q_SIGNALS:
    void currentIndexChanged();
    void currentPlayerChanged();
    void countChanged();

private Q_SLOTS:
    void donoMudou(const QString &nome, const QString &antigo, const QString &novo);

private:
    void acrescentar(const QString &servico);
    void tirar(const QString &servico);
    QList<PlayerContainer *> m_leitores;
    QList<PlayerContainer *> m_pendentes;
    int m_atual = -1;
};
