#!/bin/bash

set -eo pipefail

EFI='/dev/nvme0n1p1'
ROOT='/dev/nvme0n1p2'
DRIVE='/dev/nvme0n1'
EFIPART=1

mkfs.ext4 $ROOT
mount $ROOT /mnt
mount --mkdir $EFI /mnt/efi

#cryptsetup luksFormat $ROOT
#cryptsetup --allow-discards --perf-no_read_workqueue --perf-no_write_workqueue --persistent open $ROOT root
#mkfs.ext4 /dev/mapper/root
#mount /dev/mapper/root /mnt
#mount --mkdir $EFI /mnt/efi

pacstrap -K /mnt base linux linux-firmware vim sudo \
efibootmgr \
networkmanager \
terminus-font \
intel-ucode

echo '%wheel      ALL=(ALL:ALL) NOPASSWD: ALL' | tee -a /mnt/etc/sudoers > /dev/null

sed -i '/en_US.UTF-8 UTF-8/s/^#//' /mnt/etc/locale.gen
sed -i '/ro_RO.UTF-8 UTF-8/s/^#//' /mnt/etc/locale.gen
echo 'LANG=en_US.UTF-8' | tee /mnt/etc/locale.conf > /dev/null
echo 'archbox' | tee /mnt/etc/hostname > /dev/null

echo 'FONT=ter-132b' | tee /mnt/etc/vconsole.conf > /dev/null

arch-chroot /mnt ln -sf /usr/share/zoneinfo/Europe/Bucharest /etc/localtime
arch-chroot /mnt hwclock --systohc
arch-chroot /mnt locale-gen

mkdir -p /mnt/etc/cmdline.d
echo 'rw quiet' | tee /mnt/etc/cmdline.d/root.conf > /dev/null

tee /mnt/etc/mkinitcpio.d/linux.preset > /dev/null << EOF
# mkinitcpio preset file for the 'linux' package

#ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-linux"

PRESETS=('default')

#default_config="/etc/mkinitcpio.conf"
#default_image="/boot/initramfs-linux.img"
default_uki="/efi/EFI/Linux/arch-linux.efi"
default_options="--splash=/usr/share/systemd/bootctl/splash-arch.bmp"
EOF

tee /mnt/etc/mkinitcpio.conf > /dev/null << EOF
MODULES=(i915)
#MODULES=(amdgpu)
BINARIES=()
FILES=()
HOOKS=(systemd autodetect microcode modconf keyboard sd-vconsole block filesystems fsck)
#HOOKS=(systemd autodetect microcode modconf keyboard sd-vconsole block sd-encrypt filesystems fsck)
EOF

rm -rf /mnt/efi/EFI/Linux
mkdir /mnt/efi/EFI/Linux
arch-chroot /mnt mkinitcpio -p linux

systemctl enable NetworkManager --root=/mnt
systemctl enable fstrim.timer --root=/mnt

efibootmgr --create \
--disk $DRIVE --part $EFIPART \
--label "Arch Linux" \
--loader 'EFI/Linux/arch-linux.efi' \
--unicode
