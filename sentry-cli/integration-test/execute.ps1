# Executes the script at the given path after starting a dummy Sentry server that collects and logs requests.
# The script is given the server URL as a first argument.
param(
    [Parameter(Mandatory = $true)][string] $Script
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version latest

$ServerUri = "http://127.0.0.1:8000"
$ServerOutFile = "server-output.txt"
$ScriptOutFile = "script-output.txt"

Remove-Item -Path $ServerOutFile -ErrorAction SilentlyContinue
Remove-Item -Path $ScriptOutFile -ErrorAction SilentlyContinue

function RunApiServer([string] $ServerScript, [string] $Uri = $ServerUri)
{
    $result = "" | Select-Object -Property process, outFile, errFile, stop, output, dispose
    Write-Host "Starting the $ServerScript on $Uri"
    $result.outFile = New-TemporaryFile
    $result.errFile = New-TemporaryFile

    $result.process = Start-Process "python3" -ArgumentList @("$PSScriptRoot/$ServerScript.py", $Uri) `
        -NoNewWindow -PassThru -RedirectStandardOutput $result.outFile -RedirectStandardError $result.errFile

    $result.output = { "$(Get-Content $result.outFile -Raw)`n$(Get-Content $result.errFile -Raw)" }.GetNewClosure()

    $result.dispose = {
        $result.stop.Invoke()

        $stdout = Get-Content $result.outFile -Raw
        Write-Host "Server stdout:" -ForegroundColor Yellow
        Write-Host $stdout

        $stderr = Get-Content $result.errFile -Raw
        if ("$stderr".Trim().Length -gt 0)
        {
            Write-Host "Server stderr:" -ForegroundColor Yellow
            Write-Host $stderr
        }

        Remove-Item $result.outFile -ErrorAction Continue
        Remove-Item $result.errFile -ErrorAction Continue
        return "$stdout`n$stderr".Trim() -replace $Uri, "<ServerUri>" -replace "`r`n", "`n"
    }.GetNewClosure()

    $result.stop = {
        # Stop the HTTP server
        Write-Host "Stopping the $ServerScript ... " -NoNewline
        try
        {
            Write-Host (Invoke-WebRequest -Uri "$Uri/STOP").StatusDescription
        }
        catch
        {
            Write-Host "/STOP request failed: $_ - killing the server process instead"
            $result.process | Stop-Process -Force -ErrorAction SilentlyContinue
        }
        $result.process | Wait-Process -Timeout 10 -ErrorAction Continue
        $result.stop = {}
    }.GetNewClosure()

    # The process shouldn't finish by itself, if it did, there was an error, so let's check that
    Start-Sleep -Second 1
    if ($result.process.HasExited)
    {
        Write-Host "Couldn't start the $ServerScript" -ForegroundColor Red
        Write-Host "Standard Output:" -ForegroundColor Yellow
        Get-Content $result.outFile
        Write-Host "Standard Error:" -ForegroundColor Yellow
        Get-Content $result.errFile
        Remove-Item $result.outFile
        Remove-Item $result.errFile
        exit 1
    }

    return $result
}

function RunWithApiServer([ScriptBlock] $Callback)
{
    # start the server
    $httpServer = RunApiServer "sentry-server"
    # run the test
    try
    {
        $Callback.Invoke()
    }
    finally
    {
        $httpServer.stop.Invoke()
    }

    return $httpServer.dispose.Invoke()
}

if (Get-Command 'chmod' -ErrorAction SilentlyContinue)
{
    chmod +x $Script
}

$serverOutput = RunWithApiServer -Callback {
    try
    {
        $scriptOutput = & $Script $ServerUri
        $failed = -not $?
    }
    catch
    {
        $scriptOutput = $_
        $failed = $true
    }
    $scriptOutput | Out-File $ScriptOutFile -Encoding utf8 -NoNewline
    if ($failed)
    {
        throw "Script execution failed: $Script $ServerUri | output: $scriptOutput"
    }
    else
    {
        Write-Host "Script finished successfully" -ForegroundColor Green
    }
}

$serverOutput | Out-File $ServerOutFile -Encoding utf8 -NoNewline

Write-Host "Outputs written to '$ServerOutFile' and '$ScriptOutFile'" -ForegroundColor Green