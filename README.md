# RootPrompt

Provides users a sandbox to run as root in a unprivileged virtual machine.

## Uses
* Functions that require root level access
* Building Singularity or Docker containers
* Building VM images

## Features
* BIOS-based amd64 virtual machines
* CentOS 7 and CentOS 8 compatible
* Serial console for text based interactions
* Host file system mounted at /host
  * Symlinks for /home, /depot, and /scratch
* Passwordless auto-login to a user account
* Passwordless, full sudo access
* MOTD describe critical pieces of information
* Set of helpful command aliases (eg exit -> poweroff)
* Includes our standard set of VM appliance command line options (-i, -m, etc)
* Self hosting to make updating images easy

## Creating new images
1. Start a VM with at least 20GB of free space and 8GB of memory
1. Copy generate.sh script into /tmp inside a running VM
1. Download appropriate CentOS 7 or 8 cloud image (Google the filename the script spits out)
1. Invoke the generate.sh script and follow the prompts
1. If successful, copy the qcow2 image file out of the image

This work is based on the script provided by the Clear Linux project and their serial-based UEFI virtual machines. See the contents of the "original" directory.

