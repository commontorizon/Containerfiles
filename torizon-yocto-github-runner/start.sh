#!/bin/bash

RUNNER_VERSION="2.313.0"

REPO=$REPO
ACCESS_TOKEN=$ACCESS_TOKEN

getRegToken() {
    # Token here expires after 1 hour
    token=$(curl -s -L \
     -X POST \
     -H "Accept: application/vnd.github+json" \
     -H "Authorization: Bearer ${ACCESS_TOKEN}" \
     -H "X-GitHub-Api-Version: 2022-11-28" \
     "https://api.github.com/repos/${REPO}/actions/runners/registration-token" |
     jq -r .token)


    # If adding to an organization use the following endpoint instead:
    # https://api.github.com/orgs/${ORG}/actions/runners/registration-token

    echo ${token}
}

cleanup() {
    echo "Removing runner..."
    token=$(getRegToken)
    ./config.sh remove --token ${token}
}

# Dummy git suer configs
git config --global user.email "you@example.com"
git config --global user.name "Your Name"
git config --global color.ui  true

mkdir -p /workdir

# Install Runner
mkdir /home/pokyuser/actions-runner
cd /home/pokyuser/actions-runner
curl -s -O -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz
tar xzf ./actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz
chown -R pokyuser ~pokyuser

# Configure and start runner
token=$(getRegToken)
./config.sh --unattended --url https://github.com/${REPO} --token ${token} --labels yocto,x64,linux

trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

./run.sh & wait $!
