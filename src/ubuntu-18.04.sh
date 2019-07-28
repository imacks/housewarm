#!/bin/sh

set -e

# --- BEGIN CONFIGURATION ---

CPU_ARCH="intel"
IS_VIRTUAL_MACHINE="true"
DISABLE_NETPLAN="true"
DISABLE_SWAP="true"
NTP_SOURCE="hyperv"
MOTD_BANNER_URL="https://raw.githubusercontent.com/imacks/housewarm/master/src/motd/00-banner.sh"
MOTD_COMPUTER_INFO_URL="https://raw.githubusercontent.com/imacks/housewarm/master/src/motd/15-computer-info.sh"
COLORFUL_BASHRC="true"
OEMUSER_NAME="administrator"
OEMUSER_RENAME_GROUP="administrators"
AUTO_REBOOT="true"
#PKG_POWERSHELL_URL="https://github.com/PowerShell/PowerShell/releases/download/v6.2.2/powershell_6.2.2-1.ubuntu.18.04_amd64.deb"
#PKG_OMI_URL="https://github.com/microsoft/omi/releases/download/v1.6.0/omi-1.6.0-0.ssl_110.ulinux.x64.deb"
#PKG_PSRP_URL="https://github.com/PowerShell/psl-omi-provider/releases/download/v1.4.2-2/psrp-1.4.2-2.universal.x64.deb"
#PKG_DOCKER_URL="https://download.docker.com/linux/ubuntu/dists/bionic/pool/stable/amd64/docker-ce_19.03.1~3-0~ubuntu-bionic_amd64.deb"
#PKG_DOCKER_CLI_URL="https://download.docker.com/linux/ubuntu/dists/bionic/pool/stable/amd64/docker-ce-cli_19.03.1~3-0~ubuntu-bionic_amd64.deb"
#PKG_DOCKER_CONTAINERD_URL="https://download.docker.com/linux/ubuntu/dists/bionic/pool/stable/amd64/containerd.io_1.2.6-3_amd64.deb"

# --- END CONFIGURATION ---

echo '[housewarm.info] update package data'
apt-get update

echo '[housewarm.info] minimizing operating system'
apt-get install -f -y ubuntu-minimal aptitude
aptitude markauto '~i!~nubuntu-minimal'
apt-get autoremove --purge -y
rm -rf /etc/cloud
rm -rf /var/lib/cloud

echo '[housewarm.info] install required packages'
apt-get install -f -y ncurses-term screen curl chrony net-tools iptables dnsutils mdadm xfsprogs secureboot-db openssh-server

if [ "$CPU_ARCH" = "intel" ]; then
	echo '[housewarm.info] install intel microcode'
	apt-get install -f -y intel-microcode
elif [ "$CPU_ARCH" = "amd" ]; then
	echo '[housewarm.info] install amd microcode'
	apt-get install -f -y amd64-microcode
fi

if [ "$IS_VIRTUAL_MACHINE" = "true" ]; then
	echo '[housewarm.info] install VM optimization packages'
	apt-get install -f -y linux-virtual-hwe-18.04 linux-cloud-tools-virtual-hwe-18.04 linux-tools-virtual-hwe-18.04
	sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=""/GRUB_CMDLINE_LINUX_DEFAULT="elevator=noop"/g' /etc/default/grub
	cat /sys/block/sda/queue/scheduler
fi

echo '[housewarm.info] uninstall extra packages'
apt-get purge -f -y --autoremove vim-common vim-tiny bash-completion debconf-i18n ubuntu-advantage-tools thermald net-tools

if [ "$DISABLE_NETPLAN" = "true" ]; then
	echo '[housewarm.info] degrade netplan to ifupdown'

	apt-get install -f -y ifupdown

	echo 'source /etc/network/interfaces.d/*' > /etc/network/interfaces
	echo '' >> /etc/network/interfaces
	echo '# Loopback network interface' >> /etc/network/interfaces
	echo 'auto lo' >> /etc/network/interfaces
	echo 'iface lo inet loopback' >> /etc/network/interfaces

	echo 'allow-hotplug eth0' > /etc/network/interfaces.d/eth0-dhcp
	echo 'auto eth0' >> /etc/network/interfaces.d/eth0-dhcp
	echo 'iface eth0 inet dhcp' >> /etc/network/interfaces.d/eth0-dhcp

	apt-get purge -f -y --autoremove nplan netplan.io
	rm -rf /etc/netplan
	rm -rf /usr/share/netplan

	sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="netcfg\/do_not_use_netplan=true"/g' /etc/default/grub
fi

echo '[housewarm.info] final packages cleanup'
apt-get purge -f -y wireless-regdb aptitude
apt-get autoclean -y
apt-get clean -y
apt autoremove -f --purge

# Regenerate grub
echo '[housewarm.info] apply boot settings'
update-grub

# Primary user
if [ "x${OEMUSER_RENAME_GROUP}x" != "xx" ]; then
	if [ "${OEMUSER_RENAME_GROUP}" != "$OEMUSER_NAME" ]; then
		echo '[housewarm.info] rename default user group'
		groupmod -n "$OEMUSER_RENAME_GROUP" "$OEMUSER_NAME"
		id "$OEMUSER_NAME"
	else
		echo '[housewarm.warn] default user group name == default user name'
	fi
fi

# Swap file

if [ "$DISABLE_SWAP" = "true" ]; then
	echo '[housewarm.info] disable swap'
	swapoff -a
	sed -i 's/\/swap.img/#\/swap.img/g' /etc/fstab

	if [ -f '/swap.img' ]; then
		echo '[housewarm.info] del swap file'
		rm -f /swap.img
	fi
fi

# Chrony

echo '[housewarm.info] configure ntp'

sed -i 's/pool/#pool/g' /etc/chrony/chrony.conf
sed -i 's/but only in the first three clock updates/for all clock updates/g' /etc/chrony/chrony.conf
sed -i 's/makestep 1 3/makestep 1 -1/g' /etc/chrony/chrony.conf

mkdir -p /etc/chrony/chrony.conf.d
chrony_include_source='include /etc/chrony/chrony.conf.d/*.conf'
chrony_include_configured=$(cat /etc/chrony/chrony.conf | grep "$chrony_include_source")
if [ "x${chrony_include_configured}x" != "xx" ]; then
	echo '' >> /etc/chrony/chrony.conf
	echo '# Include configuration directory' >> /etc/chrony/chrony.conf
	echo '' >> /etc/chrony/chrony.conf
fi

if [ "$NTP_SOURCE" = "hyperv" ]; then
	echo '[housewarm.info] add Hyper-V time integration'

	echo '# Hyper-V time service integration' >> /etc/chrony/chrony.conf.d/hyperv.conf
	echo 'refclock PHC /dev/ptp0 trust poll 3 dpoll -2 offset 0' >> /etc/chrony/chrony.conf
fi

echo '[housewarm.info] apply NTP settings'
systemctl restart chronyd
chronyc sources

# MOTD

echo '[housewarm.info] disable dynamic MOTD news'
sed -i 's/ENABLED=1/ENABLED=0/g' /etc/default/motd-news

echo '[housewarm.info] del default motd info'
rm -rf /etc/update-motd.d/10-help-text

if [ "x${MOTD_BANNER_URL}x" != "xx" ]; then
	echo '[housewarm.info] install motd banner'
	curl -L "$MOTD_BANNER_URL" -o /tmp/00-banner.sh
	cp /tmp/00-banner.sh /etc/update-motd.d/00-header
fi
if [ "x${MOTD_COMPUTER_INFO_URL}x" != "xx" ]; then
	echo '[housewarm.info] install motd info'
	curl -L "$MOTD_COMPUTER_INFO_URL" -o /tmp/15-computer-info.sh
	cp /tmp/15-computer-info.sh /etc/update-motd.d/15-computer-info
fi
chmod +x /etc/update-motd.d/*

# BashRC

if [ "$COLORFUL_BASHRC" = "true" ]; then
	echo '[housewarm.info] patch bashrc colors'

	color_prompt='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u\033[01;31m\]@\033[01;33m\]\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$'
	color_prompt="PS1='${color_prompt} '"
	bashrc_repl_value=$(echo "$color_prompt" | sed 's/[\/&]/\\&/g')
	bashrc_repl_keyword=$(echo 'if [ "$color_prompt" = yes ]; then' | sed 's/[]\/$*.^[]/\\&/g')
	sed -i "/^${bashrc_repl_keyword}/{n;d}" /etc/skel/.bashrc
	sed -i "/^${bashrc_repl_keyword}/a\ \ \ \ ${bashrc_repl_value}" /etc/skel/.bashrc

	if [ -f "/home/${OEMUSER_NAME}/.bashrc" ]; then
		echo '[housewarm.info] apply bashrc to default user'
		cp /etc/skel/.bashrc "/home/${OEMUSER_NAME}/.bashrc"
	fi
fi

# Packages

if [ "x${PKG_POWERSHELL_URL}x" != "xx" ]; then
	echo '[housewarm.info] install powershell'
	curl -L "$PKG_POWERSHELL_URL" -o /tmp/powershell.deb
	dpkg -i /tmp/powershell.deb
	apt-get install -f

	if [ "x${PKG_OMI_URL}x" != "xx" ]; then
		echo '[housewarm.info] install microsoft-omi'
		curl -l "$PKG_OMI_URL" -o /tmp/omi.deb
		dpkg -i /tmp/omi.deb
		apt-get install -f
	fi

	if [ "x${PKG_PSRP_URL}x" != "xx" ]; then
		echo '[housewarm.info] install powershell-psrp'
		curl -l "$PKG_PSRP_URL" -o /tmp/psrp.deb
		dpkg -i /tmp/psrp.deb
		apt-get install -f
	fi
fi

# Reboot

if [ "$AUTO_REBOOT" = "true" ]; then
	echo '[housewarm.info] rebooting...brb'
	reboot
else
	echo '[housewarm.info] all done. Reboot for changes to take effect.'
fi
