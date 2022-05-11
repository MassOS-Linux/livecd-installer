# Check which desktop environment is installed and configure autologin for it.

## Xfce.
if [ -x iso-workdir/massos-rootfs/usr/bin/xfce4-session ]; then
  echo "--> Configuring autologin for Xfce..."
  . autologin/xfce.sh
else
  echo "--> No supported desktop environment found, not configuring autologin."
  echo "--> If you are using a desktop environment not yet supported by us,"
  echo "--> please consider contributing support. See 'autologin/README.md'."
fi
