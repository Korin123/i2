#!/usr/bin/env bash
# Azure equivalent of the i2 pki + provision_secrets roles. Generates the CA and
# per-service leaf certs and the i2 password set, and stores them in Key Vault.
# Idempotent: a secret is created only if absent (never re-passwords a live system).
source "$(dirname "$0")/00-common.sh"

kv_has() { az keyvault secret show --vault-name "$KV" -n "$1" >/dev/null 2>&1; }
kv_set() { az keyvault secret set --vault-name "$KV" -n "$1" --value "$2" 1>/dev/null; }
kv_set_file() { az keyvault secret set --vault-name "$KV" -n "$1" --file "$2" 1>/dev/null; }
rand_pw() { echo "$(openssl rand -base64 30 | tr -dc 'A-Za-z0-9' | head -c 24)"; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT; cd "$tmp"

# Passwords (i2 secret set). solr-auth is shared by Solr BasicAuth and ZK digest.
for s in db-postgres-password db-dba-password db-dbb-password db-etl-password \
         db-i2etl-password db-i2analyze-password db-i2public-password \
         liberty-admin-password solr-auth-password; do
  kv_has "$s" || { kv_set "$s" "$(rand_pw)"; log "seeded $s"; }
done

# PKI - CA once, then leaf cert/key per component. Regenerate only if the CA is absent.
if ! kv_has i2-ca-cert; then
  log "generating CA"
  openssl req -x509 -newkey rsa:4096 -nodes -keyout ca.key -out ca.cer -days 3650 -subj "/CN=i2 Analyze Internal CA"
  kv_set_file i2-ca-cert ca.cer
  kv_set_file i2-ca-key  ca.key
else
  az keyvault secret show --vault-name "$KV" -n i2-ca-cert --query value -o tsv > ca.cer
  az keyvault secret show --vault-name "$KV" -n i2-ca-key  --query value -o tsv > ca.key
fi

leaf() { # name  "SAN,SAN,..."
  local name="$1" sans="$2"
  kv_has "${name}-cert" && { log "${name} cert exists"; return; }
  openssl req -newkey rsa:4096 -nodes -keyout "${name}.key" -out "${name}.csr" -subj "/CN=${name}"
  printf "subjectAltName=%s" "$sans" > "${name}.ext"
  openssl x509 -req -in "${name}.csr" -CA ca.cer -CAkey ca.key -CAcreateserial \
    -out "${name}.cer" -days 825 -extfile "${name}.ext"
  kv_set_file "${name}-cert" "${name}.cer"
  kv_set_file "${name}-key"  "${name}.key"
  log "seeded ${name} cert/key"
}

leaf postgres   "DNS:postgres,DNS:localhost"
leaf solr       "DNS:solr,DNS:solr-headless,DNS:localhost"
leaf zookeeper  "DNS:zookeeper,DNS:zookeeper-headless,DNS:localhost"
leaf liberty    "DNS:liberty,DNS:i2-analyze.internal,DNS:localhost"
leaf jwt        "DNS:jwt"
leaf gateway    "DNS:external_gateway_user"
log "PKI + secret set seeded into $KV"
