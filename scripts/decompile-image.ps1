# Copyright (c) 2023 Matheus Castello
# SPDX-License-Identifier: MIT

param(
    [Parameter(Mandatory=$true)]
    [string]$IMAGE
)

# we need to have the image locally
docker pull $IMAGE

## https://hub.docker.com/r/alpine/dfimage
# run the container with the docker socket mounted
docker run -v /var/run/docker.sock:/var/run/docker.sock `
    --rm -it alpine/dfimage $IMAGE
