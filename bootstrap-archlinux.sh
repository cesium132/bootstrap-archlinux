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

# Set magic variables for current file & dir
__dir="$(cd "$(dirname "$0")" && pwd)"
__file="${__dir}/$(basename "$0")"
__base="$(basename ${__file} .sh)"

# Exit Codes
EXIT_CODE_INVALID_PARAMETER=1

# Logging Configuration
LOG_LEVEL_ERROR=1
LOG_LEVEL_INFO=2
LOG_LEVEL_DEBUG=3
LOG_LEVEL=${LOG_LEVEL_DEBUG}

# Constants
readonly TMP_INIT_PASSWORD_FILE="tmp_init_password.sh"
readonly LOG_FILE="${__base}.log"

# Parameters
user_login=${1:-user_login}
hostname=${2:-myhostname}
localdomain=${3:-mylocaldomain}
device_boot_partition=${4:-sda1}
device_system_partition=${5:-sda2}
device_home_partition=${6:-sda3}
locale=${7:-fr_FR.UTF-8}
country=${8:-fr}
zoneinfo=${9:-"Europe/Paris"}
keyboard_mapping=${10:-fr-pc}


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

initPassword() {
  login = $1
  password = $2
  log INFO "Prepare init password script"
  echo "echo '${login}:${password}' | chpasswd" > /mnt/${TMP_INIT_PASSWORD_FILE}
  log INFO "Give execution right to ${TMP_INIT_PASSWORD_FILE} file"
  chmod 700 /mnt/${TMP_INIT_PASSWORD_FILE}
  log INFO "Init the ${login} password"
  arch-chroot /mnt "/${TMP_INIT_PASSWORD_FILE}"
  log INFO "Delete ${TMP_INIT_PASSWORD_FILE} file"
  rm -f /mnt/${TMP_INIT_PASSWORD_FILE}
}


#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------

(

logTitle INFO "Parameters"
log INFO "user_login=${user_login}"
log INFO "hostname=${hostname}"
log INFO "localdomain=${localdomain}"
log INFO "device_boot_partition=${device_boot_partition}"
log INFO "device_system_partition=${device_system_partition}"
log INFO "device_home_partition=${device_home_partition}"
log INFO "locale=${locale}"
log INFO "country=${country}"
log INFO "keyboard_mapping=${keyboard_mapping}"

logTitle INFO "Input"
log INFO "Configure '${keyboard_mapping}' keyboard"
loadkeys ${keyboard_mapping}
log INFO "Enter the new root password:"
read -s root_password
log INFO "Enter the new user password:"
read -s user_password

logTitle INFO "Configure usb arch system"
log INFO "Configure ntp"
timedatectl set-ntp true
log INFO "Format boot partition on ${device_boot_partition}"
mkfs.ext2 -qF /dev/${device_boot_partition}
log INFO "Format system partition on ${device_system_partition}"
mkfs.ext4 -qF /dev/${device_system_partition}
log INFO "Format home partition on ${device_home_partition}"
mkfs.ext4 -qF /dev/${device_home_partition}
log INFO "Mount system partition"
mount /dev/${device_system_partition} /mnt
log INFO "Mount home partition"
mkdir /mnt/home && mount /dev/${device_home_partition} /mnt/home
log INFO "Mount boot partition"
mkdir /mnt/boot && mount /dev/${device_boot_partition} /mnt/boot
log INFO "Backup rankmirrors file"
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
log INFO "Activate all servers for the best mirror benchmark"
sed -ie 's/^#Server/Server/' /etc/pacman.d/mirrorlist.backup
log INFO "Determine the 10 best mirrors in mirrorlist file (this may take 2-3min)"
rankmirrors -n 10 /etc/pacman.d/mirrorlist.backup > /etc/pacman.d/mirrorlist
log INFO "Install base packages"
pacstrap /mnt base base-devel
log INFO "Generate fstab file"
genfstab -U -p /mnt >> /mnt/etc/fstab

logTitle INFO "Configure new arch system"
echo "Chroot to the new system"
cat << EOF | sudo arch-chroot /mnt
echo ${hostname} > /etc/hostname
echo "Configure hosts file"
echo -e "127.0.1.1\t${hostname}.${localdomain}\t${hostname}" >> /etc/hosts
echo "Disable default localtime"
rm /etc/localtime
echo "Configure localtime on ${zoneinfo}"
ln -s /usr/share/zoneinfo/${zoneinfo} /etc/localtime
echo "Desactive default configuration in locale.gen file"
sed -ie 's/^en/#en/' /etc/locale.gen
echo "Active '${locale}' configuration in locale.gen file"
sed -ie "s/^#${locale}/${locale}/" /etc/locale.gen
echo "Generate locale"
locale-gen
echo "Add '${locale}' to locale.conf file "
echo LANG="${locale}" > /etc/locale.conf
echo "Export '${locale}' in LANG variable"
export LANG=${locale}
echo "Configure '${country}' keymap in vconsole.conf file"
echo KEYMAP=${country} > /etc/vconsole.conf
echo "Create initial ramdisk"
mkinitcpio -p linux
echo "Install openssh package"
pacman -Sq --noconfirm openssh
echo "Enable DHCP service"
systemctl enable dhcpcd
echo "Enable openssh service"
systemctl enable sshd
echo "Add user ${user_login}"
useradd -g wheel ansible

echo -e "\n-- Bootloader installation --"
echo "Install syslinux package"
pacman -Sq --noconfirm syslinux
echo "Configure syslinux for BIOS system"
syslinux-install_update -iam
echo "Desactive default configuration in locale.gen file"
sed -ie "s/sda3/${device_system_partition}/" /boot/syslinux/syslinux.cfg
EOF
log INFO "Exit chroot done"

logTitle INFO "End of installation"
initPassword "root" "${root_password}"
initPassword "${user_login}" "${user_password}"

) 2>&1 | tee -a $LOG_FILE

log INFO "Copy log file to the new arch installation"
mv ${LOG_FILE} /mnt/
log INFO "Unmount the new arch installation"
umount -R /mnt
log INFO "You could now reboot and remove the usb key"
