# Silicon LogiX / SLX EchoBench
# Copyright (c) 2026 Marco Pezzullo (Silicon LogiX).
# License: Silicon LogiX Evaluation License 1.0. See LICENSE.
param([Parameter(Mandatory=$true)][string]$Godot)
$ErrorActionPreference='Stop'
$projectRoot=Split-Path -Parent $PSScriptRoot
New-Item -ItemType Directory -Force -Path "$projectRoot/build" | Out-Null
& $Godot --headless --editor --path "$projectRoot/godot" --import
if($LASTEXITCODE -ne 0){throw 'Godot import failed'}
& $Godot --headless --path "$projectRoot/godot" --export-pack 'Windows Desktop' "$projectRoot/build/EchoBench.pck"
if($LASTEXITCODE -ne 0){throw 'Interface export failed'}
