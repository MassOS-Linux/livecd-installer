# About
This repository contains the MassOS Installation Program for the MassOS Live CD, as well as the scripts to create the Live CD ISO file.
# Downloading
Official releases can be found on the standard [MassOS Releases Page](https://github.com/MassOS-Linux/MassOS/releases). From there, you can download the ISO of the latest stable version.
# Building an ISO file (for developers)
Only developers who build MassOS themselves will need to create an ISO file. You must have a local rootfs tarball from which to create the ISO from, and the following dependencies (we strongly encourage running this from an official MassOS system):

- curl (for downloading the necessary ISO components).
- dosfstools (for creating efiboot.img; required for booting from the ISO in UEFI mode).
- libisoburn (for the xorriso utility; used to create the ISO image).
- mass-chroot (must be the version from MassOS 2022.02 or newer. If using a non-MassOS distribution, install mass-chroot from the MassOS repository somewhere in your PATH such as `/usr/local/bin`).
- squashfs-tools (for creating a squashfs filesystem, required for live CDs).

Simply clone this repository and run the create-iso.sh script as root (or create-iso-firmware.sh to create an ISO image without non-free firmware included).

You must pass the rootfs file you want to use for creating the ISO as an argument, like this (for example):
```
sudo ./create-iso.sh massos-2022.02-x86_64.tar.xz
```
Replacing the above command with the filename of your rootfs.
