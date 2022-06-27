Set-StrictMode -Version latest

$testCases = Get-ChildItem "$PSScriptRoot/testdata/changelog/"

foreach ($testCase in $testCases)
{
    Write-Host "Testing $testCase" -ForegroundColor Yellow

    cp "$testCase/CHANGELOG.md.original" "$testCase/CHANGELOG.md"

    pwsh -WorkingDirectory $testCase -File "$PSScriptRoot/../scripts/update-changelog.ps1" `
        -Name 'Dependency' `
        -PR 'https://github.com/getsentry/dependant/pulls/123' `
        -RepoUrl 'https://github.com/getsentry/dependency' `
        -MainBranch 'main' `
        -OldTag '7.16.0' `
        -NewTag '7.17.0'

    $result = Compare-Object (Get-Content "$testCase/CHANGELOG.md") (Get-Content "$testCase/CHANGELOG.md.expected")
    if ($null -eq $result -or $result.Count -eq 0)
    {
        Write-Host "$testCase PASS" -ForegroundColor Green
    }
    else
    {
        Write-Host "$testCase FAILED" -ForegroundColor Red
        $result | Format-Table -AutoSize
        exit $result.Count
    }
}
