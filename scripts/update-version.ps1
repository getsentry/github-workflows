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

Write-Host "Updating version from $OldVersion to $NewVersion"

# Update specific workflow files with _workflow_version inputs
Write-Host "Updating workflow files..."
$workflowFiles = @(
    ".github/workflows/updater.yml",
    ".github/workflows/danger.yml"
)

foreach ($filePath in $workflowFiles) {
    $content = Get-Content -Path $filePath -Raw

    # Check if this file has _workflow_version input with a default value
    if ($content -match '(?ms)_workflow_version:.*?default:\s*([^\s#]+)') {
        Write-Host "Updating $filePath..."
        $oldDefault = $Matches[1]

        # Replace the default value for _workflow_version
        $newContent = $content -replace '((?ms)_workflow_version:.*?default:\s*)([^\s#]+)', "`${1}$NewVersion"

        # Write the updated content back to the file
        $newContent | Out-File -FilePath $filePath -Encoding utf8 -NoNewline

        Write-Host "  Updated default from '$oldDefault' to '$NewVersion'"
    } else {
        Write-Error "No _workflow_version default found in $filePath"
    }
}

Write-Host "Version update completed successfully!"
