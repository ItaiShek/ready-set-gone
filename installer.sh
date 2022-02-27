#!/bin/bash
# (c) 2022 Itai Shek 
# arch linux installer

set -e

clear
echo "Arch linux installer script"

# step 1 - setup system's clock and keyboard layout
echo -e "\nSetting the console keyboard layout to US"
loadkeys us
echo -e "\nUpdating system's clock"
timedatectl set-ntp true

read -srn1 -p "Press any key to continue";echo
clear

# step 2 - partitioning
# only use if there isn't already an EFI partition as formatting
# it can destroy the bootloaders for other installed OS
echo -e "\nPartition tables list:"
fdisk -l  
echo -e "\nEnter the disk drive:"
read drive

echo "Would you like to create the partition yourself [y/n] (default - n)"
read choice

if [[ $choice == 'y' ]] || [[ $choice == 'Y' ]]
then
	cfdisk $drive
else
	echo "Enter the EFI partition size (default 550M):"
	echo "(K, M, G, T, P)"
	read efiSize
	efiSize=${efiSize:-550M}
	
	echo "Enter the SWAP partition size (recomendded - RAM*2):"
	echo "(K, M, G, T, P)"
	read swapSize
	swapSize=${swapSize:-8G}

	echo "Creating the partitions"

	(
	# delete the partitions 1-4
	echo "d"	# delete a partition
	echo ""
	echo "d"	# delete a partition
	echo ""
	echo "d"	# delete a partition
	echo ""
	echo "d"	# delete a partition
	echo ""
	
	# EFI partition
	echo "n"	# new partition
	echo "p"	# primary
	echo ""		# partition number - default
	echo ""		# first sector - default
	echo "+$efiSize"
	echo "t"	# change partition type
	echo "EF"
	
	# swap partition
	echo "n"	# new partition
	echo "p"	# primary
	echo ""		# partition number - default
	echo ""		# first sector - default
	echo "+$swapSize"
	echo "t"	# change partition type
	echo ""		# partition - default
	echo "82"	# swap partition
	
	# linux partition
	echo "n"	# new partition
	echo "p"	# primary
	echo ""		# partition number - default
	echo ""		# first sector - default
	echo ""		# last sector - default
	echo "w"	# write
	) | fdisk $drive
fi

read -srn1 -p "Press any key to continue";echo
clear

# step 3 - formatting the partitions
echo -e "\nPartition tables list:"
fdisk -l  

echo -e "\nDo you want to format the EFI partition? [y/n]"
read choice
choice=${choice:-y}
if [[ $choice == 'y' ]] || [[ $choice == 'Y' ]]
then
	echo "Enter the EFI partition:"
	read efiPartition
fi

echo "Enter the SWAP partition:"
read swapPartition

echo "Enter the linux partition:"
read linuxPartition

echo -e "\nFormatting the partitions"

# unmounting just in case we ran the script before
# umount -R /mnt
# swapoff $swapPartition

# format the efi partition
if [[ $efiPartition ]]
then
	mkfs.fat -F 32 $efiPartition
fi

# format the linux partition
mkfs.ext4 $linuxPartition

# initialize the swap partition
mkswap $swapPartition

read -srn1 -p "Press any key to continue";echo
clear

# step 4 - mount the file systems
echo "Mounting the file systems"

# mounting the linux partition
mount $linuxPartition /mnt

# enabling the swap volume
swapon $swapPartition

# mounting the EFI system partition
if [[ $efiPartition ]]
then
	mkdir /mnt/boot
	mount $efiPartition /mnt/boot
fi

read -srn1 -p "Press any key to continue";echo
clear

# step 5 - installation

# in case there are problem importing GPG keys we might need to change
# "SigLevel = Never" inside pacman.conf to workaround it
echo -e "\nDo you need to edit pacman.conf in the new system? [y/n]"
read choice
choice=${choice:-n}
if [[ $choice == 'y' ]] || [[ $choice == 'Y' ]]
then
	pacstrap /mnt base linux linux-firmware vim
else
	pacstrap /mnt base linux linux-firmware
fi

read -srn1 -p "Press any key to continue";echo
clear

# step 6 - configuring the system
echo "Configuring the system"
# generating the fstab file
genfstab -U /mnt >> /mnt/etc/fstab

echo -e "\nChanging to root"

# create a script in /mnt for the next step
cat <<EOF > /mnt/installer_chroot.sh 
#!/bin/bash

set -e

clear
echo -e "\nDo you need to edit pacman.conf? [y/n]"
read choice
choice=\${choice:-n}
if [[ \$choice == 'y' ]] || [[ \$choice == 'Y' ]]
then
	vim /etc/pacman.conf
fi
echo "Setting the time zone"
ln -sf /usr/share/zoneinfo/Asia/Tel_Aviv /etc/localtime
hwclock --systohc

# instead of commenting the line just add it at the end - locale.gen
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen

# creating locale.conf file
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "LANGUAGE=en_US" >> /etc/locale.conf

# creating the vconsole.conf file
echo "KEYMAP=il-heb" > /etc/vconsole.conf

echo "Enter the hostname:"
read hostname
echo "\$hostname" > /etc/hostname

# creating hosts file
echo "127.0.0.1	localhost" >> /etc/hosts
echo "::1	localhost" >> /etc/hosts
echo "127.0.0.1	\$hostname" >> /etc/hosts

mkinitcpio -P
echo "Set root's password:"
passwd

read -srn1 -p "Press any key to continue";echo
clear

# step 7 - configuring the boot loader
# os-prober to detect other OS
# efibootmgrto write boot entries to NVRAM
pacman --noconfirm -S grub efibootmgr os-prober
if [[ -z \$efiPartition ]]
then
	echo "Enter the EFI partition:"
	read efiPartition
fi
mkdir /boot/efi
mount \$efiPartition /boot/efi
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg


pacman -S --noconfirm dhcpcd networkmanager sudo git zsh

echo -e "\nEnter username:"
read username

# adding a new user
useradd \$username -m -G wheel -s /bin/zsh
passwd \$username
# adding the user to sudoeres file
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# enable internet service
systemctl enable NetworkManager.service

# create a script in the user\'s home directory for the next step
cat <<EEOF > /home/\$username/install_dots.sh
#!/bin/bash

set -e

# enable aliases in script
shopt -s expand_aliases

# step 7 install dotfiles and user configurations, etc...
clear
cd \\\$HOME
# clone dotfiles from github and create an alias
git clone --bare https://github.com/ItaiShek/.dotfiles.git \\\$HOME/.dotfiles
alias dots='/usr/bin/git --git-dir=\\\$HOME/.dotfiles/ --work-tree=\\\$HOME'

# restore workng tree files (move the dotfiles to their correct location)
dots checkout -f

# change bash_profile name temporarily to avoid issues with password
mv -f \\\$HOME/.bash_profile \\\$HOME/.bash_profile_tmp
mv -f \\\$HOME/.zshrc \\\$HOME/.zshrc_tmp

# install packages, user settings, etc...
\\\$HOME/.dotfiles/dotfiles.sh -i

mv -f \\\$HOME/.bash_profile_tmp \\\$HOME/.bash_profile 
mv -f \\\$HOME/.zshrc_tmp \\\$HOME/.zshrc
dots config --local status.showUntrackedFiles no

# enable sddm service
sudo systemctl enable sddm.service

exit
EEOF

# change file permissions
chmod +x /home/\$username/install_dots.sh
# run the next step as the new user
runuser -u \$username /home/\$username/install_dots.sh

exit
EOF

# run the script
chmod +x /mnt/installer_chroot.sh
arch-chroot /mnt ./installer_chroot.sh


umount -R /mnt
echo -e "\nReboot and continue with dotfiles"
read -srn1 -p "Press any key to reboot";echo
reboot
