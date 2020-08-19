alarmontegrak1_version=latest
board=jetson-tk1
archlinux_arch="armv7"
archlinux_version="latest"
kernel_version=5.8.1-2-armv7h
xorg_server_git_version=1.20.0.r704.g5c20e4b83-1-armv7h


if [ "$EUID" -ne 0 ]; then
  echo "Errot: This script needs to be run as root"
  exit
fi

latest=""
if [[ "$alarmontegrak1_version" == "latest" ]]; then
  alarmontegrak1_version=""
  latest="latest"
fi

rootfs_file="http://archlinuxarm.org/os/ArchLinuxARM-${archlinux_arch}-${archlinux_version}.tar.gz"
xorg_server_common_git_file="https://github.com/LordRafa/ALARMOnTegraK1/releases/${latest}/download/${alarmontegrak1_version}/xorg-server-common-git-${xorg_server_git_version}.pkg.tar.xz"
xorg_server_xephyr_git_file="https://github.com/LordRafa/ALARMOnTegraK1/releases/${latest}/download/${alarmontegrak1_version}/xorg-server-xephyr-git-${xorg_server_git_version}.pkg.tar.xz"
xorg_server_xwayland_git_file="https://github.com/LordRafa/ALARMOnTegraK1/releases/${latest}/download/${alarmontegrak1_version}/xorg-server-xwayland-git-${xorg_server_git_version}.pkg.tar.xz"
xorg_server_devel_git_file="https://github.com/LordRafa/ALARMOnTegraK1/releases/${latest}/download/${alarmontegrak1_version}/xorg-server-devel-git-${xorg_server_git_version}.pkg.tar.xz"
xorg_server_xnest_git_file="https://github.com/LordRafa/ALARMOnTegraK1/releases/${latest}/download/${alarmontegrak1_version}/xorg-server-xnest-git-${xorg_server_git_version}.pkg.tar.xz"
xorg_server_git_file="https://github.com/LordRafa/ALARMOnTegraK1/releases/${latest}/download/${alarmontegrak1_version}/xorg-server-git-${xorg_server_git_version}.pkg.tar.xz"
xorg_server_xvfb_git_file="https://github.com/LordRafa/ALARMOnTegraK1/releases/${latest}/download/${alarmontegrak1_version}/xorg-server-xvfb-git-${xorg_server_git_version}.pkg.tar.xz"
kernel_file="https://github.com/LordRafa/ALARMOnTegraK1/releases/${latest}/download/${alarmontegrak1_version}/linux-${board}-${kernel_version}.pkg.tar.xz"
headers_file="https://github.com/LordRafa/ALARMOnTegraK1/releases/${latest}/download/${alarmontegrak1_version}/linux-${board}-headers-${kernel_version}.pkg.tar.xz"
alsacfg_file="https://github.com/LordRafa/ALARMOnTegraK1/releases/${latest}/download/${alarmontegrak1_version}/alsacfg.tar.xz"

CWD=`pwd`
LOGFILE="${CWD}/archlinux-install.log"
PROGRESS_PID=
spin='-\|/'

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
echo -n " ...$1."
echo
}

trap 'end_progress "fail. Check log file for more info"' SIGINT SIGTERM EXIT

