param(
    [Parameter(Mandatory=$true)]
    [string]$ContainerFileFolder
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

Binfmt
DockerRegistryLogin

if (Test-Path $ContainerFileFolder) {
    # read metadata
    $metadata = Get-Content -Path `
        (Join-Path $ContainerFileFolder args.json) `
            | ConvertFrom-Json

    $env:IMAGE_VERSION = $metadata.version
    $env:IMAGE_REGISTRY = $metadata.registry
    $env:REGISTRY = $metadata.registry

    foreach ($args in $metadata.machines) {
        $env:BASE_REGISTRY = $args.BASE_REGISTRY
        $env:BASE_IMAGE = $args.BASE_IMAGE
        $env:BASE_VERSION = $args.BASE_VERSION
        $env:BASE_IMAGE2 = $args.BASE_IMAGE2
        $env:BASE_VERSION2 = $args.BASE_VERSION2
        $env:IMAGE_ARCH = $args.IMAGE_ARCH
        $env:GPU = $args.GPU

        # set IMAGE_NAME and build it
        $env:IMAGE_NAME = "$($metadata.image_prefix)-$($args.name)"

        Write-Host -ForegroundColor Yellow `
            "Building:"
        Write-Host -ForegroundColor Yellow `
            "`tImage: $($env:IMAGE_REGISTRY)$($env:IMAGE_NAME)$($env:GPU):$($env:IMAGE_VERSION)"
        Write-Host -ForegroundColor Yellow `
            "`tBASE_REGISTRY: $($env:BASE_REGISTRY)"
        Write-Host -ForegroundColor Yellow `
            "`tBASE_IMAGE: $($env:BASE_IMAGE)"
        Write-Host -ForegroundColor Yellow `
            "`tBASE_VERSION: $($env:BASE_VERSION)"
        Write-Host -ForegroundColor Yellow `
            "`tBASE_IMAGE2: $($env:BASE_IMAGE2)"
        Write-Host -ForegroundColor Yellow `
            "`tBASE_VERSION2: $($env:BASE_VERSION2)"
        Write-Host -ForegroundColor Yellow `
            "`tIMAGE_ARCH: $($env:IMAGE_ARCH)"
        Write-Host -ForegroundColor Yellow `
            "`tREGISTRY: $($env:REGISTRY)"
        Write-Host -ForegroundColor Yellow `
            "`tGPU: $($env:GPU)"

        docker compose -f $ContainerFileFolder/docker-compose.yml build
        docker compose -f $ContainerFileFolder/docker-compose.yml push
    }
} else {
    Write-Host -ForegroundColor Red `
        "$ContainerFileFolder does not exists"
}
