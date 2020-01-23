#!/bin/sh
#
# $FreeBSD$
#

#
# Please keep in sync with release/tools/ec2.conf.
#

# Packages to install into the image we're creating.  This is a deliberately
# minimalist set, providing only the packages necessary to bootstrap further
# package installation as specified via EC2 user-data.
export VM_EXTRA_PACKAGES="ec2-scripts firstboot-freebsd-update firstboot-pkgs dual-dhclient-daemon"

# Include the amazon-ssm-agent package in amd64 images, since some users want
# to be able to use it on systems which are not connected to the Internet.
# (It is not enabled by default, however.)  This package does not exist for
# aarch64, so we have to be selective about when we install it.
if [ "${TARGET_ARCH}" = "amd64" ]; then
	export VM_EXTRA_PACKAGES="${VM_EXTRA_PACKAGES} amazon-ssm-agent"
fi

# Set to a list of third-party software to enable in rc.conf(5).
export VM_RC_LIST="ec2_configinit ec2_fetchkey ec2_loghostkey firstboot_freebsd_update firstboot_pkgs ntpd"

# Build with a 3.9 GB UFS partition; the growfs rc.d script will expand
# the partition to fill the root disk after the EC2 instance is launched.
# Note that if this is set to <N>G, we will end up with an <N+1> GB disk
# image since VMSIZE is the size of the UFS partition, not the disk which
# it resides within.
export VMSIZE=4000M

# No swap space; the ec2_ephemeralswap rc.d script will allocate swap
# space on EC2 ephemeral disks.  (If they exist -- the T2 low-cost instances
# and the C4 compute-optimized instances don't have ephemeral disks.  But
# it would be silly to bloat the image and increase costs for every instance
# just for those two families, especially since instances ranging in size
# from 1 GB of RAM to 60 GB of RAM would need different sizes of swap space
# anyway.)
export NOSWAP=YES

vm_extra_pre_umount() {
	# The firstboot_pkgs rc.d script will download the repository
	# catalogue and install or update pkg when the instance first
	# launches, so these files would just be replaced anyway; removing
	# them from the image allows it to boot faster.
	chroot ${DESTDIR} ${EMULATOR} env ASSUME_ALWAYS_YES=yes \
		/usr/sbin/pkg delete -f -y pkg
	rm ${DESTDIR}/var/db/pkg/repo-*.sqlite

	# The size of the EC2 root disk can be configured at instance launch
	# time; expand our filesystem to fill the disk.
	echo 'growfs_enable="YES"' >> ${DESTDIR}/etc/rc.conf

	# EC2 instances use DHCP to get their network configuration.  IPv6
	# requires accept_rtadv.
	echo 'ifconfig_DEFAULT="SYNCDHCP accept_rtadv"' >> ${DESTDIR}/etc/rc.conf

	# Unless the system has been configured via EC2 user-data, the user
	# will need to SSH in to do anything.
	echo 'sshd_enable="YES"' >> ${DESTDIR}/etc/rc.conf

	# The AWS CLI tools are generally useful, and small enough that they
	# will download quickly; but users will often override this setting
	# via EC2 user-data.
	echo 'firstboot_pkgs_list="awscli"' >> ${DESTDIR}/etc/rc.conf

	# Enable IPv6 on all interfaces, and use DHCP on both IPv4 and IPv6.
	echo 'ipv6_activate_all_interfaces="YES"' >> ${DESTDIR}/etc/rc.conf
	echo 'dhclient_program="/usr/local/sbin/dual-dhclient"' >> ${DESTDIR}/etc/rc.conf

	# The EC2 console is output-only, so while printing a backtrace can
	# be useful, there's no point dropping into a debugger or waiting
	# for a keypress.
	echo 'debug.trace_on_panic=1' >> ${DESTDIR}/boot/loader.conf
	echo 'debug.debugger_on_panic=0' >> ${DESTDIR}/boot/loader.conf
	echo 'kern.panic_reboot_wait_time=0' >> ${DESTDIR}/boot/loader.conf

	# The console is not interactive, so we might as well boot quickly.
	echo 'autoboot_delay="-1"' >> ${DESTDIR}/boot/loader.conf
	echo 'beastie_disable="YES"' >> ${DESTDIR}/boot/loader.conf

	# The emulated keyboard attached to EC2 instances is inaccessible to
	# users, and there is no mouse attached at all; disable to keyboard
	# and the keyboard controller (to which the mouse would attach, if
	# one existed) in order to save time in device probing.
	echo 'hint.atkbd.0.disabled=1' >> ${DESTDIR}/boot/loader.conf
	echo 'hint.atkbdc.0.disabled=1' >> ${DESTDIR}/boot/loader.conf

	# EC2 has two consoles: An emulated serial port ("system log"),
	# which has been present since 2006; and a VGA console ("instance
	# screenshot") which was introduced in 2016.
	echo 'boot_multicons="YES"' >> ${DESTDIR}/boot/loader.conf

	# Some older EC2 hardware used a version of Xen with a bug in its
	# emulated serial port.  It is not clear if EC2 still has any such
	# nodes, but apply the workaround just in case.
	echo 'hw.broken_txfifo="1"' >> ${DESTDIR}/boot/loader.conf

	# Load the kernel module for the Amazon "Elastic Network Adapter"
	echo 'if_ena_load="YES"' >> ${DESTDIR}/boot/loader.conf

	# Disable ChallengeResponseAuthentication according to EC2
	# requirements.
	sed -i '' -e \
		's/^#ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' \
		${DESTDIR}/etc/ssh/sshd_config

	# Use the NTP service provided by Amazon
	sed -i '' -e 's/^pool/#pool/' \
		-e '1,/^#server/s/^#server.*/server 169.254.169.123 iburst/' \
		${DESTDIR}/etc/ntp.conf

	# The first time the AMI boots, the installed "first boot" scripts
	# should be allowed to run:
	# * ec2_configinit (download and process EC2 user-data)
	# * ec2_fetchkey (arrange for SSH using the EC2-provided public key)
	# * growfs (expand the filesystem to fill the provided disk)
	# * firstboot_freebsd_update (install critical updates)
	# * firstboot_pkgs (install packages)
	touch ${DESTDIR}/firstboot

	rm -f ${DESTDIR}/etc/resolv.conf

	return 0
}
