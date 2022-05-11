# PORTING DESKTOP ENVIRONMENTS
Do the following if you are porting a desktop environment to MassOS:

1. Fork this repo.
2. Add a script named `<your-de>.sh` containing the commands used to configure autologin. Look at the reference `xfce.sh` if you are unsure on how it should be formatted.
3. Modify `autologin.sh` to add a check for your desktop environment. Follow the format of others. The most common way to check is to see if the desktop environment's session launcher program is installed. e.g. `if [ -x iso-workdir/massos-rootfs/usr/bin/xfce4-session ]` for Xfce. You might use `elif` to keep in the one condition statement.
5. Test your changes to ensure they work.
6. Create a pull request with your additions.
