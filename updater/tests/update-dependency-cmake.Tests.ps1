BeforeAll {
    # Load CMake helper functions from the main script
    . "$PSScriptRoot/../scripts/cmake-functions.ps1"

    $testDataDir = "$PSScriptRoot/testdata/cmake"
}

Describe 'CMake Helper Functions' {
    Context 'Parse-CMakeFetchContent' {
        It 'parses basic FetchContent_Declare with explicit dependency name' {
            $testFile = "$testDataDir/single-dependency.cmake"

            $result = Parse-CMakeFetchContent $testFile 'sentry-native'

            $result.GitRepository | Should -Be 'https://github.com/getsentry/sentry-native'
            $result.GitTag | Should -Be 'v0.9.1'
            $result.DepName | Should -Be 'sentry-native'
        }

        It 'auto-detects single FetchContent_Declare' {
            $testFile = "$testDataDir/single-dependency.cmake"

            $result = Parse-CMakeFetchContent $testFile $null

            $result.GitRepository | Should -Be 'https://github.com/getsentry/sentry-native'
            $result.GitTag | Should -Be 'v0.9.1'
            $result.DepName | Should -Be 'sentry-native'
        }

        It 'handles hash values correctly' {
            $testFile = "$testDataDir/hash-dependency.cmake"

            $result = Parse-CMakeFetchContent $testFile 'sentry-native'

            $result.GitRepository | Should -Be 'https://github.com/getsentry/sentry-native'
            $result.GitTag | Should -Be 'a64d5bd8ee130f2cda196b6fa7d9b65bfa6d32e2'
            $result.DepName | Should -Be 'sentry-native'
        }

        It 'handles complex multi-line formatting' {
            $testFile = "$testDataDir/complex-formatting.cmake"

            $result = Parse-CMakeFetchContent $testFile 'sentry-native'

            $result.GitRepository | Should -Be 'https://github.com/getsentry/sentry-native'
            $result.GitTag | Should -Be 'v0.9.1'
            $result.DepName | Should -Be 'sentry-native'
        }

        It 'throws on multiple dependencies without explicit name' {
            $testFile = "$testDataDir/multiple-dependencies.cmake"

            { Parse-CMakeFetchContent $testFile $null } | Should -Throw '*Multiple FetchContent declarations found*'
        }

        It 'handles specific dependency from multiple dependencies' {
            $testFile = "$testDataDir/multiple-dependencies.cmake"

            $result = Parse-CMakeFetchContent $testFile 'googletest'

            $result.GitRepository | Should -Be 'https://github.com/google/googletest'
            $result.GitTag | Should -Be 'v1.14.0'
            $result.DepName | Should -Be 'googletest'
        }

        It 'throws on missing dependency' {
            $testFile = "$testDataDir/single-dependency.cmake"

            { Parse-CMakeFetchContent $testFile 'nonexistent' } | Should -Throw "*FetchContent_Declare for 'nonexistent' not found*"
        }

        It 'throws on missing GIT_REPOSITORY' {
            $testFile = "$testDataDir/missing-repository.cmake"

            { Parse-CMakeFetchContent $testFile 'sentry-native' } | Should -Throw '*Could not parse GIT_REPOSITORY or GIT_TAG*'
        }

        It 'throws on missing GIT_TAG' {
            $testFile = "$testDataDir/malformed.cmake"

            { Parse-CMakeFetchContent $testFile 'sentry-native' } | Should -Throw '*Could not parse GIT_REPOSITORY or GIT_TAG*'
        }
    }

    Context 'Find-TagForHash' {
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

    Context 'Update-CMakeFile' {
        BeforeEach {
            # Create a temporary copy of test files for modification
            $script:tempDir = "$TestDrive/cmake-tests"
            New-Item $tempDir -ItemType Directory -Force | Out-Null
        }

        It 'updates tag to tag preserving format' {
            $sourceFile = "$testDataDir/single-dependency.cmake"
            $testFile = "$tempDir/test.cmake"
            Copy-Item $sourceFile $testFile

            Update-CMakeFile $testFile 'sentry-native' 'v0.9.2'

            $content = Get-Content $testFile -Raw
            $content | Should -Match 'GIT_TAG v0.9.2'
            $content | Should -Not -Match 'v0.9.1'
        }

        It 'preserves file structure and other content' {
            $sourceFile = "$testDataDir/single-dependency.cmake"
            $testFile = "$tempDir/test.cmake"
            Copy-Item $sourceFile $testFile

            Update-CMakeFile $testFile 'sentry-native' 'v0.9.2'

            $content = Get-Content $testFile -Raw
            $content | Should -Match 'include\(FetchContent\)'
            $content | Should -Match 'FetchContent_MakeAvailable'
            $content | Should -Match 'GIT_REPOSITORY https://github.com/getsentry/sentry-native'
            $content | Should -Match 'GIT_SHALLOW FALSE'
        }

        It 'handles complex formatting correctly' {
            $sourceFile = "$testDataDir/complex-formatting.cmake"
            $testFile = "$tempDir/test.cmake"
            Copy-Item $sourceFile $testFile

            Update-CMakeFile $testFile 'sentry-native' 'v0.9.2'

            $content = Get-Content $testFile -Raw
            $content | Should -Match 'GIT_TAG\s+v0.9.2'
            $content | Should -Not -Match 'v0.9.1'
        }

        It 'throws on failed regex match' {
            $sourceFile = "$testDataDir/single-dependency.cmake"
            $testFile = "$tempDir/test.cmake"
            Copy-Item $sourceFile $testFile

            # Try to update a dependency that doesn't exist
            { Update-CMakeFile $testFile 'nonexistent-dep' 'v1.0.0' } | Should -Throw "*FetchContent_Declare for 'nonexistent-dep' not found*"
        }

        # Note: Hash update tests require network access for git ls-remote
        # and are better suited for integration tests
    }
}
