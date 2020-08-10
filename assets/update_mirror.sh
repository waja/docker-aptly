#! /usr/bin/env bash
set -e

# Automate the initial creation and update of a mirror in aptly.
# Uncomment a prepared section or use your own.

# For any section you select, you need to install repo signing public
# key, if you wanna take it from your system you can look for in:
# /usr/share/keyrings/ (like /usr/share/keyrings/ubuntu-archive-keyring.gpg) or you can take it from apt-key (apt-key help / list / export).
# Export the key to the pubring in GPG utility (ususaly /root/.gnupg/pubring.gpg). You can use prepared script /opt/keys_imp.sh for it.

# The variables (as set below) will create a mirror of the Ubuntu Trusty repo
# with the main & universe components, you can add other components like restricted
# multiverse etc by adding to the array (separated by spaces).

# For more detail about each of the variables below refer to:
# https://help.ubuntu.com/community/Repositories/CommandLine

# UPSTREAM_URL="http://archive.ubuntu.com/ubuntu/"
# REPO=ubuntu
# OS_RELEASE=bionic
# DISTS=( ${OS_RELEASE} ${OS_RELEASE}-updates ${OS_RELEASE}-security )
# COMPONENTS=( main universe )
# ARCH=amd64

# The variables (as set below) will create a mirror of the Debian Jessie repo
# with the main and update components. If you do mirror these, you'll want to
# include "deb http://security.debian.org jessie/updates main" in your sources.list
# file or mirror it similarly as done below to keep up with security updates.

# UPSTREAM_URL="http://deb.debian.org/debian/"
# REPO=debian
# OS_RELEASE=jessie
# DISTS=( ${OS_RELEASE} ${OS_RELEASE}-updates )
# COMPONENTS=( main )
# ARCH=amd64

# The variables (as set below) will create a mirror of the default Raspbian Buster
# repo (that is used in Raspbian images).

UPSTREAM_URL="http://raspbian.raspberrypi.org/raspbian/"
REPO=raspbian
DISTS=( buster )
COMPONENTS=( main contrib non-free rpi )
ARCH=armhf

# Create the mirror repository, if it doesn't exist
set +e
for component in ${COMPONENTS[@]}; do
  for dist in ${DISTS[@]}; do
    aptly mirror list -raw | grep "^${REPO}$"
    if [[ $? -ne 0 ]]; then
      echo "Creating mirror of ${REPO} repository."
      aptly mirror create \
        -architectures=${ARCH} ${REPO} ${UPSTREAM_URL} ${dist} ${component}
    fi
  done
done
set -e

# Update the all repository mirrors
for component in ${COMPONENTS[@]}; do
  for dist in ${DISTS[@]}; do
    echo "Updating ${REPO} repository mirror.."
    aptly mirror update ${REPO}
  done
done

# Create snapshots of updated repositories
for component in ${COMPONENTS[@]}; do
  for dist in ${DISTS[@]}; do
    echo "Creating snapshot of ${REPO} repository mirror.."
    SNAPSHOTARRAY+="${REPO}-`date +%Y%m%d%H%M` "
    aptly snapshot create ${REPO}-`date +%Y%m%d%H%M` from mirror ${REPO}
  done
done

echo ${SNAPSHOTARRAY[@]}

# Merge snapshots into a single snapshot with updates applied
REPO_MERGED=${REPO}-merged-`date +%Y%m%d%H%M`
echo "Merging snapshots into one.."
aptly snapshot merge -latest \
  ${REPO_MERGED} ${SNAPSHOTARRAY[@]}

echo "Enter GPG passphrase"
read GPG_PASSPHRASE

# Publish the latest merged snapshot
set +e
aptly publish list -raw | awk '{print $2}' | grep "^${REPO}$"
if [[ $? -eq 0 ]]; then
  aptly publish switch \
    -passphrase="${GPG_PASSPHRASE}" \
    ${REPO} ${REPO_MERGED}
else
  aptly publish snapshot \
    -passphrase="${GPG_PASSPHRASE}" \
    -distribution=${REPO_MERGED}
fi
set -e

# Export the all GPG Public keys
if [[ ! -f /opt/aptly/public/repo_signing.key ]]; then
  gpg --export --armor > /opt/aptly/public/repo_signing.key
fi

# Generate Aptly Graph
aptly graph -output /opt/aptly/public/aptly_graph.png
