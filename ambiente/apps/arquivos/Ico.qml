// CarinaeOS — Documentos: ícones de linha ao estilo do Windows 11 (desenhados aqui, em SVG)
import QtQuick

Image {
    id: ico
    property string nome: ""
    property color cor: "white"
    property real espessura: 1.5
    property int lado: 16
    width: lado; height: lado
    sourceSize: Qt.size(lado * 2, lado * 2)
    smooth: true

    readonly property var caminhos: ({
        "voltar": "M19 12H5M11 6l-6 6 6 6",
        "avancar": "M5 12h14M13 6l6 6-6 6",
        "subir": "M12 19V5M6 11l6-6 6 6",
        "atualizar": "M19.5 12a7.5 7.5 0 1 1-2.2-5.3M19.5 4.5v4h-4",
        "mais": "M12 5v14M5 12h14",
        "cortar": "M7.5 19.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5zM16.5 19.5a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5zM9.3 15.3L17 4.5M14.7 15.3L7 4.5",
        "copiar": "M9.5 8h8a1.5 1.5 0 0 1 1.5 1.5v9a1.5 1.5 0 0 1-1.5 1.5h-8A1.5 1.5 0 0 1 8 18.5v-9A1.5 1.5 0 0 1 9.5 8zM5 16V5.5A1.5 1.5 0 0 1 6.5 4H15",
        "colar": "M9 3.5h6a1 1 0 0 1 1 1V6H8V4.5a1 1 0 0 1 1-1zM8 5H6.5A1.5 1.5 0 0 0 5 6.5v12A1.5 1.5 0 0 0 6.5 20h11a1.5 1.5 0 0 0 1.5-1.5v-12A1.5 1.5 0 0 0 17.5 5H16",
        "renomear": "M4.5 19.5h4l10.3-10.3a2 2 0 0 0 0-2.8l-1.2-1.2a2 2 0 0 0-2.8 0L4.5 15.5zM13.5 6.5l4 4",
        "partilhar": "M14 4.5h5.5V10M19.5 4.5L11 13M18 14v4.5a1.5 1.5 0 0 1-1.5 1.5h-11A1.5 1.5 0 0 1 4 18.5v-11A1.5 1.5 0 0 1 5.5 6H10",
        "eliminar": "M4.5 6.5h15M9.5 6.5V4.5h5v2M6.5 6.5l1 13h9l1-13M10 10.5v6M14 10.5v6",
        "ordenar": "M8 4.5v15M4.5 16l3.5 3.5 3.5-3.5M16 19.5v-15M12.5 8L16 4.5 19.5 8",
        "ver": "M4.5 5.5h15v5h-15zM4.5 13.5h15v5h-15z",
        "pontos": "M5.5 12h.01M12 12h.01M18.5 12h.01",
        "detalhes": "M4.5 5.5h15v13h-15zM14.5 5.5v13",
        "pesquisa": "M10.5 17.5a7 7 0 1 0 0-14 7 7 0 0 0 0 14zM15.5 15.5l5 5",
        "seta": "M9.5 6l6 6-6 6",
        "setaBaixo": "M6 9.5l6 6 6-6",
        "setaCima": "M6 14.5l6-6 6 6",
        "fechar": "M6.5 6.5l11 11M17.5 6.5l-11 11",
        "minimizar": "M5.5 12h13",
        "maximizar": "M6.5 6.5h11v11h-11z",
        "restaurar": "M8.5 8.5h10v10h-10zM5.5 15.5v-10h10",
        "fixar": "M14.5 4l5.5 5.5-2.5 1-3.5 3.5.5 4-1.5 1.5-4-4-4.5 4.5M9 15l-4 4.5M8.5 10l5.5 5.5",
        "rede": "M12 15v4.5M4.5 19.5h15M7.5 4.5h9a1 1 0 0 1 1 1V14a1 1 0 0 1-1 1h-9a1 1 0 0 1-1-1V5.5a1 1 0 0 1 1-1z",
        "terminal": "M4.5 5.5h15v13h-15zM8 10l2.5 2-2.5 2M12.5 14.5h3.5",
        "visto": "M5 12.5l4.5 4.5L19 7.5",
        "ponto": "M12 12h.01",
        "pasta": "M4.5 7V6a1.5 1.5 0 0 1 1.5-1.5h3.5l2 2H18A1.5 1.5 0 0 1 19.5 8v10a1.5 1.5 0 0 1-1.5 1.5H6A1.5 1.5 0 0 1 4.5 18z",
        "ficheiro": "M13.5 3.5H7A1.5 1.5 0 0 0 5.5 5v14A1.5 1.5 0 0 0 7 20.5h10a1.5 1.5 0 0 0 1.5-1.5V8.5zM13.5 3.5v5h5",
        "zip": "M13.5 3.5H7A1.5 1.5 0 0 0 5.5 5v14A1.5 1.5 0 0 0 7 20.5h10a1.5 1.5 0 0 0 1.5-1.5V8.5zM13.5 3.5v5h5M10 5h2M10 8h2M10 11h2M10 14h2v3h-2z",
        "abrir": "M4.5 8.5V18a1.5 1.5 0 0 0 1.5 1.5h12a1.5 1.5 0 0 0 1.5-1.5V10a1.5 1.5 0 0 0-1.5-1.5H12l-2-2H6A1.5 1.5 0 0 0 4.5 8z",
        "propriedades": "M4.5 6.5h15M4.5 12h15M4.5 17.5h9",
        "cadeado": "M7 11V8a5 5 0 0 1 10 0v3M6 11h12v9H6z",
        "etiqueta": "M4.5 4.5h7l8 8-7 7-8-8zM8.5 8.5h.01",
        "olho": "M2.5 12s3.5-6.5 9.5-6.5 9.5 6.5 9.5 6.5-3.5 6.5-9.5 6.5S2.5 12 2.5 12zM12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z",
        "ejetar": "M12 5l7 8H5zM5 18.5h14",
        "lista": "M8.5 6h11M8.5 12h11M8.5 18h11M4.5 6h.01M4.5 12h.01M4.5 18h.01",
        "grelha": "M4.5 4.5h6v6h-6zM13.5 4.5h6v6h-6zM4.5 13.5h6v6h-6zM13.5 13.5h6v6h-6z",
        "linhas": "M4.5 6h15M4.5 10h15M4.5 14h15M4.5 18h15",
        "ligar": "M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7L11.5 6.8M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1.5-1.5",
        "desligar": "M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7M4 4l16 16",
        "sol": "M12 16a4 4 0 1 0 0-8 4 4 0 0 0 0 8zM12 2.5v2M12 19.5v2M2.5 12h2M19.5 12h2M5.3 5.3l1.4 1.4M17.3 17.3l1.4 1.4M5.3 18.7l1.4-1.4M17.3 6.7l1.4-1.4",
        "lua": "M19.5 14.5A8 8 0 1 1 9.5 4.5a6.5 6.5 0 0 0 10 10z"
    })

    source: {
        const d = caminhos[nome];
        if (!d) return "";
        const largura = nome === "pontos" || nome === "ponto" ? 2.6 : espessura;
        const svg = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='" + cor
                  + "' stroke-width='" + largura + "' stroke-linecap='round' stroke-linejoin='round'><path d='" + d + "'/></svg>";
        return "data:image/svg+xml;utf8," + encodeURIComponent(svg);
    }
}
