#!/usr/bin/env pwsh

# Copyright (c) 2023 Matheus Castello
# SPDX-License-Identifier: MIT

param(
    [Parameter(
        Mandatory=$false,
        HelpMessage="Flag to push the build to Dockerhub or just test if it is building locally"
    )]
    [string]$PushToDockerhub = "false",
    [Parameter(
        ValueFromRemainingArguments=$true,
        Mandatory=$true,
        HelpMessage="List of image names (folders) that should have the image built"
    )]
    [string[]]$ImageNames
)

if ($PushToDockerhub -ne "true" -and $PushToDockerhub -ne "false") {
    Write-Error "Invalid value for PushToDockerhub. It should be 'true' or 'false'"
    exit 69
} else {
    $_PushToDockerhub = $PushToDockerhub -eq "true"
}

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', "Internal PS variable"
)]

$PSNativeCommandUseErrorActionPreference = $true
$ErrorActionPreference = "Stop"

# get the actual script path without the file
$SCRIPT_PATH = Split-Path -Parent $MyInvocation.MyCommand.Definition

foreach ($_path in $ImageNames) {
    # read metadata
    $metadata = Get-Content -Path `
        (Join-Path $_path args.json) `
            | ConvertFrom-Json

    if ($metadata.multiarch -eq $true) {
        . (Join-Path $SCRIPT_PATH ./build-multiarch.ps1) -ContainerFileFolder $_path -PushToDockerhub $_PushToDockerhub
    } else {
        . (Join-Path $SCRIPT_PATH ./build.ps1) -ContainerFileFolder $_path -PushToDockerhub $_PushToDockerhub
    }
}
