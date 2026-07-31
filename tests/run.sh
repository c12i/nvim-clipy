#!/bin/sh
# Runs tests/client_test.lua headlessly and propagates its exit code.
set -eu
cd "$(dirname "$0")/.."
exec nvim --headless --clean -u NONE -c "luafile tests/client_test.lua"
