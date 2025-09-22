#!/usr/bin/env pwsh

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$OldVersion,

    [Parameter(Mandatory=$true, Position=1)]
    [string]$NewVersion
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

Write-Host "Preparing release version update from $OldVersion to $NewVersion"

# Note: Workflow files cannot be updated automatically during Craft releases
# because GitHub Apps don't have 'workflows' permission by default.
#
# After this release is published, manually update the following files:
# - .github/workflows/updater.yml (line ~45)
# - .github/workflows/danger.yml (line ~9)
#
# Change the default value from '$OldVersion' to '$NewVersion'

Write-Host ""
Write-Host "⚠️  MANUAL ACTION REQUIRED AFTER RELEASE:"
Write-Host "Update _workflow_version defaults in workflow files from '$OldVersion' to '$NewVersion'"
Write-Host ""
Write-Host "Release preparation completed successfully!"
