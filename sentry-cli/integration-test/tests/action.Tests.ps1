Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# In CI, the module is expected to be loaded
if (!(Test-Path env:CI ))
{
    Import-Module $PSScriptRoot/../action.psm1 -Force
}

Describe 'Invoke-SentryServer' {
    It "works fine with a simple callback" {
        $result = Invoke-SentryServer {
            Param([string]$url)
            $url | Should -Be "http://127.0.0.1:8000"
            "custom script output"
        }
        Should -ActualValue $result.ServerStdOut -HaveType [string[]]
        Should -ActualValue $result.ServerStdErr -HaveType [string[]]
        Should -ActualValue $result.ScriptOutput -HaveType [string[]]
        $result.ServerStdErr.Length | Should -Be 0
        Should -ActualValue $result.HasErrors() -BeFalse
        $result.ServerStdOut.Length | Should -BeGreaterThan 1
        $result.ServerStdOut[0] | Should -Match "Server started successfully in [0-9]+ ms."
        $result.ServerStdOut | Should -Contain 'HTTP server listening on <ServerUri>'
        $result.ScriptOutput | Should -Be "custom script output"
    }

    It "rethrows an exception and recovers" {
        { Invoke-SentryServer { throw "hello there" } } | Should -Throw "hello there"
        $result = Invoke-SentryServer {}
        $result.ServerStdOut | Should -Contain 'HTTP server listening on <ServerUri>'
    }

    It "collects debug-files uploads" {
        $result = Invoke-SentryServer {
            Param([string]$url)
            Invoke-WebRequest -Uri "$url/api/0/projects/org/project/files/difs/assemble/" -Method Post `
                -Body '{"9a01653a":{"name":"file3.dylib","debug_id":"eb4a7644","chunks":["f84d"]},"abcd":{"name":"file2.so","debug_id":"foo","chunks":["ab"]}}'
            Invoke-WebRequest -Uri "$url/api/0/projects/org/project/files/difs/assemble/" -Method Post `
                -Body '{"9a01653a":{"name":"file1.dll","debug_id":"aa","chunks":["def"]}}'
        }
        Should -ActualValue $result.HasErrors() -BeFalse
        $result.UploadedDebugFiles() | Should -Be @('file3.dylib', 'file2.so', 'file1.dll')
    }

    It "collects proguard mapping" {
        $result = Invoke-SentryServer {
            Param([string]$url)
            Invoke-WebRequest -Uri "$url/api/0/projects/org/project/files/dsyms/associate/" -Method Post
            Invoke-WebRequest -Uri "$url/api/0/projects/org/project/files/proguard-artifact-releases" -Method Post
        }
        Should -ActualValue $result.HasErrors() -BeFalse
    }

    It "collects envelopes" {
        $result = Invoke-SentryServer {
            Param([string]$url)
            Invoke-WebRequest -Uri "$url/api/0/envelope" -Method Post -Body @'
{"event_id":"9ec79c33ec9942ab8353589fcb2e04dc","dsn":"https://e12d836b15bb49d7bbf99e64295d995b:@sentry.io/42"}
{"type":"attachment","length":10,"content_type":"text/plain","filename":"hello.txt"}
\xef\xbb\xbfHello\r\n
{"type":"event","length":41,"content_type":"application/json","filename":"application.log"}
{"message":"hello world","level":"error"}
'@
            Invoke-WebRequest -Uri "$url/api/0/envelope" -Method Post -Body @'
{"event_id":"9ec79c33ec9942ab8353589fcb2e04dc"}
{"type":"attachment"}
helloworld
'@
        }
        Should -ActualValue $result.HasErrors() -BeFalse
        $result.Envelopes().Length | Should -Be 2
        $result.Envelopes()[0].Length | Should -Be 352
        $result.Envelopes()[1].Length | Should -Be 81
    }

    It "collects gzip compressed envelopes" {
        $result = Invoke-SentryServer {
            Param([string]$url)
            $ms = New-Object System.IO.MemoryStream
            $gzip = New-Object System.IO.Compression.GZipStream($ms, [System.IO.Compression.CompressionMode]::Compress)
            $bytes = [System.Text.Encoding]::UTF8.GetBytes(@'
{"event_id":"9ec79c33ec9942ab8353589fcb2e04dc","dsn":"https://e12d836b15bb49d7bbf99e64295d995b:@sentry.io/42"}
{"type":"attachment","length":10,"content_type":"text/plain","filename":"hello.txt"}
\xef\xbb\xbfHello\r\n
{"type":"event","length":41,"content_type":"application/json","filename":"application.log"}
{"message":"hello world","level":"error"}
'@)
            $gzip.Write($bytes, 0, $bytes.Length)
            $gzip.Close()
            $body = $ms.ToArray()
            $ms.Close()
            Invoke-WebRequest -Uri "$url/api/0/envelope" -Method Post -Body $body -Headers @{ "Content-Encoding" = "gzip" }
        }
        
        Should -ActualValue $result.HasErrors() -BeFalse
        $result.Envelopes().Length | Should -Be 1
        $result.Envelopes()[0].Length | Should -Be 352
    }

    It "discards duplicate events" {
        $result = Invoke-SentryServer {
            param([string]$url)
            Invoke-WebRequest -Uri "$url/api/0/envelope" -Method Post -Body @'
{"dsn":"https://e12d836b15bb49d7bbf99e64295d995b:@sentry.io/42","sent_at":"2025-11-20T03:52:42.924Z"}
{"type":"session","length":42}
{"sid":"66356dadc138458a8d5cd9e258065175"}
'@
            Invoke-WebRequest -Uri "$url/api/0/envelope" -Method Post -Body @'
{"event_id":"9ec79c33ec9942ab8353589fcb2e04dc","dsn":"https://e12d836b15bb49d7bbf99e64295d995b:@sentry.io/42","sent_at":"2025-11-20T03:53:38.929Z"}
{"type":"attachment","length":10,"content_type":"text/plain","filename":"hello.txt"}
\xef\xbb\xbfHello\r\n
{"type":"event","length":47,"content_type":"application/json"}
{"event_id":"9ec79c33ec9942ab8353589fcb2e04dc"}
'@
            Invoke-WebRequest -Uri "$url/api/0/envelope" -Method Post -Body @'
{"event_id":"9ec79c33ec9942ab8353589fcb2e04dc","dsn":"https://e12d836b15bb49d7bbf99e64295d995b:@sentry.io/42","sent_at":"2025-11-20T03:53:41.505Z"}
{"type":"attachment","length":10,"content_type":"text/plain","filename":"hello.txt"}
\xef\xbb\xbfHello\r\n
{"type":"event","length":47,"content_type":"application/json"}
{"event_id":"9ec79c33ec9942ab8353589fcb2e04dc"}
'@
        }

        Should -ActualValue $result.HasErrors() -BeFalse
        $result.Envelopes().Length | Should -Be 3
        $result.Events().Length | Should -Be 1
        $result.Events()[0].Length | Should -Be 47
    }
}
