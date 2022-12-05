WORK_PATH=/tmp/arfs
alarmontegrak1_version=v1.0.4-M1
board=jetson-tk1
archlinux_arch="armv7"
archlinux_version="latest"
kernel_version=6.0.11-1-armv7h


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

