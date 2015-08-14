#!/bin/bash

ARCH="amd64"
DIST="sid"

# Load in library
source mkdebdisk.img/mkdebdisk.img.lib.bash

function SoekrisNet6501() {
	GrubAppendEtcDefaultVar \
		"GRUB_CMDLINE_LINUX" \
		"vga=normal console=ttyS0,115200,n8"
}

#                          #
# Begin Debdisk definition #
#                          #

Begin \
	>> ${CUSTOMIZE}

#
# Systemd Services
#

SystemdEnableService systemd-networkd \
	>> ${CUSTOMIZE}

SystemdEnableService systemd-resolved \
	>> ${CUSTOMIZE}

#
# Apt Repositories
#

AptRepo "httpredir.debian.org/debian" "sid" \
	main contrib non-free

AptRepo "http.us.debian.org/debian" "sid" \
	main contrib non-free

AptRepo "ftp.us.debian.org/debian" "sid" \
	main contrib non-free

AptRepoSources \
	>> ${CUSTOMIZE}

AptInstall <<-EOF >> ${CUSTOMIZE}
	iptables iptables-persistent iproute2 iproute2-doc packagekit
	policykit-1 collectd systemd-cron systemd-shim systemd-sysv
	openssh-server openssh-client mosh isc-dhcp-server bind9
	docker.io git bzr mercurial subversion binutils
	kmod linux-base grub-pc intel-microcode
EOF

SystemdDisableService isc-dhcp-server \
	>> ${CUSTOMIZE}

SystemdDisableService bind9 \
	>> ${CUSTOMIZE}

SystemdEnableService collectd \
	>> ${CUSTOMIZE}

SystemdEnableService ssh \
	>> ${CUSTOMIZE}

SystemdEnableService docker \
	>> ${CUSTOMIZE}

AptCleanup \
	>> ${CUSTOMIZE}

AptRepoSources no-proxy \
	>> ${CUSTOMIZE}

SystemdRootPassword "net6501" \
	>> ${CUSTOMIZE}

SoekrisNet6501 \
	>> ${CUSTOMIZE}

chmod +x ${CUSTOMIZE}

sudo vmdebootstrap \
	--arch "${MKDDP_ARCH}" \
	--distribution "${MKDDP_DIST}" \
	--mirror "http://${APT_PROXY}httpredir.debian.org/debian" \
	--image "net6501-${MKDDP_DIST}-${MKDDP_TIME}.img" \
	--size 2048M \
	--bootsize 64M \
	--boottype vfat \
	--log-level debug \
	--verbose \
	--no-kernel \
	--no-extlinux \
	--hostname net6501 \
	--foreign "$(which qemu-arm-static)" \
	--customize "${PWD}/${CUSTOMIZE}" \
	--serial-console-command "/sbin/getty -L ttyS0  115200 vt100" \
	--package debian-archive-keyring \
	--package apt-transport-https \
	--package debootstrap \
	--package minicom \
	--package locales \
	--package curl \
	--package nano

sudo mv debootstrap.log debootstrap-${MKDDP_TIME}.log &>/dev/null
