#! /usr/bin/env bash
set -e

# Automate the initial creation and update of a mirror in aptly
# Uncomment a prepared section or use your own.

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

# The variables (as set below) will create a mirror of the Debian Jessie repo
# with the main and update components. If you do mirror these, you'll want to
# include "deb http://security.debian.org jessie/updates main" in your sources.list
# file or mirror it similarly as done below to keep up with security updates.

# UPSTREAM_URL="http://deb.debian.org/debian/"
# REPO=debian
# OS_RELEASE=jessie
# DISTS=( ${OS_RELEASE} ${OS_RELEASE}-updates )
# COMPONENTS=( main )

# The variables (as set below) will create a mirror of the default Raspbian Buster
# repo (that is used in Raspbian images).

UPSTREAM_URL="http://raspbian.raspberrypi.org/raspbian/"
REPO=raspbian
DISTS=( buster )
COMPONENTS=( main contrib non-free rpi )

# Create repository mirrors if they don't exist
set +e
for component in ${COMPONENTS[@]}; do
  for dist in ${DISTS[@]}; do
    aptly mirror list -raw | grep "^${REPO}$"
    if [[ $? -ne 0 ]]; then
      echo "Creating mirror of ${REPO} repository."
      aptly mirror create \
        -architectures=amd64 ${REPO} ${UPSTREAM_URL} ${dist} ${component}
    fi
  done
done
set -e

# Update all repository mirrors
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
echo "Merging snapshots into one.."
aptly snapshot merge -latest \
  ${REPO}-merged-`date +%Y%m%d%H%M` ${SNAPSHOTARRAY[@]}

# Publish the latest merged snapshot
set +e
aptly publish list -raw | awk '{print $2}' | grep "^${REPO}$"
if [[ $? -eq 0 ]]; then
  aptly publish switch \
    -passphrase="${GPG_PASSPHRASE}" \
    ${REPO} ${REPO}-merged-`date +%Y%m%d%H%M`
else
  aptly publish snapshot \
    -passphrase="${GPG_PASSPHRASE}" \
    -distribution=${REPO} ${REPO}-merged-`date +%Y%m%d%H%M`
fi
set -e

# Export the GPG Public key
if [[ ! -f /opt/aptly/public/aptly_repo_signing.key ]]; then
  gpg --export --armor > /opt/aptly/public/aptly_repo_signing.key
fi

# Generate Aptly Graph
aptly graph -output /opt/aptly/public/aptly_graph.png
