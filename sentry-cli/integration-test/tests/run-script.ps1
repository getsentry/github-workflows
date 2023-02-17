param(
    [Parameter(Mandatory = $true)][string] $ServerUri
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version latest

if ("$ServerUri" -ne "http://127.0.0.1:8000")
{
    throw "Invalid server URI given to this script"
}

"This is the client output"