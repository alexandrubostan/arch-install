#!/bin/bash

set -eo pipefail

EFI='/dev/nvme0n1p1'
#BOOT='/dev/nvme0n1p4'
ROOT='/dev/nvme0n1p5'

ext4fs () {
  mkfs.ext4 "$ROOT"
  mount "$ROOT" /mnt
  mount --mkdir "$EFI" /mnt/efi
  #mount --mkdir "$BOOT" /mnt/boot
}

ext4fs

pacstrap -K /mnt base linux linux-firmware-amdgpu linux-firmware-realtek vim sudo amd-ucode

sed -e '/en_US.UTF-8/s/^#*//' -i /mnt/etc/locale.gen
sed -e '/ro_RO.UTF-8/s/^#*//' -i /mnt/etc/locale.gen

arch-chroot /mnt ln -sf /usr/share/zoneinfo/Europe/Bucharest /etc/localtime
arch-chroot /mnt hwclock --systohc
arch-chroot /mnt locale-gen

echo 'LANG=en_US.UTF-8' | tee /mnt/etc/locale.conf > /dev/null
echo 'LC_TIME=ro_RO.UTF-8' | tee -a /mnt/etc/locale.conf > /dev/null

echo '/dev/gpt-auto-root  /  ext4  defaults,noatime  0  1' | tee -a /mnt/etc/fstab > /dev/null

tee -a /mnt/etc/hosts > /dev/null << EOF
127.0.0.1        localhost
::1              localhost ip6-localhost ip6-loopback
EOF

echo 'archie' | tee /mnt/etc/hostname > /dev/null
echo 'rw amdgpu.ppfeaturemask=0xffffffff' | tee /mnt/etc/kernel/cmdline > /dev/null

tee /mnt/etc/mkinitcpio.d/linux.preset > /dev/null << EOF
# mkinitcpio preset file for the 'linux' package

#ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-linux"

PRESETS=('default')

#default_config="/etc/mkinitcpio.conf"
#default_image="/boot/initramfs-linux.img"
default_uki="/efi/EFI/Linux/arch-linux.efi"
#default_options=""
EOF

tee /mnt/etc/mkinitcpio.conf > /dev/null << EOF
MODULES=()
BINARIES=()
FILES=()
HOOKS=(systemd autodetect microcode modconf block filesystems fsck)
EOF

systemctl enable fstrim.timer --root=/mnt

arch-chroot /mnt passwd
arch-chroot /mnt useradd -m -G wheel alexb
arch-chroot /mnt passwd alexb

echo '%wheel      ALL=(ALL:ALL) ALL' | tee -a /mnt/etc/sudoers > /dev/null