# Emojis: "emo fogo" → 🔥 (Enter copia). Os nomes vêm do Unicode (em inglês) e de uma lista em português.
import unicodedata

PT = {
    'coracao': '❤️ 💖 💕 💔 🧡 💛 💚 💙 💜 🖤 🤍', 'amor': '❤️ 😍 🥰 😘 💕', 'sorriso': '😀 😃 😄 😁 😊 🙂',
    'riso': '😂 🤣 😆 😹', 'rir': '😂 🤣 😆', 'triste': '😢 😭 😞 😔 🥺', 'choro': '😭 😢', 'raiva': '😠 😡 🤬',
    'fogo': '🔥', 'ok': '👌 👍 ✅', 'joinha': '👍', 'sim': '👍 ✅', 'nao': '👎 ❌ 🚫', 'palmas': '👏', 'festa': '🎉 🥳 🎊',
    'obrigado': '🙏', 'rezar': '🙏', 'pensar': '🤔', 'olhos': '👀', 'estrela': '⭐ 🌟 ✨ 💫', 'sol': '☀️ 🌞',
    'lua': '🌙 🌕', 'chuva': '🌧️ ☔', 'neve': '❄️ ⛄', 'cafe': '☕', 'cerveja': '🍺 🍻', 'vinho': '🍷', 'bolo': '🎂 🍰',
    'pizza': '🍕', 'carro': '🚗', 'casa': '🏠', 'dinheiro': '💰 💵 💸', 'musica': '🎵 🎶 🎧', 'livro': '📖 📚',
    'computador': '💻 🖥️', 'telefone': '📱 ☎️', 'gato': '🐱 🐈', 'cao': '🐶 🐕', 'flor': '🌸 🌹 🌻 🌷',
    'arvore': '🌳 🌲', 'futebol': '⚽', 'trofeu': '🏆', 'foguete': '🚀', 'tempo': '⏰ ⌛', 'aviso': '⚠️',
    'certo': '✅ ✔️', 'errado': '❌', 'piscar': '😉', 'beijo': '😘 💋', 'legal': '😎', 'medo': '😱 😨',
    'sono': '😴', 'doente': '🤒 🤢', 'brasil': '🇧🇷', 'portugal': '🇵🇹', 'mundo': '🌍 🌎', 'presente': '🎁',
}
_FAIXAS = [(0x1F300, 0x1FAFF), (0x2600, 0x27BF), (0x1F000, 0x1F2FF)]
_TODOS = None


def _todos():
    global _TODOS
    if _TODOS is None:
        _TODOS = []
        for a, b in _FAIXAS:
            for cp in range(a, b + 1):
                ch = chr(cp)
                n = unicodedata.name(ch, '')
                if n:
                    _TODOS.append((ch, n.lower()))
    return _TODOS


def _sem(t):
    return ''.join(c for c in unicodedata.normalize('NFD', t.lower()) if unicodedata.category(c) != 'Mn')


def procurar(texto, ctx):
    t = _sem(texto.strip())
    if not t:
        t = 'sorriso'
    vistos, r = set(), []
    for chave, lista in PT.items():
        if chave.startswith(t) or t in chave:
            for e in lista.split():
                if e not in vistos:
                    vistos.add(e)
                    r.append(dict(titulo=e + '   ' + chave, sub='Enter copia', acao='copiar', valor=e, icone='face-smile'))
    for ch, n in _todos():
        if t in n and ch not in vistos:
            vistos.add(ch)
            r.append(dict(titulo=ch + '   ' + n, sub='Enter copia', acao='copiar', valor=ch, icone='face-smile'))
        if len(r) >= 12:
            break
    return r
