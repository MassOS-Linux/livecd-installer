cp iso-workdir/massos-rootfs/etc/gdm/custom.conf{,.orig}
sed -i '6iAutomaticLoginEnable=True' /etc/gdm/custom.conf
sed -i '7iAutomaticLogin=massos' /etc/gdm/custom.conf
