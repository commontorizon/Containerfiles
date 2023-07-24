# Copyright (c) 2023 Matheus Castello
# SPDX-License-Identifier: MIT

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', "Internal PS variable"
)]
$PSNativeCommandUseErrorActionPreference = $true
$ErrorActionPreference = "Stop"

function Env {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$true)]
        [string]$Default
    )

    # check if the environment variable exists
    if (Test-Path env:$Name) {
        # return the value of the environment variable
        return (Get-Item env:$Name).Value
    } else {
        # return default
        return $Default
    }
}

function Binfmt {
    # firts of all we need to run torizon/binfmt
    # to enable qemu for arm64 and arm32
    docker run --rm --privileged torizon/binfmt
}

function BuildxMultiArchSetup {
    docker buildx create --name multiarch --driver docker-container --use
}
