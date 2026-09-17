#!/usr/bin/env bash
# Azure tooling on top of i2's ADT dev image (UBI 9 minimal): az, Bicep, kubectl, kubelogin.
# The MS devcontainer features are apt-only, hence installing here. Run by both
# configurations' onCreateCommand (after ADT's own bootstrap in the ADT configuration).
set -euo pipefail

mkdir -p "$HOME/.local/bin"
# a new named volume mounted at ~/.azure is root-owned; az needs to write there
sudo chown "$(id -u):$(id -g)" "$HOME/.azure" 2>/dev/null || true

# az in a venv (the azure-cli RPM pulls deps that are not in the UBI repos)
if ! command -v az >/dev/null; then
  sudo microdnf install -y python3.12 python3.12-pip >/dev/null
  python3.12 -m venv "$HOME/.local/azure-cli"
  "$HOME/.local/azure-cli/bin/pip" install -q --upgrade pip azure-cli
  ln -sf "$HOME/.local/azure-cli/bin/az" "$HOME/.local/bin/az"
fi
export PATH="$PATH:$HOME/.local/bin"

az bicep install
az aks install-cli \
  --install-location "$HOME/.local/bin/kubectl" \
  --kubelogin-install-location "$HOME/.local/bin/kubelogin" 2>/dev/null
