#!/bin/bash

set -e

: "${USER_PASSWORD:=voidlinux}"

xbps-install -Sy xorg xfce4 neovim curl unzip spice-vdagent mesa-dri dejavu-fonts-ttf openssl
ln -sf /etc/sv/dbus /var/service/
ln -sf /etc/sv/spice-vdagentd /var/service/
id voiduser >/dev/null 2>&1 || useradd -mG wheel voiduser
echo "exec startxfce4" > /home/voiduser/.xinitrc
sed -i 's/#\s*\(%wheel ALL=(ALL:ALL) NOPASSWD: ALL\)/\1/' /etc/sudoers
chown voiduser:voiduser /home/voiduser/.xinitrc
usermod -p "$(openssl passwd -6 "$USER_PASSWORD")" voiduser
getent shadow voiduser | cut -d: -f2 | grep -q '^\$' || {
    echo "ERROR: password for voiduser was not set!"
    exit 1
}
