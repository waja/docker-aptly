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
# OS_RELEASE=bionic
# DISTS=( ${OS_RELEASE} ${OS_RELEASE}-updates ${OS_RELEASE}-security )
# COMPONENTS=( main universe )

# The variables (as set below) will create a mirror of the Debian Jessie repo
# with the main and update components. If you do mirror these, you'll want to
# include "deb http://security.debian.org jessie/updates main" in your sources.list
# file or mirror it similarly as done below to keep up with security updates.

# UPSTREAM_URL="http://deb.debian.org/debian/"
# OS_RELEASE=jessie
# DISTS=( ${OS_RELEASE} ${OS_RELEASE}-updates )
# COMPONENTS=( main )

# The variables (as set below) will create a mirror of the default Raspbian Buster
# repo (that is used in Raspbian images).

UPSTREAM_URL="http://raspbian.raspberrypi.org/raspbian/"
OS_RELEASE=buster
DISTS=( ${OS_RELEASE} )
COMPONENTS=( main contrib non-free rpi )

# Create repository mirrors if they don't exist
set +e
for component in ${COMPONENTS[@]}; do
  for dist in ${DISTS[@]}; do
    aptly mirror list -raw | grep "^${dist}-${component}$"
    if [[ $? -ne 0 ]]; then
      echo "Creating mirror of ${dist}-${component} repository."
      aptly mirror create \
        -architectures=amd64 ${dist}-${component} ${UPSTREAM_URL} ${dist} ${component}
    fi
  done
done
set -e

# Update all repository mirrors
for component in ${COMPONENTS[@]}; do
  for dist in ${DISTS[@]}; do
    echo "Updating ${dist}-${component} repository mirror.."
    aptly mirror update ${dist}-${component}
  done
done

# Create snapshots of updated repositories
for component in ${COMPONENTS[@]}; do
  for dist in ${DISTS[@]}; do
    echo "Creating snapshot of ${dist}-${component} repository mirror.."
    SNAPSHOTARRAY+="${dist}-${component}-`date +%Y%m%d%H` "
    aptly snapshot create ${dist}-${component}-`date +%Y%m%d%H` from mirror ${dist}-${component}
  done
done

echo ${SNAPSHOTARRAY[@]}

# Merge snapshots into a single snapshot with updates applied
echo "Merging snapshots into one.."
aptly snapshot merge -latest                 \
  ${OS_RELEASE}-merged-`date +%Y%m%d%H`  \
  ${SNAPSHOTARRAY[@]}

# Publish the latest merged snapshot
set +e
aptly publish list -raw | awk '{print $2}' | grep "^${OS_RELEASE}$"
if [[ $? -eq 0 ]]; then
  aptly publish switch            \
    -passphrase="${GPG_PASSPHRASE}" \
    ${OS_RELEASE} ${OS_RELEASE}-merged-`date +%Y%m%d%H`
else
  aptly publish snapshot \
    -passphrase="${GPG_PASSPHRASE}" \
    -distribution=${OS_RELEASE} ${OS_RELEASE}-merged-`date +%Y%m%d%H`
fi
set -e

# Export the GPG Public key
if [[ ! -f /opt/aptly/public/aptly_repo_signing.key ]]; then
  gpg --export --armor > /opt/aptly/public/aptly_repo_signing.key
fi

# Generate Aptly Graph
aptly graph -output /opt/aptly/public/aptly_graph.png
