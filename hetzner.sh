#!/usr/bin/bash
#
# Void Linux installer for Hetzner Cloud rescue console (ARM64)
# Run this from Hetzner's rescue system (Debian-based)
#

set -e

: "${DISK:=/dev/sda}"
: "${ROOT_PASSWORD:=password}"
: "${VOID_HOSTNAME:=voidvm}"
: "${VOID_USER:=sheran}"
: "${SSH_PUBKEY:=}"
: "${XBPS_ARCH:=aarch64}"
: "${VOID_REPO:=https://repo-default.voidlinux.org/current/aarch64}"
: "${VOID_STATIC_XBPS:=https://repo-default.voidlinux.org/static/xbps-static-latest.aarch64-musl.tar.xz}"

MOUNTPOINT="/mnt/void"

echo "==> Installing dependencies in rescue system..."
apt-get update
apt-get install -y parted dosfstools curl xz-utils

echo "==> Downloading static XBPS..."
mkdir -p /tmp/xbps
curl -fsSL "$VOID_STATIC_XBPS" | tar -xJ -C /tmp/xbps
export PATH="/tmp/xbps/usr/bin:$PATH"

echo "==> Partitioning ${DISK}..."
wipefs -a "$DISK"
parted -s "$DISK" mklabel gpt
parted -s "$DISK" mkpart primary fat32 1MiB 512MiB
parted -s "$DISK" set 1 boot on
parted -s "$DISK" set 1 esp on
parted -s "$DISK" mkpart primary ext4 512MiB 12GiB
parted -s "$DISK" mkpart primary ext4 12GiB 95%
parted -s "$DISK" mkpart primary linux-swap 95% 100%
parted -s "$DISK" print

echo "==> Formatting partitions..."
mkfs.vfat -F32 "${DISK}1"
mkfs.ext4 -F -L root "${DISK}2"
mkfs.ext4 -F -L home "${DISK}3"
mkswap "${DISK}4"

echo "==> Mounting filesystems..."
mkdir -p "$MOUNTPOINT"
mount "${DISK}2" "$MOUNTPOINT"
mkdir -p "$MOUNTPOINT/home"
mount "${DISK}3" "$MOUNTPOINT/home"
mkdir -p "$MOUNTPOINT/boot/efi"
mount "${DISK}1" "$MOUNTPOINT/boot/efi"

echo "==> Installing Void Linux base system..."
mkdir -p "$MOUNTPOINT/var/db/xbps/keys"
cp /tmp/xbps/var/db/xbps/keys/* "$MOUNTPOINT/var/db/xbps/keys/"

XBPS_ARCH="$XBPS_ARCH" xbps-install -Sy -R "$VOID_REPO" -r "$MOUNTPOINT" \
    base-system \
    grub-arm64-efi \
    dracut \
    linux6.12 \
    dhcpcd \
    curl \
    wget \
    git \
    zsh \
    unzip \
    python3 \
    openssh \
    sudo \
    tailscale \
    void-repo-nonfree

echo "==> Generating fstab..."
cat > "$MOUNTPOINT/etc/fstab" <<FSTAB
# <file system> <dir> <type> <options> <dump> <pass>
${DISK}2        /           ext4    defaults        0 1
${DISK}3        /home       ext4    defaults        0 2
${DISK}1        /boot/efi   vfat    defaults        0 2
${DISK}4        none        swap    sw              0 0
FSTAB

echo "==> Preparing chroot..."
mount --rbind /dev "$MOUNTPOINT/dev"
mount --make-rslave "$MOUNTPOINT/dev"
mount --rbind /proc "$MOUNTPOINT/proc"
mount --make-rslave "$MOUNTPOINT/proc"
mount --rbind /sys "$MOUNTPOINT/sys"
mount --make-rslave "$MOUNTPOINT/sys"

echo "==> Configuring system in chroot..."
chroot "$MOUNTPOINT" /usr/bin/bash <<EOF
set -e

DISK="$DISK"
ROOT_PASSWORD="$ROOT_PASSWORD"
VOID_HOSTNAME="$VOID_HOSTNAME"
VOID_USER="$VOID_USER"
SSH_PUBKEY="$SSH_PUBKEY"

# Fix ownership
chown root:root /
chmod 755 /

# Root password (use passwd directly, chpasswd is flaky in chroot)
echo -e "\${ROOT_PASSWORD}\n\${ROOT_PASSWORD}" | passwd root

# SSH authorized keys
mkdir -p /root/.ssh
chmod 700 /root/.ssh
echo "\${SSH_PUBKEY}" > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# Set zsh as default shell for root
chsh -s /bin/zsh root

# Create user
useradd -m -G wheel -s /bin/zsh "\${VOID_USER}"

# SSH authorized keys for user
mkdir -p /home/\${VOID_USER}/.ssh
chmod 700 /home/\${VOID_USER}/.ssh
echo "\${SSH_PUBKEY}" > /home/\${VOID_USER}/.ssh/authorized_keys
chmod 600 /home/\${VOID_USER}/.ssh/authorized_keys
chown -R \${VOID_USER}:\${VOID_USER} /home/\${VOID_USER}/.ssh

# Enable passwordless sudo for wheel group
echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

# Hostname
echo "\${VOID_HOSTNAME}" > /etc/hostname
echo "127.0.0.1 localhost" > /etc/hosts
echo "127.0.1.1 \${VOID_HOSTNAME}" >> /etc/hosts

# Locale
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "en_US.UTF-8 UTF-8" >> /etc/default/libc-locales
xbps-reconfigure -f glibc-locales

# Timezone (adjust if needed)
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# Enable services
ln -sf /etc/sv/dhcpcd /etc/runit/runsvdir/default/
ln -sf /etc/sv/sshd /etc/runit/runsvdir/default/
ln -sf /etc/sv/tailscaled /etc/runit/runsvdir/default/

# Permit root SSH login (change after first login)
sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

# Install GRUB
grub-install --target=arm64-efi --efi-directory=/boot/efi --bootloader-id=void --removable

# Reconfigure all packages (generates initramfs, etc.)
xbps-reconfigure -fa
EOF

echo "==> Cleaning up mounts..."
umount -R "$MOUNTPOINT/dev" || true
umount -R "$MOUNTPOINT/proc" || true
umount -R "$MOUNTPOINT/sys" || true
umount -R "$MOUNTPOINT" || true

echo ""
echo "=========================================="
echo "Installation complete!"
echo ""
echo "Exit rescue mode in Hetzner console and reboot."
echo ""
echo "User '${VOID_USER}' created with sudo (no password)."
echo "SSH key installed for root and ${VOID_USER}."
echo "Tailscale installed - run 'tailscale up --qr --ssh' after reboot."
echo "=========================================="
