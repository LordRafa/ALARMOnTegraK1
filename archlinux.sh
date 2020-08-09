set -e

CWD=`pwd`
target_rootfs=/dev/mmcblk0p1
MY_CHROOT_DIR=/tmp/arfs
PROGRESS_PID=
LOGFILE="${CWD}/archlinux-install.log"
spin='-\|/'
alarmontegrak1_version=v0.0.2
xorg_server_git_version=1.20.0.r704.g5c20e4b83-1-armv7h
kernel_version=5.1-1-armv7h
board=jetson-tk1

function progress () {
  arg=$1
  echo -n "$arg   "
  while true
  do
    i=$(( (i+1) %4 ))
    printf "\r$arg   ${spin:$i:1}"
    sleep .1
  done
}

function start_progress () {
  # Start it in the background
  progress "$1" &
  # Save progress() PID
  PROGRESS_PID=$!
  disown
}

function end_progress () {

# Kill progress
kill ${PROGRESS_PID} >/dev/null  2>&1
echo -n " ...done."
echo
}

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
    end_progress
  fi

  umount ${MY_CHROOT_DIR}/proc
  umount ${MY_CHROOT_DIR}/dev
  umount ${MY_CHROOT_DIR}/dev/pts
  umount ${MY_CHROOT_DIR}/sys

}

trap unset_chroot EXIT

function copy_chros_files () {

  start_progress "Copying additional files to ArchLinuxARM rootdir"

  mkdir -p ${MY_CHROOT_DIR}/run/resolvconf
  cp /etc/resolv.conf ${MY_CHROOT_DIR}/run/resolvconf/
  ln -s -f /run/resolvconf/resolv.conf ${MY_CHROOT_DIR}/etc/resolv.conf
  echo alarm > ${MY_CHROOT_DIR}/etc/hostname
  echo -e "\n127.0.1.1\tlocalhost.localdomain\tlocalhost\talarm" >> ${MY_CHROOT_DIR}/etc/hosts

  end_progress
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

end_progress
}

function install_xbase () {

start_progress "Installing X-server basics"

cat > ${MY_CHROOT_DIR}/install-xbase.sh <<EOF

wget https://github.com/LordRafa/ALARMOnTegraK1/releases/download/${alarmontegrak1_version}/xorg-server-common-git-${xorg_server_git_version}.pkg.tar.xz
wget https://github.com/LordRafa/ALARMOnTegraK1/releases/download/${alarmontegrak1_version}/xorg-server-xephyr-git-${xorg_server_git_version}.pkg.tar.xz
wget https://github.com/LordRafa/ALARMOnTegraK1/releases/download/${alarmontegrak1_version}/xorg-server-xwayland-git-${xorg_server_git_version}.pkg.tar.xz
wget https://github.com/LordRafa/ALARMOnTegraK1/releases/download/${alarmontegrak1_version}/xorg-server-devel-git-${xorg_server_git_version}.pkg.tar.xz
wget https://github.com/LordRafa/ALARMOnTegraK1/releases/download/${alarmontegrak1_version}/xorg-server-xnest-git-${xorg_server_git_version}.pkg.tar.xz
wget https://github.com/LordRafa/ALARMOnTegraK1/releases/download/${alarmontegrak1_version}/xorg-server-git-${xorg_server_git_version}.pkg.tar.xz
wget https://github.com/LordRafa/ALARMOnTegraK1/releases/download/${alarmontegrak1_version}/xorg-server-xvfb-git-${xorg_server_git_version}.pkg.tar.xz

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
EOF

exec_in_chroot install-xbase.sh

end_progress

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

end_progress

}


function install_kernel () {

start_progress "Installing kernel"

cat > ${MY_CHROOT_DIR}/install-kernel.sh << EOF
wget https://github.com/LordRafa/ALARMOnTegraK1/releases/download/${alarmontegrak1_version}/linux-${board}-${kernel_version}.pkg.tar.xz
wget https://github.com/LordRafa/ALARMOnTegraK1/releases/download/${alarmontegrak1_version}/linux-${board}-headers-${kernel_version}.pkg.tar.xz
pacman -R --noconfirm linux-armv7
yes n | pacman -U --noconfirm linux-${board}-*

EOF

exec_in_chroot install-kernel.sh

end_progress

}


function install_misc_utils () {

start_progress "Installing some more utilities"

cat > ${MY_CHROOT_DIR}/install-utils.sh <<EOF
pacman -Syy --needed --noconfirm  sshfs screen file-roller bluez bluez-utils blueman
systemctl enable bluetooth.service
EOF

exec_in_chroot install-utils.sh

end_progress

}


function install_misc_conf () {

start_progress "Performing some misc configuration"

cat > ${MY_CHROOT_DIR}/misc-conf.sh <<EOF
echo AutoEnable=true >> /etc/bluetooth/main.conf
EOF

exec_in_chroot misc-conf.sh

end_progress

}

function install_sound () {

start_progress "Installing sound (alsa/pulseaudio)"

cat > ${MY_CHROOT_DIR}/install-sound.sh <<EOF

pacman -Syy --needed --noconfirm \
        alsa-lib alsa-utils alsa-tools alsa-oss alsa-firmware alsa-plugins \
        pulseaudio pulseaudio-alsa
EOF

exec_in_chroot install-sound.sh

end_progress

}

echo "" > $LOGFILE

archlinux_arch="armv7"
archlinux_version="latest"

echo -e "Installing ArchLinuxARM ${archlinux_version}\n"

echo -e "Installing ArchLinuxARM Arch: ${archlinux_arch}\n"

read -p "Press [Enter] to continue..."

if [ ! -d /tmp/arfs ]
then
  mkdir /tmp/arfs
fi

mkfs.ext4 ${target_rootfs}
mount -t ext4 ${target_rootfs} /tmp/arfs

tar_file="http://archlinuxarm.org/os/ArchLinuxARM-${archlinux_arch}-${archlinux_version}.tar.gz"

start_progress "Downloading and extracting ArchLinuxARM rootfs"

curl -s -L --output - $tar_file | tar xzvvp -C /tmp/arfs/ >> ${LOGFILE} 2>&1

end_progress

setup_chroot

copy_chros_files

install_dev_tools

install_xbase

install_mate

install_sound

install_kernel

install_misc_utils

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
