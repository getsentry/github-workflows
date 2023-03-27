# Executes the given block starting a dummy Sentry server that collects and logs requests.
# The block is given the server URL as a first argument.
# Returns the dummy server logs.

$ServerUri = "http://127.0.0.1:8000"

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
        return ("$stdout`n$stderr".Trim() -replace $Uri, "<ServerUri>" -replace "`r`n", "`n") -split "`n" | ForEach-Object { $_.Trim() }
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
        $result.stop.Invoke()
        $result.dispose.Invoke()
        throw Write-Host "Couldn't start the $ServerScript"
    }

    return $result
}

function Invoke-SentryServer([ScriptBlock] $Callback)
{
    # start the server
    $httpServer = RunApiServer "sentry-server"

    $result = $null
    try
    {
        # run the test
        Invoke-Command -ScriptBlock $Callback -ArgumentList $ServerUri
    }
    finally
    {
        $httpServer.stop.Invoke()
        $result = $httpServer.dispose.Invoke()
    }

    return $result
}

Export-ModuleMember -Function Invoke-SentryServer
