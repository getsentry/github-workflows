BeforeAll {
    # Load CMake helper functions from the main script
    . "$PSScriptRoot/../scripts/cmake-functions.ps1"
}

Describe 'CMake Helper Functions' {
    Context 'Parse-CMakeFetchContent' {
        BeforeEach {
            $script:tempDir = "$TestDrive/cmake-tests"
            New-Item $tempDir -ItemType Directory -Force | Out-Null
        }

        It 'parses FetchContent_Declare with various scenarios' {
            # Test 1: Basic parsing with explicit dependency name
            $testFile1 = "$tempDir/basic.cmake"
            @'
include(FetchContent)

FetchContent_Declare(
    sentry-native
    GIT_REPOSITORY https://github.com/getsentry/sentry-native
    GIT_TAG v0.9.1
    GIT_SHALLOW FALSE
)

FetchContent_MakeAvailable(sentry-native)
'@ | Out-File $testFile1

            $result = Parse-CMakeFetchContent $testFile1 'sentry-native'
            $result.GitRepository | Should -Be 'https://github.com/getsentry/sentry-native'
            $result.GitTag | Should -Be 'v0.9.1'
            $result.DepName | Should -Be 'sentry-native'

            # Test 2: Auto-detection with same file
            $result = Parse-CMakeFetchContent $testFile1 $null
            $result.GitRepository | Should -Be 'https://github.com/getsentry/sentry-native'
            $result.GitTag | Should -Be 'v0.9.1'
            $result.DepName | Should -Be 'sentry-native'

            # Test 3: Hash values
            $testFile2 = "$tempDir/hash.cmake"
            @'
include(FetchContent)

FetchContent_Declare(
    sentry-native
    GIT_REPOSITORY https://github.com/getsentry/sentry-native
    GIT_TAG a64d5bd8ee130f2cda196b6fa7d9b65bfa6d32e2 # 0.9.1
    GIT_SHALLOW FALSE
    GIT_SUBMODULES "external/breakpad"
)

FetchContent_MakeAvailable(sentry-native)
'@ | Out-File $testFile2

            $result = Parse-CMakeFetchContent $testFile2 'sentry-native'
            $result.GitRepository | Should -Be 'https://github.com/getsentry/sentry-native'
            $result.GitTag | Should -Be 'a64d5bd8ee130f2cda196b6fa7d9b65bfa6d32e2'
            $result.DepName | Should -Be 'sentry-native'

            # Test 4: Complex multi-line formatting
            $testFile3 = "$tempDir/complex.cmake"
            @'
include(FetchContent)

FetchContent_Declare(
    sentry-native
    GIT_REPOSITORY
        https://github.com/getsentry/sentry-native
    GIT_TAG
        v0.9.1
    GIT_SHALLOW
        FALSE
    GIT_SUBMODULES
        "external/breakpad"
)

FetchContent_MakeAvailable(sentry-native)
'@ | Out-File $testFile3

            $result = Parse-CMakeFetchContent $testFile3 'sentry-native'
            $result.GitRepository | Should -Be 'https://github.com/getsentry/sentry-native'
            $result.GitTag | Should -Be 'v0.9.1'
            $result.DepName | Should -Be 'sentry-native'
        }

        It 'handles multiple dependencies correctly' {
            $testFile = "$tempDir/multiple.cmake"
            @'
include(FetchContent)

FetchContent_Declare(
    sentry-native
    GIT_REPOSITORY https://github.com/getsentry/sentry-native
    GIT_TAG v0.9.1
)

FetchContent_Declare(
    googletest
    GIT_REPOSITORY https://github.com/google/googletest
    GIT_TAG v1.14.0
)

FetchContent_MakeAvailable(sentry-native googletest)
'@ | Out-File $testFile

            # Should throw when no explicit name given
            { Parse-CMakeFetchContent $testFile $null } | Should -Throw '*Multiple FetchContent declarations found*'

            # Should work with explicit dependency name
            $result = Parse-CMakeFetchContent $testFile 'googletest'
            $result.GitRepository | Should -Be 'https://github.com/google/googletest'
            $result.GitTag | Should -Be 'v1.14.0'
            $result.DepName | Should -Be 'googletest'
        }

        It 'throws appropriate errors for invalid scenarios' {
            # Test 1: Missing dependency
            $testFile1 = "$tempDir/valid.cmake"
            @'
include(FetchContent)

FetchContent_Declare(
    sentry-native
    GIT_REPOSITORY https://github.com/getsentry/sentry-native
    GIT_TAG v0.9.1
)
'@ | Out-File $testFile1

            { Parse-CMakeFetchContent $testFile1 'nonexistent' } | Should -Throw "*FetchContent_Declare for 'nonexistent' not found*"

            # Test 2: Missing GIT_REPOSITORY
            $testFile2 = "$tempDir/missing-repo.cmake"
            @'
include(FetchContent)

FetchContent_Declare(
    sentry-native
    GIT_TAG v0.9.1
)
'@ | Out-File $testFile2

            { Parse-CMakeFetchContent $testFile2 'sentry-native' } | Should -Throw '*Could not parse GIT_REPOSITORY or GIT_TAG*'

            # Test 3: Missing GIT_TAG
            $testFile3 = "$tempDir/missing-tag.cmake"
            @'
include(FetchContent)

FetchContent_Declare(
    sentry-native
    GIT_REPOSITORY https://github.com/getsentry/sentry-native
)
'@ | Out-File $testFile3

            { Parse-CMakeFetchContent $testFile3 'sentry-native' } | Should -Throw '*Could not parse GIT_REPOSITORY or GIT_TAG*'
        }
    }

    Context 'Find-TagForHash' {
        It 'handles hash resolution scenarios' {
            # Test 1: Hash without matching tag
            $fakeHash = 'abcdef1234567890abcdef1234567890abcdef12'
            $repo = 'https://github.com/getsentry/sentry-native'

            $result = Find-TagForHash $repo $fakeHash
            $result | Should -BeNullOrEmpty

            # Test 2: Network failures
            $invalidRepo = 'https://github.com/nonexistent/repo'
            $hash = 'abcdef1234567890abcdef1234567890abcdef12'

            # Should not throw, but return null and show warning
            $result = Find-TagForHash $invalidRepo $hash
            $result | Should -BeNullOrEmpty
        }

        # Note: Testing actual hash resolution requires network access
        # and is better suited for integration tests
    }

    Context 'Update-CMakeFile' {
        BeforeEach {
            $script:tempDir = "$TestDrive/cmake-tests"
            New-Item $tempDir -ItemType Directory -Force | Out-Null
        }

        It 'updates CMake files preserving format and structure' {
            # Test 1: Tag to tag update
            $testFile1 = "$tempDir/tag-update.cmake"
            @'
include(FetchContent)

FetchContent_Declare(
    sentry-native
    GIT_REPOSITORY https://github.com/getsentry/sentry-native
    GIT_TAG v0.9.1
    GIT_SHALLOW FALSE
)

FetchContent_MakeAvailable(sentry-native)
'@ | Out-File $testFile1

            Update-CMakeFile $testFile1 'sentry-native' 'v0.9.2'

            $content = Get-Content $testFile1 -Raw
            $content | Should -Match 'GIT_TAG v0.9.2'
            $content | Should -Not -Match 'v0.9.1'
            # Verify structure preservation
            $content | Should -Match 'include\(FetchContent\)'
            $content | Should -Match 'FetchContent_MakeAvailable'
            $content | Should -Match 'GIT_REPOSITORY https://github.com/getsentry/sentry-native'
            $content | Should -Match 'GIT_SHALLOW FALSE'

            # Test 2: Hash to newer hash update
            $testFile2 = "$tempDir/hash-update.cmake"
            @'
include(FetchContent)

FetchContent_Declare(
    sentry-native
    GIT_REPOSITORY https://github.com/getsentry/sentry-native
    GIT_TAG a64d5bd8ee130f2cda196b6fa7d9b65bfa6d32e2 # 0.9.1
    GIT_SHALLOW FALSE
    GIT_SUBMODULES "external/breakpad"
)

FetchContent_MakeAvailable(sentry-native)
'@ | Out-File $testFile2

            # Update to a newer tag that will be converted to hash (0.11.0 is known to exist)
            Update-CMakeFile $testFile2 'sentry-native' '0.11.0'

            $content = Get-Content $testFile2 -Raw
            # Should have new hash with tag comment
            $content | Should -Match 'GIT_TAG [a-f0-9]{40} # 0.11.0'
            # Should not have old hash or old comment
            $content | Should -Not -Match 'a64d5bd8ee130f2cda196b6fa7d9b65bfa6d32e2'
            $content | Should -Not -Match '# 0.9.1'

            # Test 3: Complex formatting
            $testFile3 = "$tempDir/complex-format.cmake"
            @'
include(FetchContent)

FetchContent_Declare(
    sentry-native
    GIT_REPOSITORY
        https://github.com/getsentry/sentry-native
    GIT_TAG
        v0.9.1
    GIT_SHALLOW
        FALSE
    GIT_SUBMODULES
        "external/breakpad"
)

FetchContent_MakeAvailable(sentry-native)
'@ | Out-File $testFile3

            Update-CMakeFile $testFile3 'sentry-native' 'v0.9.2'

            $content = Get-Content $testFile3 -Raw
            $content | Should -Match 'GIT_TAG\s+v0.9.2'
            $content | Should -Not -Match 'v0.9.1'
        }

        It 'handles error scenarios appropriately' {
            $testFile = "$tempDir/error-test.cmake"
            @'
include(FetchContent)

FetchContent_Declare(
    sentry-native
    GIT_REPOSITORY https://github.com/getsentry/sentry-native
    GIT_TAG v0.9.1
)
'@ | Out-File $testFile

            # Try to update a dependency that doesn't exist
            { Update-CMakeFile $testFile 'nonexistent-dep' 'v1.0.0' } | Should -Throw "*FetchContent_Declare for 'nonexistent-dep' not found*"
        }

        # Note: Hash update tests require network access for git ls-remote
        # and are better suited for integration tests
    }
}