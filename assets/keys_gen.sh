#! /usr/bin/env bash

# Copyright 2018-2020 Artem B. Smirnov
# Licensed under the Apache License, Version 2.0

# Use: keys_gen.sh <FULL_NAME> <EMAIL_ADDRESS> <GPG_PASSPHRASE>

[[ -z ${1} ]] && exit 1;
[[ -z ${2} ]] && exit 1;
[[ -z ${3} ]] && exit 1;

# https://stackoverflow.com/questions/4437573/bash-assign-default-value
: ${FULL_NAME:=${1}}
: ${EMAIL_ADDRESS:=${2}}
: ${GPG_PASSPHRASE:=${3}}

gen_batch() {
  cat << EOF > /opt/gpg_batch
%echo Generating a GPG key, might take a while
Key-Type: RSA
Key-Length: 4096
Subkey-Type: ELG-E
Subkey-Length: 1024
Name-Real: ${1}
Name-Comment: Aptly Repo Signing
Name-Email: ${2}
Expire-Date: 0
Passphrase: ${3}
%pubring /opt/aptly/gpg/pubring.gpg
%secring /opt/aptly/gpg/secring.gpg
%commit
%echo done
EOF
}

# If the repository GPG keypair doesn't exist, create it.
if [[ ! -f /opt/aptly/gpg/secring.gpg ]] || [[ ! -f /opt/aptly/gpg/pubring.gpg ]]; then
  echo "Generating the new GPG keypair"
  cp -a /dev/urandom /dev/random

  mkdir -p /opt/aptly/gpg

  # Generate the GPG config for generating the new keypair
  gen_batch ${FULL_NAME} ${EMAIL_ADDRESS} ${GPG_PASSPHRASE}

  # If your system doesn't have a lot of entropy this may, take a long time
  # Google how-to create "artificial" entropy, if this gets stuck
  gpg --gen-key --batch /opt/gpg_batch

  # Remove batch after generating the keypair
  rm /opt/gpg_batch
else
  echo "No need to generate the new GPG keypair"
fi

# If the repository public key doesn't exist, export it.
if [[ ! -d /opt/aptly/public ]] || [[ ! -f /opt/aptly/public/aptly_repo_signing.key ]]; then
  echo "Export the GPG public keys"
  mkdir -p /opt/aptly/public
  # Export only all public keys,
  # for export private keys use --export-secret-keys
  gpg --keyring /opt/aptly/gpg/pubring.gpg --export --armor > /opt/aptly/public/aptly_repo_signing.key
else
  echo "No need to export the GPG keys"
fi
