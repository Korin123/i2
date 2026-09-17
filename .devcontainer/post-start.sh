#!/usr/bin/env bash
# Every start: next-step hints. In the ADT configuration, ADT's own bootstrap has
# already relinked the environment (manage-environment -t link) if ADT is installed.
set -euo pipefail

if [[ "${I2_DEVCONTAINER:-}" == azure ]]; then
  echo ">>> Azure tools container: deploy with scripts/10, 20, 40, 50, 60."
  echo "    Building images (scripts/05, 30) needs the 'ADT + Azure' container opened from WSL."
elif [[ ! -x "${WORKSPACE:-}/scripts/manage-environment" ]]; then
  echo ">>> In this repo ADT is installed into adt/ by: scripts/05-install-adt.sh"
fi
[ -f scripts/env.sh ] || echo ">>> Copy scripts/env.example to scripts/env.sh and fill it in."
