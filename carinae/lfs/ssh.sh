#!/bin/bash
# CarinaeOS - instala o OpenSSH seguindo o livro BLFS 13.1-systemd (servidor SSH)
set -e
LOG=/root/ssh-instalacao.log
exec > >(tee $LOG) 2>&1
mkdir -p /sources/blfs && cd /sources/blfs
baixa(){ python3 -c 'import sys,ssl,urllib.request as r;open(sys.argv[2],"wb").write(r.urlopen(sys.argv[1],context=ssl._create_unverified_context(),timeout=120).read())' "$1" "$2"; }
B=https://www.linuxfromscratch.org/blfs/view/13.1-systemd
echo "== baixando paginas do livro BLFS 13.1-systemd"
baixa $B/postlfs/openssh.html openssh.html
baixa $B/introduction/systemd-units.html units.html
python3 - <<'PY'
import re,html
def txt(x): return html.unescape(re.sub(r'<[^>]+>','',x))
def pacote(pag, nome):
    s=open(pag,encoding='utf-8').read()
    url=re.findall(r'href=\s*"(https?://[^"]*'+nome+r'-[0-9][^"]*\.tar\.(?:gz|xz))"',s)[0]
    m=re.search(r'MD5 sum:\s*([0-9a-f]{32})',txt(s))
    md5=m.group(1) if m else '-'

    return s,url,md5
s,url,md5=pacote('openssh.html','openssh')
open('openssh.url','w').write(url+'\n'+md5+'\n')
_,uurl,umd5=pacote('units.html','blfs-systemd-units')
open('units.url','w').write(uurl+'\n'+umd5+'\n')
bl=[txt(b).strip() for b in re.findall(r'<pre\s+class="(?:root|userinput)"\s*>(.*?)</pre>',s,re.S)]
PULAR=re.compile(r'\btests\b|PermitRootLogin|PasswordAuthentication|KbdInteractive|ssh-keygen|ssh-copy-id -i|install-sshd|UsePAM|pam\.d')
usar=[]
for i,b in enumerate(bl):
    l1=b.splitlines()[0][:80]
    if PULAR.search(b): print(f'   PULADO #{i}: {l1}')
    else: print(f'   RODA   #{i}: {l1}'); usar.append(b)
open('build.sh','w').write('\n'.join(usar)+'\n')
print('== openssh:',url,md5); print('== units:',uurl,umd5)
PY
U=$(sed -n 1p openssh.url); M=$(sed -n 2p openssh.url); T=$(basename $U)
baixa $U $T; echo "$M  $T" | md5sum -c -
UU=$(sed -n 1p units.url); UM=$(sed -n 2p units.url); UT=$(basename $UU)
baixa $UU $UT; [ "$UM" = "-" ] || echo "$UM  $UT" | md5sum -c -
D=$(tar -tf $T | sed -n 1p | cut -d/ -f1); rm -rf $D; tar -xf $T; cd $D
echo "== compilando $D (comandos do BLFS)"
bash -e ../build.sh
cd /sources/blfs
UD=$(tar -tf $UT | sed -n 1p | cut -d/ -f1); rm -rf $UD; tar -xf $UT; cd $UD
make install-sshd
grep -q '^PermitRootLogin yes' /etc/ssh/sshd_config || echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
systemctl enable --now sshd
systemctl --no-pager status sshd | head -5
echo "== SSH PRONTO. Enderecos:"; ip -4 -br addr
