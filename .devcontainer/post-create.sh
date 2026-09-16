#!/usr/bin/env bash
# One-time tool setup for the dev container.
set -euo pipefail

sudo apt-get update -qq
sudo apt-get install -y -qq openssl jq shellcheck >/dev/null

# kubectl + kubelogin (scripts/40-deploy-workload.sh, 60-sanity.sh), matched to what AKS expects
mkdir -p "$HOME/.local/bin"
az aks install-cli \
  --install-location "$HOME/.local/bin/kubectl" \
  --kubelogin-install-location "$HOME/.local/bin/kubelogin" >/dev/null

[ -f scripts/env.sh ] || echo ">>> Copy scripts/env.example to scripts/env.sh and fill it in."
