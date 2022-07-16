# Check which desktop environment is installed and configure autologin for it.

## Xfce.
if [ -e iso-workdir/massos-rootfs/usr/share/xsessions/xfce.desktop ]; then
  echo "--> Configuring autologin for Xfce..."
  . autologin/xfce.sh
elif [ -e iso-workdir/massos-rootfs/usr/share/wayland-sessions/gnome-wayland.desktop ]; then
  echo "--> Configuring autologin for GNOME..."
  . autologin/gnome.sh
elif [ -e iso-workdir/massos-rootfs/usr/share/xsessions/plasma.desktop ]; then
  echo "--> Configuring autologin for KDE Plasma..."
  . autologin/plasma.sh
else
  echo "--> No supported desktop environment found, not configuring autologin."
  echo "--> If you are using a desktop environment not yet supported by us,"
  echo "--> please consider contributing support. See 'autologin/README.md'."
fi
