install -dm755 /etc/sddm.conf.d
cat > /etc/sddm.conf.d/autologin.conf << "END"
[Autologin]
User=massos
Session=plasma
END
