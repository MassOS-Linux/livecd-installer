#!/bin/bash
#
# MassOS LiveCD ISO Creator - Copyright (C) 2022 MassOS Developers.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# Exit on error.
set -e
# Ensure we are running as root.
if [ $EUID -ne 0 ]; then
  echo "Error: $(basename "$0") must be run as root."
  exit 1
fi
# Ensure dependencies are present.
which curl &>/dev/null || (echo "Error: curl is required." >&2; exit 1)
which mass-chroot &>/dev/null || (echo "Error: mass-chroot (part of MassOS) is required." >&2; exit 1)
which mkfs.fat &>/dev/null || (echo "Error: mkfs.fat from dosfstools is required." >&2; exit 1)
which mksquashfs &>/dev/null || (echo "Error: mksquashfs from squashfs-tools is required." >&2; exit 1)
which xorriso &>/dev/null || (echo "Error: xorriso from libisoburn is required." >&2; exit 1)
# Ensure that the rootfs file is specified and valid.
if [ -z "$1" ]; then
  echo "Error: Rootfs file must be specified." >&2
  echo "Usage: $(basename "$0") <rootfs-file-name>.tar.xz" >&2
  exit 1
fi
if [ ! -f "$1" ]; then
  echo "Error: Specified rootfs file $1 is not valid." >&2
  exit 1
fi
# Check if an existring directory exists.
if [ -e "iso-workdir" ]; then
  echo "The working directory 'iso-workdir' already exists, please remove" >&2
  echo "it before running $(basename "$0")." >&2
  exit 1
fi
# Create directories.
mkdir -p iso-workdir/{iso-root,massos-rootfs,mnt,squashfs-tmp,syslinux}
mkdir -p iso-workdir/iso-root/EFI/BOOT
mkdir -p iso-workdir/iso-root/isolinux
mkdir -p iso-workdir/iso-root/LiveOS
mkdir -p iso-workdir/squashfs-tmp/LiveOS
mkdir -p iso-workdir/efitmp
# Download stuff.
echo "Downloading SYSLINUX..."
curl -L https://cdn.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.xz -o iso-workdir/syslinux.tar.xz
tar --no-same-owner -xf iso-workdir/syslinux.tar.xz -C iso-workdir/syslinux --strip-components=1
echo "Downloading Limine..."
curl -L https://raw.githubusercontent.com/limine-bootloader/limine/v2.78.2-binary/BOOTX64.EFI -o iso-workdir/iso-root/EFI/BOOT/BOOTX64.EFI
curl -L https://raw.githubusercontent.com/limine-bootloader/limine/v2.78.2-binary/LICENSE.md -o iso-workdir/iso-root/EFI/BOOT/LICENSE-BOOTX64.txt
# Extract rootfs.
echo "Extracting rootfs..."
tar -xpf "$1" -C iso-workdir/massos-rootfs
ver="$(cat iso-workdir/massos-rootfs/etc/massos-release)"
# Prepare the live system.
echo "Preparing the live system..."
chroot iso-workdir/massos-rootfs /usr/sbin/groupadd -r autologin
chroot iso-workdir/massos-rootfs /usr/sbin/useradd -c "Live Session User" -G wheel,netdev,lpadmin,autologin -ms /bin/bash massos
echo "massos:massos" | chroot iso-workdir/massos-rootfs /usr/sbin/chpasswd -c SHA512
echo "massos ALL=(ALL) NOPASSWD: ALL" > iso-workdir/massos-rootfs/etc/sudoers.d/live
cat > iso-workdir/massos-rootfs/etc/polkit-1/rules.d/49-live.rules << "END"
polkit.addRule(function(action, subject) {
    if (subject.isInGroup("massos")) {
        return polkit.Result.YES;
    }
});
END
cp iso-workdir/massos-rootfs/etc/lightdm/lightdm.conf iso-workdir/massos-rootfs/etc/lightdm/lightdm.conf.orig
sed -i 's/#autologin-user=/autologin-user=massos/' iso-workdir/massos-rootfs/etc/lightdm/lightdm.conf
sed -i 's/#autologin-user-timeout=0/autologin-user-timeout=0/' iso-workdir/massos-rootfs/etc/lightdm/lightdm.conf
sed -i 's/#autologin-session=/autologin-session=xfce/' iso-workdir/massos-rootfs/etc/lightdm/lightdm.conf
install -m755 livecd-installer iso-workdir/massos-rootfs/usr/bin/livecd-installer
install -m644 livecd-installer.desktop iso-workdir/massos-rootfs/usr/share/applications/livecd-installer.desktop
chroot iso-workdir/massos-rootfs /usr/bin/install -o massos -g massos -dm755 /home/massos/Desktop
chroot iso-workdir/massos-rootfs /usr/bin/install -o massos -g massos -m755 /usr/share/applications/livecd-installer.desktop /home/massos/Desktop/livecd-installer.desktop
# Download firmware.
echo "Downloading firmware..."
FW_VER="20220209"
MVER="20220207"
SOF_VER="v2.0"
curl -L https://cdn.kernel.org/pub/linux/kernel/firmware/linux-firmware-$FW_VER.tar.xz -o iso-workdir/firmware.tar.xz
curl -L https://github.com/intel/Intel-Linux-Processor-Microcode-Data-Files/archive/microcode-$MVER.tar.gz -o iso-workdir/mcode.tar.gz
curl -L https://github.com/thesofproject/sof-bin/releases/download/$SOF_VER/sof-bin-$SOF_VER.tar.gz -o iso-workdir/sof.tar.gz
# Install firmware.
echo "Installing firmware..."
mkdir -p iso-workdir/{firmware,mcode,sof}
tar --no-same-owner -xf iso-workdir/firmware.tar.xz -C iso-workdir/firmware --strip-components=1
tar --no-same-owner -xf iso-workdir/mcode.tar.gz -C iso-workdir/mcode --strip-components=1
tar --no-same-owner -xf iso-workdir/sof.tar.gz -C iso-workdir/sof --strip-components=1
install -d iso-workdir/massos-rootfs/usr/lib/firmware
pushd iso-workdir/firmware >/dev/null
patch -sNp1 -i ../../livecd-files/linux-firmware-compression.patch
./copy-firmware.sh -C "$PWD"/../massos-rootfs/usr/lib/firmware
install -t "$PWD"/../massos-rootfs/usr/lib/firmware -Dm644 GPL-2 GPL-3 LICENCE* LICENSE* WHENCE
popd >/dev/null
install -d iso-workdir/massos-rootfs/usr/lib/firmware/intel-ucode
install -m644 iso-workdir/mcode/intel-ucode{,-with-caveats}/* iso-workdir/massos-rootfs/usr/lib/firmware/intel-ucode
pushd iso-workdir/sof >/dev/null
cp -r sof*$SOF_VER "$PWD"/../massos-rootfs/usr/lib/firmware/intel
ln -sf sof-$SOF_VER "$PWD"/../massos-rootfs/usr/lib/firmware/intel/sof
ln -sf sof-tplg-$SOF_VER "$PWD"/../massos-rootfs/usr/lib/firmware/intel/sof-tplg
install -t "$PWD"/../massos-rootfs/usr/lib/firmware/intel/sof -Dm644 LICENCE.Intel LICENCE.NXP Notice.NXP
popd >/dev/null
# Create Squashfs image.
echo "Creating squashfs image..."
cd iso-workdir/massos-rootfs
mksquashfs * ../iso-root/LiveOS/squashfs.img -comp xz -quiet
cd ../..
# Copy kernel and generate initramfs.
echo "Copying kernel..."
cp iso-workdir/massos-rootfs/boot/vmlinuz* iso-workdir/iso-root/vmlinuz
echo "Generating initramfs..."
mass-chroot iso-workdir/massos-rootfs /usr/bin/dracut -q -a dmsquash-live initrd.img "$(ls iso-workdir/massos-rootfs/usr/lib/modules)"
echo "Copying initramfs..."
cp iso-workdir/massos-rootfs/initrd.img iso-workdir/iso-root/initrd.img
# Install bootloader files.
echo "Setting up bootloader..."
# Legacy BIOS.
cp iso-workdir/syslinux/bios/core/isolinux.bin iso-workdir/iso-root/isolinux/isolinux.bin
cp iso-workdir/syslinux/bios/com32/elflink/ldlinux/ldlinux.c32 iso-workdir/iso-root/isolinux/ldlinux.c32
cp iso-workdir/syslinux/bios/com32/lib/libcom32.c32 iso-workdir/iso-root/isolinux/libcom32.c32
cp iso-workdir/syslinux/bios/com32/libutil/libutil.c32 iso-workdir/iso-root/isolinux/libutil.c32
cp iso-workdir/syslinux/bios/com32/menu/vesamenu.c32 iso-workdir/iso-root/isolinux/vesamenu.c32
cp iso-workdir/syslinux/bios/mbr/isohdpfx.bin iso-workdir/iso-root/isolinux/isohdpfx.bin
cp livecd-files/isolinux.cfg iso-workdir/iso-root/isolinux/isolinux.cfg
cp livecd-files/splash.png iso-workdir/iso-root/isolinux/splash.png
# EFI.
chmod 755 iso-workdir/iso-root/EFI/BOOT/BOOTX64.EFI
cp livecd-files/limine.cfg iso-workdir/iso-root/EFI/BOOT/limine.cfg
truncate -s 1M iso-workdir/iso-root/EFI/BOOT/efiboot.img
mkfs.fat -F12 iso-workdir/iso-root/EFI/BOOT/efiboot.img -n "MASSOS_EFI"
mount -o loop iso-workdir/iso-root/EFI/BOOT/efiboot.img iso-workdir/efitmp
mkdir -p iso-workdir/efitmp/EFI/BOOT
cp -a iso-workdir/iso-root/EFI/BOOT/{BOOTX64.EFI,limine.cfg,LICENSE-BOOTX64.txt} iso-workdir/efitmp/EFI/BOOT
umount iso-workdir/efitmp
# Copy additional files.
cp livecd-files/autorun.ico iso-workdir/iso-root/autorun.ico
cp livecd-files/autorun.inf iso-workdir/iso-root/autorun.inf
cp livecd-files/README.txt iso-workdir/iso-root/README.txt
cp LICENSE iso-workdir/iso-root/LICENSE.txt
cp iso-workdir/syslinux/COPYING iso-workdir/iso-root/isolinux/LICENSE-ISOLINUX.txt
# Create the ISO image.
echo "Creating ISO image..."
xorriso -as mkisofs -iso-level 3 -R -J -max-iso9660-filenames -omit-period -omit-version-number -relaxed-filenames -allow-lowercase -volid "MASSOS" -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -e EFI/BOOT/efiboot.img -isohybrid-gpt-basdat -no-emul-boot -isohybrid-mbr iso-workdir/iso-root/isolinux/isohdpfx.bin -o massos-$ver-x86_64.iso iso-workdir/iso-root
# Clean up.
echo "Cleaning up..."
rm -rf iso-workdir
# Finishing message.
echo "All done! Output image written to massos-$ver-x86_64.iso."
