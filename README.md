# Install ArchLinuxARM (alarm) on Jetson TK1

# Introduction

The archlinux.sh script allows one to install ArchLinuxARM
(http://www.archlinuxarm.org) on a Jetson TK1.
Instead of just a base system, the script installs an entire Mate system.

The script itself is derived from the work Clifford Wolf's chrubuntu
script, which can be found here:

http://www.clifford.at/blog/index.php?/archives/131-Installing-Ubuntu-on-an-Acer-Chromebook-13-Tegra-K1.html

And Tristan Bastian script, which can be found here:

https://github.com/reey/LinuxOnAcerCB5-311

I implemented the following changes: 

* Removed patches already present in mainline.
* Added a patch to enable WF_EN gpio by default. This enables mini-pcie wifi cards.
* Included BT and Wifi modules.
* Replaced XCFE4 by Mate.
* Included xorg-server-git package required to start X.
* Formarts and installs ALArm directly into /dev/mmcblk0p1.
* Installs the required boot.scr in /boot.

# Obligatory disclaimer

This code is provided without any warranty, use under your own resposability.

# Usage

Follow this guide to install the latest uBoot on the Jetson TK1
https://wiki.debian.org/InstallingDebianOn/NVIDIA/Jetson-TK1

From a PC use the create_installation_sd.sh script to configure a SD card as an installation medium.
```bash
curl -L https://github.com/LordRafa/ALARMOnTegraK1/releases/latest/download/create_installation_sd.sh -o create_installation_sd.sh
sh create_installation_sd.sh /dev/sdX
```

Using the SD card boot the Jetson TK1, login as root (root:root) and run:
```bash
curl -L https://github.com/LordRafa/ALARMOnTegraK1/releases/latest/download/archlinux.sh -o archlinux.sh
sh archlinux.sh INSTALLATION_TARGET
# INSTALLATION_TARGET must be replaced by "emmc", "sd", "sda" or manual, which correspond respectively to the internal eMMC, the SD Card, any SATA connected or a manually mounted filesystem.
```
The "manual" option can be useful when you want to create complex file systems with specific folders mounted in specific partitions (e.g. separate / and /home in different partitions). It will require to do the partitioning and the formatting manually and then mount the partitions under /tmp/arfs/.

Once the script finish the Jetson TK1 will reboot remove the SD and it will boot on the new installation.
