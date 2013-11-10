#!/bin/bash
sst=`date -u "+%FT%H.%M.%SZ"` #Script Start Time
owd="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" #Path to THIS script.
#   Copyright 2013 Roy Pfund
#
#   Licensed under the Apache License, Version 2.0 (the  "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable  law  or  agreed  to  in  writing,
#   software distributed under the License is distributed on an  "AS
#   IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,  either
#   express or implied. See the License for  the  specific  language
#   governing permissions and limitations under the License.
#_______________________________________________________________________________
# invoke with "sudo bash /path/to/funtoo-pi.sh /dev/sdX"
# run "sudo blkid" to get a list of possible /dev/sdX and choose the correct one
# you wish to install Funtoo for Raspberry Pi on.
blkidDev=$1
source "$owd/txzExtract.sh"

if [ ! -f "$owd/stage3-latest.tar.xz" ]; then #if stage3 isn't available download it
	# amd64-k10
	wget -O "$owd/stage3-latest.tar.xz" http://ftp.osuosl.org/pub/funtoo/funtoo-current/x86-64bit/amd64-k10/stage3-latest.tar.xz
fi

if [ ! -f "$owd/portage.txz" ]; then #if portage isn't available download it
	cd "$owd" && sudo git clone --depth 1 -nb funtoo.org git://github.com/funtoo/ports-2012.git portage
	cd "$owd" && tar cf - "portage" | nice -19 xz -vf9eC sha256 -T 2 > "$owd/portage.txz"
	sudo rm -rf "$owd/portage"
fi

txzExtract "$owd/stage3-latest.tar.xz" "/media/funtoo/"
txzExtract "$owd/portage.txz" "/media/funtoo/usr/portage/"
cd "/media/funtoo/usr/portage/" && git checkout

# http://www.funtoo.org/wiki/Funtoo_Linux_Installation#.2Fetc.2Ffstab
sudo tee "/media/funtoo/etc/fstab" > /dev/null <<EOF
# /etc/fstab: static file system information.
#
# Use 'blkid -o value -s UUID' to print the universally unique identifier
# for a device; this may be used with UUID= as a more robust way to name
# devices that works even if disks are added and removed. See fstab(5).
#
# <file system>								<mount point>	<type>	<options>			<dump>	<pass>
UUID=$RootUUID	/				ext4	errors=remount-ro	0		1
UUID=$SwapUUID	none			swap	sw					0		0

EOF
# http://www.funtoo.org/wiki/Funtoo_Linux_Installation#Set_your_root_password
passwd_raspberry="$(python -c "import crypt, getpass, pwd; print crypt.crypt('raspberry', '\$6\$SALTsalt\$')")"
sudo sed -i "s/root.*/root:${passwd_raspberry}:14698:0:::::/" /mnt/pi/etc/shadow
# http://www.funtoo.org/wiki/Funtoo_Linux_Installation#Chroot_into_Funtoo
# Before chrooting into your new system, there's a few things that need to be done first. You will need to mount /proc and /dev inside your new system. Use the following commands:
cd /media/funtoo; mount -t proc none proc; mount --rbind /sys sys; mount --rbind /dev dev
# You'll also want to copy over resolv.conf in order to have proper DNS name resolution from inside the chroot:
cp /etc/resolv.conf etc
#Now you can chroot into your new system. Use env before chroot to ensure that no environment variables from the installation media are used by your new system:
env -i HOME=/root TERM=$TERM /bin/bash
chroot . /bin/bash -l
#sync portage tree
cd /usr/portage
emerge --sync
# http://www.funtoo.org/wiki/Funtoo_Linux_Installation#.2Fetc.2Flocaltime
#ln -sf /usr/share/zoneinfo/UTC /etc/localtime
# http://www.funtoo.org/wiki/Funtoo_Linux_Installation#.2Fetc.2Fmake.conf

# Optional http://www.funtoo.org/wiki/Funtoo_Linux_Installation#.2Fetc.2Fconf.d.2Fhwclock
#sudo sed -i "s/clock/local/" /etc/conf.d/hwclock #windows is gay
# Optional http://www.funtoo.org/wiki/Funtoo_Linux_Installation#Localization
# Optional http://www.funtoo.org/wiki/Funtoo_Linux_Installation#Profiles
# http://www.funtoo.org/wiki/Funtoo_Linux_Installation#Configuring_and_installing_the_Linux_kernel
echo "sys-kernel/debian-sources binary" >> /etc/portage/package.use
emerge debian-sources
# http://www.funtoo.org/wiki/Funtoo_Linux_Installation#Configuring_your_network
rc-update add dhcpcd default
emerge linux-firmware
emerge networkmanager
rc-update add NetworkManager default
# http://www.funtoo.org/wiki/Funtoo_Linux_Installation#Running_grub-install_and_boot-update
#grub-install --force --root-directory=/ /dev/sdX#


#	raid 5 Gaming Rig
#	$85		MotherBoard		GA-F2A88XM-D3H
#	$110	CPU + GPU		A8-6600K
#	$80		Ram				8gb(2x4gb) 11-11-11-27 dual channel 2133mhz or faster

#	This gives 8 x SATA 6Gb/s connectors capable of Raid 5
#	if all drives are 4TB thats a 28TB NAS/gaming rig capable of having 1 hard 
#	drive failure with no data loss

