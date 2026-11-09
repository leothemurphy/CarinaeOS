#!/bin/bash
# CarinaeOS - passa a rede para o NetworkManager (bloco #9 da pagina do livro),
# desativando o systemd-networkd que configuramos no LFS. So vale no proximo
# arranque, por isso o SSH atual nao cai.
set -e
systemctl enable NetworkManager
systemctl disable systemd-networkd.service systemd-networkd.socket systemd-networkd-wait-online.service 2>/dev/null || true
mkdir -p /etc/systemd/network/desativado
mv -v /etc/systemd/network/10-eth-dhcp.network /etc/systemd/network/desativado/ 2>/dev/null || true
