#!/bin/bash
# Compare iPhone screenshots with content-only v3 references. See --help.
set -euo pipefail
exec python3 "$(dirname "$0")/compare.py" "$@"
