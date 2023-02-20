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
    Write-Host "Starting the $ServerScript on $Uri" -ForegroundColor DarkYellow
    $stopwatch = [system.diagnostics.stopwatch]::StartNew()

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

    $startupFailed = $false
    while ($true)
    {
        Start-Sleep -Milliseconds 100
        try
        {
            if ((Invoke-WebRequest -Uri "$Uri/_check" -SkipHttpErrorCheck -Method Head).StatusCode -eq 999)
            {
                Write-Host "Server started successfully in $($stopwatch.ElapsedMilliseconds) ms." -ForegroundColor Green
                break;
            }
        }
        catch
        {}
        if ($stopwatch.ElapsedMilliseconds -gt 10000)
        {
            Write-Warning "Server startup timed out."
            $startupFailed = $true;
            break;
        }
        else
        {
            Write-Host "Waiting for server to become available..."
        }
    }

    if ($result.process.HasExited -or $startupFailed)
    {
        Write-Host "Couldn't start the $ServerScript" -ForegroundColor Red
        $result.stop.Invoke()
        $result.dispose.Invoke()
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
    if ($LastExitCode -ne 0)
    {
        throw "chmod failed";
    }
}

function Append([string] $File, $Value)
{
    $info = Get-Item $file -ErrorAction SilentlyContinue
    if ($null -ne $info -and $info.Length -gt 0)
    {
        "`n" | Out-File $file -Encoding utf8 -Append -NoNewline
    }
    $value | Out-File $file -Encoding utf8 -Append -NoNewline
}

$serverOutput = RunWithApiServer -Callback {
    try
    {
        Write-Host "Running $Script $ServerUri" -ForegroundColor DarkYellow
        & $Script $ServerUri | ForEach-Object {
            Write-Host "  $_"
            Append -File $ScriptOutFile -Value $_
        }
        if (-not $?)
        {
            throw "Script execution failed"
        }
    }
    catch
    {
        Append -File $ScriptOutFile -Value $_
        Write-Error "  $_"
    }
    Write-Host "Script finished successfully" -ForegroundColor Green
}

Append -File $ServerOutFile -Value $serverOutput
Write-Host "Outputs written to '$ServerOutFile' and '$ScriptOutFile'" -ForegroundColor Green