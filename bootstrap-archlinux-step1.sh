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

# Constants
BOOTSTRAP_ARCHLINUX_RAW_MASTER_REPO="https://raw.githubusercontent.com/cesium132/bootstrap-archlinux/master"
BOOTSTRAP_ARCHLINUX_STEP2_SCRIPT="bootstrap-archlinux-step2.sh"

# Parameters
keyboard_mapping=${1:-fr-pc}


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
log INFO "keyboard_mapping=${keyboard_mapping}"

logTitle INFO "Configure usb arch system"
log INFO "Configure '${keyboard_mapping}' keyboard"
loadkeys ${keyboard_mapping}
log INFO "Configure ntp"
timedatectl set-ntp true
log INFO "Format boot partition on sda1"
mkfs.ext2 -F /dev/sda1
log INFO "Format system partition on sda2"
mkfs.ext4 -F /dev/sda2
log INFO "Format home partition on sda3"
mkfs.ext4 -F /dev/sda3
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
log INFO "Download '${BOOTSTRAP_ARCHLINUX_STEP2_SCRIPT}'"
wget -O /mnt/root/${BOOTSTRAP_ARCHLINUX_STEP2_SCRIPT} "${BOOTSTRAP_ARCHLINUX_RAW_MASTER_REPO}/${BOOTSTRAP_ARCHLINUX_STEP2_SCRIPT}"
log INFO "Give execution right to root on ${BOOTSTRAP_ARCHLINUX_STEP2_SCRIPT}"
chmod 700 /mnt/root/${BOOTSTRAP_ARCHLINUX_STEP2_SCRIPT}
log INFO "Chroot to the new system, then you could now execute '${BOOTSTRAP_ARCHLINUX_STEP2_SCRIPT}'"
arch-chroot /mnt
