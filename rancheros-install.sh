#!/bin/sh

################################################
#
# For now it's only for debian based systems
# 
################################################

set -e
set -u

parted_remove_partition() {
  for PARTITION in $(parted -sm ${RANCHER_DEV} print|grep -oE '^[0-9]+:')
  do
    parted -sm ${RANCHER_DEV} rm ${PARTITION} > /dev/null
  done
}
    
parted_create_partition() {
  local DISKSIZE=$(parted -s /dev/vdb print|awk '/^Disk/ {print $3}'|sed 's/[Mm][Bb]//')
  parted -sm /dev/vdb mkpart primary 0 ${DISKSIZE}
}

# Workaround for older wget versions
wget_download() {
  wget -q $1 \
  || wget -q --no-check-certificate $1
}


# Globals
DEBIAN_FRONTEND=noninteractive
RANCHEROS_VERSION=${RANCHEROS_VERSION:-"v0.4.5"}
RANCHER_ENV="generic"

RANCHER_DEV="${1}"


cat > /etc/apt/sources.list << _EOF_
deb http://archive.debian.org/debian squeeze main
deb http://archive.debian.org/debian squeeze-lts main
_EOF_
echo "Acquire::Check-Valid-Until false;" > /etc/apt/apt.conf
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 8B48AD6246925553
apt-get update && apt-get install -y grub2 parted ca-certificates


parted_remove_partition
parted_create_partition

MYDIR=$(mktemp -p /tmp/ -d XXXXXX)
cd ${MYDIR}

wget_download https://releases.rancher.com/os/latest/initrd
wget_download https://releases.rancher.com/os/latest/vmlinuz

