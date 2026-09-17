#!/usr/bin/env bash
# Every start: relink the ADT environment if it is installed (as ADT's own
# .devcontainer/bootstrap start does), otherwise say how to install it.
set -euo pipefail

if [[ "${I2_DEVCONTAINER:-}" == azure ]]; then
  echo ">>> Azure tools container: deploy with scripts/10, 20, 40, 50, 60."
  echo "    Building images (scripts/05, 30) needs the 'ADT + Azure' container opened from WSL."
elif [[ -x "${ANALYZE_CONTAINERS_ROOT_DIR:-}/scripts/manage-environment" ]]; then
  CONTINUE_ON_ERROR=true "${ANALYZE_CONTAINERS_ROOT_DIR}/scripts/manage-environment" -t link
  echo "Dev container ready (ADT linked)."
else
  echo ">>> ADT not installed. Run: scripts/05-install-adt.sh"
fi
[ -f scripts/env.sh ] || echo ">>> Copy scripts/env.example to scripts/env.sh and fill it in."
