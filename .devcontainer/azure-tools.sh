#!/usr/bin/env bash
# Azure tooling on top of i2's ADT dev image (UBI 9 minimal): az, Bicep, kubectl, kubelogin.
# The MS devcontainer features are apt-only, hence installing here. Run by onCreateCommand
# after ADT's own bootstrap; safe to run again by hand: bash .devcontainer/azure-tools.sh
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Networks that inspect TLS (corporate proxies) re-sign traffic with their own root CA.
# Trust any root CA put in .devcontainer/certs (git-ignored), then point Python at the
# system bundle, since pip and az use their own bundle otherwise.
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
bundle=/etc/pki/tls/certs/ca-bundle.crt
export PIP_CERT="$bundle" REQUESTS_CA_BUNDLE="$bundle" SSL_CERT_FILE="$bundle"

mkdir -p "$HOME/.local/bin"
# a new named volume mounted at ~/.azure is root-owned; az needs to write there
sudo chown "$(id -u):$(id -g)" "$HOME/.azure" 2>/dev/null || true

# az in a venv (the azure-cli RPM pulls deps that are not in the UBI repos)
if [ ! -x "$HOME/.local/bin/az" ]; then
  sudo microdnf install -y python3.12 python3.12-pip >/dev/null
  python3.12 -m venv "$HOME/.local/azure-cli"
  "$HOME/.local/azure-cli/bin/pip" install -q --upgrade pip azure-cli
  ln -sf "$HOME/.local/azure-cli/bin/az" "$HOME/.local/bin/az"
fi
export PATH="$PATH:$HOME/.local/bin"

az bicep install
az aks install-cli \
  --install-location "$HOME/.local/bin/kubectl" \
  --kubelogin-install-location "$HOME/.local/bin/kubelogin"
echo ">>> Azure tools installed: $(az version --query '\"azure-cli\"' -o tsv 2>/dev/null) - open a new terminal"
