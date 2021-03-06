###
# Repositories
###

%include fedberry-repos.ks


###
# Kickstart Options
###

# System language
lang en_US.UTF-8

# Firewall configuration
firewall --enabled --service=mdns,ssh

# System authorization information
auth --useshadow --passalgo=sha512

# Disable bootloader
bootloader --location=none --disabled

# Run the Setup Agent on first boot
firstboot --reconfig

# SELinux configuration
selinux --enforcing

# Set root password
rootpw fedberry

# System services
services --disabled="lvm2-monitor,dmraid-activation" --enabled="rootfs-grow,initial-setup,headless-check,saveclock"

# Define how large you want your rootfs to be
# NOTE: /boot and swap MUST use --asprimary to ensure '/' is the last partition in order for rootfs-resize to work.
# Need to create logical volume groups first then partition
part /boot --fstype="vfat" --size 512 --label=BOOT --asprimary
part / --fstype="ext4" --size 1664 --grow --fsoptions="noatime" --label=rootfs --asprimary



###
# Packages
###

### Fedberry packages
%include fedberry-pkgs.ks

%packages
@core
@hardware-support
authconfig
bash-completion
crda
dracut-config-generic
fedberry-headless
GeoIP
glibc-langpack-en
hardlink
nfs-utils
plymouth-theme-charge
policycoreutils
timedatex

### Remove packages
-@dial-up
-geolite2-*
-@standard
-initial-setup-gui
-trousers
%end



###
# Post-installation Scripts
###

### Setup systemd to boot to the right runlevel
%post
echo "Setting default runlevel to multiuser text mode"
rm -f /etc/systemd/system/default.target
ln -s /lib/systemd/system/multi-user.target /etc/systemd/system/default.target
%end


### Set colour depth to 16bit
%post
echo "Setting default colour depth to 16bit"
sed -i '/### Display Options/i framebuffer_depth=16\n' /boot/config.txt
%end


### Expire the current root password (forces new password on first login)
%post
passwd -e root
%end


%include fedberry-post.ks
