#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh
#
#  rootprompt.sh
#

module load qemu

IMAGE=NO_IMAGE
MEM=2048
SMP=2
WORKDIR=/tmp

while getopts ":i:m:c:w" opt; do
  case ${opt} in
    i ) # process option i - image file
        IMAGE=$OPTARG
        echo "-i triggered, value is $OPTARG"
      ;;
    m ) # process option m - RAM size
        MEM=$OPTARG 
        echo "-m triggered, value is $OPTARG"
      ;;
    c ) # process option c - core count
        SMP=$OPTARG
        echo "-c triggered, value is $OPTARG"
      ;;
    w ) # working directory
        WORKDIR=$OPTARG
        echo "-w triggered, value is $OPTARG"
      ;;
    \? ) echo "Usage: $0 -i imagefile  [-m] XXG [-c] cores [-w] state_directory"
        exit 1;
      ;;
  esac
done

if [ ! -f "$IMAGE" ]; then
    >&2 echo "Can't find image file \"$IMAGE\""
    echo
    echo "Please copy an image from /depot/itap/ayounts/privatevms"
    echo " to your scratch or Data Depot space and specify an image"
    echo " using the -i option."
    echo
    exit 1
fi

if [ ! -d "$WORKDIR" ]; then
    >&2 echo "Temporary state directory does not exist!"
    exit 1
fi

LOCKFILE="${WORKDIR}/rootprompt_vm.lock"
if [[ -e "${LOCKFILE}" ]]; then
        echo "ERROR: Lock file present. Another instance of this image may be running: "
        echo
        echo "$LOCKFILE"
        date -r "$LOCKFILE"
        cat "$LOCKFILE"
        stat -c "%U" "$LOCKFILE"
        echo
        echo "Loading this image with another VM running from it will destroy the image."
        echo "Log into the above machine and end your existing instance and remove lock file."
        echo "Only remove lock file if you are absolutely sure the other VM is stopped and proceed with extreme caution."
        exit 1
fi
hostname > "$LOCKFILE"

## Documentation about the qemu innvocation
# emulate a x86 64bit system
#qemu-system-x86_64 \
# enable KVM acceleration
#    -enable-kvm \
# define processor layout and capabilities
#    -smp sockets=1,cpus=${SMP},cores=${SMP} -cpu host \
# define system memory size
#    -m ${MEM} \
# explicitly remove all graphics cards
#    -vga none -nographic \
# define virtual disk with the OS
#    -drive file="${IMAGE}",if=virtio,aio=threads,format=qcow2 \
# define a user-land NAT network with SMB server sharing hosts's / into VM
#    -netdev user,id=mynet0,smb=/ \
# define an emulated network card for the VM
#    -device virtio-net-pci,netdev=mynet0 \
# defined an emulated RNG device for the VM
#    -device virtio-rng-pci \
# specify where to write debug logs
#    -debugcon file:$WORKDIR/debug.log -global isa-debugcon.iobase=0x402

qemu-system-x86_64 \
    -enable-kvm \
    -smp sockets=1,cpus=${SMP},cores=${SMP} -cpu host \
    -m ${MEM} \
    -vga none -nographic \
    -drive file="${IMAGE}",if=virtio,aio=threads,format=qcow2 \
    -netdev user,id=mynet0,smb=/ \
    -device virtio-net-pci,netdev=mynet0 \
    -device virtio-rng-pci \
    -debugcon file:$WORKDIR/debug.log -global isa-debugcon.iobase=0x402

rm ${LOCKFILE}
