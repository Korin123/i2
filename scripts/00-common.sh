#!/usr/bin/env bash
# Shared helpers. Settings come from scripts/env.sh (copied from env.example); Azure
# resource names come from the infra deployment's outputs (azure_outputs), because Bicep
# names and creates the resources.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$here/env.sh" ] && source "$here/env.sh"
log() { echo ">>> $*"; }
ns=i2analyze
export PATH="$PATH:$HOME/.local/bin"
# The subscription-scope deployment scripts/10-deploy-infra.sh creates and reads back.
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-i2-infra-alpha}"

# Resource names from the infra deployment outputs: RG, KV, ACR, AKS, WI_CLIENT_ID, MI_FQDN,
# plus TENANT_ID from the signed-in account. A value already set (env.sh or the environment)
# wins, so names can still be overridden.
azure_outputs() {
  [[ -n "${SUBSCRIPTION_ID:-}" ]] && az account set --subscription "$SUBSCRIPTION_ID"
  local names
  if ! names="$(az deployment sub show -n "$DEPLOYMENT_NAME" --query "[
        properties.outputs.resourceGroupName.value, properties.outputs.keyVaultName.value,
        properties.outputs.acrName.value, properties.outputs.aksClusterName.value,
        properties.outputs.workloadIdentityClientId.value, properties.outputs.sqlManagedInstanceFqdn.value]" \
        -o tsv 2>/dev/null)" || [[ -z "$names" ]]; then
    echo "No infra deployment '$DEPLOYMENT_NAME' found in this subscription - run scripts/10-deploy-infra.sh first" >&2
    exit 1
  fi
  local out_rg out_kv out_acr out_aks out_wi out_mi
  { read -r out_rg; read -r out_kv; read -r out_acr; read -r out_aks; read -r out_wi; read -r out_mi; } <<<"$names"
  RG="${RG:-$out_rg}"; KV="${KV:-$out_kv}"; ACR="${ACR:-$out_acr}"; AKS="${AKS:-$out_aks}"
  WI_CLIENT_ID="${WI_CLIENT_ID:-$out_wi}"; MI_FQDN="${MI_FQDN:-$out_mi}"
  TENANT_ID="${TENANT_ID:-$(az account show --query tenantId -o tsv)}"
  export RG KV ACR AKS WI_CLIENT_ID MI_FQDN TENANT_ID
}

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
  : "${AKS:?set AKS}"; : "${RG:?set RG}"
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
