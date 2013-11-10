#!/bin/bash
ISO_8601=`date -u "+%FT%TZ"` #ISO 8601 Script Start UTC Time
utc=`date -u "+%Y.%m.%dT%H.%M.%SZ"` #UTC Time (filename safe)
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
# Creates a .img file to install funtoo for raspberry pi with
# invoke with "sudo bash /path/to/funtoo-pi.sh"

# xz -dc /path/to/funtoo-pi.img.xz | sudo dd bs=4M of=/dev/sdb

#http://www.funtoo.org/Raspberry_Pi
#http://www.funtoo.org/Funtoo_Linux_Installation_on_ARM
#http://wiki.gentoo.org/wiki/Raspberry_Pi_Quick_Install_Guide
#http://wiki.gentoo.org/wiki/Raspberry_Pi_Cross_building

source "$owd/txzExtract.sh"

#Download Everthing
	#if stage3 isn't available download it
	if [ ! -f "$owd/stage3-latest.txz" ]; then
		wget -O "$owd/stage3-latest.txz" http://ftp.osuosl.org/pub/funtoo/funtoo-current/arm-32bit/armv6j_hardfp/stage3-latest.txz
	fi
	#if portage isn't available download it
	if [ ! -f "$owd/portage.txz" ]; then
		cd "$owd" && sudo git clone --depth 1 -nb funtoo.org git://github.com/funtoo/ports-2012.git portage
		cd "$owd" && tar cf - "portage" | nice -19 xz -vf9eC sha256 -T 2 > "$owd/portage.txz"
		sudo rm -rf "$owd/portage"
	fi
	#if firmware isn't available download it
	if [ ! -f "$owd/firmware.txz" ]; then
		cd "$owd" && sudo git clone --depth 1 -n git://github.com/raspberrypi/firmware/
		cd "$owd" && tar cf - "firmware" | nice -19 xz -vf9eC sha256 -T 2 > "$owd/firmware.txz"
		sudo rm -rf "$owd/firmware"
	fi

#create a img & mount the partitions
	blkidDevFile="${owd}/funtoo-pi.img"
	sudo rm $blkidDevFile
	sleep 2; dd bs=1M count=0 seek=4096 if=/dev/zero of=$blkidDevFile
	#partion the img
	sleep 2; sudo sfdisk "$blkidDevFile" -u M <<EOF
	,39,c
	,216,S
	,,L
	EOF
	#http://superuser.com/questions/367196/linux-how-to-format-multiple-file-systems-within-one-file
	sudo kpartx -a $blkidDevFile   #it maps (mounts) found partitions to /dev/mapper/loop...

	#format the partitions of the img
	#sudo partprobe /dev/mapper/loop0p
	#sleep 2; sudo dd bs=512 count=1 if=/dev/zero of=/dev/mapper/loop0p1
	sleep 2; sudo mkfs.vfat -F 16 -n boot /dev/mapper/loop0p1
	sleep 2; sudo mkswap -L swap /dev/mapper/loop0p2
	sleep 2; sudo mkfs.ext4 -L pi /dev/mapper/loop0p3

	#add boot flag to 1st partition
	sleep 2; sudo sfdisk "$blkidDevFile" -A 1

	#mount the partitions
	sleep 2; sudo rm -rf /mnt/pi; mkdir /mnt/pi && sleep 2; sudo mount /dev/mapper/loop0p3 /mnt/pi
	sleep 2; sudo rm -rf /mnt/boot; mkdir /mnt/boot && sleep 2; sudo mount /dev/mapper/loop0p1 /mnt/boot

#Extract Stage 3 Image
	txzExtract "${owd}/stage3-latest.txz" "/mnt/pi/"
#Install Portage
	txzExtract "$owd/portage.txz" "/mnt/pi/usr/portage/"
	cd /mnt/pi/usr/portage && git checkout

#Install kernel and modules
#The Raspberry Pi Foundation maintain a branch of the Linux kernel that will run on the Raspberry Pi, including a compiled version which we use here.
rm -rf /tmp/firmware
txzExtract "$owd/firmware.txz" "/tmp/firmware"
cd "/tmp/firmware" && git checkout
cd /tmp/firmware/boot
cp ./* /mnt/boot/
cp -r ../modules /mnt/pi/lib/

#set fstab
sudo tee "/mnt/pi/etc/fstab" > /dev/null <<EOF
# /etc/fstab: static file system information.
#
# Use 'blkid -o value -s UUID' to print the universally unique identifier
# for a device; this may be used with UUID= as a more robust way to name
# devices that works even if disks are added and removed. See fstab(5).
#
# <file system>		<mount point>	<type>	<options>			<dump>	<pass>
/dev/mmcblk0p1		/boot			auto	noauto,noatime		1		2
/dev/mmcblk0p2		none			swap	sw					0		0
/dev/mmcblk0p3		/				ext4	noatime				0		1

EOF
#Set boot options
sudo tee "/mnt/boot/cmdline.txt" > /dev/null <<EOF
dwc_otg.lpm_enable=0 console=ttyAMA0,115200 kgdboc=ttyAMA0,115200 console=tty1 root=/dev/mmcblk0p3 rootfstype=ext4 elevator=deadline rootwait
EOF
#set root passwd
passwd_raspberry="$(python -c "import crypt, getpass, pwd; print crypt.crypt('raspberry', '\$6\$SALTsalt\$')")"
sudo sed -i "s/root.*/root:${passwd_raspberry}:14698:0:::::/" /mnt/pi/etc/shadow
#enable SSH & ethernet
sudo ln -sf /mnt/pi/etc/init.d/sshd /mnt/pi/etc/runlevels/default
sudo ln -sf /mnt/pi/etc/init.d/dhcpcd /mnt/pi/etc/runlevels/default
#Use swclock
sudo ln -sf /mnt/pi/etc/init.d/swclock /mnt/pi/etc/runlevels/boot
sudo rm /mnt/pi/etc/runlevels/boot/hwclock
sudo mkdir -p /mnt/pi/lib/rc/cache
sudo touch /mnt/pi/lib/rc/cache/shutdowntime
#set hostname
sudo sed -i "s/hostname=\"localhost\".*/hostname=\"raspberrypi\"/" /mnt/pi/etc/conf.d/hostname
#set /boot/config.txt w/ modest overclock
openssl enc -base64 -A -d <<EOF > '/mnt/boot/config.txt'
IyB1bmNvbW1lbnQgaWYgeW91IGdldCBubyBwaWN0dXJlIG9uIEhETUkgZm9yIGEgZGVmYXVsdCAic2FmZSIgbW9kZQojaGRtaV9zYWZlPTEKCiMgdW5jb21tZW50IHRoaXMgaWYgeW91ciBkaXNwbGF5IGhhcyBhIGJsYWNrIGJvcmRlciBvZiB1bnVzZWQgcGl4ZWxzIHZpc2libGUKIyBhbmQgeW91ciBkaXNwbGF5IGNhbiBvdXRwdXQgd2l0aG91dCBvdmVyc2NhbgpkaXNhYmxlX292ZXJzY2FuPTEKCiMgdW5jb21tZW50IHRoZSBmb2xsb3dpbmcgdG8gYWRqdXN0IG92ZXJzY2FuLiBVc2UgcG9zaXRpdmUgbnVtYmVycyBpZiBjb25zb2xlCiMgZ29lcyBvZmYgc2NyZWVuLCBhbmQgbmVnYXRpdmUgaWYgdGhlcmUgaXMgdG9vIG11Y2ggYm9yZGVyCiNvdmVyc2Nhbl9sZWZ0PTE2CiNvdmVyc2Nhbl9yaWdodD0xNgojb3ZlcnNjYW5fdG9wPTE2CiNvdmVyc2Nhbl9ib3R0b209MTYKCiMgdW5jb21tZW50IHRvIGZvcmNlIGEgY29uc29sZSBzaXplLiBCeSBkZWZhdWx0IGl0IHdpbGwgYmUgZGlzcGxheSdzIHNpemUgbWludXMKIyBvdmVyc2Nhbi4KI2ZyYW1lYnVmZmVyX3dpZHRoPTEyODAKI2ZyYW1lYnVmZmVyX2hlaWdodD03MjAKCiMgdW5jb21tZW50IGlmIGhkbWkgZGlzcGxheSBpcyBub3QgZGV0ZWN0ZWQgYW5kIGNvbXBvc2l0ZSBpcyBiZWluZyBvdXRwdXQKI2hkbWlfZm9yY2VfaG90cGx1Zz0xCgojIHVuY29tbWVudCB0byBmb3JjZSBhIHNwZWNpZmljIEhETUkgbW9kZSAodGhpcyB3aWxsIGZvcmNlIFZHQSkKI2hkbWlfZ3JvdXA9MQojaGRtaV9tb2RlPTEKCiMgdW5jb21tZW50IHRvIGZvcmNlIGEgSERNSSBtb2RlIHJhdGhlciB0aGFuIERWSS4gVGhpcyBjYW4gbWFrZSBhdWRpbyB3b3JrIGluCiMgRE1UIChjb21wdXRlciBtb25pdG9yKSBtb2RlcwojaGRtaV9kcml2ZT0yCgojIHVuY29tbWVudCB0byBpbmNyZWFzZSBzaWduYWwgdG8gSERNSSwgaWYgeW91IGhhdmUgaW50ZXJmZXJlbmNlLCBibGFua2luZywgb3IKIyBubyBkaXNwbGF5CiNjb25maWdfaGRtaV9ib29zdD00CgojIHVuY29tbWVudCBmb3IgY29tcG9zaXRlIFBBTAojc2R0dl9tb2RlPTIKCiN1bmNvbW1lbnQgdG8gb3ZlcmNsb2NrIHRoZSBhcm0uCiMjIk5vbmUiICI3MDBNSHogQVJNLCAyNTBNSHogY29yZSwgNDAwTUh6IFNEUkFNLCAwIG92ZXJ2b2x0IgojYXJtX2ZyZXE9NzAwCiNjb3JlX2ZyZXE9MjUwCiNzZHJhbV9mcmVxPTQwMAojb3Zlcl92b2x0YWdlPTAKIyMiTW9kZXN0IiAiODAwTUh6IEFSTSwgMzAwTUh6IGNvcmUsIDQwME1IeiBTRFJBTSwgMCBvdmVydm9sdCIKYXJtX2ZyZXE9ODAwCmNvcmVfZnJlcT0zMDAKc2RyYW1fZnJlcT00MDAKb3Zlcl92b2x0YWdlPTAKIyMiTWVkaXVtIiAiOTAwTUh6IEFSTSwgMzMzTUh6IGNvcmUsIDQ1ME1IeiBTRFJBTSwgMiBvdmVydm9sdCIKI2FybV9mcmVxPTkwMAojY29yZV9mcmVxPTMzMwojc2RyYW1fZnJlcT00NTAKI292ZXJfdm9sdGFnZT0yCiMjIkhpZ2giICI5NTBNSHogQVJNLCA0NTBNSHogY29yZSwgNDUwTUh6IFNEUkFNLCA2IG92ZXJ2b2x0IgojYXJtX2ZyZXE9OTUwCiNjb3JlX2ZyZXE9NDUwCiNzZHJhbV9mcmVxPTQ1MAojb3Zlcl92b2x0YWdlPTYKIyMiVHVyYm8iICIxMDAwTUh6IEFSTSwgNTAwTUh6IGNvcmUsIDUwME1IeiBTRFJBTSwgNiBvdmVydm9sdCIKI2FybV9mcmVxPTEwMDAKI2NvcmVfZnJlcT01MDAKI3NkcmFtX2ZyZXE9NTAwCiNvdmVyX3ZvbHRhZ2U9NgoKIyBmb3IgbW9yZSBvcHRpb25zIHNlZSBodHRwOi8vZWxpbnV4Lm9yZy9SUGlfY29uZmlnLnR4dAo=
EOF
#cleanup kpartx & /mnt
sleep 2; sudo umount /mnt/boot && sudo rm -rf /mnt/boot
sleep 2; sudo umount /mnt/pi && sudo rm -rf /mnt/pi
sleep 2; sudo kpartx -d $blkidDevFile && sudo rm -rf /dev/mapper/loop*
#sudo rm -rf /mnt/boot;sudo rm -rf /mnt/pi

#special thanks to https://blog.ramses-pyramidenbau.de/?p=188
#for how to get qemu and crossdev working
#qemu startup img
	#Add user "pi" with password = "raspberry"
	#useradd -m -g users -G audio,video,cdrom,wheel pi && echo -en "raspberry\n" | passwd pi
	#??emerge --ask raspberrypi-userland

#nice -19 xz -vf9eC sha256 $blkidDevFile
