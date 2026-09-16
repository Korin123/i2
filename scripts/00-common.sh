#!/usr/bin/env bash
# Shared helpers. Source env.sh (copied from env.example) before running.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$here/env.sh" ] && source "$here/env.sh"
: "${RG:?set RG}"; : "${LOCATION:?set LOCATION}"; : "${KV:?set KV}"
log() { echo ">>> $*"; }
ns=i2analyze
export PATH="$PATH:$HOME/.local/bin"

# kubectl, kubelogin and jq, installed to ~/.local/bin only if missing (no sudo), so the
# same scripts run in the dev container and on a bare self-hosted agent.
ensure_tools() {
  mkdir -p "$HOME/.local/bin"
  if ! command -v kubectl >/dev/null || ! command -v kubelogin >/dev/null; then
    log "installing kubectl + kubelogin to ~/.local/bin"
    az aks install-cli --install-location "$HOME/.local/bin/kubectl" \
      --kubelogin-install-location "$HOME/.local/bin/kubelogin" >/dev/null 2>&1
  fi
  if ! command -v jq >/dev/null; then
    log "installing jq to ~/.local/bin"
    curl -fsSL -o "$HOME/.local/bin/jq" https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-amd64
    chmod +x "$HOME/.local/bin/jq"
  fi
}

# Credentials for the private AKS cluster (Entra ID via the az login / service connection).
aks_login() {
  : "${AKS:?set AKS}"
  ensure_tools
  az aks get-credentials -g "$RG" -n "$AKS" --overwrite-existing >/dev/null
  kubelogin convert-kubeconfig -l azurecli >/dev/null
}

# Fail early if an image the deploy needs is not in ACR (images are built locally by
# scripts/30-build-images.sh, so a deploy can otherwise run against missing/stale tags).
# Set SKIP_IMAGE_CHECK=true to bypass.
require_images() { # repo:tag ...
  local skip="${SKIP_IMAGE_CHECK:-false}"
  [[ "${skip,,}" == true ]] && return
  : "${ACR:?set ACR}"
  local img missing=()
  for img in "$@"; do
    az acr manifest show-metadata --registry "$ACR" --name "$img" >/dev/null 2>&1 || missing+=("$img")
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    printf 'Missing in %s.azurecr.io (run scripts/30-build-images.sh):\n' "$ACR" >&2
    printf '  %s\n' "${missing[@]}" >&2
    exit 1
  fi
  log "images present in ACR: $*"
}
