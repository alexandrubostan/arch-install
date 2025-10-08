#!/bin/bash

set -eo pipefail

EFI='/dev/nvme0n1p1'
#BOOT='/dev/nvme0n1p4'
ROOT='/dev/nvme0n1p5'

ext4fs () {
  mkfs.ext4 -O fast_commit "$ROOT"
  mount "$ROOT" /mnt
  mount --mkdir "$EFI" /mnt/efi
  #mount --mkdir "$BOOT" /mnt/boot
}

ext4fs

pacstrap -K /mnt base linux linux-firmware-amdgpu linux-firmware-realtek vim sudo booster networkmanager

sed -e '/en_US.UTF-8/s/^#*//' -i /mnt/etc/locale.gen
sed -e '/ro_RO.UTF-8/s/^#*//' -i /mnt/etc/locale.gen

arch-chroot /mnt ln -sf /usr/share/zoneinfo/Europe/Bucharest /etc/localtime
arch-chroot /mnt hwclock --systohc
arch-chroot /mnt locale-gen

echo 'LANG=en_US.UTF-8' | tee /mnt/etc/locale.conf > /dev/null
echo 'LC_TIME=ro_RO.UTF-8' | tee -a /mnt/etc/locale.conf > /dev/null
echo '/dev/gpt-auto-root  /  ext4  rw,noatime,commit=15  0  1' | tee -a /mnt/etc/fstab > /dev/null
echo 'archie' | tee /mnt/etc/hostname > /dev/null

systemctl enable fstrim.timer --root=/mnt
systemctl enable NetworkManager.service --root=/mnt

arch-chroot /mnt passwd
arch-chroot /mnt useradd -m -G wheel alexb
arch-chroot /mnt passwd alexb

echo '%wheel      ALL=(ALL:ALL) ALL' | tee -a /mnt/etc/sudoers > /dev/null
