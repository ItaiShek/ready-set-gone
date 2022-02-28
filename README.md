## Info
If you want to install Arch linux for the very first time, then you should do it yourself with help of the [Arch wiki](https://wiki.archlinux.org/title/Installation_guide).
<br>
<br>
This Arch linux installer script is meant for personal use. If you want to use an Arch linux installer, then you might want to use another one, or at the very last edit mine. If you use it as is then your system will look like mine.

## Installation
If `sudo pacman -Sy git` gives a GPG key import error, then you need to edit `/etc/pacman.conf` and replace `SigLevel = Required DatabaseOptional` with `SigLevel = Never`.

#### Insallation with curl
```
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ItaiShek/ready-set-gone/main/installer.sh)"
```

#### Installation from github repository
```
sudo pacman -Sy git
git clone https://github.com/ItaiShek/ready-set-gone.git tempdir
mv tempdir/installer.sh .
rm -rf tempdir
./insatller.sh
```
