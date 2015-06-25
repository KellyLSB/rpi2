#!/bin/bash

ARCH="armhf"
DIST="jessie"

# Load in library
source mkdebdisk.img/mkdebdisk.img.lib.bash

# RPI Firmware Files to Install
# (from github)
RPI_FIRMWARE_FILES=(
	"README.md"
	"COPYING.linux"
	"LICENSE.broadcom"
	"bcm2708-rpi-cm.dtb"
	"bcm2708-rpi-b.dtb"
	"bcm2708-rpi-b-plus.dtb"
	"bcm2708-rpi-2-b.dtb"
	"bootcode.bin"
	"fixup_cd.dat"
	"fixup_db.dat"
	"fixup_x.dat"
	"start.elf"
	"start_cd.elf"
	"start_db.elf"
	"start_x.elf"
)

# RPi2Firmware installation
# Copies the kernel to the expected kernel name by the Pi.
# Downloads the non-free firmwares and device tree blobs from GitHub.
# Installs the cmdline.txt and config.txt to the boot partition.
function RPi2Firmware() {
	Script "Rpi2KernelInitd" <<-EOF
	cp "\$(ls /boot/vmlinuz* | sort | tail -n1)" /boot/kernel7.img
	cp "\$(ls /boot/initrd* | sort | tail -n1)" /boot/initrd.img
	cp "\$(ls /boot/System.map* | sort | tail -n1)" /boot/Module7.symvers
	EOF

	for file in "${RPI_FIRMWARE_FILES[@]}"; do
		url="https://github.com/Hexxeh/rpi-firmware/blob/master/${file}?raw=true"

		Script "Rpi2Firmware" <<-EOF
		echo "Fetching: $(basename "${file}")"
		curl -#Lk "${url}" > "/boot/${file}"
		EOF
	done

	File "RPi2CmdLine" "/boot/cmdline.txt" <<-EOF
	$(cat "${PWD}/config/cmdline.txt")
	EOF

	File "RPi2Config" "/boot/config.txt" <<-EOF
	$(cat "${PWD}/config/config.txt")
	EOF
}

#                          #
# Begin Debdisk definition #
#                          #

Begin \
	>> ${CUSTOMIZE}

#
# Systemd Services
#

SystemdEnableService \
	systemd-networkd \
	>> ${CUSTOMIZE}

SystemdEnableService \
	systemd-resolved \
	>> ${CUSTOMIZE}

SystemdStartService \
	systemd-networkd \
	>> ${CUSTOMIZE}

SystemdStartService \
	systemd-resolved \
	>> ${CUSTOMIZE}

#
# Apt Repositories
#

AptRepo "httpredir.debian.org/debian" "jessie" \
	main contrib non-free

AptRepo "http.us.debian.org/debian" "jessie" \
	main contrib non-free

AptRepo "ftp.us.debian.org/debian" "jessie" \
	main contrib non-free

AptRepoSources \
	>> ${CUSTOMIZE}

AptInstall <<-EOF >> ${CUSTOMIZE}
	iptables iproute2 iproute2-doc
	openssh-server openssh-client mosh
	git-core binutils kmod
EOF

### --- RPi2 Specific --- ###

AptKeyFile ${PWD}/config/raspbian-archive-keyring.gpg
AptKeyFile ${PWD}/config/collabora-archive-keyring.gpg

AptKeysImport \
	>> ${CUSTOMIZE}

AptRepo "archive.raspbian.org/raspbian" "jessie" \
	main contrib non-free firmware rpi

AptRepo "repositories.collabora.co.uk/debian"	"jessie" \
	rpi2

AptRepoSources \
	>> ${CUSTOMIZE}

AptInstall <<-EOF >> ${CUSTOMIZE}
linux-image-3.18.0-trunk-rpi2
linux-headers-3.18.0-trunk-rpi2
linux-support-3.18.0-trunk
EOF

AptCleanup \
	>> ${CUSTOMIZE}

AptRepoSources no-proxy \
	>> ${CUSTOMIZE}

SystemdRootPassword "pi" \
	>> ${CUSTOMIZE}

RPi2Firmware \
	>> ${CUSTOMIZE}

chmod +x ${CUSTOMIZE}

sudo vmdebootstrap \
	--arch "${MKDDP_ARCH}" \
	--distribution "${MKDDP_DIST}" \
	--mirror "http://${APT_PROXY}httpredir.debian.org/debian" \
	--image "rpi2-${MKDDP_DIST}-${MKDDP_TIME}.img" \
	--size 2048M \
	--bootsize 64M \
	--boottype vfat \
	--log-level debug \
	--verbose \
	--no-kernel \
	--no-extlinux \
	--hostname rpi2 \
	--foreign "$(which qemu-arm-static)" \
	--customize "${PWD}/${CUSTOMIZE}" \
	--serial-console-command "/sbin/getty -L ttyAMA0 115200 vt100" \
	--package debian-archive-keyring \
	--package apt-transport-https \
	--package debootstrap \
	--package minicom \
	--package curl \
	--package nano

sudo mv debootstrap.log debootstrap-${MKDDP_TIME}.log &>/dev/null
