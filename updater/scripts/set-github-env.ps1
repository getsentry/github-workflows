param(
    [Parameter(Mandatory = $true)][string] $Name,
    [string] $Data = ''
)

Set-StrictMode -Version latest

if ($null -eq $env:GITHUB_ENV) {
    throw "GITHUB_ENV environment variable is missing - this script is supposed to be run in GitHub-Actions."
}

Write-Output "$Name<<EOF`n$Data`nEOF" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
