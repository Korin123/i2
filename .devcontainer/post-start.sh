#!/usr/bin/env bash
# Every start: next-step hints. ADT's own bootstrap has already relinked the
# environment (manage-environment -t link) if ADT is installed.
set -euo pipefail

if [[ ! -x "${WORKSPACE:-}/scripts/manage-environment" ]]; then
  echo ">>> In this repo ADT is installed into adt/ by: scripts/05-install-adt.sh"
fi
[ -f scripts/env.sh ] || echo ">>> Copy scripts/env.example to scripts/env.sh and fill it in."
