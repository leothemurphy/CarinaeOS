// CarinaeOS — catálogo dos aplicativos (.desktop): ler, abrir, contar o uso, reconhecer janelas
// SPDX-License-Identifier: GPL-2.0-or-later
#pragma once

#include <QDateTime>
#include <QHash>
#include <QObject>
#include <QStringList>
#include <QTimer>
#include <QVector>

class QFileSystemWatcher;

struct AcaoApp {
    QString id, nome, icone, exec;
};

struct App {
    QString id;            // "org.kde.dolphin.desktop"
    QString caminho;
    QString nome, nomeGenerico, comentario, icone, exec, pasta, wmClass;
    QStringList categorias, palavras;
    QVector<AcaoApp> acoes;
    bool terminal = false;
    bool visivel = true;   // aparece nos menus (NoDisplay/Hidden/OnlyShowIn/TryExec)
    qint64 instalado = 0;  // mtime do .desktop
    QString descricao() const { return !nomeGenerico.isEmpty() ? nomeGenerico : comentario; }
};

class Catalogo : public QObject {
    Q_OBJECT
public:
    static Catalogo *instancia();

    const QVector<App> &apps() const { return m_visiveis; }   // visíveis, por nome
    const App *porId(const QString &id) const;                // também os escondidos
    const App *porCaminho(const QString &caminho) const;
    // "applications:x.desktop" / "file:///.../x.desktop" / "x.desktop" -> id (ou o nome do ficheiro)
    QString idDeUrl(const QString &url) const;
    // a que aplicativo pertence uma janela
    QString idParaJanela(const QString &instancia, const QString &classe, const QString &dica) const;

    // abre; devolve o pid (0 se falhou)
    qint64 lancar(const QString &id, const QString &acao = QString(), const QStringList &urls = QStringList());
    qint64 lancarArquivo(const QString &caminhoDesktop);

    void registarUso(const QString &id);
    QVector<QPair<QString, int>> maisUsados() const;      // (id, vezes), do mais usado para o menos

    static QStringList pastasAplicativos();
    static QString nomeCategoria(const App &a, QString *icone = nullptr);   // primeira categoria principal
    static QStringList categoriasPrincipais(const App &a);                 // todas (o lançador junta)

public Q_SLOTS:
    void recarregar();

Q_SIGNALS:
    void mudou();
    void usoMudou();

private:
    explicit Catalogo(QObject *parent = nullptr);
    bool lerDesktop(const QString &caminho, const QString &id, App &a) const;
    qint64 executarExec(const QString &exec, const App *a, const QStringList &urls);
    void lerUso();
    void gravarUso();
    void vigiar();

    QVector<App> m_todos;
    QVector<App> m_visiveis;
    QHash<QString, int> m_porId;           // id em minúsculas -> índice em m_todos
    QHash<QString, int> m_porCaminho;
    QHash<QString, QString> m_porClasse;   // StartupWMClass, nome do binário, fim do id... -> id
    QHash<QString, QPair<int, qint64>> m_uso;
    QFileSystemWatcher *m_vigia = nullptr;
    QTimer m_atraso;
};
