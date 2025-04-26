# Void Linux Minimal Automated Installer

This project provides a minimal shell script to automatically install Void Linux onto a target disk with full disk encryption and LVM. It is designed to work with ARM64 only but can easily be adapted if you know what you're doing.

Designed for:
- Automated VM deployments running UEFI
- Clean, simple Void ARM64 setups
- Hands-free installation with default settings

---

## Features

- Wipes and partitions the target disk (`/dev/vda`)
- Creates encrypted LUKS container
- Sets up LVM logical volumes (`root`, `home`, `swap`)
- Formats and mounts filesystems
- Installs Void Linux base system
- Configures encryption and LVM for boot
- Installs and configures GRUB bootloader
- Sets root password to a predefined value

---

## Requirements

- Void Linux live ARM64 glibc image
- Internet access (to fetch packages)
- Basic shell tools available (`bash`, `curl`, `lsblk`, `parted`, `cryptsetup`, `lvm2`, `xbps-install`)
- `xchroot` available (Void installer provides it)

---

## Usage

Fetch and run the script inside a Void Linux live session:

```bash
curl -fsSL http://your-server-address/setup.sh | sh
```

or clone and run:

```bash
git clone https://github.com/sheran/voidvm-arm-efi-installer.git
cd voidvm-arm-efi-installer
sh setup.sh
```

---

## Hardcoded Settings

| Setting | Value |
|:--------|:------|
| Disk | `/dev/vda` |
| Encryption Password | `password` |
| Root Login Password | `password` |
| Hostname | `voidvm` |

---

## Important Notes

- **WARNING:** This script will completely erase `/dev/vda`.  
- **Double check** that `/dev/vda` is the intended install disk before running.
- The encryption and root passwords are currently **fixed**. Modify the script to change them if necessary.
- No interactive confirmation is performed — installation starts immediately.

---

## License

This project is licensed under the MIT License.  
You are free to modify, adapt, or redistribute it.

---

## Future Improvements (Optional)

- Make disk and passwords configurable via environment variables
- Add basic error handling for missing tools
- Add SSH key installation for remote login
- Support different partition layouts


