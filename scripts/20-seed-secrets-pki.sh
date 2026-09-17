#!/usr/bin/env bash
# Azure equivalent of the i2 pki + provision_secrets roles. Generates the CA and
# per-service leaf certs and the i2 password set, and stores them in Key Vault.
# Idempotent: a secret is created only if absent (never re-passwords a live system).
# Solr/ZK secrets follow ADT 3.2.2 (utils/common_variables.sh, src/adt/secrets):
#   Solr BasicAuth users  solr (admin) + liberty (application), security.json in ZK
#   ZK digest users       solr + readonly-user
# Reissue named leaf certs (e.g. after a SAN change): REISSUE_CERTS="solr zookeeper" $0
source "$(dirname "$0")/00-common.sh"
azure_outputs

kv_has() { az keyvault secret show --vault-name "$KV" -n "$1" >/dev/null 2>&1; }
kv_get() { az keyvault secret show --vault-name "$KV" -n "$1" --query value -o tsv; }
kv_set() { az keyvault secret set --vault-name "$KV" -n "$1" --value "$2" 1>/dev/null; }
kv_set_file() { az keyvault secret set --vault-name "$KV" -n "$1" --file "$2" 1>/dev/null; }
rand_pw() { echo "$(openssl rand -base64 30 | tr -dc 'A-Za-z0-9' | head -c 24)"; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT; cd "$tmp"

# Passwords (i2 secret set).
seeded_solr_users=false
for s in db-postgres-password db-dba-password db-dbb-password db-etl-password \
         db-i2etl-password db-i2analyze-password db-i2public-password \
         liberty-admin-password \
         solr-admin-digest-password solr-application-digest-password \
         zk-digest-password zk-digest-readonly-password; do
  kv_has "$s" && continue
  kv_set "$s" "$(rand_pw)"; log "seeded $s"
  [[ "$s" == solr-*-digest-password ]] && seeded_solr_users=true
done

# Solr security.json (BasicAuth + rule-based authz), as ADT's create_solr_security:
# credential = base64(sha256(sha256(salt_bytes + password))) + " " + base64(salt).
# Regenerated whenever a Solr user password was (re)seeded, or with REGENERATE_SOLR_SECURITY=true
# (after changing a Solr password in Key Vault).
solr_cred() { # password
  local salt; salt="$(openssl rand 32 | base64)"
  local digest; digest="$( { printf '%s' "$salt" | base64 -d; printf '%s' "$1"; } \
    | openssl dgst -sha256 -binary | openssl dgst -sha256 -binary | base64)"
  echo "$digest $salt"
}
regen="${REGENERATE_SOLR_SECURITY:-false}"
if $seeded_solr_users || [[ "${regen,,}" == true ]] || ! kv_has solr-security-json; then
  cat > security.json <<EOF
{
  "authentication": {
    "blockUnknown": true,
    "class": "solr.BasicAuthPlugin",
    "credentials": {
      "liberty": "$(solr_cred "$(kv_get solr-application-digest-password)")",
      "solr": "$(solr_cred "$(kv_get solr-admin-digest-password)")"
    },
    "realm": "My Solr users",
    "forwardCredentials": false
  },
  "authorization": {
    "class": "solr.RuleBasedAuthorizationPlugin",
    "user-role": { "solr": "admin", "liberty": "client" },
    "permissions": [
      { "name": "security-edit", "role": "admin" },
      { "name": "read", "role": "client" }
    ]
  }
}
EOF
  kv_set_file solr-security-json security.json
  log "seeded solr-security-json (re-run the solr-zk-init Job to push it to ZooKeeper)"
fi

# Trust for external systems (ADT SSL_ADDITIONAL_TRUST_CERTIFICATES): certificate checks
# cannot be turned off, and Managed Instance presents a certificate from a public Microsoft
# chain, not our internal CA. Seeds the Azure SQL root CAs once. No outbound internet on the
# agent? Supply a PEM bundle: TRUST_CERTS_FILE=roots.pem. Refresh: REFRESH_TRUST_CERTS=true.
TRUST_CERT_URLS=(
  "https://cacerts.digicert.com/DigiCertGlobalRootG2.crt.pem"
  "https://cacerts.digicert.com/DigiCertGlobalRootCA.crt.pem"
  "https://www.microsoft.com/pkiops/certs/Microsoft%20RSA%20Root%20Certificate%20Authority%202017.crt"
)
refresh="${REFRESH_TRUST_CERTS:-false}"
if [[ "${refresh,,}" == true ]] || ! kv_has ssl-additional-trust-certificates; then
  : > trust.pem
  if [[ -n "${TRUST_CERTS_FILE:-}" ]]; then
    cat "$TRUST_CERTS_FILE" >> trust.pem
  else
    for url in "${TRUST_CERT_URLS[@]}"; do
      curl -fsSL "$url" -o root.crt
      # DigiCert serves PEM, Microsoft serves DER
      openssl x509 -in root.crt -out root.pem 2>/dev/null || openssl x509 -inform DER -in root.crt -out root.pem
      cat root.pem >> trust.pem
    done
  fi
  grep -q "BEGIN CERTIFICATE" trust.pem || { echo "no certificates in the trust bundle" >&2; exit 1; }
  kv_set_file ssl-additional-trust-certificates trust.pem
  log "seeded ssl-additional-trust-certificates ($(grep -c 'BEGIN CERTIFICATE' trust.pem) certs)"
fi

# PKI - CA once, then leaf cert/key per component. Regenerate only if the CA is absent.
if ! kv_has i2-ca-cert; then
  log "generating CA"
  openssl req -x509 -newkey rsa:4096 -nodes -keyout ca.key -out ca.cer -days 3650 -subj "/CN=i2 Analyze Internal CA"
  kv_set_file i2-ca-cert ca.cer
  kv_set_file i2-ca-key  ca.key
else
  kv_get i2-ca-cert > ca.cer
  kv_get i2-ca-key  > ca.key
fi

leaf() { # name  "SAN,SAN,..."  [extendedKeyUsage]
  local name="$1" sans="$2" eku="${3:-serverAuth,clientAuth}"
  if kv_has "${name}-cert" && [[ " ${REISSUE_CERTS:-} " != *" ${name} "* ]]; then
    log "${name} cert exists"; return
  fi
  openssl req -newkey rsa:4096 -nodes -keyout "${name}.key" -out "${name}.csr" -subj "/CN=${name}"
  printf "subjectAltName=%s\nextendedKeyUsage=%s\n" "$sans" "$eku" > "${name}.ext"
  openssl x509 -req -in "${name}.csr" -CA ca.cer -CAkey ca.key -CAcreateserial \
    -out "${name}.cer" -days 825 -extfile "${name}.ext"
  kv_set_file "${name}-cert" "${name}.cer"
  kv_set_file "${name}-key"  "${name}.key"
  log "seeded ${name} cert/key"
}

# StatefulSet pods are addressed per pod (SOLR_HOST, ZK_HOST), so cover the headless
# service subdomains, short and fully qualified.
ns=i2analyze   # namespace in the cert SANs
svc_sans() { # service
  echo "DNS:$1,DNS:$1.$ns.svc.cluster.local,DNS:*.$1,DNS:*.$1.$ns,DNS:*.$1.$ns.svc.cluster.local"
}
leaf postgres    "DNS:postgres,DNS:localhost"
leaf solr        "DNS:solr,$(svc_sans solr-headless),DNS:localhost"
leaf solr-client "DNS:solr-client" clientAuth
leaf zookeeper   "DNS:zookeeper,$(svc_sans zookeeper-headless),DNS:localhost"
leaf liberty     "DNS:liberty,DNS:liberty.$ns.svc.cluster.local,DNS:i2-analyze.internal,DNS:localhost"
leaf jwt         "DNS:jwt"
leaf gateway     "DNS:external_gateway_user" clientAuth
log "PKI + secret set seeded into $KV"
