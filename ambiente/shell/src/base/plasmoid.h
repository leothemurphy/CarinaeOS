// CarinaeOS — "Plasmoid": a configuração e o contexto da Dock (substitui org.kde.plasma.plasmoid)
// A configuração vive em ~/.config/carinaeos/dock.json. Na primeira vez, importa a da Dock do Plasma.
// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QObject>
#include <QQmlEngine>
#include <QQmlPropertyMap>
#include <QRect>
#include <QTimer>
#include <QtQml/qqmlregistration.h>

class Configuracao : public QQmlPropertyMap {
    Q_OBJECT
public:
    explicit Configuracao(const QString &arquivo, QObject *parent = nullptr);
    void gravarJa();

protected:
    QVariant updateValue(const QString &chave, const QVariant &valor) override;

private:
    void carregar();
    void importarDoPlasma();
    QString m_arquivo;
    QTimer m_gravar;
};

class Contentor : public QObject {
    Q_OBJECT
    Q_PROPERTY(QRect screenGeometry READ screenGeometry NOTIFY screenGeometryChanged)
public:
    using QObject::QObject;
    QRect screenGeometry() const;
Q_SIGNALS:
    void screenGeometryChanged();
};

class Plasmoid : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QObject *configuration READ configuration CONSTANT)
    Q_PROPERTY(int location READ location CONSTANT)
    Q_PROPERTY(int formFactor READ formFactor CONSTANT)
    Q_PROPERTY(QObject *containment READ containment CONSTANT)
    Q_PROPERTY(int backgroundHints MEMBER m_fundo NOTIFY compatChanged)
    Q_PROPERTY(bool busy MEMBER m_ocupado NOTIFY compatChanged)
    Q_PROPERTY(int status MEMBER m_estado NOTIFY compatChanged)
public:
    static Plasmoid *instancia();
    static Plasmoid *create(QQmlEngine *, QJSEngine *);

    QObject *configuration() const { return m_config; }
    int location() const { return 4; }       // em baixo
    int formFactor() const { return 2; }     // horizontal
    QObject *containment() const { return m_contentor; }

    Q_INVOKABLE void ativar() { Q_EMIT activated(); }

Q_SIGNALS:
    void activated();
    void compatChanged();

private:
    explicit Plasmoid(QObject *parent = nullptr);
    Configuracao *m_config;
    Contentor *m_contentor;
    int m_fundo = 0, m_estado = 0;
    bool m_ocupado = false;
};
