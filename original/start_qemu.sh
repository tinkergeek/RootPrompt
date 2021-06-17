#!/bin/bash
# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; -*-
# ex: ts=8 sw=4 sts=4 et filetype=sh
#
#  start_qemu.sh
#
#  Copyright (c) 2016-2017 Intel Corporation
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

module load qemu

IMAGE=/depot/itap/ayounts/centos/centos8.img

if [ ! -f "$IMAGE" ]; then
    >&2 echo "Can't find image file \"$IMAGE\""
    exit 1
fi

WORKDIR=$RCAC_SCRATCH/.centos_vm

if [ ! -d "$WORKDIR" ]; then
    mkdir $WORKDIR
    echo 
    echo "To exit, shutdown the VM."
    echo
    sleep 5
fi
    
rm -f $WORKDIR/debug.log

cp /depot/itap/ayounts/centos/OVMF_VARS.fd $WORKDIR/OVMF_VARS.fd
cp /depot/itap/ayounts/centos/OVMF_CODE.fd $WORKDIR/OVMF_CODE.fd
cp /depot/itap/ayounts/centos/OVMF.fd $WORKDIR/OVMF.fd
chmod 644 $WORKDIR/OVMF_VARS.fd
chmod 644 $WORKDIR/OVMF_CODE.fd
chmod 644 $WORKDIR/OVMF.fd

if [ ! -f "$WORKDIR/centos.qcow2" ]; then
    qemu-img create -f qcow2 -b $IMAGE $WORKDIR/centos.qcow2
fi

# 10/25/2018: keep back compatibility for a while
UEFI_BIOS="-bios $WORKDIR/OVMF.fd"

if [ -f OVMF_VARS.fd -a -f OVMF_CODE.fd ]; then
    UEFI_BIOS=" -drive file=$WORKDIR/OVMF_CODE.fd,if=pflash,format=raw,unit=0,readonly=on "
    UEFI_BIOS+=" -drive file=$WORKDIR/OVMF_VARS.fd,if=pflash,format=raw,unit=1 "
fi

VMN=${VMN:=1}

qemu-system-x86_64 \
    -enable-kvm \
    ${UEFI_BIOS} \
    -smp sockets=1,cpus=2,cores=2 -cpu host \
    -m 2048 \
    -vga none -nographic \
    -drive file="$WORKDIR/centos.qcow2",if=virtio,aio=threads,format=qcow2 \
    -netdev user,id=mynet0,hostfwd=tcp::${VMN}0022-:22,hostfwd=tcp::${VMN}2375-:2375,smb=/ \
    -device virtio-net-pci,netdev=mynet0 \
    -device virtio-rng-pci \
    -debugcon file:$WORKDIR/debug.log -global isa-debugcon.iobase=0x402 $@
