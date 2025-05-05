#!/usr/bin/bash

set -e 

: "${DISK:=/dev/vda}"
: "${CRYPT_PASSWORD:=password}"

xbps-install -Sy parted
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart primary fat32 1MiB 100MiB
parted -s "$DISK" set 1 boot on
parted -s "$DISK" set 1 esp on
parted -s "$DISK" mkpart primary ext4 100MiB 100%
parted -s "$DISK" print

echo -n "$CRYPT_PASSWORD" | cryptsetup luksFormat --type luks1 "${DISK}2" --key-file -
echo -n "$CRYPT_PASSWORD" | cryptsetup luksOpen "${DISK}2" voidvm --key-file -

vgcreate voidvm /dev/mapper/voidvm
lvcreate --name root -L 10G voidvm
lvcreate --name swap -L 2G voidvm
lvcreate --name home -l 100%FREE voidvm

mkfs.ext4 -L root /dev/voidvm/root
mkfs.ext4 -L home /dev/voidvm/home
mkswap /dev/voidvm/swap
swapon /dev/voidvm/swap

mount /dev/voidvm/root /mnt
mkdir -p /mnt/home
mount /dev/voidvm/home /mnt/home
mkfs.vfat "${DISK}1"
mkdir -p /mnt/boot/efi
mount "${DISK}1" /mnt/boot/efi

mkdir -p /mnt/var/db/xbps/keys
cp /var/db/xbps/keys/* /mnt/var/db/xbps/keys/
xbps-install -Sy -R https://repo-default.voidlinux.org/current/aarch64 -r /mnt base-system cryptsetup grub-arm64-efi lvm2 dracut linux-6.12_1 curl

xgenfstab /mnt > /mnt/etc/fstab

UUID=$(blkid -o value -s UUID "${DISK}2")

xchroot /mnt /usr/bin/bash <<EOF
set -e

DISK="$DISK"
CRYPT_PASSWORD="$CRYPT_PASSWORD"
UUID="$UUID"

chown root:root /
chmod 755 /

echo -e "${CRYPT_PASSWORD}\n${CRYPT_PASSWORD}" | passwd root
echo "${CRYPT_PASSWORD}" | su -c "echo Login successful!" root || {
    echo "ERROR: Root password test failed!"
    exit 1
}
echo "voidvm" > /etc/hostname
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "en_US.UTF-8 UTF-8" >> /etc/default/libc-locales
xbps-reconfigure -f glibc-locales

echo "GRUB_ENABLE_CRYPTODISK=y" >> /etc/default/grub

sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=\"\\(.*\\)\"|GRUB_CMDLINE_LINUX_DEFAULT=\"\\1 rd.lvm.vg=voidvm rd.luks.uuid=\${UUID}\"|" /etc/default/grub

dd bs=1 count=64 if=/dev/urandom of=/boot/volume.key

echo -n "\${CRYPT_PASSWORD}" | cryptsetup luksAddKey \${DISK}2 /boot/volume.key --key-file -
chmod 000 /boot/volume.key
chmod -R g-rwx,o-rwx /boot

echo "voidvm \${DISK}2 /boot/volume.key luks" >> /etc/crypttab

echo 'install_items+=" /boot/volume.key /etc/crypttab "' > /etc/dracut.conf.d/10-crypt.conf
grub-install ${DISK}
xbps-reconfigure -fa
EOF

