#!/usr/bin/python3
"""CarinaeOS — porta a Dock, o Launchpad e o menu estrela do Plasma para o carinae-shell.

O QML continua o MESMO que escreveste para o Plasma; este script só troca:
  * os imports do Plasma/Kirigami pelos módulos do CarinaeOS (CarinaeOS.Compat / CarinaeOS.Base),
    que têm os mesmos nomes de tipos (Icon, Dialog, DataSource, TasksModel, RootModel, Menu...);
  * os comandos qdbus do Plasma (reiniciar, desligar, sair, editar painéis) pelos do CarinaeOS;
  * meia dúzia de linhas que só fazem sentido dentro de um painel do Plasma.

Uso:
  portar-do-plasma.py [ORIGEM_PLASMOIDES] [DESTINO_QML]
  (por omissão: /usr/share/plasma/plasmoids  ->  /usr/local/share/carinaeos/shell)

Assim, quando mexeres na Dock do Plasma, voltas a correr isto e o CarinaeOS fica igual.
"""
import os
import re
import shutil
import sys

ORIGEM = sys.argv[1] if len(sys.argv) > 1 else "/usr/share/plasma/plasmoids"
DESTINO = sys.argv[2] if len(sys.argv) > 2 else "/usr/local/share/carinaeos/shell"

MODULOS_COMPAT = [
    "org.kde.plasma.private.kicker",
    "org.kde.plasma.private.mpris",
    "org.kde.plasma.plasma5support",
    "org.kde.plasma.components",
    "org.kde.plasma.extras",
    "org.kde.plasma.core",
    "org.kde.kirigami",
    "org.kde.taskmanager",
]
MODULOS_BASE = ["org.kde.plasma.plasmoid", "org.kde.kwindowsystem"]

COMANDOS = {
    "qdbus6 org.kde.LogoutPrompt /LogoutPrompt promptReboot": "carinae-sessao reiniciar",
    "qdbus6 org.kde.LogoutPrompt /LogoutPrompt promptShutDown": "carinae-sessao desligar",
    "qdbus6 org.kde.LogoutPrompt /LogoutPrompt promptLogout": "carinae-sessao sair",
    "qdbus6 org.kde.KWin /KWin killWindow": "xkill",
    "qdbus6 org.kde.plasmashell /PlasmaShell org.freedesktop.DBus.Properties.Set org.kde.PlasmaShell editMode true":
        "carinae-shell --enviar recarregar",
}
TEXTOS = {
    '"Editar barras e widgets…"': '"Recarregar o ambiente"',
}


def portar(texto: str, nome: str) -> str:
    # imports (e o texto dentro de Qt.createQmlObject, que também importa o Kicker)
    for m in MODULOS_COMPAT:
        texto = re.sub(r"\b" + re.escape(m) + r"(\s+\d+(\.\d+)?)?(?=\s+as\b|\s*;|\s*$)", "CarinaeOS.Compat", texto, flags=re.M)
    for m in MODULOS_BASE:
        texto = re.sub(r"^(\s*)import\s+" + re.escape(m) + r"(\s+\d+(\.\d+)?)?\s*$", r"\1import CarinaeOS.Base", texto, flags=re.M)
    # linhas que só existem dentro de um painel do Plasma
    texto = re.sub(r"^\s*Plasmoid\.(backgroundHints|constraintHints|status|icon)\s*:.*\n", "", texto, flags=re.M)
    # traduções do KDE -> o texto em português que já lá está
    texto = re.sub(r'i18nc\(\s*"[^"]*"\s*,\s*("(?:[^"\\]|\\.)*")\s*\)', r"\1", texto)
    texto = re.sub(r'i18n\(\s*("(?:[^"\\]|\\.)*")\s*\)', r"\1", texto)
    for velho, novo in COMANDOS.items():
        texto = texto.replace(velho, novo)
    for velho, novo in TEXTOS.items():
        texto = texto.replace(velho, novo)

    if nome == "Dock.qml":
        # a forma de entrada (carinaeos-dock-cliques) era para a janela do painel do Plasma;
        # no CarinaeOS a janela da Dock já tem só a altura do vidro
        texto = texto.replace('onTriggered: cliques.connectSource("carinaeos-dock-cliques --teste")',
                              'onTriggered: {}    // CarinaeOS: a janela da Dock já é só o vidro')
    if nome == "Pulsar.qml":
        # o "agora toca" chama-se Pulsar Player e tem ícone próprio
        texto = texto.replace('source: "carinaeos-musica"', 'source: "carinaeos-pulsar"')
        texto = texto.replace('correr("carinaeos-musica")', 'correr("carinaeos-pulsar")')
        cab = "                x: 16; y: 16; width: parent.width - 32; spacing: 12\n"
        marca = ('                Row {      // Pulsar Player\n'
                 '                    spacing: 8\n'
                 '                    Kirigami.Icon { source: "carinaeos-pulsar"; width: 22; height: 22; anchors.verticalCenter: parent.verticalCenter }\n'
                 '                    Text { text: "Pulsar Player"; color: "#ffcf8f"; font.pixelSize: 13; font.weight: Font.DemiBold; '
                 'font.letterSpacing: 0.6; anchors.verticalCenter: parent.verticalCenter }\n'
                 '                }\n')
        if cab in texto and "Pulsar Player" not in texto:
            texto = texto.replace(cab, cab + "\n" + marca, 1)
    if nome == "Lancador.qml":
        # o papel de parede vem primeiro de ~/.config/carinaeos-shell.json (o do CarinaeOS)
        alvo = 'lp.lerFundo.connectSource("f=$(grep'
        if alvo in texto and "carinaeos-shell.json" not in texto.split(alvo)[1][:400]:
            novo = ('lp.lerFundo.connectSource("f=$(sed -n \'s/.*\\"papel\\": *\\"\\\\([^\\"]*\\\\)\\".*/\\\\1/p\' '
                    '\\"$HOME/.config/carinaeos-shell.json\\" | head -1); [ -n \\"$f\\" ] || f=$(grep')
            texto = texto.replace(alvo, novo, 1)
    return texto


def copiar(pasta_origem: str, pasta_destino: str, renomear: dict) -> list:
    os.makedirs(pasta_destino, exist_ok=True)
    feitos = []
    for f in sorted(os.listdir(pasta_origem)):
        if not f.endswith(".qml"):
            continue        # deixa de fora os backups (.antes, .quebrado...)
        destino = renomear.get(f, f)
        with open(os.path.join(pasta_origem, f), encoding="utf-8") as e:
            texto = e.read()
        texto = portar(texto, destino)
        cab = "// Portado do Plasma pelo portar-do-plasma.py (CarinaeOS). Original: %s\n" % os.path.join(pasta_origem, f)
        with open(os.path.join(pasta_destino, destino), "w", encoding="utf-8") as s:
            s.write(cab + texto)
        feitos.append(destino)
    return feitos


def main() -> int:
    dock = os.path.join(ORIGEM, "org.carinaeos.dock", "contents", "ui")
    estrela = os.path.join(ORIGEM, "org.carinaeos.menuestrela", "contents", "ui")
    if not os.path.isdir(dock):
        print("Não encontrei a Dock em", dock)
        return 1
    feitos = copiar(dock, os.path.join(DESTINO, "dock"), {"main.qml": "Dock.qml"})
    print("Dock e Launchpad:", ", ".join(feitos))
    if os.path.isdir(estrela):
        feitos = copiar(estrela, os.path.join(DESTINO, "barra"), {"main.qml": "MenuEstrela.qml"})
        print("Menu estrela:", ", ".join(feitos))
    agora = os.path.join(ORIGEM, "org.carinaeos.agoratoca", "contents", "ui")
    if os.path.isdir(agora):
        feitos = copiar(agora, os.path.join(DESTINO, "barra"), {"main.qml": "Pulsar.qml"})
        print("Pulsar Player (o \"agora toca\"):", ", ".join(feitos))
        velho = os.path.join(DESTINO, "barra", "AgoraToca.qml")
        if os.path.exists(velho):
            os.remove(velho)
    # avisos: coisas do Plasma que ficaram e que o CarinaeOS não tem
    for pasta in ("dock", "barra"):
        p = os.path.join(DESTINO, pasta)
        for f in os.listdir(p):
            if not f.endswith(".qml"):
                continue
            t = open(os.path.join(p, f), encoding="utf-8").read()
            for m in re.findall(r"^\s*import\s+(org\.kde\.[\w.]+)", t, flags=re.M):
                print("  atenção: %s/%s ainda importa %s" % (pasta, f, m))
            for m in set(re.findall(r"qdbus6? [\w.]+", t)):
                print("  atenção: %s/%s ainda chama %s" % (pasta, f, m))
    return 0


if __name__ == "__main__":
    sys.exit(main())
