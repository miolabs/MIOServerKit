#!/bin/bash
#
# Pre-build step: regenerate the @Endpoint route registration file.
#
# Compiler macro plugins run sandboxed and cannot write files, so route
# codegen happens here, before the build. Hook this script as a pre-build
# phase (Xcode "Run Script" / CI step / make target) in the server project
# that uses MIOServerKit, e.g.:
#
#   Scripts/generate_endpoints.sh --sources Sources/MyServer \
#       --output Sources/MyServer/Endpoints+Generated.swift
#
# All arguments are forwarded to the generate-endpoints tool (see --help).

set -euo pipefail

PACKAGE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

swift run --package-path "$PACKAGE_DIR" generate-endpoints "$@"
