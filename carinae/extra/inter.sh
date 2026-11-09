#!/bin/bash
# CarinaeOS - fonte Inter 4.1 (licenca SIL OFL), a letra da interface: limpa e
# proxima da do macOS. Instalada como na pagina "TTF and OTF fonts" do BLFS.
set -e
cd /sources/blfs && mkdir -p fontes && cd fontes
F=Inter-4.1.zip
[ -s $F ] && echo "d00ce561d197b9a2fb82b2fa615075b7  $F" | md5sum -c - >/dev/null 2>&1 || {
  rm -f $F; wget -q -O $F https://github.com/rsms/inter/releases/download/v4.1/$F; }
echo "d00ce561d197b9a2fb82b2fa615075b7  $F" | md5sum -c -
rm -rf inter && python3 -m zipfile -e $F inter
install -v -d -m755 /usr/share/fonts/inter
install -v -m644 inter/InterVariable.ttf inter/InterVariable-Italic.ttf /usr/share/fonts/inter
fc-cache -v /usr/share/fonts/inter
