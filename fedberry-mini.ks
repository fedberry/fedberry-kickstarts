###
# RELEASE = 2
###


###
# Repositories
###

%include fedberry-repos.ks


###
# Kickstart Options
###

# System language
lang en_US.UTF-8
keyboard us
timezone US/Eastern

# Firewall configuration
firewall --disabled

# System authorization information
auth --useshadow --enablemd5
rootpw fedberry

#user --name=raspberry --password=$1$wxMhW7mr$YCUqK.ZGyNsfwY5V5Aib31 --iscrypted
# Seems this is also broken at present, need to add a user manually in %post :-(

# SELinux configuration
selinux --disabled

# Installation logging level
logging --level=info

# System services
services --disabled="network" --enabled="ssh,NetworkManager,chronyd"

# System bootloader configuration
bootloader --location=boot
# Need to create logical volume groups first then partition
part /boot --fstype="vfat" --size 128 --label="BOOT" --asprimary
part / --fstype="ext4" --size 1664 --grow --label="rootfs" --asprimary
# Note: the --fsoptions & --fsprofile switches dont seem to work at all!
#  <SIGH> Will have to edit fstab in %post :-(



###
# Packages
###

%packages --instLangs=en_US.utf8 --excludedocs
@core
generic-release
kernel
# DNF has 'issues' with time travel!
chrony

# Raspberry Pi2 specific packages
python-rpi-gpio
raspberrypi-local
raspberrypi-vc-utils
raspberrypi-vc-libs
raspberrypi-repo

# Packages to Remove
-fedora-release
-fedora-release-notes
-uboot-tools
-gsettings-desktop-schemas
-selinux-policy
-selinux-policy-targeted
-plymouth*
%end



###
# Post-installation Scripts
###

### RPM & dnf related tweaking
%post
# Work around for poor key import UI in PackageKit
rm -f /var/lib/rpm/__db*
releasever=$(cat /etc/os-release |grep VERSION_ID |sed 's/VERSION_ID=//')
basearch=armhfp
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-fedora-$releasever-$basearch
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-rpi2

# Note that running rpm recreates the rpm db files which aren't needed or wanted
rm -f /var/lib/rpm/__db*

# Don't need this!
dnf -y remove dracut-config-rescue

# Use only en_US language for rpms
echo %_install_langs en_US.utf8 >> /etc/rpm/macros

# Disable delta rpms as many of them don't install correctly as
# we save space by excluding docs & only install the en_US.utf8 language)
echo "deltarpm=0" >>/etc/dnf/dnf.conf
%end


### Create 'raspberry' user manually, as kickstart 'user' function seems to be broken!
%post
echo "Creating user 'raspberry'"
/sbin/useradd -m -p $(openssl passwd -1 raspberry) raspberry

# Expire the current password, & force new password on first login
passwd -e raspberry
%end


### Disallow root logins via sshd (we need at least some resemblance of sceurity!)
%post
echo "Disabling root logins for sshd"
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
%end


### Having /tmp on tmpfs is enabled as this helps extend lifespan of sd cards
# However, size should be limited to 100M.
# This may cause issues for programs making heavy use of /tmp
%post
echo "Setting size limit of 100M for tmpfs for /tmp."
echo "tmpfs /tmp tmpfs    defaults,noatime,size=100m 0 0" >>/etc/fstab
%end


#### Setup systemd to boot to the right runlevel
%post
echo "Setting default runlevel to multiuser text mode"
rm -f /etc/systemd/system/default.target
ln -s /lib/systemd/system/multi-user.target /etc/systemd/system/default.target
%end


#### Give the remix a better name than 'generic'
# This is hacky! Need to make my own fedberry-release rpm
%post
echo "Modifying release information"
sed -i -e 's/Generic release/RPi2 Fedora Remix/g' /etc/fedora-release /etc/issue /etc/issue.net
sed -i -e 's/(Generic)/(Twenty Three)/g' /etc/fedora-release /etc/issue /etc/issue.net
sed -i 's/NAME=Generic/NAME="RPi2 Fedora Remix"/g' /etc/os-release
sed -i 's/ID=generic/ID=FedBerry/g' /etc/os-release
sed -i 's/(Generic)/(Twenty Three)/g' /etc/os-release
sed -i '/ID=FedBerry/a ID_LIKE="rhel fedora"' /etc/os-release
sed -i 's/Generic 23/RPi2 Fedora Remix 23/g' /etc/os-release
%end


#### Need to ensure have our custom rpi2 kernel & firmware NOT the fedora kernel & firmware
%post
sed -i '/skip_if_unavailable=False/a exclude=kernel* bcm283x-firmware' /etc/yum.repos.d/fedora-updates.repo
%end


### Tweak boot options
%post
echo "Modifying cmdline.txt boot options"
sed -i 's/nortc/elevator=deadline nortc libahci.ignore_sss=1 raid=noautodetect selinux=0/g' /boot/cmdline.txt

# With no swap for 'mini' release we need to change our root partition
sed -i 's|root=/dev/mmcblk0p3|root=/dev/mmcblk0p2|g' /boot/cmdline.txt
%end


### Edit fstab options manually
%post
echo "Modifying fstab options"
sed -i 's/ext4.*defaults/ext4    defaults,data=writeback/' /etc/fstab
%end


### Keep systemd's journal size under control
%post
echo "Setting systemd max journal size to 20M"
sed -i 's/#SystemMaxUse=/SystemMaxUse=20/' /etc/systemd/journald.conf
%end


### Need some more agressive space saving cleanups for 'mini' builds
%post
echo "Removing firewalld service"
dnf -C -y autoremove firewalld

echo "Removing linux-firmware"
# Note: At some point firmware will get pulled back in when the kernel is updated.
rpm -e --nodeps linux-firmware

echo "cleaning yumdb"
rm -rf /var/lib/yum/yumdb/*

echo "Cleaning up pre-compiled python files"
find /usr/ | grep -E "(__pycache__|\.pyc|\.pyo$)" | xargs rm -rf

echo "Zeroing out empty space."
# This forces the filesystem to reclaim space from deleted files
dd bs=1M if=/dev/zero of=/var/tmp/zeros || :
rm -f /var/tmp/zeros
%end