#!/bin/bash

set -e

: "${USER_PASSWORD:=voidlinux}"

xbps-install -Sy xorg xfce4 curl unzip spice-vdagent mesa-dri dejavu-fonts-ttf openssl \
    ghostty git zsh wget python3 flatpak xdg-desktop-portal-gtk tailscale
ln -sf /etc/sv/dbus /var/service/
ln -sf /etc/sv/spice-vdagentd /var/service/
ln -sf /etc/sv/tailscaled /var/service/

flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install -y --or-update flathub com.brave.Browser
id voiduser >/dev/null 2>&1 || useradd -mG wheel voiduser
echo "exec startxfce4" > /home/voiduser/.xinitrc
sed -i 's/#\s*\(%wheel ALL=(ALL:ALL) NOPASSWD: ALL\)/\1/' /etc/sudoers
chown voiduser:voiduser /home/voiduser/.xinitrc
usermod -p "$(openssl passwd -6 "$USER_PASSWORD")" voiduser
getent shadow voiduser | cut -d: -f2 | grep -q '^\$' || {
    echo "ERROR: password for voiduser was not set!"
    exit 1
}
