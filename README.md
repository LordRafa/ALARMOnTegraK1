# Install ArchLinuxARM (alarm) on Jetson TK1

# Introduction

The archlinux.sh script allows one to install ArchLinuxARM
(http://www.archlinuxarm.org) on a Jetson TK1.
Instead of just a base system, the script
installs an entire Mate system.

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

# Usage

From an up and runing Tegra4Linux on a Jetson TK1 run:
curl -L https://github.com/LordRafa/ALARMOnTegraK1/releases/latest/download/archlinux.sh -o archlinux.sh
sudo sh archlinux.sh
