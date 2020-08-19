#!/bin/bash

set -e

# Downloads common.sh if script was run out of the git tree eg: Following readme instructions.
common_file="https://github.com/LordRafa/ALARMOnTegraK1/releases/latest/download/common.sh"
ls common.sh &> /dev/null || curl -s -L $common_file -o common.sh
. ./common.sh

if [[ "$(lsblk -ndo tran ${1})" != "usb" ]]; then
  echo "Error: The selected device is not a USB/SD memory. Aborting to avoid damaging the system."
  exit
fi

echo -e "Installing ArchLinuxARM ${archlinux_version} version to ${1}"
echo -e "Warning: This will destroy any data in ${1}\n"
read -p "Press [Enter] to continue or CTRL+C to abort..."

echo "" > ${LOGFILE}

start_progress "Formating SD memory."
echo 'type=83' | sfdisk $1 >> ${LOGFILE} 2>&1
mkfs.ext4 -L ALARM_SD ${1}1 >> ${LOGFILE} 2>&1
end_progress "done"

start_progress "Mounting new SD partition."
ls ${WORK_PATH} &> /dev/null || mkdir ${WORK_PATH} >> ${LOGFILE} 2>&1
mount ${1}1 ${WORK_PATH} >> ${LOGFILE} 2>&1
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
umount ${1}1 >> ${LOGFILE} 2>&1
end_progress "done"

echo "Everything is finished, now you can use $1 to boot Jetson TK1 and continue with the installation."
echo "done..." >> ${LOGFILE}

