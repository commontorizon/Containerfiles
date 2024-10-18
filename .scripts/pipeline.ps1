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
        Mandatory=$false,
        HelpMessage="Flag to set if the build should or not use cache"
    )]
    [string]$NoCache = "false",
    [Parameter(
        Position=0,
        ValueFromRemainingArguments=$true
    )]
    [string[]]$ImageNames
)

if ($PushToDockerhub -ne "true" -and $PushToDockerhub -ne "false") {
    Write-Error "Invalid value for PushToDockerhub :: {$PushToDockerhub}. It should be 'true' or 'false'"
    exit 69
} else {
    $_PushToDockerhub = $PushToDockerhub -eq "true"
}

if ($NoCache -ne "true" -and $NoCache -ne "false") {
    Write-Warning "Invalid value for NoCache. It should be 'true' or 'false'"
    Write-Warning "Using default value 'false'"
    $_NoCache = $false
} else {
    $_NoCache = $NoCache -eq "true"
}


[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', "Internal PS variable"
)]

$PSNativeCommandUseErrorActionPreference = $true
$ErrorActionPreference = "Stop"

# get the actual script path without the file
$SCRIPT_PATH = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ImageNames = @($ImageNames)

# show to the user the order of the images that will be built
Write-Host -ForegroundColor Blue "Images to be built:"
foreach ($_path in $ImageNames) {
    Write-Host -ForegroundColor Blue "`t$_path"
}
Write-Host ""

foreach ($_path in $ImageNames) {
    Write-Host -ForegroundColor Blue "Sending $((Join-Path $SCRIPT_PATH ../ $_path args.json)) to build"
    Write-Host ""

    # read metadata
    $metadata = Get-Content -Path `
        (Join-Path $SCRIPT_PATH ../ $_path args.json) `
            | ConvertFrom-Json

    Set-Location (Join-Path  $SCRIPT_PATH ../)

    if ($metadata.multiarch -eq $true) {
        . (Join-Path $SCRIPT_PATH ./build-multiarch.ps1) -ContainerFileFolder $_path -PushToDockerhub $_PushToDockerhub -NoCache $_NoCache
    } else {
        . (Join-Path $SCRIPT_PATH ./build.ps1) -ContainerFileFolder $_path -PushToDockerhub $_PushToDockerhub -NoCache $_NoCache
    }
}
