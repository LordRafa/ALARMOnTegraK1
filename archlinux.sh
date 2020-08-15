#!/bin/bash

set -e

target_rootfs=""

emmc="/dev/mmcblk0p1"
sd="/dev/mmcblk1p1"
sda="/dev/sda1"

case $1 in

 "emmc")
    target_rootfs=${emmc}
    ;;

 "sd")
    target_rootfs=${sd}
    ;;

 "sda")
    target_rootfs=${sda}
    ;;

  *)
    echo -e "Usage: archlinux.sh [emmc|sd|sda]\n"\
         "\temmc -> Installs Arch Linux ARM on the EMMC\n"\
         "\tsd   -> Installs Arch Linux ARM on the SD Card\n"\
         "\tsda  -> Installs Arch Linux ARM on the SATA Device\n"
  	exit 1
  	;;

esac


function format_target () {

  start_progress "Formating and mount target rootfs"

  ls /tmp/arfs &> /dev/null || mkdir /tmp/arfs >> ${LOGFILE} 2>&1
  mkfs.ext4 ${target_rootfs} >> ${LOGFILE} 2>&1
  mount -t ext4 ${target_rootfs} /tmp/arfs >> ${LOGFILE} 2>&1
  if [[ $1 == "sda" ]]; then
    mkfs.ext4 ${emmc} >> ${LOGFILE} 2>&1
    mkdir /tmp/arfs/boot >> ${LOGFILE} 2>&1
    mount -t ext4 ${emmc} /tmp/arfs/boot >> ${LOGFILE} 2>&1
  fi

  end_progress "done"

}

function install_base () {

  start_progress "Downloading and extracting ArchLinuxARM rootfs"
  curl -s -L --output - $rootfs_file | tar xzvvp -C /tmp/arfs/ >> ${LOGFILE} 2>&1
  end_progress "done"

}

# Downloads common.sh if script was run out of the git tree eg: Following readme instructions.
common_file="https://github.com/LordRafa/ALARMOnTegraK1/releases/latest/download/common.sh"
ls common.sh &> /dev/null || curl -s -L $common_file -o common.sh
. ./common.sh

MY_CHROOT_DIR=/tmp/arfs

#
# Note, this function removes the script after execution
#
function exec_in_chroot () {

  script=$1

  if [ -f ${MY_CHROOT_DIR}/${script} ] ; then
    chmod a+x ${MY_CHROOT_DIR}/${script}
    chroot ${MY_CHROOT_DIR} /bin/bash -c /${script} >> ${LOGFILE} 2>&1
    rm ${MY_CHROOT_DIR}/${script}
  fi
}

function setup_chroot () {

  mount -o bind /proc ${MY_CHROOT_DIR}/proc
  mount -o bind /dev ${MY_CHROOT_DIR}/dev
  mount -o bind /dev/pts ${MY_CHROOT_DIR}/dev/pts
  mount -o bind /sys ${MY_CHROOT_DIR}/sys

}


function unset_chroot () {

  if [ "x${PROGRESS_PID}" != "x" ]
  then
    end_progress "done"
  fi

  umount ${MY_CHROOT_DIR}/proc
  umount ${MY_CHROOT_DIR}/dev
  umount ${MY_CHROOT_DIR}/dev/pts
  umount ${MY_CHROOT_DIR}/sys

}

trap unset_chroot EXIT

function copy_chros_files () {

  start_progress "Copying additional files to ArchLinuxARM rootdir"
  dhcpcd
  mkdir -p ${MY_CHROOT_DIR}/run/resolvconf
  cp /etc/resolv.conf ${MY_CHROOT_DIR}/run/resolvconf/
  ln -s -f /run/resolvconf/resolv.conf ${MY_CHROOT_DIR}/etc/resolv.conf
  echo alarm > ${MY_CHROOT_DIR}/etc/hostname
  echo -e "\n127.0.1.1\tlocalhost.localdomain\tlocalhost\talarm" >> ${MY_CHROOT_DIR}/etc/hosts

  end_progress "done"
}

function install_dev_tools () {

  start_progress "Installing development base packages"

  #
  # Add some development tools and put the alarm user into the
  # wheel group. Furthermore, grant ALL privileges via sudo to users
  # that belong to the wheel group
  #
  cat > ${MY_CHROOT_DIR}/install-develbase.sh << EOF
pacman-key --init
pacman-key --populate archlinuxarm
pacman -Syyu --needed --noconfirm sudo wget dialog base-devel devtools vim rsync git vboot-utils
usermod -aG wheel alarm
sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
EOF

  exec_in_chroot install-develbase.sh

  end_progress "done"
}

function install_xbase () {

  start_progress "Installing X-server basics"

  cat > ${MY_CHROOT_DIR}/install-xbase.sh <<EOF
wget ${xorg_server_common_git_file}
wget ${xorg_server_xephyr_git_file} 
wget ${xorg_server_xwayland_git_file} 
wget ${xorg_server_devel_git_file} 
wget ${xorg_server_xnest_git_file} 
wget ${xorg_server_git_file} 
wget ${xorg_server_xvfb_git_file}

yes n | pacman -U --noconfirm xorg-server*git*

pacman -Syy --needed --noconfirm \
        iw networkmanager network-manager-applet \
        lightdm lightdm-gtk-greeter \
        chromium \
        xorg-apps \
        xorg-twm xorg-xclock xterm xorg-xinit \
        xf86-input-evdev xf86-video-fbdev

systemctl enable NetworkManager
systemctl enable lightdm
rm xorg-server*git*
EOF

  exec_in_chroot install-xbase.sh

  end_progress "done"

}


function install_mate () {

  start_progress "Installing Mate"

  # add .xinitrc to /etc/skel that defaults to Mate session
  cat > ${MY_CHROOT_DIR}/etc/skel/.xinitrc << EOF
#!/bin/sh
#
# ~/.xinitrc
#
# Executed by startx (run your window manager from here)

if [ -d /etc/X11/xinit/xinitrc.d ]; then
  for f in /etc/X11/xinit/xinitrc.d/*; do
    [ -x \"\$f\" ] && . \"\$f\"
  done
  unset f
fi

exec mate-session
# exec startkde
# exec startxfce4
# ...or the Window Manager of your choice
EOF

  cat > ${MY_CHROOT_DIR}/install-mate.sh << EOF
pacman -Syy --needed --noconfirm  mate mate-extra
# copy .xinitrc to already existing home of user 'alarm'
cp /etc/skel/.xinitrc /home/alarm/.xinitrc
cp /etc/skel/.xinitrc /home/alarm/.xprofile
sed -i 's/exec mate-session/# exec mate-session/' /home/alarm/.xprofile
chown alarm:users /home/alarm/.xinitrc
chown alarm:users /home/alarm/.xprofile
EOF

  exec_in_chroot install-mate.sh

  end_progress "done"

}


function install_kernel () {

  start_progress "Installing kernel"

  cat > ${MY_CHROOT_DIR}/install-kernel.sh << EOF
wget ${kernel_file}
wget ${headers_file}
pacman -R --noconfirm linux-armv7
yes n | pacman -U --noconfirm linux-${board}-*
rm linux-${board}-*
EOF

  exec_in_chroot install-kernel.sh

  end_progress "done"

}


function install_misc_utils () {

  start_progress "Installing some more utilities"

  cat > ${MY_CHROOT_DIR}/install-utils.sh <<EOF
pacman -Syy --needed --noconfirm  sshfs screen file-roller bluez bluez-utils blueman uboot-tools
systemctl enable bluetooth.service
EOF

  exec_in_chroot install-utils.sh

  end_progress "done"

}

function install_uboot_conf () {

  start_progress "Performing configure U-BOOT."

  cat > ${MY_CHROOT_DIR}/misc-conf.sh <<EOF
pacman -Syy --needed --noconfirm  uboot-tools
echo 0 > /sys/block/mmcblk0boot1/force_ro
echo "/dev/mmcblk0boot1       0x3fe000        0x2000" >> /etc/fw_env.config
fw_setenv bootargs "console=ttyS0,115200n8 console=tty1 root=${target_rootfs} rw rootwait"
EOF

  exec_in_chroot misc-conf.sh

  end_progress "done"

}

function install_misc_conf () {

  start_progress "Performing some additional configuration."

  cat > ${MY_CHROOT_DIR}/misc-conf.sh <<EOF
echo AutoEnable=true >> /etc/bluetooth/main.conf
EOF

  exec_in_chroot misc-conf.sh

  end_progress "done"

}



function install_sound () {

  start_progress "Installing sound (alsa/pulseaudio)"

  cat > ${MY_CHROOT_DIR}/install-sound.sh <<EOF
pacman -Syy --needed --noconfirm \
        alsa-lib alsa-utils alsa-tools alsa-oss alsa-firmware alsa-plugins \
        pulseaudio pulseaudio-alsa
        amixer -c 0 set 'IEC958' 100% unmute
        alsactl store
        echo "load-module module-alsa-sink device=hw:0,3" >> /etc/pulse/default.pa
EOF

  exec_in_chroot install-sound.sh

  end_progress "done"

}

echo "" > $LOGFILE

echo -e "Installing ArchLinuxARM ${archlinux_version}-${archlinux_arch}\n"
echo -e "Warning: This will destroy any data on ${target_rootfs}\n"
read -p "Press [Enter] to continue..."

format_target $1
install_base
setup_chroot
copy_chros_files
install_dev_tools
install_xbase
install_mate
install_sound
install_kernel
install_misc_utils
install_uboot_conf
install_misc_conf

echo -e "

Installation seems to be complete.

The ArchLinuxARM login is:

Username:  alarm
Password:  alarm

Root access can either be gained via sudo, or the root user:

Username:  root
Password:  root

We're now ready to start ArchLinuxARM!
"

read -p "Press [Enter] to reboot..."

reboot

