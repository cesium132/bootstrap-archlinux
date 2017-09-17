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
hostname=${1:-myhostname}
localdomain=${2:-mylocaldomain}
device_system_partition=${3:-sda2}
locale=${3:-fr_FR.UTF-8}
country=${4:-fr}
zoneinfo=${5:-"Europe/Paris"}

# Methods
#-------------------------------------------------------------------------------
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
log INFO "locale=${locale}"
log INFO "country=${country}"

logTitle INFO "Configure new arch system"
log INFO "Configure hostname file"
echo ${hostname} > /etc/hostname
log INFO "Configure hosts file"
echo -e "127.0.1.1\t${hostname}.${localdomain}\t${hostname}" >> /etc/hosts
log INFO "Disable default localtime"
rm /etc/localtime
log INFO "Configure localtime"
ln -s /usr/share/zoneinfo/${zoneinfo} /etc/localtime
log INFO "Desactive default configuration in locale.gen file"
sed -ie 's/^en/#en/' /etc/locale.gen
log INFO "Active '${locale}' configuration in locale.gen file"
sed -ie "s/^#${locale}/${locale}/" /etc/locale.gen
log INFO "Generate locale"
locale-gen
log INFO "Add '${locale}' to locale.conf file "
echo LANG="${locale}" > /etc/locale.conf
log INFO "Export '${locale}' in LANG variable"
export LANG=${locale}
log INFO "Configure '${country}' keymap in vconsole.conf file"
echo KEYMAP=${country} > /etc/vconsole.conf
log INFO "Create initial ramdisk"
mkinitcpio -p linux
log INFO "Desactive default configuration in locale.gen file"
sed -ie "s/sda2/${device_system_partition}/" /etc/locale.gen

logTitle INFO "Bootloader installation"
log INFO "Install syslinux package"
pacman -Sq syslinux
log INFO "Configure syslinux for BIOS system"
syslinux-install_update -iam

logTitle INFO "End of installation"
log INFO "You can now exit chroot and unmount the new arch installation :"
log INFO " $ exit"
log INFO " $ umount -R /mnt"
log INFO "Then, you could reboot and remove the usb key"
