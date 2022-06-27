function RunTest ([string] $name, [ScriptBlock] $code)
{
    try
    {
        Write-Host "Test $name - starting" -ForegroundColor Yellow
        $code.Invoke();
        Write-Host "Test $name - PASS" -ForegroundColor Green
    }
    catch
    {
        Write-Host "Test $name - FAILED" -ForegroundColor Red
        throw
    }
}

function AssertEqual([string] $expected, [string] $actual)
{
    $diff = Compare-Object $expected $actual
    if ($null -ne $diff -and $diff.Count -ne 0)
    {
        Write-Host "Given strings are not equal:" -ForegroundColor Red
        $diff | Format-Table | Out-String | Write-Host
        throw "AssertEqual failed"
    }
}