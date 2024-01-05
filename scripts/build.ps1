# Copyright (c) 2023 Matheus Castello
# SPDX-License-Identifier: MIT
param(
    [Parameter(Mandatory=$true)]
    [string]$ContainerFileFolder,
    [Parameter(Mandatory=$false)]
    [bool]$NoCache = $false
)

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', "Internal PS variable"
)]
$PSNativeCommandUseErrorActionPreference = $true
$ErrorActionPreference = "Stop"

# get the actual script path without the file
$SCRIPT_PATH = Split-Path -Parent $MyInvocation.MyCommand.Definition

# includes
. (Join-Path $SCRIPT_PATH ./env.ps1)
. (Join-Path $SCRIPT_PATH ./sec.ps1)

function _checkEnvVariable {
    param(
        [Parameter(Mandatory=$true)]
        [string]$name
    )

    $_env = [Environment]::GetEnvironmentVariable(
        $name
    )

    if (
        $null -eq $_env -or
        $_env -eq ""
    ) {
        Write-Host -ForegroundColor Red `
            "❌ $name MUST BE SET"
        exit 69
    }
}

Binfmt
DockerRegistryLogin

if (Test-Path $ContainerFileFolder) {
    # read metadata
    $metadata = Get-Content -Path `
        (Join-Path $ContainerFileFolder args.json) `
            | ConvertFrom-Json

    # check if this is the right script to build it
    if ($metadata.multiarch -eq $true) {
        Write-Host -ForegroundColor Red `
            "This is not buildable with this script, please use ./scripts/build-multiarch.ps1"
        exit 69
    }

    try {
        Set-Location $ContainerFileFolder

        # common properties
        $env:IMAGE_VERSION = $metadata.version
        $env:IMAGE_REGISTRY = $metadata.registry
        $env:REGISTRY = $metadata.registry
        $env:IMAGE_PREFIX = $metadata.image_prefix

        foreach ($args in $metadata.machines) {
            # query $args properties and set them as env variables
            $args.PSObject.Properties | ForEach-Object {
                # the name should be uppercase
                [Environment]::SetEnvironmentVariable(
                    $_.Name.ToUpper(),
                    $_.Value
                )
            }

            # sanity check
            _checkEnvVariable "IMAGE_REGISTRY"
            _checkEnvVariable "IMAGE_PREFIX"
            _checkEnvVariable "NAME"
            _checkEnvVariable "IMAGE_VERSION"

            # set IMAGE_NAME and build it
            $env:IMAGE_NAME = "$($metadata.image_prefix)-$($args.name)"

            Write-Host -ForegroundColor Yellow `
                "Building:"
            Write-Host -ForegroundColor Yellow `
                "`tImage: $($env:IMAGE_REGISTRY)$($env:IMAGE_NAME)$($env:GPU):$($env:IMAGE_VERSION)"
            Write-Host -ForegroundColor Yellow `
                "`tArgs:"

            # query $env properties and set them as env variables
            $args.PSObject.Properties | ForEach-Object {
                # the name should be uppercase
                $_env = [Environment]::GetEnvironmentVariable(
                    $_.Name.ToUpper()
                )

                Write-Host -ForegroundColor Yellow `
                    "`t`t$($_.Name.ToUpper()): $($_env)"
            }

            if ($NoCache -eq $true) {
              docker compose build --no-cache
            } else {
              docker compose build
            }

            docker compose push
        }
    } catch {
        Set-Location -
    } finally {
        Set-Location -
    }
} else {
    Write-Host -ForegroundColor Red `
        "$ContainerFileFolder does not exists"
}
