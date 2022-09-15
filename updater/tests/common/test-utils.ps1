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
        Write-Host "========================================"
        Write-Host "Expected:"
        Write-Host "----------------------------------------"
        Write-Host $expected
        Write-Host "----------------------------------------"
        Write-Host "Actual:"
        Write-Host "----------------------------------------"
        Write-Host $actual
        Write-Host "========================================"
        throw "AssertEqual failed"
    }
}
function AssertFailsWith([string] $substring, [scriptblock] $block)
{
    $e = $null
    try
    {
        $block.Invoke()
    }
    catch
    {
        $e = $_
    }
    if (-not "$e".Contains($substring))
    {
        throw "AssertFailsWith failed - expected to find '$substring' in the error '$e'"
    }
}