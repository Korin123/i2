#!/usr/bin/env bash
# Shared helpers. Source env.sh (copied from env.example) before running.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$here/env.sh" ] && source "$here/env.sh"
: "${RG:?set RG}"; : "${LOCATION:?set LOCATION}"; : "${KV:?set KV}"
log() { echo ">>> $*"; }
