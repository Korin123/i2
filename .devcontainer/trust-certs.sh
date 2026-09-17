#!/usr/bin/env bash
# The Azure tools are baked into the dev container image (.devcontainer/image). This only
# does the per-PC part, with no downloads, so it works on any network:
#   - trust any organisation root CA put in .devcontainer/certs (git-ignored). Networks that
#     inspect TLS re-sign traffic with it, which breaks az, curl and pip until it is trusted.
#   - make sure the ~/.azure volume (az login) is writable.
# Run by onCreateCommand; safe to run again by hand: bash .devcontainer/trust-certs.sh
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

sudo chown "$(id -u):$(id -g)" "$HOME/.azure" 2>/dev/null || true

shopt -s nullglob
certs=("$here"/certs/*.crt "$here"/certs/*.cer "$here"/certs/*.pem)
if (( ${#certs[@]} )); then
  for c in "${certs[@]}"; do
    dest="/etc/pki/ca-trust/source/anchors/$(basename "${c%.*}").crt"
    if grep -q "BEGIN CERTIFICATE" "$c"; then sudo cp "$c" "$dest"
    else openssl x509 -inform der -in "$c" | sudo tee "$dest" >/dev/null; fi   # Windows DER export
  done
  sudo update-ca-trust
  echo ">>> Trusted ${#certs[@]} extra root CA(s) from .devcontainer/certs"
fi
