BeforeAll {
    # Load CMake helper functions from the main script
    . "$PSScriptRoot/../scripts/cmake-functions.ps1"
}

Describe 'Parse-CMakeFetchContent' {
    Context 'Basic single dependency file' {
        BeforeAll {
            $script:tempDir = "$TestDrive/cmake-tests"
            New-Item $tempDir -ItemType Directory -Force | Out-Null

            $script:basicFile = "$tempDir/basic.cmake"
            @'
include(FetchContent)

FetchContent_Declare(
    sentry-native
    GIT_REPOSITORY https://github.com/getsentry/sentry-native
    GIT_TAG v0.9.1
    GIT_SHALLOW FALSE
)

FetchContent_MakeAvailable(sentry-native)
'@ | Out-File $basicFile
        }

        It 'parses with explicit dependency name' {
            $result = Parse-CMakeFetchContent $basicFile 'sentry-native'

            $result.GitRepository | Should -Be 'https://github.com/getsentry/sentry-native'
            $result.GitTag | Should -Be 'v0.9.1'
            $result.DepName | Should -Be 'sentry-native'
        }

        It 'auto-detects single dependency' {
            $result = Parse-CMakeFetchContent $basicFile $null

            $result.GitRepository | Should -Be 'https://github.com/getsentry/sentry-native'
            $result.GitTag | Should -Be 'v0.9.1'
            $result.DepName | Should -Be 'sentry-native'
        }

        It 'throws on missing dependency' {
            { Parse-CMakeFetchContent $basicFile 'nonexistent' } | Should -Throw "*FetchContent_Declare for 'nonexistent' not found*"
        }
    }

    Context 'Hash-based dependency file' {
        BeforeAll {
            $script:tempDir = "$TestDrive/cmake-tests"
            New-Item $tempDir -ItemType Directory -Force | Out-Null

            $script:hashFile = "$tempDir/hash.cmake"
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
'@ | Out-File $hashFile
        }

        It 'handles hash values correctly' {
            $result = Parse-CMakeFetchContent $hashFile 'sentry-native'

            $result.GitRepository | Should -Be 'https://github.com/getsentry/sentry-native'
            $result.GitTag | Should -Be 'a64d5bd8ee130f2cda196b6fa7d9b65bfa6d32e2'
            $result.DepName | Should -Be 'sentry-native'
        }
    }

    Context 'Complex formatting file' {
        BeforeAll {
            $script:tempDir = "$TestDrive/cmake-tests"
            New-Item $tempDir -ItemType Directory -Force | Out-Null

            $script:complexFile = "$tempDir/complex.cmake"
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
'@ | Out-File $complexFile
        }

        It 'handles complex multi-line formatting' {
            $result = Parse-CMakeFetchContent $complexFile 'sentry-native'

            $result.GitRepository | Should -Be 'https://github.com/getsentry/sentry-native'
            $result.GitTag | Should -Be 'v0.9.1'
            $result.DepName | Should -Be 'sentry-native'
        }
    }

    Context 'Multiple dependencies file' {
        BeforeAll {
            $script:tempDir = "$TestDrive/cmake-tests"
            New-Item $tempDir -ItemType Directory -Force | Out-Null

            $script:multipleFile = "$tempDir/multiple.cmake"
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
'@ | Out-File $multipleFile
        }

        It 'throws on multiple dependencies without explicit name' {
            { Parse-CMakeFetchContent $multipleFile $null } | Should -Throw '*Multiple FetchContent declarations found*'
        }

        It 'handles specific dependency from multiple dependencies' {
            $result = Parse-CMakeFetchContent $multipleFile 'googletest'

            $result.GitRepository | Should -Be 'https://github.com/google/googletest'
            $result.GitTag | Should -Be 'v1.14.0'
            $result.DepName | Should -Be 'googletest'
        }
    }

    Context 'Malformed files' {
        BeforeAll {
            $script:tempDir = "$TestDrive/cmake-tests"
            New-Item $tempDir -ItemType Directory -Force | Out-Null

            $script:missingRepoFile = "$tempDir/missing-repo.cmake"
            @'
include(FetchContent)

FetchContent_Declare(
    sentry-native
    GIT_TAG v0.9.1
)
'@ | Out-File $missingRepoFile

            $script:missingTagFile = "$tempDir/missing-tag.cmake"
            @'
include(FetchContent)

FetchContent_Declare(
    sentry-native
    GIT_REPOSITORY https://github.com/getsentry/sentry-native
)
'@ | Out-File $missingTagFile
        }

        It 'throws on missing GIT_REPOSITORY' {
            { Parse-CMakeFetchContent $missingRepoFile 'sentry-native' } | Should -Throw '*Could not parse GIT_REPOSITORY or GIT_TAG*'
        }

        It 'throws on missing GIT_TAG' {
            { Parse-CMakeFetchContent $missingTagFile 'sentry-native' } | Should -Throw '*Could not parse GIT_REPOSITORY or GIT_TAG*'
        }
    }
}

Describe 'Find-TagForHash' {
    Context 'Hash resolution scenarios' {
        It 'returns null for hash without matching tag' {
            # Use a fake hash that won't match any real tag
            $fakeHash = 'abcdef1234567890abcdef1234567890abcdef12'
            $repo = 'https://github.com/getsentry/sentry-native'

            $result = Find-TagForHash $repo $fakeHash

            $result | Should -BeNullOrEmpty
        }

        It 'handles network failures gracefully' {
            $invalidRepo = 'https://github.com/nonexistent/repo'
            $hash = 'abcdef1234567890abcdef1234567890abcdef12'

            # Should not throw, but return null and show warning
            $result = Find-TagForHash $invalidRepo $hash

            $result | Should -BeNullOrEmpty
        }

        # Note: Testing actual hash resolution requires network access
        # and is better suited for integration tests
    }
}

Describe 'Update-CMakeFile' {
    Context 'Basic tag updates' {
        BeforeAll {
            $script:tempDir = "$TestDrive/cmake-update-tests"
            New-Item $tempDir -ItemType Directory -Force | Out-Null

            $script:basicTemplate = @'
include(FetchContent)

FetchContent_Declare(
    sentry-native
    GIT_REPOSITORY https://github.com/getsentry/sentry-native
    GIT_TAG v0.9.1
    GIT_SHALLOW FALSE
)

FetchContent_MakeAvailable(sentry-native)
'@
        }

        BeforeEach {
            $script:basicTestFile = "$tempDir/basic-test.cmake"
        }

        It 'updates tag to tag preserving format' {
            $basicTemplate | Out-File $basicTestFile

            Update-CMakeFile $basicTestFile 'sentry-native' 'v0.9.2'

            $content = Get-Content $basicTestFile -Raw
            $content | Should -Match 'GIT_TAG v0.9.2'
            $content | Should -Not -Match 'v0.9.1'
        }

        It 'preserves file structure and other content' {
            $basicTemplate | Out-File $basicTestFile

            Update-CMakeFile $basicTestFile 'sentry-native' 'v0.9.2'

            $content = Get-Content $basicTestFile -Raw
            $content | Should -Match 'include\(FetchContent\)'
            $content | Should -Match 'FetchContent_MakeAvailable'
            $content | Should -Match 'GIT_REPOSITORY https://github.com/getsentry/sentry-native'
            $content | Should -Match 'GIT_SHALLOW FALSE'
        }

        It 'throws on failed regex match' {
            $basicTemplate | Out-File $basicTestFile

            # Try to update a dependency that doesn't exist
            { Update-CMakeFile $basicTestFile 'nonexistent-dep' 'v1.0.0' } | Should -Throw "*FetchContent_Declare for 'nonexistent-dep' not found*"
        }
    }

    Context 'Hash updates' {
        BeforeAll {
            $script:tempDir = "$TestDrive/cmake-update-tests"
            New-Item $tempDir -ItemType Directory -Force | Out-Null

            $script:hashTemplate = @'
include(FetchContent)

FetchContent_Declare(
    sentry-native
    GIT_REPOSITORY https://github.com/getsentry/sentry-native
    GIT_TAG a64d5bd8ee130f2cda196b6fa7d9b65bfa6d32e2 # 0.9.1
    GIT_SHALLOW FALSE
    GIT_SUBMODULES "external/breakpad"
)

FetchContent_MakeAvailable(sentry-native)
'@
        }

        BeforeEach {
            $script:hashTestFile = "$tempDir/hash-test.cmake"
        }

        It 'updates hash to newer hash preserving format' {
            $hashTemplate | Out-File $hashTestFile

            # Update to a newer tag that will be converted to hash (0.11.0 is known to exist)
            Update-CMakeFile $hashTestFile 'sentry-native' '0.11.0'

            $content = Get-Content $hashTestFile -Raw
            # Should have new hash with tag comment
            $content | Should -Match 'GIT_TAG [a-f0-9]{40} # 0.11.0'
            # Should not have old hash or old comment
            $content | Should -Not -Match 'a64d5bd8ee130f2cda196b6fa7d9b65bfa6d32e2'
            $content | Should -Not -Match '# 0.9.1'
        }
    }

    Context 'Complex formatting' {
        BeforeAll {
            $script:tempDir = "$TestDrive/cmake-update-tests"
            New-Item $tempDir -ItemType Directory -Force | Out-Null

            $script:complexTemplate = @'
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
'@
        }

        BeforeEach {
            $script:complexTestFile = "$tempDir/complex-test.cmake"
        }

        It 'handles complex formatting correctly' {
            $complexTemplate | Out-File $complexTestFile

            Update-CMakeFile $complexTestFile 'sentry-native' 'v0.9.2'

            $content = Get-Content $complexTestFile -Raw
            $content | Should -Match 'GIT_TAG\s+v0.9.2'
            $content | Should -Not -Match 'v0.9.1'
        }
    }

    # Note: Hash update tests require network access for git ls-remote
    # and are better suited for integration tests
}