# Compare commits by ancestry, independently of their names or timestamps.
function Get-CommitRelationship {
    param(
        [Parameter(Mandatory=$true)][string]$Repository,
        [Parameter(Mandatory=$true)][string]$Current,
        [Parameter(Mandatory=$true)][string]$Target
    )

    $currentCommit = git -C $Repository rev-parse --verify "$Current^{commit}"
    if ($LASTEXITCODE -ne 0) {
        throw "Could not resolve current revision '$Current' in '$Repository' (git exit code $LASTEXITCODE)"
    }
    $targetCommit = git -C $Repository rev-parse --verify "$Target^{commit}"
    if ($LASTEXITCODE -ne 0) {
        throw "Could not resolve target revision '$Target' in '$Repository' (git exit code $LASTEXITCODE)"
    }
    if ($currentCommit -eq $targetCommit) { return 'Same' }

    git -C $Repository merge-base --is-ancestor $currentCommit $targetCommit
    $exitCode = $LASTEXITCODE
    if ($exitCode -eq 0) { return 'Behind' }
    if ($exitCode -ne 1) {
        throw "Could not compare '$Current' with '$Target' in '$Repository' (git merge-base exit code $exitCode)"
    }

    git -C $Repository merge-base --is-ancestor $targetCommit $currentCommit
    $exitCode = $LASTEXITCODE
    if ($exitCode -eq 0) { return 'Ahead' }
    if ($exitCode -ne 1) {
        throw "Could not compare '$Target' with '$Current' in '$Repository' (git merge-base exit code $exitCode)"
    }

    # Exit code 1 means a negative ancestry result, not a failed Git command.
    $global:LASTEXITCODE = 0
    return 'Diverged'
}

function Get-RemoteCommitRelationship {
    param(
        [Parameter(Mandatory=$true)][string]$Repository,
        [Parameter(Mandatory=$true)][string]$Current,
        [Parameter(Mandatory=$true)][string]$Target
    )

    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid())
    try {
        git init --quiet --bare $tempDir
        if ($LASTEXITCODE -ne 0) {
            throw "Could not initialize ancestry repository '$tempDir' (git exit code $LASTEXITCODE)"
        }
        git -C $tempDir fetch --quiet --no-tags $Repository $Current
        if ($LASTEXITCODE -ne 0) {
            throw "Could not fetch current revision '$Current' from '$Repository' (git exit code $LASTEXITCODE)"
        }
        $currentCommit = git -C $tempDir rev-parse --verify 'FETCH_HEAD^{commit}'
        if ($LASTEXITCODE -ne 0) { throw "Could not resolve fetched revision '$Current' to a commit" }

        git -C $tempDir fetch --quiet --no-tags $Repository $Target
        if ($LASTEXITCODE -ne 0) {
            throw "Could not fetch target revision '$Target' from '$Repository' (git exit code $LASTEXITCODE)"
        }
        return Get-CommitRelationship $tempDir $currentCommit FETCH_HEAD
    } finally {
        if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
    }
}
