#!/usr/bin/env bash
# One-time setup on top of i2's ADT dev image (UBI 9 minimal): join ADT's docker
# network, then add the Azure tooling. The MS devcontainer features are apt-only,
# hence installing here.
set -euo pipefail

# Same as ADT's .devcontainer/bootstrap create: ADT's containers run on network "eia"
if [[ -z "$(docker network ls -q --filter name='^eia$')" ]]; then
  docker network create eia
fi
docker network connect eia "${HOSTNAME}" 2>/dev/null || true

mkdir -p "$HOME/.local/bin"

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
