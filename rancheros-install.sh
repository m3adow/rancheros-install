#!/bin/sh
set -x
################################################
#
# For now only for debian based systems
# 
################################################

set -e
set -u

# Globals
DEBIAN_FRONTEND=noninteractive
RANCHEROS_VERSION=${RANCHEROS_VERSION:-"v0.4.5"}
RANCHER_ENV="${RANCHER_ENV:-generic}"

MYPWD="$(dirname $0)"
RANCHER_DEV="${1}"
CLOUD_CONFIG_URL="${2:-}"

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
  WGET_ARGS=${2:-}
  wget -q $WGET_ARGS $1 \
  || wget -q $WGET_ARGS --no-check-certificate $1
}

prepare_system() {
  cat > /etc/apt/sources.list << _EOF_
  deb http://archive.debian.org/debian squeeze main
  deb http://archive.debian.org/debian squeeze-lts main
_EOF_
  echo "Acquire::Check-Valid-Until false;" > /etc/apt/apt.conf
  apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 8B48AD6246925553
  apt-get update && apt-get install -y grub2 parted ca-certificates


  parted_remove_partition
  parted_create_partition

  wget_download "https://releases.rancher.com/os/latest/initrd" "-O ${MYPWD}/scripts/"
  wget_download "https://releases.rancher.com/os/latest/vmlinuz" "-O ${MYPWD}/scripts/"

  if [ -n "${CLOUD_CONFIG_URL}" ]
  then
    wget_download "${CLOUD_CONFIG_URL}" "-O ${MYPWD}/scripts/user_config.yml"
  fi
}


prepare_system
cd ${MYPWD}/scripts
if [ -n "${CLOUD_CONFIG_URL}" ]
then
  ${MYPWD}/scripts/lay-down-os -d ${RANCHER_DEV} -c ./user_config.yml -i "${MYPWD}" 
else
  ${MYPWD}/scripts/lay-down-os -d ${RANCHER_DEV} -i "${MYPWD}
fi
