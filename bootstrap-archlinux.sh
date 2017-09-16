#!/usr/bin/env bash

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace

# Exit Codes
EXIT_CODE_INVALID_PARAMETER=1

# Logging Configuration
LOG_LEVEL_ERROR=1
LOG_LEVEL_INFO=2
LOG_LEVEL_DEBUG=3
LOG_LEVEL=${LOG_LEVEL_DEBUG}

# Parameters
hostname=${$1:"myhostname"}
localdomain=${$2:"mylocaldomain"}

#-------------------------------------------------------------------------------
# Methods
#-------------------------------------------------------------------------------

logTitle() {
  log $1 ""
  log $1 "----------------------------------------------"
  log $1 "   # $2"
  log $1 "----------------------------------------------"
}

log() {
  case "$1" in
    ERROR) log_level_code=${LOG_LEVEL_ERROR} ;;
    INFO) log_level_code=${LOG_LEVEL_INFO} ;;
    DEBUG) log_level_code=${LOG_LEVEL_DEBUG} ;;
    *)
        log ERROR "Invalid log level: '$1', log level must be ERROR, INFO or DEBUG"
        exit ${EXIT_CODE_INVALID_PARAMETER}
        ;;
  esac
  if (( "${LOG_LEVEL}" >= "$log_level_code" )); then
    horodate=$(date +%Y-%m-%d:%H:%M:%S)
    echo "${horodate} $1 $2"
  fi
}


#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------

logTitle INFO "Parameters"
log INFO "hostname=${hostname}"
log INFO "localdomain=${localdomain}"

logTitle INFO "Configure usb arch system"
log INFO "Configure 'fr' keyboard"
loadkeys fr-pc
log INFO "Configure ntp"
timedatectl set-ntp true
log INFO "Format boot partition on sda1"
mkfs.ext2 /dev/sda1
log INFO "Format system partition on sda2"
mkfs.ext4 /dev/sda2
log INFO "Format home partition on sda3"
mkfs.ext4 /dev/sda3
log INFO "Mount system partition"
mount /dev/sda2 /mnt
log INFO "Mount home partition"
mkdir /mnt/home && mount /dev/sda3 /mnt/home
log INFO "Mount boot partition"
mkdir /mnt/boot && mount /dev/sda1 /mnt/boot
log INFO "Backup rankmirrors file"
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
log INFO "Activate all servers for the best mirror benchmark"
sed -s 's/^#Server/Server/' /etc/pacman.d/mirrorlist.backup
log INFO "Select 10 best mirrors in mirrorlist file"
rankmirrors -n 10 /etc/pacman.d/mirrorlist.backup > /etc/pacman.d/mirrorlist
log INFO "Install base packages"
pacstrap /mnt base base-devel
log INFO "Generate fstab file"
genfstab -U -p /mnt >> /mnt/etc/fstab

logTitle INFO "Configure new arch system"
log INFO "Chroot to the new system"
arch-chroot /mnt
log INFO "Configure hostname file"
echo ${hostname} > /etc/hostname
log INFO "Configure hosts file"
echo '127.0.1.1 ${hostname}.${localdomain} ${hostname}' >> /etc/hosts
log INFO "Configure localtime"
ln -s /usr/share/zoneinfo/Europe/Paris /etc/localtime
log INFO "Desactive default configuration in locale.gen file"
sed -ie 's/^en/#en/' /etc/locale.gen
log INFO "Active 'FR.UTF-8' configuration in locale.gen file"
sed -ie 's/^#fr_FR.UTF-8/fr_FR.UTF-8/' /etc/locale.gen
log INFO "Generate locale"
locale-gen
log INFO "Add 'fr_FR.UTF-8' to locale.conf file "
echo LANG="fr_FR.UTF-8" > /etc/locale.conf
log INFO "Export 'fr_FR.UTF-8' in LANG variable"
export LANG=fr_FR.UTF-8
log INFO "Configure 'fr' keymap in vconsole.conf file"
echo KEYMAP=fr > /etc/vconsole.conf
log INFO "Create initial ramdisk"
mkinitcpio -p linux

logTitle INFO "Bootloader installation"
log INFO "Install syslinux package"
pacman -S syslinux
log INFO "Configure syslinux for BIOS system"
syslinux-install_update -iam


logTitle INFO "Prepare end of installation"
log INFO "Exit chroot"
exit
log INFO "Umount the new arch system"
umount -R /mnt
log INFO "You could reboot and remove the usb key"
