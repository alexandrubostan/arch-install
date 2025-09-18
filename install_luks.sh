#!/bin/bash

set -eo pipefail

EFI='/dev/nvme0n1p1'
#BOOT='/dev/nvme0n1p4'
ROOT='/dev/nvme0n1p5'

ext4fs_luks () {
  cryptsetup luksFormat "$ROOT"
  cryptsetup --allow-discards --perf-no_read_workqueue --perf-no_write_workqueue --persistent open "$ROOT" root
  
  pvcreate /dev/mapper/root
  vgcreate g /dev/mapper/root
  lvcreate -L 16G -n swap g
  lvcreate -l 100%FREE -n root g
  lvreduce -L -256M g/root
  
  mkfs.btrfs /dev/g/root --force
  mount /dev/g/root /mnt
  btrfs subvolume create /mnt/@
  btrfs subvolume create /mnt/@home
  umount /mnt
  mount -o compress-force=zstd:2,noatime,subvol=@ /dev/g/root /mnt
  mkdir -p /mnt/home
  mount -o compress-force=zstd:2,noatime,subvol=@home /dev/g/root /mnt/home
  
  mount --mkdir "$EFI" /mnt/efi
  mkswap /dev/g/swap
  #mount --mkdir "$BOOT" /mnt/boot
}

ext4fs_luks

pacstrap -K /mnt base linux linux-firmware-intel vim sudo intel-ucode lvm2
genfstab -U /mnt >> /mnt/etc/fstab

sed -e '/en_US.UTF-8/s/^#*//' -i /mnt/etc/locale.gen
sed -e '/ro_RO.UTF-8/s/^#*//' -i /mnt/etc/locale.gen

arch-chroot /mnt ln -sf /usr/share/zoneinfo/Europe/Bucharest /etc/localtime
arch-chroot /mnt hwclock --systohc
arch-chroot /mnt locale-gen

echo 'LANG=en_US.UTF-8' | tee /mnt/etc/locale.conf > /dev/null
echo 'LC_TIME=ro_RO.UTF-8' | tee -a /mnt/etc/locale.conf > /dev/null

tee -a /mnt/etc/hosts > /dev/null << EOF
127.0.0.1        localhost
::1              localhost ip6-localhost ip6-loopback
EOF

echo 'ArchLenovo' | tee /mnt/etc/hostname > /dev/null

ROOTUUID="$(blkid -s UUID -o value "$ROOT")"
echo "rd.luks.name=$ROOTUUID=root root=/dev/g/root ipv6.disable=1 systemd.gpt_auto=0" | tee /mnt/etc/kernel/cmdline > /dev/null

mkdir -p /mnt/efi/EFI/BOOT
tee /mnt/etc/mkinitcpio.d/linux.preset > /dev/null << EOF
# mkinitcpio preset file for the 'linux' package

#ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-linux"

PRESETS=('default')

#default_config="/etc/mkinitcpio.conf"
#default_image="/boot/initramfs-linux.img"
default_uki="/efi/EFI/BOOT/BOOTX64.EFI"
#default_options=""
EOF

tee /mnt/etc/mkinitcpio.conf > /dev/null << EOF
MODULES=()
BINARIES=()
FILES=()
HOOKS=(systemd autodetect microcode modconf keyboard sd-vconsole block sd-encrypt lvm2 filesystems fsck)
EOF

systemctl enable fstrim.timer --root=/mnt

arch-chroot /mnt passwd
arch-chroot /mnt useradd -m -G wheel alexb
arch-chroot /mnt passwd alexb

echo '%wheel      ALL=(ALL:ALL) ALL' | tee -a /mnt/etc/sudoers > /dev/null
