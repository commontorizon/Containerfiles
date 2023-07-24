# Copyright (c) 2023 Matheus Castello
# SPDX-License-Identifier: MIT
param(

)

$IMAGE = $args[0]

$_json = curl -s `
            "https://hub.docker.com/v2/repositories/${IMAGE}/tags/" | ConvertFrom-Json

# get for each results the name and the platform
$_json.results | `
    ForEach-Object {
        $name = $_.name
        $platform = $_.images | `
            ForEach-Object {
                $_.os + "/" + $_.architecture
            }
        [PSCustomObject]@{
            name = $name
            platform = $platform
        }
    } | `
    ConvertTo-Json | jq
