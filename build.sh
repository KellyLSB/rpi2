#!/bin/bash
#set -x
ARCH="armhf"
DIST="jessie"

BUILDTS="$(date '+%m-%d-%Y-%H-%M-%S')"

if timeout 1 bash -c 'cat < /dev/null > /dev/tcp/127.0.0.1/3142' &>/dev/null; then
	echo "Enabling Apt-Cacher-NG Proxy"
	APT_PROXY="127.0.0.1:3142/"
fi

APT_MIRRORS=()
APT_KEYF=()
APT_KEYS=()

APT_ARGS=(
	"--force-yes" "-y"
	"--no-install-recommends"
	"--no-install-suggests"
)

APT_CACHE_DIRECT=(
	"get.docker.io"
	"get.docker.com"
	"download.oracle.com"
)

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

function Begin() {
	cat <<-EOBEGIN
	#!/bin/sh
	cd "\$1"
	tail -n +7 "\$0" > provision
	echo 'rm -f /provision' >> provision
	chmod +x provision
	exec chroot "\$1" /provision
	#!/bin/bash
	EOBEGIN
	echo -e '\n'

}

function AptRepo() {
	APT_MIRRORS+=("$(echo "$@" | tr ' ' '%')")
}

function AptKey() {
	APT_KEYS+=($@)
}

function AptKeyFile() {
	APT_KEYF+=($@)
}

function AptCache() {
	echo "if dpkg -l | grep apt-cacher-ng &>/dev/null; then"
	echo "cat <<EOCACHE > /etc/apt/apt.conf.d/01proxy"
	echo 'Acquire::HTTP::Proxy "http://127.0.0.1:3142";'
	if [[ "${APT_CACHE_DIRECT[@]}" != "" ]]; then
		for host in "${APT_CACHE_DIRECT[@]}"; do
			echo "Acquire::HTTP::Proxy::${host} \"DIRECT\";"
		done
	fi
	echo "EOCACHE"
	echo "fi"
	echo -e '\n'
}


function AptRepoSources() {
	if [[ "${APT_KEYS[@]}" != "" ]]; then
		echo "apt-key adv --keyserver pgpkeys.mit.edu --recv-keys ${APT_KEYS[@]}"
		echo -e '\n'
	fi

	if [[ "${APT_KEYF[@]}" != "" ]]; then
		echo 'apt-key add - <<EOKEYS'
		for file in "${APT_KEYF[@]}"; do
			cat $file
		done
		echo 'EOKEYS'
		echo -e '\n'
	fi

	if [[ "${APT_MIRRORS[@]}" != "" ]]; then
		echo 'cat <<EOLIST > /etc/apt/sources.list'
		for src in "" "-src"; do
			for mir in "${APT_MIRRORS[@]}"; do
				mir="$(tr '%' ' ' <<<"$mir")"
				srv="$(cut -d' ' -f1 <<<"$mir")"
				dst="$(cut -d' ' -f2 <<<"$mir")"
				cmp="$(cut -d' ' -f3- <<<"$mir")"
				echo "deb${src} [arch=${ARCH}] http://${srv} ${dst} ${cmp}"
				# if [[ "$1" == "no-proxy" ]]; then
				# 	echo "deb${src} [arch=${ARCH}] http://${srv} ${dst} ${cmp}"
				# else
				# 	echo "deb${src} [arch=${ARCH}] http://${APT_PROXY}${srv} ${dst} ${cmp}"
				# fi
			done
		done
		echo 'EOLIST'
		echo -e '\n'
	fi
}

function AptInstall() {
	[[ "$@" != "" ]] || return

	cat <<-EOCMDS
	export DFEBK="\$DEBIAN_FRONTEND"
	export DEBIAN_FRONTEND="noninteractive"
	apt-get update	${APT_ARGS[@]}
	apt-get upgrade ${APT_ARGS[@]}
	apt-get install ${APT_ARGS[@]} $@
	export DEBIAN_FRONTEND="\$DFEBK"
	DFEBK= ; unset DFEBK
	EOCMDS
	echo -e '\n'
}

function AptCleanup() {
	cat <<-EOCMDS
	apt-get autoremove ${APT_ARGS[@]}
	apt-get autoclean ${APT_ARGS[@]}
	apt-get purge ${APT_ARGS[@]}
	apt-get clean ${APT_ARGS[@]}
	EOCMDS
	echo -e '\n'
}

function ChangeRootPassword() {
	echo "chpasswd <<<'root:$1'"
	echo -e '\n'
}

function RPi2Firmware() {
	cat <<-EOKERNEL
	cp "\$(ls /boot/vmlinuz* | sort | tail -n1)" /boot/kernel7.img
	cp "\$(ls /boot/initrd* | sort | tail -n1)" /boot/initrd.img
	cp "\$(ls /boot/System.map* | sort | tail -n1)" /boot/Module7.symvers
	EOKERNEL
	echo -e '\n'

	for file in "${RPI_FIRMWARE_FILES[@]}"; do
		url="https://github.com/Hexxeh/rpi-firmware/blob/master/${file}?raw=true"

		cat <<-EOFIRMWARE
		mkdir -p $(dirname ${file})
		echo "Downloading firmware $(basename ${file})"
		curl -#Lk ${url} > /boot/${file}
		EOFIRMWARE
	done
	echo -e '\n'

	cat <<-EOBOOT
	cat <<-EOCMDLINE > /boot/cmdline.txt
	$(cat ${PWD}/config/cmdline.txt)
	EOCMDLINE

	cat <<-EOCONFIG > /boot/config.txt
	$(cat ${PWD}/config/config.txt)
	EOCONFIG
	EOBOOT
	echo -e '\n'
}

function EnableServices() {
	for srvc in "$@"; do
		echo "systemctl enable ${srvc}"
	done
	echo -e '\n'
}

function StartServices() {
	for srvc in "$@"; do
		echo "systemctl start ${srvc}"
	done
	echo -e '\n'
}

trap "sudo chown -Rf ${USER}:${USER} $(dirname $0)" EXIT SIGQUIT SIGTERM

Begin \
	>> customize-${BUILDTS}

EnableServices \
	systemd-networkd systemd-resolved \
	apt-p2p apt-cacher-ng \
	>> customize-${BUILDTS}

StartServices \
	systemd-networkd systemd-resolved \
	apt-p2p apt-cacher-ng \
	>> customize-${BUILDTS}

AptRepo "httpredir.debian.org/debian"	"jessie" \
 	main contrib non-free
AptRepo "http.us.debian.org/debian" "jessie" \
	main contrib non-free

AptRepoSources \
	>> customize-${BUILDTS}

AptInstall minicom netbase net-tools \
	curl nano ca-cerficicates ifupdown \
	iptables iproute2 iproute2-doc dnsutils \
	openssh-server openssh-client mosh \
	git-core apt-transport-https binutils kmod \
	>> customize-${BUILDTS}

### --- RPi2 Specific --- ###

AptKeyFile ${PWD}/config/raspbian-archive-keyring.gpg
AptKeyFile ${PWD}/config/collabora-archive-keyring.gpg

AptRepo "archive.raspbian.org/raspbian" "jessie" \
	main contrib non-free firmware rpi
AptRepo "repositories.collabora.co.uk/debian"	"jessie" \
	rpi2

AptRepoSources \
	>> customize-${BUILDTS}

AptInstall linux-image-3.18.0-trunk-rpi2 \
	linux-headers-3.18.0-trunk-rpi2 \
	linux-support-3.18.0-trunk \
	>> customize-${BUILDTS}

AptCleanup \
	>> customize-${BUILDTS}

ChangeRootPassword "pi" \
	>> customize-${BUILDTS}

AptRepoSources no-proxy \
	>> customize-${BUILDTS}

AptCache \
	>> customize-${BUILDTS}

RPi2Firmware \
	>> customize-${BUILDTS}

chmod +x customize-${BUILDTS}

sudo vmdebootstrap \
	--variant minbase \
	--arch armhf \
	--distribution jessie \
	--mirror "http://${APT_PROXY}httpredir.debian.org/debian" \
	--image "rpi2-${DIST}-${BUILDTS}.img" \
	--size 2048M \
	--bootsize 64M \
	--boottype vfat \
	--log-level debug \
	--verbose \
	--no-kernel \
	--no-extlinux \
	--root-password pi \
	--hostname raspberrypi \
	--foreign /usr/bin/qemu-arm-static \
	--customize "${PWD}/customize-${BUILDTS}" \
	--serial-console-command "/sbin/getty -L ttyAMA0 115200 vt100" \
	--package debian-archive-keyring \
	--package apt-transport-https \
	--package apt-cacher-ng \
	--package apt-p2p \
	--package minicom \
	--package netbase \
	--package net-tools \
	--package ca-certificates \
	--package curl \
	--package nano

sudo mv debootstrap.log debootstrap-${BUILDTS}.log &>/dev/null
