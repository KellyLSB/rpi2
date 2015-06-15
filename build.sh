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

function AptRepo() {
	APT_MIRRORS+=("$(echo "$@" | tr ' ' '%')")
}

function AptKey() {
	APT_KEYS+=($@)
}

function AptKeyFile() {
	APT_KEYF+=($@)
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
				if [[ "$1" == "no-proxy" ]]; then
					echo "deb${src} [arch=${ARCH}] http://${srv} ${dst} ${cmp}"
				else
					echo "deb${src} [arch=${ARCH}] http://${APT_PROXY}${srv} ${dst} ${cmp}"
				fi
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
	cp \$(ls /boot/vmlinuz* | sort | tail -n1) kernel7.img
	cp \$(ls /boot/initrd* | sort | tail -n1) initrd.img
	cp \$(ls /boot/System.map* | sort | tail -n1) Module7.symvers
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
	$(cat $PWD/config/cmdline.txt)
	EOCMDLINE

	cat <<-EOCONFIG > /boot/config.txt
	$(cat $PWD/config/config.txt)
	EOCONFIG
	EOBOOT
	echo -e '\n'
}

cat <<EOF > customize
#!/bin/sh
cd "\$1"
tail -n +6 "\$0" > provision
chmod +x provision
exec chroot "\$1" /provision
#!/bin/bash
EOF
echo -e '\n' >> customize

AptRepo "httpredir.debian.org/debian"	 "jessie" "main" "contrib" "non-free"
AptRepo "http.us.debian.org/debian"	 "jessie" "main" "contrib" "non-free"

AptRepoSources >> customize

AptInstall curl wget ca-certificates netbase net-tools ifupdown iptables \
	iproute2 iproute2-doc dnsutils openssh-server openssh-client mosh \
	git-core  apt-transport-https binutils kmod nano \
	>> customize

# Install non-free binary blob needed to boot Raspberry Pi.	This
# install a kernel somewhere too.
#wget https://raw.github.com/Hexxeh/rpi-update/master/rpi-update \
#		-O $rootdir/usr/bin/rpi-update
#chmod a+x $rootdir/usr/bin/rpi-update
#mkdir -p $rootdir/lib/modules
#touch $rootdir/boot/start.elf

AptKeyFile $PWD/config/raspbian-archive-keyring.gpg
AptKeyFile $PWD/config/collabora-archive-keyring.gpg

AptRepo "archive.raspbian.org/raspbian"		 "jessie" "main" "contrib" "non-free" "firmware" "rpi"
AptRepo "repositories.collabora.co.uk/debian"	 "jessie" "rpi2"

AptRepoSources >> customize

AptInstall linux-image-3.18.0-trunk-rpi2 \
	linux-headers-3.18.0-trunk-rpi2 \
	linux-support-3.18.0-trunk \
	>> customize

AptCleanup >> customize

ChangeRootPassword "pi" >> customize

AptRepoSources no-proxy >> customize

RPi2Firmware >> customize

chmod +x customize

trap "sudo chown -Rf $USER:$USER $(dirname $0)" EXIT SIGQUIT SIGTERM

sudo vmdebootstrap \
	--variant minbase \
	--arch armhf \
	--distribution jessie \
	--mirror http://${APT_PROXY}httpredir.debian.org/debian \
	--image rpi2-${DIST}.img \
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
	--customize `pwd`/customize \
	--package netbase \
	--package net-tools \
	--package ca-certificates \
	--package curl

sudo mv debootstrap.log debootstrap-${BUILDTS}.log &>/dev/null
sudo mv customize customize-${BUILDTS} &>/dev/null
sudo mv rpi2-${DIST}.img rpi2-${DIST}-${BUILDTS}.img &>/dev/null
