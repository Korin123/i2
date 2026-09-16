# Certificates and secrets

Everything lives in Key Vault. `scripts/20-seed-secrets-pki.sh` only **adds what is missing**. It never changes an existing password.

## Reissue certificates

Needed after a change to certificate names (SANs), or before they expire (825 days).
```bash
REISSUE_CERTS="solr zookeeper" scripts/20-seed-secrets-pki.sh
kubectl rollout restart statefulset/zookeeper statefulset/solr -n i2analyze
```
You can reissue `solr`, `solr-client`, `zookeeper`, `liberty`, `jwt`, `gateway` and `postgres`. Restart whatever uses them (for `liberty`, `deployment/liberty`). In the pipeline, put the names in **Secrets: reissue these certs**.

## Add a new secret

Add its name to the list in `scripts/20-seed-secrets-pki.sh`, run the script, map it in `k8s/secretproviderclass.yaml`, then redeploy `base` and restart the pods that use it.

## Change a password

The script will not do this, on purpose: the database and Solr hold their own copy of each password.
- **Solr users:** set the new value in Key Vault, run `REGENERATE_SOLR_SECURITY=true scripts/20-seed-secrets-pki.sh`, re-run Solr setup ([rerun-init-jobs.md](rerun-init-jobs.md)), then restart Solr and Liberty.
- **Database logins:** change the login on the Managed Instance first (`ALTER LOGIN ... WITH PASSWORD`), then set the same value in Key Vault and restart Liberty.

Pods read secrets when they start, so restart them after any change.
