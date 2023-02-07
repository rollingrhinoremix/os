#!/bin/bash

set -e

# check for root permissions
(( EUID )) && {

    echo "E: Requires root permissions" >&2

    exit 1
}

# get config
if [[ -n "$1" ]]; then
  CONFIG_FILE="$1"
else
  CONFIG_FILE="etc/terraform.conf"
fi
BASE_DIR="${PWD}"
source "${BASE_DIR}"/"${CONFIG_FILE}"

echo -e "
#----------------------#
# INSTALL DEPENDENCIES #
#----------------------#
"

apt-get update
apt-get install -y patch gnupg2 binutils zstd ubuntu-keyring apt-utils
ln -sfn /usr/share/debootstrap/scripts/gutsy /usr/share/debootstrap/scripts/devel

build () {
  BUILD_ARCH="$1"

  mkdir -p "${BASE_DIR}/tmp/${BUILD_ARCH}"
  cd "${BASE_DIR}/tmp/${BUILD_ARCH}" || exit

  # remove old configs and copy over new
  rm -rf config auto
  cp -r "${BASE_DIR}"/etc/* .
  # Make sure conffile specified as arg has correct name
  cp -f "${BASE_DIR}"/"${CONFIG_FILE}" terraform.conf

  # Symlink chosen package lists to where live-build will find them
  ln -s "package-lists.${PACKAGE_LISTS_SUFFIX}" "config/package-lists"

  echo -e "
#------------------#
# LIVE-BUILD CLEAN #
#------------------#
"
  lb clean

  echo -e "
#-------------------#
# LIVE-BUILD CONFIG #
#-------------------#
"
  lb config

  echo -e "
#------------------#
# LIVE-BUILD BUILD #
#------------------#
"
  lb --force build

  echo -e "
#---------------------------#
# MOVE OUTPUT TO BUILDS DIR #
#---------------------------#
"

  OUTPUT_DIR="${BASE_DIR}/builds/${BUILD_ARCH}"
  mkdir -p "${OUTPUT_DIR}"
  FNAME="Rolling-Linux-OS-${VERSION}${OUTPUT_SUFFIX}"
  mv "${BASE_DIR}/tmp/${BUILD_ARCH}/live-image-${BUILD_ARCH}.hybrid.iso" "${OUTPUT_DIR}/${FNAME}.iso"

  # cd into output to so {FNAME}.sha256.txt only
  # includes the filename and not the path to
  # our file.
  cd ${OUTPUT_DIR}
  sha512sum "${FNAME}.iso" > "${FNAME}.sha512"
  sha256sum "${FNAME}.iso" > "${FNAME}.sha256"
  cd ${BASE_DIR}
}

if [[ "${ARCH}" == "all" ]]; then
    build amd64
else
    build "${ARCH}"
fi
