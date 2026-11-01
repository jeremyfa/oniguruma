#!/bin/bash
# Build and run the tests with Node.js.
# Usage: ./run.sh [filter]
set -e
cd "$(dirname "$0")"
HAXE="${HAXE:-haxe}"
"$HAXE" build.hxml
node bin/test.js fixtures "$@"
