# Extensões do Comando (Ctrl+Espaço)

Cada extensão é uma pasta com `extensao.json` e `extensao.py`. Coloque as suas em
`~/.local/share/carinaeos/extensoes/` (o Comando as lê ao abrir; digite `?` para ver todas).

## extensao.json
```json
{"nome": "Dicionário", "descricao": "def palavra → significado", "icone": "accessories-dictionary",
 "palavras": ["def"]}
```
- `palavras`: o que se digita antes do texto (`def casa`). Vazio = a extensão responde a tudo o que se digita
  (tem de ser rápida; se demorar, o Comando para de chamá-la em cada tecla).
- `comeca` (opcional): responde quando o texto começa assim (ex.: `["~/", "/"]`).

## extensao.py
```python
def procurar(texto, ctx):
    # texto: o que vem depois da palavra; ctx: {"casa", "idioma", "palavra"}
    return [{"titulo": "Casa", "sub": "Edifício onde se mora", "icone": "go-home",
             "acao": "copiar", "valor": "casa"}]
```
Ações: `copiar` (texto), `abrir` (endereço ou arquivo), `correr` (comando), `terminal` (comando num terminal),
`completar` (troca o texto da pesquisa — para navegar).
