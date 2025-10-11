#!/bin/bash
set -eo pipefail

EFI='/dev/nvme0n1p1'
#BOOT='/dev/nvme0n1p4'
ROOT='/dev/nvme0n1p5'

ext4fs_luks () {
  cryptsetup luksFormat "$ROOT"
  cryptsetup --allow-discards --perf-no_read_workqueue --perf-no_write_workqueue --persistent open "$ROOT" cry
  mkfs.ext4 /dev/mapper/cry
  tune2fs -O fast_commit /dev/mapper/cry
  mount /dev/mapper/cry /mnt
  mount --mkdir "$EFI" /mnt/efi
  #mount --mkdir "$BOOT" /mnt/boot
}
ext4fs_luks

pacstrap -K /mnt base linux linux-firmware-intel vim sudo intel-ucode networkmanager

sed -e '/en_US.UTF-8/s/^#*//' -i /mnt/etc/locale.gen
sed -e '/ro_RO.UTF-8/s/^#*//' -i /mnt/etc/locale.gen

arch-chroot /mnt ln -sf /usr/share/zoneinfo/Europe/Bucharest /etc/localtime
arch-chroot /mnt hwclock --systohc
arch-chroot /mnt locale-gen

echo 'LANG=en_US.UTF-8' | tee /mnt/etc/locale.conf > /dev/null
echo 'LC_TIME=ro_RO.UTF-8' | tee -a /mnt/etc/locale.conf > /dev/null
echo '/dev/gpt-auto-root  /  ext4  rw,noatime  0  1' | tee -a /mnt/etc/fstab > /dev/null
echo 'archie' | tee /mnt/etc/hostname > /dev/null

ROOTUUID="$(blkid -s UUID -o value "$ROOT")"
echo "rw rd.luks.name=$ROOTUUID=cry root=/dev/mapper/cry" | tee /mnt/etc/kernel/cmdline > /dev/null

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
HOOKS=(systemd autodetect microcode modconf keyboard sd-vconsole block sd-encrypt filesystems fsck)
EOF

arch-chroot /mnt bootctl install
#arch-chroot /mnt bootctl --esp-path=/efi --boot-path=/boot install
efibootmgr -c -d "$EFI" -l '\EFI\SYSTEMD\SYSTEMD-BOOTX64.EFI' -u

systemctl enable fstrim.timer --root=/mnt
systemctl enable NetworkManager.service --root=/mnt

arch-chroot /mnt passwd
arch-chroot /mnt useradd -m -G wheel alexb
arch-chroot /mnt passwd alexb

echo '%wheel      ALL=(ALL:ALL) ALL' | tee -a /mnt/etc/sudoers > /dev/null
