#!/bin/bash

set -e

# Downloads common.sh if script was run out of the git tree eg: Following readme instructions.
common_file="https://github.com/LordRafa/ALARMOnTegraK1/releases/latest/download/common.sh"
ls common.sh &> /dev/null || curl -s -L $common_file -o common.sh
. ./common.sh

echo "" > ${LOGFILE}

[ $# -eq 0 ] && echo -e "Usage: create_installation_sd.sh /dev/YOUR_SD_DEVICE [-f]\n\tNote: -f forces format, this can be potentially dangerous and not recommended" && exit
lsblk -ndo tran ${1} >> ${LOGFILE} 2>&1 || { echo "First parameter must be a block device"; exit; }

if [[ "$(lsblk -ndo tran ${1})" != "usb" ]] && [[ "${2}" != "-f" ]]; then
  echo "Error: The provided device is not a USB/SD memory. Aborting to prevent damaging your system."
  echo "If you know what are you doing, you can force the installation by adding -f as seccond parameter (risking destroying all you data)"
  exit
fi

echo -e "Installing ArchLinuxARM ${archlinux_version} version to ${1}"
echo -e "Warning: This will destroy any data in ${1}\n"
read -p "Press [Enter] to continue or CTRL+C to abort..."

start_progress "Formating SD memory."
echo ';' | sfdisk ${1} >> ${LOGFILE} 2>&1
partition1=$(lsblk ${1} -n -p -l -o name,type | grep part | cut -f 1 -d " ")
mkfs.ext4 -L ALARM_SD ${partition1} >> ${LOGFILE} 2>&1
end_progress "done"

start_progress "Mounting new SD partition."
ls ${WORK_PATH} &> /dev/null || mkdir ${WORK_PATH} >> ${LOGFILE} 2>&1
mount ${partition1} ${WORK_PATH} >> ${LOGFILE} 2>&1
end_progress "done"

start_progress "Downloading and extracting ArchLinuxARM rootfs."
curl -s -L --output - $rootfs_file | tar xzvvp -C ${WORK_PATH}/ >> ${LOGFILE} 2>&1
end_progress "done"

start_progress "Downloading and extracting jetson tk1 kernel."
curl -s -L --output - $kernel_file | tar xJvvp -C ${WORK_PATH}/ >> ${LOGFILE} 2>&1
end_progress "done"

start_progress "Syncing and unmounting new SD partition."
echo "Syncing disks..." >> ${LOGFILE}
sync
umount ${partition1} >> ${LOGFILE} 2>&1
end_progress "done"

echo "Everything is finished, now you can use $1 to boot Jetson TK1 and continue with the installation."
echo "done..." >> ${LOGFILE}

