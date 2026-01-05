# Executes the given block starting a dummy Sentry server that collects and logs requests.
# The block is given the server URL as a first argument.
# Returns the dummy server logs.

$ServerUri = "http://127.0.0.1:8000"

class InvokeSentryResult
{
    [string[]]$ServerStdOut
    [string[]]$ServerStdErr
    [string[]]$ScriptOutput

    # It is common to test debug files uploaded to the server so this function gives you a list.
    [string[]]UploadedDebugFiles()
    {
        $prefix = "upload-dif:"
        return @($this.ServerStdOut | Where-Object { $_.StartsWith($prefix) } | ForEach-Object { $_.Substring($prefix.Length).Trim() })
    }

    # Envelopes are collected to a list, each envelope body a single item.
    [string[]]Envelopes()
    {
        $envelopes = @()
        $this.ServerStdOut | ForEach-Object {
            if ($_.Trim() -eq "envelope start")
            {
                $envelope = ''
            }
            elseif ($_ -eq "envelope end")
            {
                $envelopes += $envelope
                $envelope = $null
            }
            elseif ($null -ne $envelope)
            {
                $envelope += $_ + "`n"
            }
        }
        return $envelopes
    }

    # Events are extracted from envelopes, each event body as single item.
    # Note: Unlike Envelopes(), this method discards potential duplicates based on event_id.
    [string[]]Events()
    {
        $ids = @()
        $events = @()
        foreach ($envelope in $this.Envelopes())
        {
            $lines = @($envelope -split "`n")
            $header = $lines[0].Trim() | ConvertFrom-Json
            $eventId = $header | Select-Object -ExpandProperty event_id -ErrorAction SilentlyContinue
            if ($eventId -and $ids -notcontains $eventId)
            {
                $body = $lines | Select-Object -Skip 1 | Where-Object {
                    $_ -like "*`"event_id`":`"$eventId`"*"
                } | Select-Object -First 1
                if ($body)
                {
                    $ids += $eventId
                    $events += $body
                }
            }
        }
        return $events
    }

    [bool]HasErrors()
    {
        return $this.ServerStdErr.Length -gt 0
    }
}

function IsNullOrEmpty([string] $value)
{
    "$value".Trim().Length -eq 0
}

function OutputToArray($output, [string] $uri = $null)
{
    if ($output -isnot [system.array])
    {
        $output = ("$output".Trim() -replace "`r`n", "`n") -split "`n"
    }

    if (!(IsNullOrEmpty $uri))
    {
        $output = $output -replace $uri, "<ServerUri>"
    }
    $output | ForEach-Object { "$_".Trim() }
}

function RunApiServer([string] $ServerScript, [string] $Uri = $ServerUri)
{
    $result = "" | Select-Object -Property process, outFile, errFile, stop, output, dispose
    Write-Host "Starting the $ServerScript on $Uri" -ForegroundColor DarkYellow
    $stopwatch = [system.diagnostics.stopwatch]::StartNew()

    $result.outFile = New-TemporaryFile
    $result.errFile = New-TemporaryFile

    $result.process = Start-Process "python3" -ArgumentList @("$PSScriptRoot/$ServerScript.py", $Uri) `
        -NoNewWindow -PassThru -RedirectStandardOutput $result.outFile -RedirectStandardError $result.errFile -WorkingDirectory $PSScriptRoot

    $out = New-Object InvokeSentryResult
    $out.ServerStdOut = @()
    $out.ServerStdErr = @()

    # We must reassign functions as variables to make them available in a block scope together with GetNewClosure().
    $OutputToArray = { OutputToArray $args[0] $args[1] }
    $IsNullOrEmpty = { IsNullOrEmpty $args[0] }

    $result.dispose = {
        $result.stop.Invoke()

        $stdout = Get-Content $result.outFile -Raw
        Write-Host "Server stdout:" -ForegroundColor Yellow
        Write-Host $stdout

        $out.ServerStdOut += & $OutputToArray $stdout $Uri

        $stderr = Get-Content $result.errFile -Raw
        if (!(& $IsNullOrEmpty $stderr))
        {
            Write-Host "Server stderr:" -ForegroundColor Yellow
            Write-Host $stderr
            $out.ServerStdErr += & $OutputToArray $stderr $Uri
        }

        Remove-Item $result.outFile -ErrorAction Continue
        Remove-Item $result.errFile -ErrorAction Continue
        return $out
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
                $msg = "Server started successfully in $($stopwatch.ElapsedMilliseconds) ms."
                Write-Host $additionalOutput -ForegroundColor Green
                $out.ServerStdOut += $msg
                break;
            }
        }
        catch
        {}
        if ($stopwatch.ElapsedMilliseconds -gt 60000)
        {
            $msg = "Server startup timed out."
            Write-Warning $msg
            $out.ServerStdErr += $msg
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
    $output = $null
    try
    {
        # run the test
        $output = & $Callback $ServerUri
    }
    finally
    {
        $result = $httpServer.dispose.Invoke()[0]
    }

    if ($null -ne $result)
    {
        $result.ScriptOutput = OutputToArray $output
    }
    return $result
}

Export-ModuleMember -Function Invoke-SentryServer
