#!/bin/bash

xbps-install -Sy xorg xfce4 neovim curl unzip spice-vdagent mesa-dri dejavu-fonts-ttf
ln -s /etc/sv/dbus /var/service/
ln -s /etc/sv/spice-vdagentd /var/service/
useradd -mG wheel voiduser
echo "exec startxfce4" >> /home/voiduser/.xinitrc
sed -i 's/#\s*\(%wheel ALL=(ALL:ALL) NOPASSWD: ALL\)/\1/' /etc/sudoers
chown voiduser:voiduser /home/voiduser/.xinitrc
passwd voiduser
