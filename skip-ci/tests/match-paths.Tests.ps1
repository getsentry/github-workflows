BeforeAll {
    function MatchPaths([string[]] $Files, [string[]] $Patterns)
    {
        & "$PSScriptRoot/../scripts/match-paths.ps1" -Files $Files -Patterns $Patterns
    }
}

Describe 'match-paths' {
    It '**/*.md matches Markdown at the root and in folders' {
        MatchPaths @('CHANGELOG.md', 'docs/a.md', 'a/b/c.md') @('**/*.md') | Should -BeTrue
    }

    It 'fails when one file does not match' {
        MatchPaths @('CHANGELOG.md', 'src/a.cs') @('**/*.md') | Should -BeFalse
    }

    It '* does not cross folders' {
        MatchPaths @('README.md') @('*.md') | Should -BeTrue
        MatchPaths @('docs/a.md') @('*.md') | Should -BeFalse
    }

    It '** without a slash crosses folders' {
        MatchPaths @('README.md', 'docs/a.md') @('**.md') | Should -BeTrue
        MatchPaths @('docs/a/b.png') @('docs/**') | Should -BeTrue
    }

    It '? matches one character' {
        MatchPaths @('a1.md') @('a?.md') | Should -BeTrue
        MatchPaths @('a12.md') @('a?.md') | Should -BeFalse
    }

    It 'treats dots and other regex characters literally' {
        MatchPaths @('README_md') @('*.md') | Should -BeFalse
        MatchPaths @('a+b.md') @('a+b.md') | Should -BeTrue
    }

    It 'matches case-sensitively' {
        MatchPaths @('README.MD') @('**/*.md') | Should -BeFalse
    }

    It '! takes files back out' {
        $patterns = @('**/*.md', '!package*/**')
        MatchPaths @('README.md') $patterns | Should -BeTrue
        MatchPaths @('package/README.md') $patterns | Should -BeFalse
        MatchPaths @('package-dev/Documentation~/index.md') $patterns | Should -BeFalse
    }

    It 'the last matching pattern wins' {
        MatchPaths @('docs/keep.md') @('**/*.md', '!docs/**', 'docs/keep.md') | Should -BeTrue
    }

    It 'ignores blank lines and comments' {
        MatchPaths @('README.md') @('', '# docs', '  **/*.md  ') | Should -BeTrue
    }

    It 'never matches without files or patterns' {
        MatchPaths @() @('**/*.md') | Should -BeFalse
        MatchPaths @('README.md') @('', '# only a comment') | Should -BeFalse
    }
}
