#!/bin/bash

if ! (rpm -q --quiet qemu-kvm || rpm -q --quiet qemu-img || rpm -q --quiet nbdkit); then
	echo "This script requires qemu and nbd to be installed."
	echo "On Redhat: yum install -y qemu-kvm qemu-img nbdkit"
	exit 1
fi
selinuxenabled
if [ $? -eq 0 ]; then
	echo "Please disable selinux first."
	exit 1
fi
echo "All questions are mandatory!"
echo 
echo "All base images must exist in your CWD."
echo
read -p "What version of CentOS? (eg. 7 or 8): " CENTOS
if [ "${CENTOS}" == "7" ]
then
	IMG="CentOS-7-x86_64-GenericCloud-2009.qcow2"
elif [ "${CENTOS}" == "8" ]
then
	IMG="CentOS-8-GenericCloud-8.3.2011-20201204.2.x86_64.qcow2"
else
	echo "Invalid CentOS version! Aborting!"
	exit 1
fi
echo "CentOS ${CENTOS} Base Image File Name: ${IMG}"
echo
if [ ! -f ${IMG} ]; then
	echo "Cannot find base image!"
	exit 1
fi
read -p "Image File Path:" IMGDEST
read -p "What is the size of the VM disk? (eg. 20 for 20GB):" DISKSIZE
FQDN="privatevm.localhost"
echo
echo "Deploying image with.."
echo "Base Image: " ${IMG}
echo "Destination File: " ${IMGDEST}
echo "Hostname: " ${FQDN}
echo "Disk Size: " ${DISKSIZE}"GB"
echo "Networking: DHCP"
echo 
read -p "Proceed? [Yes or No]" YESNO
if [ "${YESNO}" == "Yes" ]
then
	echo "Beginning image build."
elif [ "${YESNO}" == "No" ]
then
	echo "Ok, aborting"
	exit 0
else
	echo "Invalid choice. Aborting!"
	exit 1
fi

SHORT=`echo ${FQDN} | cut -d\. -f 1`

if [ -f ${IMGDEST} ]
then
	echo "Destination VM qcow2 file exists. Aborting!"
	exit 1
fi

set -e
set -x

modprobe nbd
cp ${IMG} ${IMGDEST}
qemu-img resize ${IMGDEST} ${DISKSIZE}G
qemu-nbd --connect /dev/nbd0 ${IMGDEST}
parted /dev/nbd0 "resizepart 1 -1"
mount -o nouuid /dev/nbd0p1 /mnt
xfs_growfs /mnt
cat >/mnt/etc/sysconfig/network-scripts/ifcfg-eth0 <<EOF
DEVICE=eth0
ONBOOT=yes
BOOTPROTO=dhcp
EOF
cat >/mnt/etc/hostname <<EOF
${FQDN}
EOF
cat >/mnt/etc/resolv.conf <<EOF
nameserver 10.0.2.3
nameserver 1.1.1.1
nameserver 8.8.8.8
EOF
cat >/mnt/etc/hosts <<EOF
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
127.0.1.1 ${FQDN} ${SHORT}
EOF
cat >/mnt/etc/selinux/config <<EOF
# This file controls the state of SELinux on the system.
# SELINUX= can take one of these three values:
#     enforcing - SELinux security policy is enforced.
#     permissive - SELinux prints warnings instead of enforcing.
#     disabled - No SELinux policy is loaded.
SELINUX=disabled
# SELINUXTYPE= can take one of three two values:
#     targeted - Targeted processes are protected,
#     minimum - Modification of targeted policy. Only selected processes are protected.
#     mls - Multi Level Security protection.
SELINUXTYPE=targeted
EOF
mkdir /mnt/etc/systemd/system/serial-getty@ttyS0.service.d
cat >/mnt/etc/systemd/system/serial-getty@ttyS0.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -- \\u' --keep-baud 115200,38400,9600 --autologin user ttyS0 linux
EOF
cat >/mnt/etc/profile.d/aliases.sh <<EOF
alias salloc='echo Please use SSH to connect to a frontend.'
alias sbatch='echo Please use SSH to connect to a frontend.'
alias srun='echo Please use SSH to connect to a frontend.'
alias sacct='echo Please use SSH to connect to a frontend.'
alias sbcast='echo Please use SSH to connect to a frontend.'
alias squeue='echo Please use SSH to connect to a frontend.'
alias sinfo='echo Please use SSH to connect to a frontend.'
alias scontrol='echo Please use SSH to connect to a frontend.'
alias modules='Lmod is not installed in this VM environment.'
alias exit='sudo poweroff'
alias logout='exit'
EOF
chmod 755 /mnt/etc/profile.d/aliases.sh
cat >/mnt/etc/motd <<EOF

You have landed in a generic user account in the VM environment.

Type cd /home/<yourusername> to get to your cluster home directory.

Similarly you can cd to your Depot or Scratch space.

For best results, ensure your terminal window is 80 columns by 24 rows or larger!

EOF
mount --bind /dev /mnt/dev
chroot /mnt rpm -e cloud-init
chroot /mnt yum install -y epel-release
chroot /mnt yum upgrade -y
chroot /mnt yum install -y singularity screen tmux samba-client vim zsh chrony
chroot /mnt yum remove -y openssh-server
chroot /mnt systemctl enable chronyd
mkdir /mnt/host
echo "//10.0.2.4/qemu /host   cifs    username=qemu,password=qemu,iocharset=utf8 0 0" >> /mnt/etc/fstab
chroot /mnt ln -s host/scratch scratch
chroot /mnt ln -s host/depot depot
chroot /mnt rm -rf home
chroot /mnt ln -s host/home home
mkdir /mnt/var/home
chroot /mnt useradd -d /var/home/user -G wheel -m -s /usr/bin/zsh user
chroot /mnt passwd -d user
umount /mnt/dev
umount /mnt
qemu-nbd -d /dev/nbd0

exit 0
