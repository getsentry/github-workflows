#!/usr/bin/env python3

from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import time
from urllib.parse import urlparse
import sys
import threading
import binascii
import json

uri = urlparse(sys.argv[1] if len(sys.argv) > 1 else 'http://127.0.0.1:8000')
apiOrg = 'org'
apiProject = 'project'
version = '1.1.0'
appIdentifier = 'app'


class Handler(BaseHTTPRequestHandler):
    body = None

    def do_HEAD(self):
        if self.path == "/_check":
            self.writeResponse(999, "text/plain", "")
        else:
            self.writeNoApiMatchesError()

        self.flushLogs()

    def do_GET(self):
        self.start_response()

        if self.path == "/STOP":
            print("HTTP server stopping!")
            self.writeResponse(HTTPStatus.OK, "text/plain", "")
            self.flushLogs()
            threading.Thread(target=self.server.shutdown).start()

        elif self.isApi('api/0'):
            self.writeJSON('{"version":"0","auth":null,"user":null}')
        elif self.isApi('api/0/organizations/{}/chunk-upload/'.format(apiOrg)):
            self.writeJSON('{"url":"' + uri.geturl() + self.path + '",'
                           '"chunkSize":8388608,"chunksPerRequest":64,"maxFileSize":2147483648,'
                           '"maxRequestSize":33554432,"concurrency":1,"hashAlgorithm":"sha1","compression":["gzip"],'
                           '"accept":["debug_files","release_files","pdbs","sources","bcsymbolmaps","il2cpp","portablepdbs"]}')
        elif self.isApi('/api/0/organizations/{}/repos/?cursor='.format(apiOrg)):
            self.writeJSONFile("assets/repos.json")
        elif self.isApi('/api/0/organizations/{}/releases/{}@{}/previous-with-commits/'.format(apiOrg, appIdentifier, version)):
            self.writeJSON('{ }')
        elif self.isApi('/api/0/projects/{}/{}/releases/{}/files/?cursor='.format(apiOrg, apiProject, version)):
            self.writeJSONFile("assets/artifacts.json")
        else:
            self.writeNoApiMatchesError()

        self.flushLogs()

    def do_POST(self):
        self.start_response()

        if self.isApi('api/0/projects/{}/{}/files/difs/assemble/'.format(apiOrg, apiProject)):
            # Request body example:
            # {
            #   "9a01653a...":{"name":"UnityPlayer.dylib","debug_id":"eb4a7644-...","chunks":["f84d3907945cdf41b33da8245747f4d05e6ffcb4", ...]},
            #   "4185e454...":{"name":"UnityPlayer.dylib","debug_id":"86d95b40-...","chunks":[...]}
            # }
            # Response body to let the CLI know we have the symbols already (we don't need to test the actual upload):
            # {
            #   "9a01653a...":{"state":"ok","missingChunks":[]},
            #   "4185e454...":{"state":"ok","missingChunks":[]}
            # }
            jsonRequest = json.loads(self.body)
            jsonResponse = '{'
            for key, value in jsonRequest.items():
                jsonResponse += '"{}"'.format(key)
                jsonResponse += ':{"state":"ok","missingChunks":[]},'
                sys.stdout.write("     upload-dif: {}\n".format(value['name']))
            jsonResponse = jsonResponse.rstrip(',') + '}'
            self.writeJSON(jsonResponse)
        elif self.isApi('api/0/projects/{}/{}/releases/'.format(apiOrg, apiProject)):
            self.writeJSONFile("assets/release.json")
        elif self.isApi('/api/0/organizations/{}/releases/{}@{}/deploys/'.format(apiOrg, appIdentifier, version)):
            self.writeJSONFile("assets/deploy.json")
        elif self.isApi('/api/0/projects/{}/{}/releases/{}@{}/files/'.format(apiOrg, apiProject, appIdentifier, version)):
            self.writeJSONFile("assets/artifact.json")
        elif self.isApi('/api/0/organizations/{}/releases/{}/assemble/'.format(apiOrg, version)):
            self.writeJSON('{"state":"ok","missingChunks":[],"detail":null}')
        elif self.isApi('/api/0/projects/{}/{}/files/dsyms/'.format(apiOrg, apiProject)):
            self.writeJSONFile("assets/debug-info-files.json")
        elif self.isApi('/api/0/projects/{}/{}/files/dsyms/associate/'.format(apiOrg, apiProject)):
            self.writeJSONFile("assets/associate-dsyms.json")
        elif self.isApi('/api/0/projects/{}/{}/reprocessing/'.format(apiOrg, apiProject)):
            self.writeJSON('{ }')
        elif self.isApi('api/0/organizations/{}/chunk-upload/'.format(apiOrg)):
            self.writeJSON('{ }')
        elif self.isApi('api/0/envelope'):
            sys.stdout.write("     envelope start\n")
            sys.stdout.write(self.body)
            sys.stdout.write("\n     envelope end\n")
            self.writeJSON('{ }')
        else:
            self.writeNoApiMatchesError()

        self.flushLogs()

    def do_PUT(self):
        self.start_response()

        if self.isApi('/api/0/organizations/{}/releases/{}@{}/'.format(apiOrg, appIdentifier, version)):
            self.writeJSONFile("assets/release.json")
        elif self.isApi('/api/0/projects/{}/{}/releases/{}@{}/'.format(apiOrg, apiProject, appIdentifier, version)):
            self.writeJSONFile("assets/release.json")
        else:
            self.writeNoApiMatchesError()

        self.flushLogs()

    def start_response(self):
        self.body = None
        self.log_request()

    def log_request(self, size=None):
        body = self.body = self.requestBody()

        log_line = self.requestline
        if size:
            log_line += " ({} bytes)".format(size)
        # if body:
        #     log_line += "\n     " + self.body[0:min(1000, len(body))]

        log_line += '\n'
        sys.stdout.write(log_line)

    # Note: this may only be called once during a single request - can't `.read()` the same stream again.
    def requestBody(self):
        if self.command == "POST" and 'Content-Length' in self.headers:
            length = int(self.headers['Content-Length'])
            content = self.rfile.read(length)
            try:
                return content.decode("utf-8")
            except:
                return binascii.hexlify(bytearray(content))
        return None

    def isApi(self, api: str):
        if self.path.strip('/') == api.strip('/'):
            # sys.stdout.write("Matched API endpoint {}\n".format(api))
            return True
        return False

    def writeNoApiMatchesError(self):
        err = "Error: no API matched {} '{}'".format(self.command, self.path)
        self.log_error(err)
        self.writeResponse(HTTPStatus.NOT_IMPLEMENTED,
                           "text/plain", err)

    def writeJSONFile(self, file_name: str):
        json_file = open(file_name, "r")
        self.writeJSON(json_file.read())
        json_file.close()

    def writeJSON(self, string: str):
        self.writeResponse(HTTPStatus.OK, "application/json", string)

    def writeResponse(self, code: HTTPStatus, type: str, body: str):
        self.send_response_only(code)
        self.send_header("Content-type", type)
        self.send_header("Content-Length", len(body))
        self.end_headers()
        self.wfile.write(str.encode(body))

    def flushLogs(self):
        sys.stdout.flush()
        sys.stderr.flush()


print("HTTP server listening on {}".format(uri.geturl()))
print("To stop the server, execute a GET request to {}/STOP".format(uri.geturl()))

try:
    httpd = ThreadingHTTPServer((uri.hostname, uri.port), Handler)
    target = httpd.serve_forever()
except KeyboardInterrupt:
    pass
