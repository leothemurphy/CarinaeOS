# Segurança do CarinaeOS

## Comunicar uma falha

Se encontrou uma falha de segurança no CarinaeOS (nos apps, nos ajudantes em `/usr/lib/carinaeos/`,
nas regras do polkit, na ISO…), **não abra uma issue pública**. Use o
[aviso privado do GitHub](https://github.com/leothemurphy/CarinaeOS/security/advisories/new)
(*Security › Report a vulnerability*).

Diga o que encontrou, como reproduzir e a versão (`cat /etc/os-release`). Respondemos assim que possível
e damos crédito na correção, se quiser.

Falhas do Debian, do KDE ou de outros programas que o CarinaeOS só inclui devem ir para esses projetos
(por exemplo, <https://www.debian.org/security/>). Se não tiver certeza, comunique aqui na mesma.

## Versões com correções

Só a versão mais recente (a de *Releases*) recebe correções. As correções de segurança do Debian
chegam sozinhas a todas as instalações, todos os dias.

## Verificar a ISO

```
curl -fsSL https://raw.githubusercontent.com/leothemurphy/CarinaeOS/main/carinaeos-chave.asc | gpg --import
gpg --verify SHA256SUMS.asc SHA256SUMS
sha256sum -c SHA256SUMS
```

Impressão digital da chave: `94E2 2F7D 9EF1 1315 1B87  CB4E 180C FE53 9CF1 308F`
