#!/bin/bash

ARCH="armhf"
DIST="jessie"

#
# Load in library
#

source mkdebdisk.img/mkdebdisk.img.lib.bash

function KosagiNovena() {
	GrubAppendEtcDefaultVar \
		"GRUB_CMDLINE_LINUX" \
		"vga=normal"

	ConsoleSystemdGetty
	ConsoleLinuxCmdline
}

#                          #
# Begin Debdisk definition #
#                          #

Begin \
	>> ${CUSTOMIZE}

#
# Serial Consoles
#

ConsoleAdd "ttymxc1" "115200" "n" "8"

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

AptRepo "repo.novena.io/repo" "jessie" \
	main contrib non-free

AptRepo "httpredir.debian.org/debian" "jessie" \
	main contrib non-free

AptRepo "http.us.debian.org/debian" "jessie" \
	main contrib non-free

AptRepo "ftp.us.debian.org/debian" "jessie" \
	main contrib non-free

AptRepoSources \
	>> ${CUSTOMIZE}

AptInstall <<-EOF >> ${CUSTOMIZE}
alsa-utils android-tools-adb android-tools-fastboot android-tools-fsutils
aptitude arandr autoconf automake avahi-daemon avahi-dnsconfd bash-completion
bc bison bison bluez bluez-hcidump bluez-tools bridge-utils build-essential
clang console-data console-setup curl dbus-x11 dc debootstrap dict dosfstools
emacs enigmail evtest exfat-fuse exfat-utils flex fuse g++ gawk gcc gdb git
git-email git-man gnupg-agent gnupg2 hexchat hwinfo i2c-tools icedove
iceweasel chromium initramfs-tools iotop iperf iptraf irqbalance-imx irssi
keychain kosagi-repo libbluetooth3 libdrm-armada2-dbg libetnaviv libnss-mdns
libqt5core5a libqt5gui5 libqt5widgets5 lightdm linux-headers-novena
linux-image-novena locales locate lzop make memtester mousepad ncurses-dev
network-manager-iodine network-manager-openvpn network-manager-pptp
network-manager-vpnc nmap novena-disable-ssp novena-eeprom novena-eeprom-gui
novena-firstrun novena-usb-hub ntfs-3g ntp ntpdate openssh-client
openssh-server mosh orage p7zip-full paprefs pavucontrol pciutils pidgin
pkg-config pm-utils powermgmt-base powertop python qalc read-edid screen
smartmontools strace subversion sudo synaptic tcpdump tmux u-boot-novena
unp unrar-free unzip usbutils user-setup vim x11-apps x11-session-utils
x11-xserver-utils xbitmaps xfce4 xfce4-appfinder xfce4-goodies xfce4-mixer
xfce4-notifyd xfce4-power-manager xfce4-session xfce4-settings xfce4-terminal
xfdesktop4 xfdesktop4-data xfonts-100dpi xfonts-75dpi xfonts-scalable xfwm4
xfwm4-themes xinit xorg xorg-docs-core xorg-novena xscreensaver
xserver-xorg-video-armada xserver-xorg-video-armada-dbg
xserver-xorg-video-armada-etnaviv xserver-xorg-video-modesetting xz-utils zip
EOF

SystemdEnableService ssh \
	>> ${CUSTOMIZE}

AptCleanup \
	>> ${CUSTOMIZE}

AptRepoSources no-proxy \
	>> ${CUSTOMIZE}

SystemdRootPassword "novena" \
	>> ${CUSTOMIZE}

KosagiNovena \
	>> ${CUSTOMIZE}

chmod +x ${CUSTOMIZE}

# Build the debian disk image.
sudo vmdebootstrap \
	--arch "${MKDDP_ARCH}" \
	--distribution "${MKDDP_DIST}" \
	--mirror "http://${APT_PROXY}httpredir.debian.org/debian" \
	--image "novena-${MKDDP_DIST}-${MKDDP_TIME}.img" \
	--size 4G \
	--bootsize 64M \
	--boottype vfat \
	--log-level debug \
	--verbose \
	--no-kernel \
	--no-extlinux \
	--hostname net6501 \
	--foreign "$(which qemu-arm-static)" \
	--customize "${PWD}/${CUSTOMIZE}" \
	--serial-console-command "$(ConsoleSerialCommand)" \
	--package debian-archive-keyring \
	--package apt-transport-https \
	--package debootstrap \
	--package minicom \
	--package locales \
	--package curl \
	--package nano

# Copy the bootstrap logs.
sudo mv debootstrap.log debootstrap-${MKDDP_TIME}.log &>/dev/null
